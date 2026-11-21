;;; boardgame-marker.el --- Cross-board navigation and navigation markers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Cross-board navigation and navigation markers for boardgame.org.
;;
;; Implements §11 of `boardgame-org-interface.md' and Stage 7 of
;; `boardgame-implementation-plan.md':
;; - Universal board navigation: `boardgame-navigate-to-board-coord' (or `boardgame-board-navigate')
;;   moving point to (x, y) on any board in active world directory.
;; - Dedicated marker creation command: `boardgame-create-marker' creating an ordinary
;;   object with heading "Marker (board filename) (x, y)", visual glyph '^',
;;   foreground 'white', DESTINATION_BOARD, DESTINATION_X, DESTINATION_Y properties,
;;   and an executable Elisp source block parameterizing return navigation.
;;
;; In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;; internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'subr-x)

;; Forward declarations for variables defined in boardgame.el
(defvar boardgame-current-board-buffer)
(defvar boardgame-current-world-directory)

;; Forward declarations for `boardgame-data.el'
(declare-function boardgame-object-create "boardgame-data")
(declare-function boardgame-object-name "boardgame-data")
(declare-function boardgame-object-file "boardgame-data")
(declare-function boardgame-board-name "boardgame-data")
(declare-function boardgame-board-file "boardgame-data")
(declare-function boardgame-board-width "boardgame-data")
(declare-function boardgame-board-height "boardgame-data")
(declare-function boardgame-coord-valid-p "boardgame-data")
(declare-function boardgame-board-add-object "boardgame-data")

;; Forward declarations for `boardgame-board.el'
(declare-function boardgame-board-open-file "boardgame-board")
(declare-function boardgame-board-goto-coord "boardgame-board")
(declare-function boardgame-board-current-coord "boardgame-board")
(declare-function boardgame-board-refresh "boardgame-board")
(declare-function boardgame-save-board "boardgame-board")

;; Forward declarations for `boardgame-window.el'
(declare-function boardgame-frame-p "boardgame-window")
(declare-function boardgame-window-board-window "boardgame-window")

;; Forward declarations for `boardgame-world.el'
(declare-function boardgame-world-resolve-board "boardgame-world")
(declare-function boardgame-world-set-active-board "boardgame-world")

;; Forward declarations for `boardgame-log.el'
(declare-function boardgame-log-append "boardgame-log")

;; -----------------------------------------------------------------------------
;; Universal Board Navigation
;; -----------------------------------------------------------------------------

(defun boardgame-marker--resolve-board-file (board-name-or-file world-dir)
  "Resolve BOARD-NAME-OR-FILE within WORLD-DIR.
Checks direct file in WORLD-DIR, then inside boards/ subdirectory."
  (let* ((candidates (list (expand-file-name board-name-or-file world-dir)
                           (expand-file-name (concat "boards/" board-name-or-file) world-dir)
                           (expand-file-name (file-name-nondirectory board-name-or-file) world-dir)
                           (expand-file-name (concat "boards/" (file-name-nondirectory board-name-or-file)) world-dir))))
    (cl-find-if #'file-exists-p candidates)))

(defun boardgame-marker--find-buffer-for-file (full-path)
  "Find an existing live board buffer visiting FULL-PATH if any."
  (let ((true-path (file-truename full-path)))
    (cl-find-if (lambda (buf)
                  (when (buffer-live-p buf)
                    (let ((data (buffer-local-value 'boardgame-board--data buf)))
                      (and data (boardgame-board-file data)
                           (string-equal (file-truename (boardgame-board-file data)) true-path)))))
                (buffer-list))))

;;;###autoload
(defun boardgame-navigate-to-board-coord (board-file x y &optional frame)
  "Navigate cursor to coordinates (X, Y) on BOARD-FILE in active world.
BOARD-FILE is the board's filename (e.g. \"board-b.org\").
If BOARD-FILE is nil, navigates on the current active board.
FRAME defaults to selected frame or dedicated game frame.
Switches to the target board buffer and positions point at (X, Y)."
  (interactive "sBoard filename: \nnX: \nnY: ")
  (let* ((world-dir (or boardgame-current-world-directory default-directory))
         (current-buf (boardgame-world-resolve-board nil))
         (target-file (if (and board-file (> (length board-file) 0))
                          (or (boardgame-marker--resolve-board-file board-file world-dir)
                              (error "Board file '%s' not found in world '%s'" board-file world-dir))
                        (and current-buf
                             (buffer-local-value 'boardgame-board--data current-buf)
                             (boardgame-board-file (buffer-local-value 'boardgame-board--data current-buf))))))
    (unless (and target-file (file-exists-p target-file))
      (error "Target board file '%s' does not exist" (or target-file board-file)))
    ;; Check if already open in a buffer
    (let* ((existing-buf (boardgame-marker--find-buffer-for-file target-file))
           (board-buf (or existing-buf (boardgame-board-open-file target-file frame)))
           (board (buffer-local-value 'boardgame-board--data board-buf)))
      (unless board
        (error "Buffer '%s' has no board data" (buffer-name board-buf)))
      (unless (boardgame-coord-valid-p board x y)
        (error "Coordinates (%d, %d) out of bounds [0..%d, 0..%d] for board '%s'"
               x y (1- (boardgame-board-width board)) (1- (boardgame-board-height board))
               (file-name-nondirectory target-file)))
      ;; Display buffer in target frame/window
      (let* ((target-frame (or frame (selected-frame)))
             (win (and (fboundp 'boardgame-window-board-window)
                       (boardgame-window-board-window target-frame))))
        (if (and win (window-live-p win))
            (set-window-buffer win board-buf)
          (set-buffer board-buf)))
      (boardgame-world-set-active-board board-buf)
      (with-current-buffer board-buf
        (boardgame-board-goto-coord x y board-buf))
      (boardgame-log-append (format "Navigated to '%s' at (%d, %d)"
                                    (file-name-nondirectory target-file) x y)
                            world-dir "Navigation")
      board-buf)))

;;;###autoload
(defalias 'boardgame-board-navigate #'boardgame-navigate-to-board-coord)

;; -----------------------------------------------------------------------------
;; Marker Generation Helpers
;; -----------------------------------------------------------------------------

(defun boardgame-marker-generate-heading (board-filename x y)
  "Generate marker root heading title according to Section 11.4.1.
Format: 'Marker (board-filename) (x, y)'."
  (format "Marker (%s) (%d, %d)" board-filename x y))

(defun boardgame-marker-generate-filename (board-filename x y)
  "Generate a filesystem-safe relative filename for a navigation marker."
  (let* ((base (file-name-sans-extension (file-name-nondirectory board-filename)))
         (clean-base (replace-regexp-in-string "[^A-Za-z0-9_-]" "-" base)))
    (format "objects/marker-%s-%d-%d.org" clean-base x y)))

(defun boardgame-marker-generate-doc (board-filename x y &optional obj-name)
  "Generate the full Org document text for a navigation marker.
Stores DESTINATION_BOARD, DESTINATION_X, DESTINATION_Y in properties drawer
and includes an executable Elisp source block."
  (let* ((title (or obj-name (boardgame-marker-generate-heading board-filename x y)))
         (bfile (file-name-nondirectory board-filename)))
    (concat
     (format "* %s\n" title)
     ":PROPERTIES:\n"
     (format ":OBJECT_TYPE: marker\n")
     (format ":GLYPH: ^\n")
     (format ":FG: white\n")
     (format ":DESTINATION_BOARD: %s\n" bfile)
     (format ":DESTINATION_X: %d\n" x)
     (format ":DESTINATION_Y: %d\n" y)
     ":END:\n\n"
     "Navigation marker return to creation coordinates.\n\n"
     "#+begin_src emacs-lisp\n"
     "(let* ((props (org-entry-properties (point)))\n"
     "       (b (cdr (assoc \"DESTINATION_BOARD\" props)))\n"
     "       (x (string-to-number (or (cdr (assoc \"DESTINATION_X\" props)) \"0\")))\n"
     "       (y (string-to-number (or (cdr (assoc \"DESTINATION_Y\" props)) \"0\"))))\n"
     "  (boardgame-navigate-to-board-coord b x y))\n"
     "#+end_src\n")))

;; -----------------------------------------------------------------------------
;; Interactive Marker Creation
;; -----------------------------------------------------------------------------

;;;###autoload
(defun boardgame-create-marker (&optional board-buf-or-data)
  "Create a navigation marker at current board cursor position.
Stores current board filename and coordinates in marker properties.
Creates a standalone object Org file and registers it on the active board."
  (interactive)
  (let* ((board-buf (or (and (bufferp board-buf-or-data) board-buf-or-data)
                        (boardgame-world-resolve-board nil))))
    (unless (and board-buf (buffer-live-p board-buf))
      (error "No active board buffer available to create marker"))
    (with-current-buffer board-buf
      (unless (bound-and-true-p boardgame-board--data)
        (error "Current buffer has no board data"))
      (let* ((board boardgame-board--data)
             (coord (or (boardgame-board-current-coord) (cons 0 0)))
             (cx (car coord))
             (cy (cdr coord))
             (bpath (or (boardgame-board-file board) "board.org"))
             (bfile (file-name-nondirectory bpath))
             (world-dir (or boardgame-current-world-directory
                            (file-name-directory bpath)
                            default-directory))
             (heading (boardgame-marker-generate-heading bfile cx cy))
             (rel-file (boardgame-marker-generate-filename bfile cx cy))
             (full-file (expand-file-name rel-file world-dir)))
        ;; Ensure we don't silently overwrite an existing file
        (when (file-exists-p full-file)
          ;; Generate unique suffix
          (let ((counter 1)
                (base-rel rel-file))
            (while (file-exists-p (expand-file-name rel-file world-dir))
              (setq rel-file (format "%s-%d.org" (file-name-sans-extension base-rel) counter))
              (setq counter (1+ counter)))
            (setq full-file (expand-file-name rel-file world-dir))))
        ;; 1. Write marker document
        (make-directory (file-name-directory full-file) t)
        (with-temp-file full-file
          (insert (boardgame-marker-generate-doc bfile cx cy heading)))
        ;; 2. Create in-memory object and add to board
        (let ((marker-obj (boardgame-object-create
                           :name heading
                           :x cx
                           :y cy
                           :glyph "^"
                           :file rel-file
                           :type "marker"
                           :fg "white"
                           :properties `(("DESTINATION_BOARD" . ,bfile)
                                         ("DESTINATION_X" . ,(number-to-string cx))
                                         ("DESTINATION_Y" . ,(number-to-string cy))))))
          (boardgame-board-add-object board marker-obj)
          (boardgame-board-refresh board-buf)
          (boardgame-log-append (format "Created navigation marker '%s' at (%d, %d)"
                                        heading cx cy)
                                world-dir "Marker")
          (message "Created marker: %s" heading)
          marker-obj)))))

;;; boardgame-marker.el ends here