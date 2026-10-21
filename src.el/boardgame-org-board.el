;;; boardgame-org-board.el --- Board model, normalization, and serialization -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 4 (Source of Truth and Serialization) and Section 4.6
;; (Felt Dimensions and Normalization) of boardgame-org.md.

;;; Code:

(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-object)

(defun boardgame-org-normalize-felt (raw-felt width height default-felt)
  "Normalize RAW-FELT string to 2D vector conforming to WIDTH and HEIGHT.
Missing cells are filled with DEFAULT-FELT; extra columns/rows are ignored."
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

(defun boardgame-org-board-parse-buffer (file-path)
  "Parse a board Org document from current buffer."
  (let* ((props (boardgame-org-parse-property-drawer))
         (id (or (cdr (assoc "ID" props)) "board-main"))
         (name (or (cdr (assoc "NAME" props)) "Felt Table"))
         (width (string-to-number (or (cdr (assoc "WIDTH" props)) "16")))
         (height (string-to-number (or (cdr (assoc "HEIGHT" props)) "10")))
         (default-felt (or (cdr (assoc "DEFAULT_FELT" props))
                           boardgame-org-default-felt-symbol))
         (raw-felt (boardgame-org-board--extract-felt))
         (grid (boardgame-org-normalize-felt raw-felt width height default-felt))
         (placed (boardgame-org-board--extract-placed)))
    (boardgame-org-board-create
     :id id
     :name name
     :width width
     :height height
     :default-felt default-felt
     :felt-grid grid
     :placed-objects placed
     :file-path file-path)))

(defun boardgame-org-board--extract-felt ()
  "Extract raw content of `#+begin_src felt` block."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^#\\+begin_src[ \t]+felt.*$" nil t)
        (let ((start (forward-line 1)))
          (if (re-search-forward "^#\\+end_src" nil t)
              (buffer-substring-no-properties start (match-beginning 0))
            ""))
      "")))

(defun boardgame-org-board--extract-placed ()
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
              (push (boardgame-org-placed-create
                     :object-id obj-id
                     :x x
                     :y y
                     :layer layer)
                    placed)))))
      (nreverse placed))))

(defun boardgame-org-board-serialize (board objects-alist)
  "Serialize BOARD to an Org document string."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-org-board-id board)))
    (insert (format ":NAME: %s\n" (boardgame-org-board-name board)))
    (insert (format ":WIDTH: %d\n" (boardgame-org-board-width board)))
    (insert (format ":HEIGHT: %d\n" (boardgame-org-board-height board)))
    (insert (format ":DEFAULT_FELT: %s\n" (boardgame-org-board-default-felt board)))
    (insert ":END:\n\n")
    (insert (format "* %s\n" (boardgame-org-board-name board)))
    (insert "Serialized tabletop environment for boardgame-org.\n\n")
    (insert "* Felt\n")
    (insert (format "#+begin_src felt :dimensions %dx%d\n"
                    (boardgame-org-board-width board)
                    (boardgame-org-board-height board)))
    (dotimes (r (boardgame-org-board-height board))
      (let ((row (aref (boardgame-org-board-felt-grid board) r)))
        (dotimes (c (boardgame-org-board-width board))
          (insert (aref row c)))
        (insert "\n")))
    (insert "#+end_src\n\n")
    (insert "* Placed Objects\n")
    (insert "| ID | X | Y | Layer | Glyph | Name |\n")
    (insert "|----+---+---+-------+-------+------|\n")
    (dolist (p (boardgame-org-board-placed-objects board))
      (let* ((id (boardgame-org-placed-object-id p))
             (obj (cdr (assoc id objects-alist)))
             (glyph (if obj (boardgame-org-object-glyph obj) "♟"))
             (name (if obj (boardgame-org-object-name obj) id)))
        (insert (format "| %s | %d | %d | %d | %s | %s |\n"
                        id
                        (boardgame-org-placed-x p)
                        (boardgame-org-placed-y p)
                        (boardgame-org-placed-layer p)
                        glyph
                        name))))
    (buffer-string)))

(defun boardgame-org-board-save (board objects-alist)
  "Save BOARD to its persistent Org file."
  (let ((full-path (boardgame-org-world-file (boardgame-org-board-file-path board))))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (boardgame-org-board-serialize board objects-alist)))))

(defun boardgame-org-board-objects-at (board x y)
  "Return list of `boardgame-org-placed` at coordinates X and Y sorted by layer."
  (let ((matched nil))
    (dolist (p (boardgame-org-board-placed-objects board))
      (when (and (= (boardgame-org-placed-x p) x)
                 (= (boardgame-org-placed-y p) y))
        (push p matched)))
    (sort matched (lambda (a b)
                    (< (boardgame-org-placed-layer a)
                       (boardgame-org-placed-layer b))))))

(defun boardgame-org-board-move-object (board object-id target-x target-y)
  "Move OBJECT-ID to TARGET-X, TARGET-Y on BOARD."
  (dolist (p (boardgame-org-board-placed-objects board))
    (when (string= (boardgame-org-placed-object-id p) object-id)
      (setf (boardgame-org-placed-x p) target-x)
      (setf (boardgame-org-placed-y p) target-y))))

(provide 'boardgame-org-board)
;;; boardgame-org-board.el ends here
