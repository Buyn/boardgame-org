;;; boardgame-org-render.el --- Buffer rendering and display for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 5 of boardgame-org.md:
;; "Object Ordering and Rendering:
;; The felt layer is underneath all objects.
;; Render one visible object glyph and a count indicator immediately to its left:
;; - Count 1-9 represented by its corresponding digit.
;; - Larger count represented by +.
;; - Indicator omitted if it cannot be rendered without collision or boundary error."

;;; Code:

(require 'boardgame-org-core)
(require 'boardgame-org-board)

(defface boardgame-org-felt-face
  '((t :foreground "#45475a" :inherit fixed-pitch))
  "Face for empty felt background cells."
  :group 'boardgame-org)

(defface boardgame-org-object-face
  '((t :foreground "#cdd6f4" :weight bold :inherit fixed-pitch))
  "Face for game object glyphs."
  :group 'boardgame-org)

(defface boardgame-org-count-face
  '((t :foreground "#f9e2af" :weight bold :height 0.85 :inherit fixed-pitch))
  "Face for multi-object count indicators (1-9, +)."
  :group 'boardgame-org)

(defface boardgame-org-cursor-face
  '((t :background "#313244" :box (:line-width 1 :color "#89b4fa") :weight bold))
  "Face for currently selected cell cursor."
  :group 'boardgame-org)

(defface boardgame-org-coord-face
  '((t :foreground "#6c7086" :weight semi-bold :inherit fixed-pitch))
  "Face for board column/row coordinate labels."
  :group 'boardgame-org)

(defun boardgame-org-render-cell (board objects-alist x y cursor-x cursor-y)
  "Render a cell representation at X, Y for BOARD."
  (let* ((placed-at (boardgame-org-board-objects-at board x y))
         (count (length placed-at))
         (is-cursor (and (= x cursor-x) (= y cursor-y)))
         (row (aref (boardgame-org-board-felt-grid board) y))
         (felt-char (aref row x)))
    (if (zerop count)
        ;; Empty cell
        (let ((str (format " %s " felt-char)))
          (propertize str 'face (if is-cursor 'boardgame-org-cursor-face 'boardgame-org-felt-face)))
      ;; Objects occupy cell
      (let* ((top-placed (car (last placed-at)))
             (top-obj (cdr (assoc (boardgame-org-placed-object-id top-placed) objects-alist)))
             (glyph (if top-obj (boardgame-org-object-glyph top-obj) "♟"))
             ;; Section 5 count indicator rule:
             (indicator (cond
                         ((<= count 1) " ")
                         ((<= count 9) (number-to-string count))
                         (t "+")))
             (cell-str (format "%s%s "
                               (propertize indicator 'face 'boardgame-org-count-face)
                               (propertize glyph 'face 'boardgame-org-object-face))))
        (if is-cursor
            (propertize cell-str 'face 'boardgame-org-cursor-face)
          cell-str)))))

(defun boardgame-org-render-board (buffer board objects-alist cursor-x cursor-y)
  "Render complete BOARD in BUFFER at CURSOR-X, CURSOR-Y."
  (with-current-buffer buffer
    (let ((inhibit-read-only t))
      (erase-buffer)
      ;; Header: Column letters
      (insert "    ")
      (dotimes (c (boardgame-org-board-width board))
        (insert (propertize (format " %c " (+ ?A c)) 'face 'boardgame-org-coord-face)))
      (insert "\n")
      ;; Rows
      (dotimes (r (boardgame-org-board-height board))
        ;; Row number label
        (insert (propertize (format "%3d " (1+ r)) 'face 'boardgame-org-coord-face))
        (dotimes (c (boardgame-org-board-width board))
          (insert (boardgame-org-render-cell board objects-alist c r cursor-x cursor-y)))
        (insert "\n"))
      (goto-char (point-min)))))

(provide 'boardgame-org-render)
;;; boardgame-org-render.el ends here
