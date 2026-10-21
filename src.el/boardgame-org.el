;;; boardgame-org.el --- Text-based tabletop environment in Emacs with Org-mode persistence -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Version: 1.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; An implementation of the boardgame-org tabletop environment adhering to the
;; architectural specifications defined in boardgame-org.md:
;; - Org documents as primary object identity and persistent representation.
;; - Distinction between Stacks (document consolidation) and Permanent Containers
;;   (organization without consolidation).
;; - In-memory model with round-trip Org serialization and felt normalization.
;; - Multi-object cell rendering with numeric count indicators (1-9, +).
;; - Git-based world repository history and recovery.
;; - Standard Emacs keymap without external dependencies.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-object)
(require 'boardgame-org-stack)
(require 'boardgame-org-container)
(require 'boardgame-org-hand)
(require 'boardgame-org-board)
(require 'boardgame-org-render)

;;; Buffer Local State

(defvar-local boardgame-org--current-board nil)
(defvar-local boardgame-org--current-objects-alist nil)
(defvar-local boardgame-org--current-hand nil)
(defvar-local boardgame-org--cursor-x 0)
(defvar-local boardgame-org--cursor-y 0)

;;; Major Mode Definition

(defvar boardgame-org-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<right>") #'boardgame-org-cursor-right)
    (define-key map (kbd "<left>")  #'boardgame-org-cursor-left)
    (define-key map (kbd "<down>")  #'boardgame-org-cursor-down)
    (define-key map (kbd "<up>")    #'boardgame-org-cursor-up)
    (define-key map (kbd "l")       #'boardgame-org-cursor-right)
    (define-key map (kbd "h")       #'boardgame-org-cursor-left)
    (define-key map (kbd "j")       #'boardgame-org-cursor-down)
    (define-key map (kbd "k")       #'boardgame-org-cursor-up)
    (define-key map (kbd "C-f")     #'boardgame-org-cursor-right)
    (define-key map (kbd "C-b")     #'boardgame-org-cursor-left)
    (define-key map (kbd "C-n")     #'boardgame-org-cursor-down)
    (define-key map (kbd "C-p")     #'boardgame-org-cursor-up)
    (define-key map (kbd "?")       #'boardgame-org-menu)
    (define-key map (kbd "SPC")     #'boardgame-org-menu)
    (define-key map (kbd "m")       #'boardgame-org-move-at-point)
    (define-key map (kbd "H")       #'boardgame-org-pickup-to-hand)
    (define-key map (kbd "P")       #'boardgame-org-play-from-hand)
    (define-key map (kbd "S")       #'boardgame-org-consolidate-stack-at-point)
    (define-key map (kbd "U")       #'boardgame-org-expand-stack-at-point)
    (define-key map (kbd "d")       #'boardgame-org-draw-from-container-at-point)
    (define-key map (kbd "s")       #'boardgame-org-shuffle-container-at-point)
    (define-key map (kbd "r")       #'boardgame-org-roll-die-at-point)
    (define-key map (kbd "F")       #'boardgame-org-flip-card-at-point)
    (define-key map (kbd "o")       #'boardgame-org-open-org-at-point)
    (define-key map (kbd "g")       #'boardgame-org-commit-action)
    (define-key map (kbd "q")       #'quit-window)
    map)
  "Keymap for `boardgame-org-mode`.")

(define-derived-mode boardgame-org-mode special-mode "Boardgame.org"
  "Major mode for the interactive text-based tabletop environment."
  (setq truncate-lines t)
  (setq buffer-read-only t)
  (hl-line-mode -1))

;;; Navigation Commands

(defun boardgame-org-cursor-right ()
  "Move cursor right on the board felt."
  (interactive)
  (when (< boardgame-org--cursor-x (1- (boardgame-org-board-width boardgame-org--current-board)))
    (cl-incf boardgame-org--cursor-x)
    (boardgame-org-refresh)))

(defun boardgame-org-cursor-left ()
  "Move cursor left on the board felt."
  (interactive)
  (when (> boardgame-org--cursor-x 0)
    (cl-decf boardgame-org--cursor-x)
    (boardgame-org-refresh)))

(defun boardgame-org-cursor-down ()
  "Move cursor down on the board felt."
  (interactive)
  (when (< boardgame-org--cursor-y (1- (boardgame-org-board-height boardgame-org--current-board)))
    (cl-incf boardgame-org--cursor-y)
    (boardgame-org-refresh)))

(defun boardgame-org-cursor-up ()
  "Move cursor up on the board felt."
  (interactive)
  (when (> boardgame-org--cursor-y 0)
    (cl-decf boardgame-org--cursor-y)
    (boardgame-org-refresh)))

(defun boardgame-org-refresh ()
  "Redraw the tabletop in current buffer."
  (interactive)
  (boardgame-org-render-board (current-buffer)
                              boardgame-org--current-board
                              boardgame-org--current-objects-alist
                              boardgame-org--cursor-x
                              boardgame-org--cursor-y)
  (boardgame-org--update-header-line))

(defun boardgame-org--update-header-line ()
  "Update header line with current point coordinates and top object."
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (count (length placed))
         (coord-name (format "%c%d"
                             (+ ?A boardgame-org--cursor-x)
                             (1+ boardgame-org--cursor-y)))
         (top (car (last placed)))
         (top-obj (when top
                    (cdr (assoc (boardgame-org-placed-object-id top)
                                boardgame-org--current-objects-alist))))
         (hand-count (length (boardgame-org-hand-object-ids boardgame-org--current-hand))))
    (setq header-line-format
          (format " [Point: %s (%d items)] %s | Hand: %d items | [?] Help"
                  coord-name
                  count
                  (if top-obj
                      (format "Top: %s %s (%s)"
                              (boardgame-org-object-glyph top-obj)
                              (boardgame-org-object-name top-obj)
                              (boardgame-org-object-type top-obj))
                    "Empty Felt")
                  hand-count))))

;;; Tabletop Gameplay Commands

(defun boardgame-org-move-at-point ()
  "Move object at point to a new coordinate."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (top (car (last placed))))
    (if (null top)
        (message "No object at point to move.")
      (let* ((obj-id (boardgame-org-placed-object-id top))
             (target-col-char (read-char-choice (format "Target Column [A-%c]: "
                                                        (+ ?A (1- (boardgame-org-board-width boardgame-org--current-board))))
                                                (mapcar (lambda (i) (+ ?A i))
                                                        (number-sequence 0 (1- (boardgame-org-board-width boardgame-org--current-board))))))
             (target-x (- (upcase target-col-char) ?A))
             (target-row (read-number (format "Target Row [1-%d]: "
                                              (boardgame-org-board-height boardgame-org--current-board))))
             (target-y (1- target-row)))
        (boardgame-org-board-move-object boardgame-org--current-board obj-id target-x target-y)
        (boardgame-org-board-save boardgame-org--current-board boardgame-org--current-objects-alist)
        (boardgame-org-git-commit (format "Moved %s to (%d, %d)" obj-id target-x target-y))
        (setq boardgame-org--cursor-x target-x)
        (setq boardgame-org--cursor-y target-y)
        (boardgame-org-refresh)
        (message "Moved %s to (%c%d)." obj-id (+ ?A target-x) (1+ target-y))))))

(defun boardgame-org-pickup-to-hand ()
  "Pick up the top object at point into player hand."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (top (car (last placed))))
    (if (null top)
        (message "No object at current coordinate.")
      (let ((obj-id (boardgame-org-placed-object-id top)))
        (setf (boardgame-org-board-placed-objects boardgame-org--current-board)
              (delete top (boardgame-org-board-placed-objects boardgame-org--current-board)))
        (boardgame-org-hand-add boardgame-org--current-hand obj-id)
        (boardgame-org-board-save boardgame-org--current-board boardgame-org--current-objects-alist)
        (boardgame-org-git-commit (format "Pickup %s to hand" obj-id))
        (boardgame-org-refresh)
        (message "Picked up %s to player hand." obj-id)))))

(defun boardgame-org-play-from-hand ()
  "Play an object from player hand to current board point."
  (interactive)
  (let ((items (boardgame-org-hand-object-ids boardgame-org--current-hand)))
    (if (null items)
        (message "Player hand is empty.")
      (let* ((selected (completing-read "Play item to board: " items nil t))
             (new-placed (boardgame-org-placed-create
                          :object-id selected
                          :x boardgame-org--cursor-x
                          :y boardgame-org--cursor-y
                          :layer 0)))
        (boardgame-org-hand-remove boardgame-org--current-hand selected)
        (push new-placed (boardgame-org-board-placed-objects boardgame-org--current-board))
        (boardgame-org-board-save boardgame-org--current-board boardgame-org--current-objects-alist)
        (boardgame-org-git-commit (format "Play %s to (%d, %d)" selected
                                          boardgame-org--cursor-x
                                          boardgame-org--cursor-y))
        (boardgame-org-refresh)
        (message "Played %s to board." selected)))))

(defun boardgame-org-consolidate-stack-at-point ()
  "Consolidate multiple objects at current point into an Org stack document.
Enforces invariant: removes original standalone Org files per Section 3.1."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y)))
    (if (< (length placed) 2)
        (message "Need at least 2 objects at coordinate to consolidate into a stack.")
      (let* ((stack-id (format "stack-%s" (format-time-string "%Y%m%d%H%M%S")))
             (stack-name (read-string "Stack Name: " "Consolidated Stack"))
             (objs (mapcar (lambda (p)
                             (cdr (assoc (boardgame-org-placed-object-id p)
                                         boardgame-org--current-objects-alist)))
                           placed))
             (stack-obj (boardgame-org-stack-consolidate objs stack-id stack-name)))
        (setf (boardgame-org-board-placed-objects boardgame-org--current-board)
              (cl-remove-if (lambda (p)
                              (and (= (boardgame-org-placed-x p) boardgame-org--cursor-x)
                                   (= (boardgame-org-placed-y p) boardgame-org--cursor-y)))
                            (boardgame-org-board-placed-objects boardgame-org--current-board)))
        (push (boardgame-org-placed-create :object-id stack-id
                                           :x boardgame-org--cursor-x
                                           :y boardgame-org--cursor-y
                                           :layer 0)
              (boardgame-org-board-placed-objects boardgame-org--current-board))
        (push (cons stack-id stack-obj) boardgame-org--current-objects-alist)
        (boardgame-org-board-save boardgame-org--current-board boardgame-org--current-objects-alist)
        (boardgame-org-git-commit (format "Consolidated %d objects into stack %s"
                                          (length objs) stack-id))
        (boardgame-org-refresh)
        (message "Consolidated stack created. Standalone files removed.")))))

(defun boardgame-org-expand-stack-at-point ()
  "Expand a stack at point into independent objects and standalone files."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (top (car (last placed)))
         (top-obj (when top
                    (cdr (assoc (boardgame-org-placed-object-id top)
                                boardgame-org--current-objects-alist)))))
    (if (or (null top-obj) (not (eq (boardgame-org-object-type top-obj) 'stack)))
        (message "Top object at point is not a stack.")
      (let ((reconstructed (boardgame-org-stack-expand top-obj)))
        (setf (boardgame-org-board-placed-objects boardgame-org--current-board)
              (delete top (boardgame-org-board-placed-objects boardgame-org--current-board)))
        (cl-loop for obj in reconstructed
                 for layer from 0
                 do (push (cons (boardgame-org-object-id obj) obj)
                          boardgame-org--current-objects-alist)
                    (push (boardgame-org-placed-create
                           :object-id (boardgame-org-object-id obj)
                           :x boardgame-org--cursor-x
                           :y boardgame-org--cursor-y
                           :layer layer)
                          (boardgame-org-board-placed-objects boardgame-org--current-board)))
        (boardgame-org-board-save boardgame-org--current-board boardgame-org--current-objects-alist)
        (boardgame-org-git-commit (format "Expanded stack %s into %d objects"
                                          (boardgame-org-object-id top-obj)
                                          (length reconstructed)))
        (boardgame-org-refresh)
        (message "Expanded stack into %d independent Org files." (length reconstructed))))))

(defun boardgame-org-draw-from-container-at-point ()
  "Draw an object from a container at point to player hand."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (top (car (last placed)))
         (top-obj (when top
                    (cdr (assoc (boardgame-org-placed-object-id top)
                                boardgame-org--current-objects-alist)))))
    (if (or (null top-obj) (not (eq (boardgame-org-object-type top-obj) 'container)))
        (message "Top object at point is not a container.")
      (condition-case err
          (let ((drawn-id (boardgame-org-container-draw top-obj)))
            (boardgame-org-hand-add boardgame-org--current-hand drawn-id)
            (boardgame-org-git-commit (format "Drawn %s from %s to hand"
                                              drawn-id (boardgame-org-object-name top-obj)))
            (boardgame-org-refresh)
            (message "Drawn %s to hand." drawn-id))
        (error (message "%s" (error-message-string err)))))))

(defun boardgame-org-shuffle-container-at-point ()
  "Shuffle container at point."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (top (car (last placed)))
         (top-obj (when top
                    (cdr (assoc (boardgame-org-placed-object-id top)
                                boardgame-org--current-objects-alist)))))
    (if (or (null top-obj) (not (eq (boardgame-org-object-type top-obj) 'container)))
        (message "Top object at point is not a container.")
      (boardgame-org-container-shuffle top-obj)
      (boardgame-org-git-commit (format "Shuffled container %s" (boardgame-org-object-name top-obj)))
      (message "Container %s shuffled." (boardgame-org-object-name top-obj)))))

(defun boardgame-org-roll-die-at-point ()
  "Roll a die object at point."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (top (car (last placed)))
         (top-obj (when top
                    (cdr (assoc (boardgame-org-placed-object-id top)
                                boardgame-org--current-objects-alist)))))
    (if (or (null top-obj) (not (eq (boardgame-org-object-type top-obj) 'die)))
        (message "Top object at point is not a die.")
      (let* ((sides (or (boardgame-org-object-sides top-obj) 6))
             (roll (1+ (random sides)))
             (d6-glyphs '("⚀" "⚁" "⚂" "⚃" "⚄" "⚅"))
             (glyph (if (= sides 6) (nth (1- roll) d6-glyphs) "🎲")))
        (setf (boardgame-org-object-value top-obj) (number-to-string roll))
        (setf (boardgame-org-object-glyph top-obj) glyph)
        (boardgame-org-object-save-file top-obj)
        (boardgame-org-git-commit (format "Rolled %s: %d" (boardgame-org-object-name top-obj) roll))
        (boardgame-org-refresh)
        (message "Rolled %s: %d" (boardgame-org-object-name top-obj) roll)))))

(defun boardgame-org-flip-card-at-point ()
  "Flip a card at point between face-up and face-down."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (top (car (last placed)))
         (top-obj (when top
                    (cdr (assoc (boardgame-org-placed-object-id top)
                                boardgame-org--current-objects-alist)))))
    (if (null top-obj)
        (message "No object at point.")
      (setf (boardgame-org-object-face-up top-obj)
            (not (boardgame-org-object-face-up top-obj)))
      (boardgame-org-object-save-file top-obj)
      (boardgame-org-git-commit (format "Flipped %s" (boardgame-org-object-name top-obj)))
      (boardgame-org-refresh)
      (message "%s is now %s."
               (boardgame-org-object-name top-obj)
               (if (boardgame-org-object-face-up top-obj) "Face-Up" "Face-Down")))))

(defun boardgame-org-open-org-at-point ()
  "Open the Org document representing the top object at point."
  (interactive)
  (let* ((placed (boardgame-org-board-objects-at boardgame-org--current-board
                                                boardgame-org--cursor-x
                                                boardgame-org--cursor-y))
         (top (car (last placed)))
         (top-obj (when top
                    (cdr (assoc (boardgame-org-placed-object-id top)
                                boardgame-org--current-objects-alist)))))
    (if (null top-obj)
        (message "No object at point.")
      (find-file-other-window
       (boardgame-org-world-file (boardgame-org-object-file-path top-obj))))))

(defun boardgame-org-commit-action ()
  "Interactively prompt for commit message and record world state in Git."
  (interactive)
  (let ((msg (read-string "Commit message: " "Manual world update")))
    (boardgame-org-git-commit msg)
    (message "World state committed to Git.")))

(defun boardgame-org-menu ()
  "Standard menu prompt for tabletop operations without external dependencies."
  (interactive)
  (let ((choice (read-char-choice
                 "[m]ove [H]and-pickup [P]lay [S]tack [U]nstack [d]raw [s]huffle [r]oll [F]lip [o]rg [g]it [q]uit: "
                 '(?m ?H ?P ?S ?U ?d ?s ?r ?F ?o ?g ?q))))
    (pcase choice
      (?m (call-interactively #'boardgame-org-move-at-point))
      (?H (boardgame-org-pickup-to-hand))
      (?P (boardgame-org-play-from-hand))
      (?S (boardgame-org-consolidate-stack-at-point))
      (?U (boardgame-org-expand-stack-at-point))
      (?d (boardgame-org-draw-from-container-at-point))
      (?s (boardgame-org-shuffle-container-at-point))
      (?r (boardgame-org-roll-die-at-point))
      (?F (boardgame-org-flip-card-at-point))
      (?o (boardgame-org-open-org-at-point))
      (?g (boardgame-org-commit-action)))))

;;; Initialization & Entry

;;;###autoload
(defun boardgame-org (&optional world-dir)
  "Launch the boardgame.org tabletop environment.
If WORLD-DIR is provided, use it as `boardgame-org-world-directory`."
  (interactive)
  (when world-dir
    (setq boardgame-org-world-directory (expand-file-name world-dir)))
  (boardgame-org-ensure-world-dirs)
  (let* ((board-file (boardgame-org-world-file "boards/main.org"))
         (buffer (get-buffer-create "*boardgame-org*")))
    (with-current-buffer buffer
      (boardgame-org-mode)
      (if (file-exists-p board-file)
          (setq boardgame-org--current-board
                (with-temp-buffer
                  (insert-file-contents board-file)
                  (org-mode)
                  (boardgame-org-board-parse-buffer "boards/main.org")))
        (let* ((width 16)
               (height 10)
               (grid (boardgame-org-normalize-felt "" width height ".")))
          (setq boardgame-org--current-board
                (boardgame-org-board-create
                 :id "board-main"
                 :name "Felt Tabletop"
                 :width width
                 :height height
                 :default-felt "."
                 :felt-grid grid
                 :placed-objects nil
                 :file-path "boards/main.org"))
          (boardgame-org-board-save boardgame-org--current-board nil)))
      (setq boardgame-org--current-hand
            (boardgame-org-hand-create
             :id "hand-player1"
             :name "Player 1 Hand"
             :player "Player 1"
             :object-ids nil
             :file-path "hands/player1.org"))
      (setq boardgame-org--cursor-x 0)
      (setq boardgame-org--cursor-y 0)
      (boardgame-org-refresh))
    (pop-to-buffer buffer)))

(provide 'boardgame-org)
;;; boardgame-org.el ends here
