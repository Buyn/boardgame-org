;;; boardgame-org-marker.el --- Cross-board navigation & navigation markers -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 11 of boardgame-org-interface.md:
;; "Cursor Navigation and Navigation Markers.
;; General-purpose navigation command boardgame-navigate-to-board-coord
;; and dedicated command boardgame-create-marker creating a '^' marker
;; whose source block invokes navigation parameterized by Org properties."

;;; Code:

(require 'org)
(require 'boardgame-org-core)

;;;###autoload
(defun boardgame-navigate-to-board-coord (board-filename x y)
  "Navigate cursor to coordinates X and Y on BOARD-FILENAME.
Resolves BOARD-FILENAME exclusively within active world's boards directory."
  (interactive "sBoard filename: \nnX coord: \nnY coord: ")
  (let* ((board-path (boardgame-world-file (format "boards/%s" board-filename))))
    (unless (file-exists-p board-path)
      (error "Board file '%s' does not exist in active world" board-filename))
    ;; Open or switch to target board buffer
    (let ((board-buf (boardgame-load-or-find-board-buffer board-path board-filename)))
      (if (fboundp 'boardgame-switch-board-in-frame)
          (boardgame-switch-board-in-frame board-buf)
        (switch-to-buffer board-buf))
      (with-current-buffer board-buf
        (when (fboundp 'boardgame-set-cursor-coord)
          (boardgame-set-cursor-coord x y))
        (when (fboundp 'boardgame-refresh-board)
          (boardgame-refresh-board)))
      (when (fboundp 'boardgame-log)
        (boardgame-log "Cursor Navigated"
                       `(("Destination" . ,(format "%s at (%d, %d)" board-filename x y))))))))

;;;###autoload
(defun boardgame-marker-generate (board-filename x y)
  "Generate and persist a navigation marker Org file targeting BOARD-FILENAME at (X, Y).
Creates an object named 'Marker (board filename) (x, y)' with glyph '^',
foreground 'white', destination properties, and an executable source block.
Returns the newly created `boardgame-object`."
  (let* ((bfilename board-filename)
         (obj-name (format "Marker %s (%d, %d)" bfilename x y))
         (obj-id (format "marker-%s-%d-%d"
                         (file-name-sans-extension bfilename) x y))
         (obj-rel-path (format "objects/%s.org" obj-id))
         (obj-full-path (boardgame-world-file obj-rel-path)))
    (unless (file-exists-p obj-full-path)
      (make-directory (file-name-directory obj-full-path) t)
      (with-temp-file obj-full-path
        (insert ":PROPERTIES:\n")
        (insert (format ":ID: %s\n" obj-id))
        (insert (format ":NAME: %s\n" obj-name))
        (insert ":OBJECT_TYPE: marker\n")
        (insert ":TYPE: marker\n")
        (insert ":GLYPH: ^\n")
        (insert ":FOREGROUND: white\n")
        (insert (format ":DESTINATION_BOARD: %s\n" bfilename))
        (insert (format ":DESTINATION_X: %d\n" x))
        (insert (format ":DESTINATION_Y: %d\n" y))
        (insert ":END:\n\n")
        (insert (format "* %s\n" obj-name))
        (insert "Navigation marker parameterizing return to creation coordinates.\n\n")
        (insert "#+begin_src emacs-lisp\n")
        (insert "(let ((b (org-entry-get (point) \"DESTINATION_BOARD\"))\n")
        (insert "      (x (string-to-number (or (org-entry-get (point) \"DESTINATION_X\") \"0\")))\n")
        (insert "      (y (string-to-number (or (org-entry-get (point) \"DESTINATION_Y\") \"0\"))))\n")
        (insert "  (boardgame-navigate-to-board-coord b x y))\n")
        (insert "#+end_src\n")))
    (boardgame-object-create
     :id obj-id
     :name obj-name
     :glyph "^"
     :type 'marker
     :foreground "white"
     :file-path obj-rel-path)))

;;;###autoload
(defun boardgame-create-marker ()
  "Create a navigation marker at current board cursor position.
Generates an object named 'Marker (board filename) (x, y)' with glyph '^',
foreground 'white', destination properties, and an executable source block."
  (interactive)
  (unless (and boardgame-current-board-buffer (buffer-live-p boardgame-current-board-buffer))
    (error "No active board buffer available to create marker"))
  (with-current-buffer boardgame-current-board-buffer
    (let* ((board (or (bound-and-true-p boardgame--current-board)
                      (error "No board loaded in buffer")))
           (bfilename (boardgame-board-filename board))
           (cx (or (bound-and-true-p boardgame--cursor-x) 0))
           (cy (or (bound-and-true-p boardgame--cursor-y) 0))
           (obj (boardgame-marker-generate bfilename cx cy))
           (obj-id (boardgame-object-id obj))
           (placed (boardgame-placed-create :object-id obj-id :x cx :y cy :layer 0)))
      (push placed (boardgame-board-placed-objects board))
      (push (cons obj-id obj) boardgame--current-objects-alist)
      (boardgame-save-board)
      (boardgame-refresh-board)
      (when (fboundp 'boardgame-log)
        (boardgame-log "Marker Created"
                       `(("Name" . ,(boardgame-object-name obj))
                         ("Destination" . ,(format "%s (%d, %d)" bfilename cx cy)))))
      (message "Created navigation marker: %s" (boardgame-object-name obj)))))

(provide 'boardgame-org-marker)
;;; boardgame-org-marker.el ends here
