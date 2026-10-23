;;; boardgame-org.el --- Tabletop game engine for Emacs with Org persistence -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implementation of boardgame.org conforming to boardgame-org.md and
;; boardgame-org-interface.md.
;; Provides dedicated Emacs frames, 3-window layout, persistent world log,
;; ZZT drawing mode, cross-board navigation markers, and canonical commands.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-log)
(require 'boardgame-org-status)
(require 'boardgame-org-frame)
(require 'boardgame-org-board)
(require 'boardgame-org-drawing)
(require 'boardgame-org-marker)
(require 'boardgame-org-object)
(require 'boardgame-org-stack)
(require 'boardgame-org-container)
(require 'boardgame-org-hand)

;;; Buffer-local Variables

(defvar-local boardgame--current-board nil)
(defvar-local boardgame--current-objects-alist nil)
(defvar-local boardgame--cursor-x 0)
(defvar-local boardgame--cursor-y 0)

;;; Mode & Keymap Definition

(defvar boardgame-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Navigation (compatible with vanilla Emacs & Evil normal mode)
    (define-key map (kbd "<right>") #'boardgame-cursor-right)
    (define-key map (kbd "<left>")  #'boardgame-cursor-left)
    (define-key map (kbd "<down>")  #'boardgame-cursor-down)
    (define-key map (kbd "<up>")    #'boardgame-cursor-up)
    (define-key map (kbd "l")       #'boardgame-cursor-right)
    (define-key map (kbd "h")       #'boardgame-cursor-left)
    (define-key map (kbd "j")       #'boardgame-cursor-down)
    (define-key map (kbd "k")       #'boardgame-cursor-up)
    (define-key map (kbd "C-f")     #'boardgame-cursor-right)
    (define-key map (kbd "C-b")     #'boardgame-cursor-left)
    (define-key map (kbd "C-n")     #'boardgame-cursor-down)
    (define-key map (kbd "C-p")     #'boardgame-cursor-up)
    ;; Canonical Operations
    (define-key map (kbd "?")       #'boardgame-menu)
    (define-key map (kbd "SPC")     #'boardgame-menu)
    (define-key map (kbd "<f6>")    #'boardgame-menu)
    (define-key map (kbd "m")       #'boardgame-move-object-at-point)
    (define-key map (kbd "H")       #'boardgame-take-object-to-hand)
    (define-key map (kbd "P")       #'boardgame-place-from-hand)
    (define-key map (kbd "S")       #'boardgame-create-stack)
    (define-key map (kbd "U")       #'boardgame-expand-stack-at-point)
    (define-key map (kbd "d")       #'boardgame-draw-from-container-at-point)
    (define-key map (kbd "s")       #'boardgame-save-board)
    (define-key map (kbd "o")       #'boardgame-open-object)
    (define-key map (kbd "i")       #'boardgame-describe-object)
    (define-key map (kbd "I")       #'boardgame-describe-object-extended)
    (define-key map (kbd "x")       #'boardgame-execute-object-block-at-point)
    (define-key map (kbd "^")       #'boardgame-create-marker)
    (define-key map (kbd "D")       #'boardgame-drawing-mode)
    (define-key map (kbd "q")       #'quit-window)
    map)
  "Keymap for `boardgame-mode`.")

(define-derived-mode boardgame-mode special-mode "Boardgame"
  "Major mode for the text-based tabletop environment."
  (setq truncate-lines t)
  (setq buffer-read-only t)
  (hl-line-mode -1))

;;; Navigation & Redraw

(defun boardgame-cursor-right ()
  "Move cursor right on the board felt."
  (interactive)
  (when (< boardgame--cursor-x (1- (boardgame-board-width boardgame--current-board)))
    (cl-incf boardgame--cursor-x)
    (when (and (bound-and-true-p boardgame-drawing-continuous)
               (bound-and-true-p boardgame-drawing-mode))
      (boardgame-draw-point-at boardgame--cursor-x boardgame--cursor-y))
    (boardgame-refresh-board)))

(defun boardgame-cursor-left ()
  "Move cursor left on the board felt."
  (interactive)
  (when (> boardgame--cursor-x 0)
    (cl-decf boardgame--cursor-x)
    (when (and (bound-and-true-p boardgame-drawing-continuous)
               (bound-and-true-p boardgame-drawing-mode))
      (boardgame-draw-point-at boardgame--cursor-x boardgame--cursor-y))
    (boardgame-refresh-board)))

(defun boardgame-cursor-down ()
  "Move cursor down on the board felt."
  (interactive)
  (when (< boardgame--cursor-y (1- (boardgame-board-height boardgame--current-board)))
    (cl-incf boardgame--cursor-y)
    (when (and (bound-and-true-p boardgame-drawing-continuous)
               (bound-and-true-p boardgame-drawing-mode))
      (boardgame-draw-point-at boardgame--cursor-x boardgame--cursor-y))
    (boardgame-refresh-board)))

(defun boardgame-cursor-up ()
  "Move cursor up on the board felt."
  (interactive)
  (when (> boardgame--cursor-y 0)
    (cl-decf boardgame--cursor-y)
    (when (and (bound-and-true-p boardgame-drawing-continuous)
               (bound-and-true-p boardgame-drawing-mode))
      (boardgame-draw-point-at boardgame--cursor-x boardgame--cursor-y))
    (boardgame-refresh-board)))

(defun boardgame-set-cursor-coord (x y)
  "Set cursor position directly to X and Y."
  (setq boardgame--cursor-x (max 0 (min x (1- (boardgame-board-width boardgame--current-board)))))
  (setq boardgame--cursor-y (max 0 (min y (1- (boardgame-board-height boardgame--current-board))))))

(defun boardgame-get-felt-at-point ()
  "Return character at current cursor position."
  (when boardgame--current-board
    (let ((row (aref (boardgame-board-felt-grid boardgame--current-board) boardgame--cursor-y)))
      (aref row boardgame--cursor-x))))

(defun boardgame-draw-point ()
  "Paint the active drawing character at current cursor."
  (interactive)
  (boardgame-draw-point-at boardgame--cursor-x boardgame--cursor-y)
  (boardgame-refresh-board))

(defun boardgame-draw-point-at (x y)
  "Set felt character at X, Y to `boardgame-drawing-char`."
  (when (and boardgame--current-board
             (>= x 0) (< x (boardgame-board-width boardgame--current-board))
             (>= y 0) (< y (boardgame-board-height boardgame--current-board)))
    (let ((row (aref (boardgame-board-felt-grid boardgame--current-board) y)))
      (aset row x boardgame-drawing-char)
      (setf (boardgame-board-dirty-p boardgame--current-board) t))))

(defun boardgame-draw-fill-region (start-x start-y end-x end-y)
  "Fill rectangular region with active drawing character."
  (interactive "nStart X: \nnStart Y: \nnEnd X: \nnEnd Y: ")
  (let ((x1 (min start-x end-x)) (x2 (max start-x end-x))
        (y1 (min start-y end-y)) (y2 (max start-y end-y)))
    (cl-loop for r from y1 to y2 do
             (cl-loop for c from x1 to x2 do
                      (boardgame-draw-point-at c r)))
    (boardgame-refresh-board)))

(defun boardgame-refresh-board ()
  "Refresh the board buffer rendering and update status area."
  (interactive)
  (when (and boardgame--current-board (get-buffer (current-buffer)))
    (let ((inhibit-read-only t)
          (hide-p (bound-and-true-p boardgame-objects-hidden-p)))
      (erase-buffer)
      ;; Column labels
      (insert "    ")
      (dotimes (c (boardgame-board-width boardgame--current-board))
        (insert (propertize (format " %c " (+ ?A c)) 'face 'boardgame-coord-face)))
      (insert "\n")
      ;; Rows
      (dotimes (r (boardgame-board-height boardgame--current-board))
        (insert (propertize (format "%3d " (1+ r)) 'face 'boardgame-coord-face))
        (dotimes (c (boardgame-board-width boardgame--current-board))
          (insert (boardgame-render-cell boardgame--current-board
                                        boardgame--current-objects-alist
                                        c r
                                        boardgame--cursor-x
                                        boardgame--cursor-y
                                        hide-p)))
        (insert "\n"))
      (goto-char (point-min))
      ;; Sync active status
      (let* ((placed (boardgame-board-objects-at boardgame--current-board
                                                boardgame--cursor-x
                                                boardgame--cursor-y))
             (top (car (last placed)))
             (top-obj (when top (cdr (assoc (boardgame-placed-object-id top)
                                            boardgame--current-objects-alist)))))
        (when (fboundp 'boardgame-status-refresh)
          (boardgame-status-refresh boardgame--current-board
                                   boardgame--cursor-x
                                   boardgame--cursor-y
                                   top-obj
                                   (when (fboundp 'boardgame-drawing-info)
                                     (boardgame-drawing-info))))))))

;;; Canonical Board Commands

(defun boardgame-save-board ()
  "Serialize the current in-memory board state to its associated Org file.
Saves the world log and commits to Git per Section 5 & 12.8."
  (interactive)
  (unless boardgame--current-board
    (error "No board loaded to save"))
  (let ((full-path (boardgame-world-file (boardgame-board-file-path boardgame--current-board))))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (boardgame-board-serialize boardgame--current-board boardgame--current-objects-alist)))
    (setf (boardgame-board-dirty-p boardgame--current-board) nil)
    ;; Save world log automatically whenever any board is saved
    (when (fboundp 'boardgame-log-save) (boardgame-log-save))
    (boardgame-git-commit (format "Saved board %s" (boardgame-board-filename boardgame--current-board)))
    (message "Board '%s' saved successfully." (boardgame-board-filename boardgame--current-board))))

(defun boardgame-save-board-as (new-filename)
  "Save the current board under a new file name selected by the user."
  (interactive "sSave board as filename (e.g. new-map.org): ")
  (unless boardgame--current-board
    (error "No board loaded"))
  (let ((clean-name (if (string-suffix-p ".org" new-filename) new-filename (concat new-filename ".org"))))
    (setf (boardgame-board-filename boardgame--current-board) clean-name)
    (setf (boardgame-board-file-path boardgame--current-board) (format "boards/%s" clean-name))
    (boardgame-save-board)
    (rename-buffer (format "*boardgame: %s*" clean-name) t)))

(defun boardgame-close-board ()
  "Close a board buffer after resolving any unsaved changes."
  (interactive)
  (when (and boardgame--current-board (boardgame-board-dirty-p boardgame--current-board))
    (when (y-or-n-p "Board has unsaved changes. Save before closing? ")
      (boardgame-save-board)))
  (kill-buffer (current-buffer)))

;;; Object Operations

(defun boardgame-describe-object ()
  "Display the names and symbols of objects at current cursor in side log."
  (interactive)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y))
         (felt-char (boardgame-get-felt-at-point)))
    (if (null placed)
        (progn
          (when (fboundp 'boardgame-log)
            (boardgame-log "Cell Inspected"
                           `(("Coordinates" . ,(format "(%c, %d)" (+ ?A boardgame--cursor-x) (1+ boardgame--cursor-y)))
                             ("Felt" . ,(format "'%s'" felt-char))
                             ("Objects" . "None"))))
          (message "Felt: '%s' (empty)" felt-char))
      (let ((details (mapcar (lambda (p)
                               (let ((obj (cdr (assoc (boardgame-placed-object-id p) boardgame--current-objects-alist))))
                                 (format "%s %s (%s)"
                                         (if obj (boardgame-object-glyph obj) "♟")
                                         (if obj (boardgame-object-name obj) (boardgame-placed-object-id p))
                                         (if obj (boardgame-object-type obj) "token"))))
                             placed)))
        (when (fboundp 'boardgame-log)
          (boardgame-log "Cell Inspected"
                         `(("Coordinates" . ,(format "(%c, %d)" (+ ?A boardgame--cursor-x) (1+ boardgame--cursor-y)))
                           ("Felt" . ,(format "'%s'" felt-char))
                           ("Objects" . ,(string-join details "\n")))))
        (message "%s" (string-join details ", "))))))

(defun boardgame-describe-object-extended ()
  "Display object information and attempt to execute its description block."
  (interactive)
  (boardgame-describe-object)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y))
         (top (car (last placed)))
         (top-obj (when top (cdr (assoc (boardgame-placed-object-id top) boardgame--current-objects-alist)))))
    (if (and top-obj (boardgame-object-description top-obj) (> (length (boardgame-object-description top-obj)) 0))
        (when (fboundp 'boardgame-log)
          (boardgame-log (format "Description: %s" (boardgame-object-name top-obj))
                         nil (boardgame-object-description top-obj)))
      (when (fboundp 'boardgame-log)
        (boardgame-log "Description Block" nil "Description not found.")))))

(defun boardgame-open-object ()
  "Open the Org file associated with the object under the cursor."
  (interactive)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y))
         (top (car (last placed)))
         (top-obj (when top (cdr (assoc (boardgame-placed-object-id top) boardgame--current-objects-alist)))))
    (if (null top-obj)
        (message "No object under cursor.")
      (find-file-other-window (boardgame-world-file (boardgame-object-file-path top-obj))))))

(defun boardgame-execute-object-block-at-point ()
  "Execute the source block belonging to the object under cursor."
  (interactive)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y))
         (top (car (last placed)))
         (top-obj (when top (cdr (assoc (boardgame-placed-object-id top) boardgame--current-objects-alist)))))
    (if (null top-obj)
        (message "No object under cursor.")
      (boardgame-execute-object-block top-obj))))

(defun boardgame-take-object-to-hand ()
  "Take object at cursor into player hand.
Per Section 9.7: if over container or stack, extracts the top item from it."
  (interactive)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y))
         (top (car (last placed)))
         (top-obj (when top (cdr (assoc (boardgame-placed-object-id top) boardgame--current-objects-alist)))))
    (if (null top)
        (message "No object at cursor to take.")
      (cond
       ;; If top object is a container: draw top item from it
       ((eq (boardgame-object-type top-obj) 'container)
        (let ((drawn (boardgame-container-draw-top top-obj)))
          (when (fboundp 'boardgame-log)
            (boardgame-log "Item Drawn to Hand"
                           `(("Container" . ,(boardgame-object-name top-obj))
                             ("Item" . ,drawn))))
          (message "Drawn %s from %s into hand." drawn (boardgame-object-name top-obj))))
       ;; If top object is a stack: expand top item
       ((eq (boardgame-object-type top-obj) 'stack)
        (message "Use [U] to expand stack or draw an item."))
       ;; Normal object: take to hand
       (t
        (let ((obj-id (boardgame-placed-object-id top)))
          (setf (boardgame-board-placed-objects boardgame--current-board)
                (delete top (boardgame-board-placed-objects boardgame--current-board)))
          (boardgame-refresh-board)
          (when (fboundp 'boardgame-log)
            (boardgame-log "Object Taken to Hand" `(("Object" . ,obj-id))))
          (message "Taken %s into hand." (boardgame-object-name top-obj))))))))

(defun boardgame-place-from-hand ()
  "Place selected item from active hand onto the board at current cursor."
  (interactive)
  (boardgame-open-hand)
  (message "Position cursor on the heading to place and press M-x boardgame-place-heading-on-board"))

(defun boardgame-create-stack ()
  "Explicitly consolidate objects at current cell into a stack."
  (interactive)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y)))
    (if (< (length placed) 2)
        (message "Need at least 2 objects to create a stack.")
      (let* ((stack-id (format "stack-%s" (format-time-string "%Y%m%d%H%M%S")))
             (stack-name (read-string "Stack Name: " "Consolidated Stack"))
             (objs (mapcar (lambda (p) (cdr (assoc (boardgame-placed-object-id p) boardgame--current-objects-alist))) placed))
             (stack-obj (boardgame-stack-consolidate objs stack-id stack-name)))
        (setf (boardgame-board-placed-objects boardgame--current-board)
              (cl-remove-if (lambda (p) (and (= (boardgame-placed-x p) boardgame--cursor-x)
                                             (= (boardgame-placed-y p) boardgame--cursor-y)))
                            (boardgame-board-placed-objects boardgame--current-board)))
        (push (boardgame-placed-create :object-id stack-id :x boardgame--cursor-x :y boardgame--cursor-y :layer 0)
              (boardgame-board-placed-objects boardgame--current-board))
        (push (cons stack-id stack-obj) boardgame--current-objects-alist)
        (boardgame-save-board)
        (boardgame-refresh-board)
        (when (fboundp 'boardgame-log)
          (boardgame-log "Stack Created"
                         `(("Stack ID" . ,stack-id)
                           ("Items" . ,(format "%d objects consolidated" (length objs))))))
        (message "Consolidated into stack '$' (black on white).")))))

(defun boardgame-expand-stack-at-point ()
  "Expand stack at current cursor back into independent objects."
  (interactive)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y))
         (top (car (last placed)))
         (top-obj (when top (cdr (assoc (boardgame-placed-object-id top) boardgame--current-objects-alist)))))
    (if (or (null top-obj) (not (eq (boardgame-object-type top-obj) 'stack)))
        (message "Object at cursor is not a stack.")
      (let ((restored (boardgame-stack-expand top-obj)))
        (setf (boardgame-board-placed-objects boardgame--current-board)
              (delete top (boardgame-board-placed-objects boardgame--current-board)))
        (cl-loop for obj in restored
                 for layer from 0
                 do (push (cons (boardgame-object-id obj) obj) boardgame--current-objects-alist)
                    (push (boardgame-placed-create :object-id (boardgame-object-id obj)
                                                   :x boardgame--cursor-x
                                                   :y boardgame--cursor-y
                                                   :layer layer)
                          (boardgame-board-placed-objects boardgame--current-board)))
        (boardgame-save-board)
        (boardgame-refresh-board)
        (message "Expanded stack into %d independent objects." (length restored))))))

(defun boardgame-draw-from-container-at-point ()
  "Draw top item from container under cursor."
  (interactive)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y))
         (top (car (last placed)))
         (top-obj (when top (cdr (assoc (boardgame-placed-object-id top) boardgame--current-objects-alist)))))
    (if (or (null top-obj) (not (eq (boardgame-object-type top-obj) 'container)))
        (message "Object under cursor is not a container.")
      (let ((drawn (boardgame-container-draw-top top-obj)))
        (when (fboundp 'boardgame-log)
          (boardgame-log "Card Drawn"
                         `(("Container" . ,(boardgame-object-name top-obj))
                           ("Drawn" . ,drawn))))
        (message "Drawn: %s" drawn)))))

(defun boardgame-move-object-at-point ()
  "Move object at point to target coordinates."
  (interactive)
  (let* ((placed (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y))
         (top (car (last placed))))
    (if (null top)
        (message "No object under cursor to move.")
      (let* ((target-col-char (read-char-choice "Target Column [A-P]: "
                                                '(?a ?b ?c ?d ?e ?f ?g ?h ?i ?j ?k ?l ?m ?n ?o ?p
                                                  ?A ?B ?C ?D ?E ?F ?G ?H ?I ?J ?K ?L ?M ?N ?O ?P)))
             (tx (- (upcase target-col-char) ?A))
             (ty (1- (read-number "Target Row (1-10): " 1))))
        (setf (boardgame-placed-x top) tx)
        (setf (boardgame-placed-y top) ty)
        (setq boardgame--cursor-x tx)
        (setq boardgame--cursor-y ty)
        (boardgame-refresh-board)
        (message "Moved object to (%c, %d)." (+ ?A tx) (1+ ty))))))

;;; Interactive Menu

(defun boardgame-menu ()
  "Display interactive command menu for boardgame operations."
  (interactive)
  (let ((c (read-char-choice
            "[m]ove [H]and [P]lay [S]tack [U]nstack [d]raw [^]marker [D]raw-mode [i]nspect [s]ave [q]uit: "
            '(?m ?H ?P ?S ?U ?d ?^ ?D ?i ?s ?q))))
    (pcase c
      (?m (call-interactively #'boardgame-move-object-at-point))
      (?H (call-interactively #'boardgame-take-object-to-hand))
      (?P (call-interactively #'boardgame-place-from-hand))
      (?S (call-interactively #'boardgame-create-stack))
      (?U (call-interactively #'boardgame-expand-stack-at-point))
      (?d (call-interactively #'boardgame-draw-from-container-at-point))
      (?^ (call-interactively #'boardgame-create-marker))
      (?D (call-interactively #'boardgame-drawing-mode))
      (?i (call-interactively #'boardgame-describe-object))
      (?s (call-interactively #'boardgame-save-board)))))

;;; Board Buffer Loader

(defun boardgame-load-or-find-board-buffer (file-path filename)
  "Load board from FILE-PATH or return existing buffer."
  (let ((buf-name (format "*boardgame: %s*" filename)))
    (if (get-buffer buf-name)
        (get-buffer buf-name)
      (let ((buf (get-buffer-create buf-name)))
        (with-current-buffer buf
          (boardgame-mode)
          (if (file-exists-p file-path)
              (setq boardgame--current-board
                    (with-temp-buffer
                      (insert-file-contents file-path)
                      (org-mode)
                      (boardgame-board-parse-buffer file-path filename)))
            ;; Initialize missing board
            (let* ((w 16) (h 10)
                   (grid (boardgame-normalize-felt "" w h ".")))
              (setq boardgame--current-board
                    (boardgame-board-create
                     :id (file-name-sans-extension filename)
                     :name (file-name-sans-extension filename)
                     :filename filename
                     :width w :height h :default-felt "."
                     :felt-grid grid
                     :placed-objects nil
                     :file-path file-path
                     :dirty-p nil))))
          (setq boardgame-current-board-buffer buf)
          (boardgame-refresh-board))
        buf))))

;;; Public Startup Command

;;;###autoload
(defun boardgame-start (&optional world-dir)
  "Start dedicated Emacs game frame with 3-window layout.
If WORLD-DIR is provided, activate it; otherwise use
`boardgame-default-world-directory` or prompt user."
  (interactive)
  (let ((target-dir (or world-dir
                        boardgame-default-world-directory
                        (read-directory-name "Select or create world directory: "
                                             (expand-file-name "~/boardgame-world/")))))
    (setq boardgame-active-world-directory (expand-file-name target-dir))
    (boardgame-ensure-world-dirs)
    (let* ((bfilename "main.org")
           (bpath (boardgame-world-file (format "boards/%s" bfilename)))
           (board-buf (boardgame-load-or-find-board-buffer bpath bfilename)))
      (boardgame-setup-game-frame board-buf)
      (when (fboundp 'boardgame-log)
        (boardgame-log "Game Started"
                       `(("World" . ,(boardgame-world-name))
                         ("Board" . ,bfilename))))
      (message "boardgame.org started in dedicated frame."))))

;;; Aliases for canonical commands
(defalias 'boardgame-open-world #'boardgame-start)
(defalias 'boardgame-create-world #'boardgame-start)
(defalias 'boardgame-open-board #'boardgame-start)

(provide 'boardgame-org)
;;; boardgame-org.el ends here
