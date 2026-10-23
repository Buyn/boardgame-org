;;; boardgame-org-drawing.el --- ZZT-style felt drawing mode and tools -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 8 of boardgame-org-interface.md:
;; "Drawing is a dedicated feature providing ZZT-style character editing of the
;; felt, including character selection, foreground and background colors,
;; pipette sampling, continuous strokes, point-by-point painting, recent-symbol
;; selection, region-based operations, and Text (Overwrite) Mode."

;;; Code:

(require 'boardgame-org-core)

(defvar-local boardgame-drawing-char "#"
  "Current character used for painting the felt.")

(defvar-local boardgame-drawing-fg nil
  "Current foreground color for drawing, or nil for default.")

(defvar-local boardgame-drawing-bg nil
  "Current background color for drawing, or nil for default.")

(defvar-local boardgame-recent-symbols '("#" "." "=" "~" "^" "@")
  "List of recently used drawing characters, ordered most-recent first.")

(defvar-local boardgame-drawing-continuous nil
  "When non-nil, moving cursor automatically paints traversed cells.")

(defvar-local boardgame-text-mode nil
  "When non-nil, typing printable characters replaces felt cells directly.")

(defvar-local boardgame-objects-hidden-p nil
  "Non-nil when objects are temporarily hidden to expose the felt layer.")

;;; Minor Mode Definition

(defvar boardgame-drawing-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "p")   #'boardgame-draw-point)
    (define-key map (kbd "c")   #'boardgame-drawing-toggle-continuous)
    (define-key map (kbd "i")   #'boardgame-pipette)
    (define-key map (kbd "s")   #'boardgame-drawing-select-symbol)
    (define-key map (kbd "r")   #'boardgame-drawing-recent-symbol-menu)
    (define-key map (kbd "F")   #'boardgame-drawing-set-fg-color)
    (define-key map (kbd "B")   #'boardgame-drawing-set-bg-color)
    (define-key map (kbd "t")   #'boardgame-text-mode-toggle)
    (define-key map (kbd "R")   #'boardgame-draw-fill-region)
    (define-key map (kbd "q")   #'boardgame-drawing-mode)
    map)
  "Keymap for `boardgame-drawing-mode`.")

;;;###autoload
(define-minor-mode boardgame-drawing-mode
  "Minor mode for ZZT-style felt character and color painting."
  :lighter " [Draw]"
  :keymap boardgame-drawing-mode-map
  (if boardgame-drawing-mode
      (progn
        (setq boardgame-objects-hidden-p t)
        (message "Drawing Mode enabled. Objects hidden. [p]aint [i]pipette [t]ext [s]ymbol [q]uit"))
    (setq boardgame-objects-hidden-p nil)
    (setq boardgame-text-mode nil)
    (setq boardgame-drawing-continuous nil)
    (message "Drawing Mode disabled. Objects restored.")))

(defun boardgame-drawing-info ()
  "Return plist of current drawing settings for status display."
  (list :tool (cond
               ((not boardgame-drawing-mode) "Off")
               (boardgame-text-mode "Text Overwrite")
               (boardgame-drawing-continuous "Continuous")
               (t "Point Paint"))
        :glyph boardgame-drawing-char
        :fg boardgame-drawing-fg
        :bg boardgame-drawing-bg))

;;;###autoload
(defun boardgame-pipette ()
  "Sample the underlying felt cell character and colors at current cursor."
  (interactive)
  (let ((char (boardgame-get-felt-at-point)))
    (when char
      (setq boardgame-drawing-char char)
      (add-to-list 'boardgame-recent-symbols char)
      (message "Pipette sampled: '%s'" char))))

;;;###autoload
(defun boardgame-drawing-select-symbol ()
  "Prompt user to select a new drawing character."
  (interactive)
  (let ((input (read-string "Draw symbol (single character): " boardgame-drawing-char)))
    (when (> (length input) 0)
      (let ((ch (substring input 0 1)))
        (setq boardgame-drawing-char ch)
        (setq boardgame-recent-symbols
              (cons ch (delete ch boardgame-recent-symbols)))
        (message "Active drawing character: '%s'" ch)))))

;;;###autoload
(defun boardgame-drawing-recent-symbol-menu ()
  "Choose a drawing symbol from recent symbols."
  (interactive)
  (let* ((candidates (delete boardgame-drawing-char (copy-sequence boardgame-recent-symbols)))
         (choice (completing-read "Recent symbol: " candidates nil t)))
    (when (and choice (> (length choice) 0))
      (setq boardgame-drawing-char choice)
      (setq boardgame-recent-symbols
            (cons choice (delete choice boardgame-recent-symbols)))
      (message "Active drawing character set to: '%s'" choice))))

(defun boardgame-drawing-set-fg-color ()
  "Set active foreground color for painting."
  (interactive)
  (let ((color (read-color "Drawing Foreground (or empty for default): ")))
    (setq boardgame-drawing-fg (if (string-empty-p color) nil color))
    (message "Foreground color: %s" (or boardgame-drawing-fg "default"))))

(defun boardgame-drawing-set-bg-color ()
  "Set active background color for painting."
  (interactive)
  (let ((color (read-color "Drawing Background (or empty for default): ")))
    (setq boardgame-drawing-bg (if (string-empty-p color) nil color))
    (message "Background color: %s" (or boardgame-drawing-bg "default"))))

(defun boardgame-drawing-toggle-continuous ()
  "Toggle continuous stroke painting as cursor moves."
  (interactive)
  (setq boardgame-drawing-continuous (not boardgame-drawing-continuous))
  (message "Continuous painting: %s" (if boardgame-drawing-continuous "ON" "OFF")))

(defun boardgame-text-mode-toggle ()
  "Toggle Text (Overwrite) Mode within drawing mode."
  (interactive)
  (setq boardgame-text-mode (not boardgame-text-mode))
  (message "Text Overwrite Mode: %s" (if boardgame-text-mode "ON" "OFF")))

(provide 'boardgame-org-drawing)
;;; boardgame-org-drawing.el ends here
