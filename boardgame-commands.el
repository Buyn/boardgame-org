;;; boardgame-commands.el --- Interactive game commands and Babel execution -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Interactive game commands, Org-Babel code block execution wrappers,
;; object inspection, and keybinding maps for boardgame.org.
;;
;; Implements §7.2, §7.4, and §13 of `boardgame-org-interface.md' and Stage 7 of
;; `boardgame-implementation-plan.md':
;; - `boardgame-execute-object-block': Execute embedded Elisp / Babel code blocks in
;;   the object document under cursor or specified object.
;; - `boardgame-execute-board-block': Execute code blocks belonging to the board document.
;; - `boardgame-describe-object': Describe objects and felt at cursor.
;; - `boardgame-open-object': Open the Org document of the object under cursor.
;; - Keybindings: F1-F12 and key chords (e.g. "C-c" sequences) for standard operations.
;;
;; In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;; internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'ob)
(require 'subr-x)

;; Forward declarations for variables defined in boardgame.el
(defvar boardgame-current-board-buffer)
(defvar boardgame-current-world-directory)

;; Forward declarations for `boardgame-data.el'
(declare-function boardgame-object-name "boardgame-data")
(declare-function boardgame-object-glyph "boardgame-data")
(declare-function boardgame-object-file "boardgame-data")
(declare-function boardgame-object-type "boardgame-data")
(declare-function boardgame-object-x "boardgame-data")
(declare-function boardgame-object-y "boardgame-data")
(declare-function boardgame-board-file "boardgame-data")
(declare-function boardgame-board-get-objects "boardgame-data")
(declare-function boardgame-board-get-felt "boardgame-data")

;; Forward declarations for `boardgame-board.el'
(declare-function boardgame-board-current-coord "boardgame-board")
(declare-function boardgame-board-refresh "boardgame-board")
(declare-function boardgame-save-board "boardgame-board")

;; Forward declarations for `boardgame-world.el'
(declare-function boardgame-world-resolve-board "boardgame-world")

;; Forward declarations for `boardgame-log.el'
(declare-function boardgame-log-append "boardgame-log")

;; Forward declarations for `boardgame-marker.el'
(declare-function boardgame-create-marker "boardgame-marker")
(declare-function boardgame-navigate-to-board-coord "boardgame-marker")

;; Forward declarations for `boardgame-hand.el'
(declare-function boardgame-open-hand "boardgame-hand")
(declare-function boardgame-place-on-board "boardgame-hand")
(declare-function boardgame-hand-take "boardgame-hand")

;; Forward declarations for `boardgame-stack.el'
(declare-function boardgame-stack-create-at-point "boardgame-stack")

;; Forward declarations for `boardgame-draw.el'
(declare-function boardgame-draw-toggle "boardgame-draw")
(declare-function boardgame-draw-pipette "boardgame-draw")
(declare-function boardgame-draw-point-paint "boardgame-draw")
(declare-function boardgame-draw-fill-region "boardgame-draw")

;; -----------------------------------------------------------------------------
;; Org-Babel Code Execution Helpers
;; -----------------------------------------------------------------------------

(defun boardgame-commands--resolve-file (file world-dir)
  "Resolve FILE relative to WORLD-DIR if not absolute."
  (if (file-name-absolute-p file)
      file
    (expand-file-name file (or world-dir boardgame-current-world-directory default-directory))))

(defun boardgame-commands--execute-block-in-buffer (buf &optional block-name)
  "Execute an Org-Babel source block in BUF.
If BLOCK-NAME is provided, looks for a block named BLOCK-NAME.
Otherwise executes the first emacs-lisp block found.
Returns the evaluation result."
  (with-current-buffer buf
    (org-mode)
    (goto-char (point-min))
    (let ((found nil))
      (if block-name
          (while (and (not found)
                      (re-search-forward (format "^[ \t]*#\\+NAME:[ \t]*%s[ \t]*$"
                                                 (regexp-quote block-name)) nil t))
            (when (re-search-forward "^[ \t]*#\\+BEGIN_SRC[ \t]+\\([A-Za-z0-9_-]+\\)" nil t)
              (setq found (point))))
        ;; Find first src block (prefer emacs-lisp or elisp)
        (if (re-search-forward "^[ \t]*#\\+BEGIN_SRC[ \t]+\\(?:emacs-lisp\\|elisp\\)" nil t)
            (setq found (point))
          (goto-char (point-min))
          (when (re-search-forward "^[ \t]*#\\+BEGIN_SRC" nil t)
            (setq found (point)))))
      (unless found
        (error "No executable source block found"))
      (let ((org-confirm-babel-evaluate nil))
        (org-babel-execute-src-block)))))

;;;###autoload
(defun boardgame-execute-object-block (&optional object block-name)
  "Execute the embedded source block belonging to OBJECT (or object under cursor).
If BLOCK-NAME is provided, executes that specific named block.
Returns the result of the executed code block."
  (interactive)
  (let* ((board-buf (boardgame-world-resolve-board nil)))
    (unless (and board-buf (buffer-live-p board-buf))
      (error "No active board buffer available"))
    (with-current-buffer board-buf
      (unless (bound-and-true-p boardgame-board--data)
        (error "Current buffer has no board data"))
      (let* ((board boardgame-board--data)
             (world-dir (or boardgame-current-world-directory
                            (and (boardgame-board-file board)
                                 (file-name-directory (boardgame-board-file board)))
                            default-directory))
             (target-obj (or object
                             (let* ((coord (boardgame-board-current-coord))
                                    (objs (and coord (boardgame-board-get-objects board (car coord) (cdr coord)))))
                               (car objs)))))
        (unless target-obj
          (error "No object selected or under cursor to execute block"))
        (let* ((rel-file (boardgame-object-file target-obj))
               (full-file (and rel-file (boardgame-commands--resolve-file rel-file world-dir))))
          (unless (and full-file (file-exists-p full-file))
            (error "Object Org file '%s' does not exist" (or full-file rel-file)))
          (let* ((obj-buf (find-file-noselect full-file))
                 (result (unwind-protect
                             (boardgame-commands--execute-block-in-buffer obj-buf block-name)
                           (when (and obj-buf (not (find-buffer-visiting full-file)))
                             (kill-buffer obj-buf)))))
            (boardgame-log-append (format "Executed code block on '%s'" (boardgame-object-name target-obj))
                                  world-dir "Execution")
            (message "Executed code block on '%s': %S" (boardgame-object-name target-obj) result)
            result))))))

;;;###autoload
(defun boardgame-execute-board-block (&optional block-name)
  "Execute a source block associated with the active board.
If BLOCK-NAME is provided, executes that named block."
  (interactive)
  (let* ((board-buf (boardgame-world-resolve-board nil)))
    (unless (and board-buf (buffer-live-p board-buf))
      (error "No active board buffer available"))
    (with-current-buffer board-buf
      (unless (bound-and-true-p boardgame-board--data)
        (error "Current buffer has no board data"))
      (let* ((board boardgame-board--data)
             (bfile (boardgame-board-file board))
             (world-dir (or boardgame-current-world-directory
                            (and bfile (file-name-directory bfile))
                            default-directory)))
        (unless (and bfile (file-exists-p bfile))
          (error "Board file '%s' does not exist" bfile))
        (let* ((file-buf (find-file-noselect bfile))
               (result (unwind-protect
                           (boardgame-commands--execute-block-in-buffer file-buf block-name)
                         (when (and file-buf (not (find-buffer-visiting bfile)))
                           (kill-buffer file-buf)))))
          (boardgame-log-append (format "Executed board code block on '%s'" (file-name-nondirectory bfile))
                                world-dir "Execution")
          (message "Executed board code block: %S" result)
          result)))))

;; -----------------------------------------------------------------------------
;; Object Inspection Commands
;; -----------------------------------------------------------------------------

;;;###autoload
(defun boardgame-describe-object ()
  "Display object and felt information for the current coordinates."
  (interactive)
  (let* ((board-buf (boardgame-world-resolve-board nil)))
    (unless (and board-buf (buffer-live-p board-buf))
      (error "No active board buffer available"))
    (with-current-buffer board-buf
      (unless (bound-and-true-p boardgame-board--data)
        (error "Current buffer has no board data"))
      (let* ((board boardgame-board--data)
             (coord (or (boardgame-board-current-coord) (cons 0 0)))
             (cx (car coord))
             (cy (cdr coord))
             (felt (boardgame-board-get-felt board cx cy))
             (objs (boardgame-board-get-objects board cx cy)))
        (if (null objs)
            (message "At (%d, %d): Empty cell, felt '%c'" cx cy felt)
          (let ((desc (mapconcat (lambda (o)
                                   (format "'%s' [glyph: %s, type: %s]"
                                           (boardgame-object-name o)
                                           (boardgame-object-glyph o)
                                           (boardgame-object-type o)))
                                 objs "; ")))
            (message "At (%d, %d): Felt '%c', %d object(s): %s"
                     cx cy felt (length objs) desc)))))))

;;;###autoload
(defun boardgame-open-object ()
  "Open the Org document associated with the object under cursor."
  (interactive)
  (let* ((board-buf (boardgame-world-resolve-board nil)))
    (unless (and board-buf (buffer-live-p board-buf))
      (error "No active board buffer available"))
    (with-current-buffer board-buf
      (unless (bound-and-true-p boardgame-board--data)
        (error "Current buffer has no board data"))
      (let* ((board boardgame-board--data)
             (coord (boardgame-board-current-coord))
             (objs (and coord (boardgame-board-get-objects board (car coord) (cdr coord))))
             (top (car objs))
             (world-dir (or boardgame-current-world-directory default-directory)))
        (unless top
          (error "No object under cursor to open"))
        (let* ((rel-file (boardgame-object-file top))
               (full-file (and rel-file (boardgame-commands--resolve-file rel-file world-dir))))
          (unless (and full-file (file-exists-p full-file))
            (error "Object file '%s' does not exist" (or full-file rel-file)))
          (find-file-other-window full-file))))))

;; -----------------------------------------------------------------------------
;; Keybinding Maps & Setup
;; -----------------------------------------------------------------------------

(defvar boardgame-commands-map
  (let ((map (make-sparse-keymap)))
    ;; Function keys (Section 13.2)
    (define-key map (kbd "<f1>") #'boardgame-describe-object)
    (define-key map (kbd "<f2>") #'boardgame-open-object)
    (define-key map (kbd "<f3>") #'boardgame-execute-object-block)
    (define-key map (kbd "<f4>") #'boardgame-create-marker)
    (define-key map (kbd "<f5>") #'boardgame-hand-take)
    (define-key map (kbd "<f6>") #'boardgame-open-hand)
    (define-key map (kbd "<f7>") #'boardgame-stack-create-at-point)
    (define-key map (kbd "<f8>") #'boardgame-draw-toggle)
    (define-key map (kbd "<f9>") #'boardgame-save-board)
    (define-key map (kbd "<f10>") #'boardgame-execute-board-block)

    ;; Standard key chords (Section 13.1 & 13.2)
    (define-key map (kbd "C-c o") #'boardgame-open-object)
    (define-key map (kbd "C-c m") #'boardgame-create-marker)
    (define-key map (kbd "C-c e") #'boardgame-execute-object-block)
    (define-key map (kbd "C-c t") #'boardgame-hand-take)
    (define-key map (kbd "C-c h") #'boardgame-open-hand)
    (define-key map (kbd "C-c s") #'boardgame-save-board)
    (define-key map (kbd "C-c k") #'boardgame-stack-create-at-point)
    (define-key map (kbd "C-c g") #'boardgame-navigate-to-board-coord)
    (define-key map (kbd "C-c ?") #'boardgame-describe-object)
    map)
  "Keymap containing standard interactive boardgame commands.")

(defun boardgame-commands--setup-board-mode ()
  "Install commands keymap in `boardgame-board-mode'."
  (let ((map (bound-and-true-p boardgame-board-mode-map)))
    (when map
      (set-keymap-parent map boardgame-commands-map))))

(add-hook 'boardgame-board-mode-hook #'boardgame-commands--setup-board-mode)

;;; boardgame-commands.el ends here