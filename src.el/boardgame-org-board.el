;;; boardgame-org-board.el --- Board model, felt grid normalization and rendering -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 4.6 of boardgame-org.md and Sections 5-6 of
;; boardgame-org-interface.md:
;; - Ordinary Emacs text buffer representation
;; - Felt normalization (padding missing cells, clipping excess)
;; - Multi-object count indicators ('1'-'9', '+')
;; - Board Org serialization and deserialization

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'subr-x)
(require 'boardgame-org-core)

;;; Custom Faces

(defface boardgame-coord-face
  '((t :foreground "gray50" :weight bold))
  "Face for board coordinate headers."
  :group 'boardgame)

(defface boardgame-felt-face
  '((t :foreground "gray40"))
  "Face for empty felt cells."
  :group 'boardgame)

(defface boardgame-cursor-face
  '((t :inverse-video t :weight bold))
  "Face for the active board cursor cell."
  :group 'boardgame)

(defface boardgame-count-face
  '((t :foreground "yellow" :weight bold))
  "Face for multi-object count indicators."
  :group 'boardgame)

(defface boardgame-stack-face
  '((t :foreground "black" :background "white" :weight bold))
  "Face for consolidated stack glyph '$' per Section 10.1."
  :group 'boardgame)

;;; Felt Normalization (Section 4.6)

;;;###autoload
(defun boardgame-normalize-felt (raw-text width height &optional default-felt)
  "Normalize RAW-TEXT felt string to exact 2D vector of WIDTH x HEIGHT.
Fills missing rows/columns with DEFAULT-FELT and truncates excess characters."
  (let* ((def-char (if (and default-felt (> (length default-felt) 0))
                       (substring default-felt 0 1)
                     "."))
         (raw-lines (if (stringp raw-text) (split-string raw-text "\n") nil))
         (grid (make-vector height nil)))
    (dotimes (r height)
      (let* ((row-vec (make-vector width def-char))
             (line (and (< r (length raw-lines)) (nth r raw-lines))))
        (when line
          (dotimes (c (min width (length line)))
            (aset row-vec c (substring line c (1+ c)))))
        (aset grid r row-vec)))
    grid))

;;; Object Queries & Coordinates

;;;###autoload
(defun boardgame-board-objects-at (board x y)
  "Return list of `boardgame-placed` objects at cell (X, Y) sorted by layer."
  (when board
    (let ((placed (cl-remove-if-not
                   (lambda (p)
                     (and (= (boardgame-placed-x p) x)
                          (= (boardgame-placed-y p) y)))
                   (boardgame-board-placed-objects board))))
      (sort placed (lambda (a b) (< (boardgame-placed-layer a)
                                    (boardgame-placed-layer b)))))))

;;; Cell Rendering (Section 5 & 6)

;;;###autoload
(defun boardgame-render-cell (board objects-alist col row cursor-x cursor-y hide-objects-p)
  "Render 3-character string representation for cell at COL, ROW."
  (let* ((is-cursor (and (= col cursor-x) (= row cursor-y)))
         (placed (unless hide-objects-p (boardgame-board-objects-at board col row)))
         (count (length placed))
         (felt-row (aref (boardgame-board-felt-grid board) row))
         (felt-ch (aref felt-row col))
         left-char
         mid-char
         (cell-face nil))
    ;; Left character: count indicator (Sections 6 & 5)
    (cond
     ((or hide-objects-p (<= count 1))
      (setq left-char " "))
     ((<= count 9)
      (setq left-char (propertize (number-to-string count) 'face 'boardgame-count-face)))
     (t
      (setq left-char (propertize "+" 'face 'boardgame-count-face))))

    ;; Middle character: top object glyph or felt symbol
    (if (and placed (> count 0))
        (let* ((top-placed (car (last placed)))
               (obj (cdr (assoc (boardgame-placed-object-id top-placed) objects-alist))))
          (if obj
              (progn
                (setq mid-char (or (boardgame-object-glyph obj) "♟"))
                (cond
                 ((eq (boardgame-object-type obj) 'stack)
                  (setq cell-face 'boardgame-stack-face))
                 ((and (boardgame-object-foreground obj) (boardgame-object-background obj))
                  (setq cell-face `(:foreground ,(boardgame-object-foreground obj)
                                    :background ,(boardgame-object-background obj))))
                 ((boardgame-object-foreground obj)
                  (setq cell-face `(:foreground ,(boardgame-object-foreground obj))))
                 ((boardgame-object-background obj)
                  (setq cell-face `(:background ,(boardgame-object-background obj))))))
            (setq mid-char (boardgame-placed-object-id top-placed))))
      ;; Empty cell
      (setq mid-char (propertize (or felt-ch ".") 'face 'boardgame-felt-face)))

    (let ((res (concat left-char
                       (if cell-face (propertize mid-char 'face cell-face) mid-char)
                       " ")))
      (if is-cursor
          (propertize res 'face 'boardgame-cursor-face)
        res))))

;;; Board Serialization & Parsing

;;;###autoload
(defun boardgame-board-parse-buffer (file-path filename)
  "Parse an Org buffer visiting a board file into a `boardgame-board` struct."
  (save-excursion
    (goto-char (point-min))
    (let* ((props (org-entry-properties (point-min)))
           (w (string-to-number (or (cdr (assoc "WIDTH" props)) "16")))
           (h (string-to-number (or (cdr (assoc "HEIGHT" props)) "10")))
           (def-felt (or (cdr (assoc "DEFAULT_FELT" props)) "."))
           (felt-text "")
           (placed nil))
      ;; 1. Extract Felt src block
      (goto-char (point-min))
      (if (re-search-forward "#\\+begin_src felt[^\n]*\n\\(\\(?:.\\|\n\\)*?\\)#\\+end_src" nil t)
          (setq felt-text (match-string-no-properties 1)))
      (let ((grid (boardgame-normalize-felt felt-text w h def-felt)))
        ;; 2. Extract Placed Objects
        (goto-char (point-min))
        (while (re-search-forward "^\\*\\*\\*? \\(Object\\|Marker\\|Stack\\|Container\\):?\\s-+\\(.*\\)$" nil t)
          (let* ((p-props (org-entry-properties (point)))
                 (oid (or (cdr (assoc "OBJECT_ID" p-props)) (cdr (assoc "ID" p-props))))
                 (ox (string-to-number (or (cdr (assoc "X" p-props)) "0")))
                 (oy (string-to-number (or (cdr (assoc "Y" p-props)) "0")))
                 (layer (string-to-number (or (cdr (assoc "LAYER" p-props)) "0"))))
            (when oid
              (push (boardgame-placed-create :object-id oid :x ox :y oy :layer layer) placed))))
        (boardgame-board-create
         :id (file-name-sans-extension filename)
         :name (file-name-sans-extension filename)
         :filename filename
         :width w
         :height h
         :default-felt def-felt
         :felt-grid grid
         :placed-objects (nreverse placed)
         :file-path file-path
         :dirty-p nil)))))

;;;###autoload
(defun boardgame-board-serialize (board objects-alist)
  "Serialize BOARD and OBJECTS-ALIST into Org document string."
  (with-temp-buffer
    (insert (format "#+TITLE: Board: %s\n" (boardgame-board-name board)))
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-board-id board)))
    (insert (format ":WIDTH: %d\n" (boardgame-board-width board)))
    (insert (format ":HEIGHT: %d\n" (boardgame-board-height board)))
    (insert (format ":DEFAULT_FELT: %s\n" (boardgame-board-default-felt board)))
    (insert ":END:\n\n")
    (insert "* Felt\n")
    (insert "#+begin_src felt\n")
    (dotimes (r (boardgame-board-height board))
      (let ((row-vec (aref (boardgame-board-felt-grid board) r)))
        (dotimes (c (boardgame-board-width board))
          (insert (or (aref row-vec c) ".")))
        (insert "\n")))
    (insert "#+end_src\n\n")
    (insert "* Placed Objects\n")
    (dolist (p (boardgame-board-placed-objects board))
      (let* ((oid (boardgame-placed-object-id p))
             (obj (cdr (assoc oid objects-alist)))
             (oname (if obj (boardgame-object-name obj) oid)))
        (insert (format "** Object %s\n" oname))
        (insert ":PROPERTIES:\n")
        (insert (format ":OBJECT_ID: %s\n" oid))
        (insert (format ":X: %d\n" (boardgame-placed-x p)))
        (insert (format ":Y: %d\n" (boardgame-placed-y p)))
        (insert (format ":LAYER: %d\n" (boardgame-placed-layer p)))
        (when (and obj (boardgame-object-file-path obj))
          (insert (format ":FILE: %s\n" (boardgame-object-file-path obj))))
        (insert ":END:\n\n")))
    (buffer-string)))

(provide 'boardgame-org-board)
;;; boardgame-org-board.el ends here
