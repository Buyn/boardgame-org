;;; boardgame-org-board.el --- Board model, serialization, and rendering -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 4 & Section 6 of boardgame-org-interface.md and Section 4 of boardgame-org.md:
;; "The board is rendered in an ordinary Emacs text buffer using non-wrapping lines.
;; Multiple objects may occupy one coordinate with numeric count markers (1-9, +)."

;;; Code:

(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-object)

(defface boardgame-felt-face
  '((t :foreground "#5c6370" :inherit fixed-pitch))
  "Face for empty felt background cells."
  :group 'boardgame-org)

(defface boardgame-object-face
  '((t :foreground "#abb2bf" :weight bold :inherit fixed-pitch))
  "Face for game object glyphs."
  :group 'boardgame-org)

(defface boardgame-count-face
  '((t :foreground "#ecbe7b" :weight bold :height 0.85 :inherit fixed-pitch))
  "Face for multi-object count indicators (1-9, +)."
  :group 'boardgame-org)

(defface boardgame-cursor-face
  '((t :background "#3e4451" :box (:line-width 1 :color "#51afef") :weight bold))
  "Face for currently selected cell cursor."
  :group 'boardgame-org)

(defface boardgame-coord-face
  '((t :foreground "#5c6370" :weight semi-bold :inherit fixed-pitch))
  "Face for board column/row coordinate labels."
  :group 'boardgame-org)

(defun boardgame-normalize-felt (raw-felt width height default-felt)
  "Normalize RAW-FELT string to 2D vector conforming to WIDTH and HEIGHT.
Missing cells are padded with DEFAULT-FELT; extra rows/cols are ignored."
  (let* ((lines (split-string raw-felt "\n" t))
         (grid (make-vector height nil)))
    (dotimes (r height)
      (let* ((line (or (nth r lines) ""))
             (chars (string-to-list line))
             (row (make-vector width default-felt)))
        (dotimes (c width)
          (when (< c (length chars))
            (aset row c (string (nth c chars)))))
        (aset grid r row)))
    grid))

(defun boardgame-board-parse-buffer (file-path filename)
  "Parse a board Org document from current buffer."
  (let* ((props (boardgame-parse-property-drawer))
         (id (or (cdr (assoc "ID" props)) (file-name-sans-extension filename)))
         (name (or (cdr (assoc "NAME" props)) "Felt Table"))
         (width (string-to-number (or (cdr (assoc "WIDTH" props)) "16")))
         (height (string-to-number (or (cdr (assoc "HEIGHT" props)) "10")))
         (default-felt (or (cdr (assoc "DEFAULT_FELT" props)) boardgame-default-felt-symbol))
         (raw-felt (boardgame-board--extract-felt))
         (grid (boardgame-normalize-felt raw-felt width height default-felt))
         (placed (boardgame-board--extract-placed)))
    (boardgame-board-create
     :id id
     :name name
     :filename filename
     :width width
     :height height
     :default-felt default-felt
     :felt-grid grid
     :placed-objects placed
     :file-path file-path
     :dirty-p nil)))

(defun boardgame-board--extract-felt ()
  "Extract raw content of `#+begin_src felt` block."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^#\\+begin_src[ \t]+felt.*$" nil t)
        (let ((start (forward-line 1)))
          (if (re-search-forward "^#\\+end_src" nil t)
              (buffer-substring-no-properties start (match-beginning 0))
            ""))
      "")))

(defun boardgame-board--extract-placed ()
  "Extract placed objects from `* Placed Objects` table."
  (save-excursion
    (goto-char (point-min))
    (let (placed)
      (when (re-search-forward "^\\*+[ \t]+Placed Objects" nil t)
        (while (and (forward-line 1)
                    (looking-at "^[ \t]*|[ \t]*\\([^|]+\\)[ \t]*|[ \t]*\\([0-9]+\\)[ \t]*|[ \t]*\\([0-9]+\\)[ \t]*|[ \t]*\\([0-9]+\\)"))
          (let ((obj-id (string-trim (match-string 1)))
                (x (string-to-number (match-string 2)))
                (y (string-to-number (match-string 3)))
                (layer (string-to-number (match-string 4))))
            (unless (string-match-p "ID\\|---" obj-id)
              (push (boardgame-placed-create
                     :object-id obj-id
                     :x x
                     :y y
                     :layer layer)
                    placed)))))
      (nreverse placed))))

(defun boardgame-board-serialize (board objects-alist)
  "Serialize BOARD into an Org document string."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-board-id board)))
    (insert (format ":NAME: %s\n" (boardgame-board-name board)))
    (insert (format ":WIDTH: %d\n" (boardgame-board-width board)))
    (insert (format ":HEIGHT: %d\n" (boardgame-board-height board)))
    (insert (format ":DEFAULT_FELT: %s\n" (boardgame-board-default-felt board)))
    (insert ":END:\n\n")
    (insert (format "* %s\n" (boardgame-board-name board)))
    (insert "Serialized tabletop environment for boardgame.org.\n\n")
    (insert "* Felt\n")
    (insert (format "#+begin_src felt :dimensions %dx%d\n"
                    (boardgame-board-width board)
                    (boardgame-board-height board)))
    (dotimes (r (boardgame-board-height board))
      (let ((row (aref (boardgame-board-felt-grid board) r)))
        (dotimes (c (boardgame-board-width board))
          (insert (aref row c)))
        (insert "\n")))
    (insert "#+end_src\n\n")
    (insert "* Placed Objects\n")
    (insert "| ID | X | Y | Layer | Glyph | Name |\n")
    (insert "|----+---+---+-------+-------+------|\n")
    (dolist (p (boardgame-board-placed-objects board))
      (let* ((id (boardgame-placed-object-id p))
             (obj (cdr (assoc id objects-alist)))
             (glyph (if obj (boardgame-object-glyph obj) "♟"))
             (name (if obj (boardgame-object-name obj) id)))
        (insert (format "| %s | %d | %d | %d | %s | %s |\n"
                        id
                        (boardgame-placed-x p)
                        (boardgame-placed-y p)
                        (boardgame-placed-layer p)
                        glyph
                        name))))
    (buffer-string)))

(defun boardgame-board-objects-at (board x y)
  "Return list of `boardgame-placed` at coordinates X and Y sorted by layer."
  (let ((matched nil))
    (dolist (p (boardgame-board-placed-objects board))
      (when (and (= (boardgame-placed-x p) x)
                 (= (boardgame-placed-y p) y))
        (push p matched)))
    (sort matched (lambda (a b)
                    (< (boardgame-placed-layer a)
                       (boardgame-placed-layer b))))))

(defun boardgame-render-cell (board objects-alist x y cursor-x cursor-y hide-objects-p)
  "Render a cell representation at X, Y for BOARD.
If HIDE-OBJECTS-P is non-nil (e.g. in drawing mode), render felt only."
  (let* ((placed-at (if hide-objects-p nil (boardgame-board-objects-at board x y)))
         (count (length placed-at))
         (is-cursor (and (= x cursor-x) (= y cursor-y)))
         (row (aref (boardgame-board-felt-grid board) y))
         (felt-char (aref row x)))
    (if (zerop count)
        (let ((str (format " %s " felt-char)))
          (propertize str 'face (if is-cursor 'boardgame-cursor-face 'boardgame-felt-face)))
      (let* ((top-placed (car (last placed-at)))
             (top-obj (cdr (assoc (boardgame-placed-object-id top-placed) objects-alist)))
             (glyph (if top-obj (boardgame-object-glyph top-obj) "♟"))
             (indicator (cond
                         ((<= count 1) " ")
                         ((<= count 9) (number-to-string count))
                         (t "+")))
             (cell-str (format "%s%s "
                               (propertize indicator 'face 'boardgame-count-face)
                               (propertize glyph 'face 'boardgame-object-face))))
        (if is-cursor
            (propertize cell-str 'face 'boardgame-cursor-face)
          cell-str)))))

(provide 'boardgame-org-board)
;;; boardgame-org-board.el ends here
