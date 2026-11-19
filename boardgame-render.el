;;; boardgame-render.el --- Buffer display redraw engine -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Rendering engine for boardgame.org.
;; Converts in-memory board state (felt characters + placed objects + stack indicators)
;; into an ordinary Emacs text buffer with text properties, glyphs, and faces.
;;
;; Key requirements:
;; - Line truncation (truncate-lines t).
;; - Object layering: topmost object displayed.
;; - Stack quantity indicator: rendered directly to the left of the cell (x-1, y),
;;   suppressed if x == 0 or if overridden by another object.
;; - Coordinate to buffer position mapping: point = y * (width + 1) + x + 1.
;; - Point to coordinate mapping: y = (point - 1) / (width + 1), x = (point - 1) % (width + 1).
;;
;; In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;; internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; Forward declarations for `boardgame-data.el'
(declare-function boardgame-board-width "boardgame-data")
(declare-function boardgame-board-height "boardgame-data")
(declare-function boardgame-board-felt-grid "boardgame-data")
(declare-function boardgame-board-felt-table "boardgame-data")
(declare-function boardgame-board-get-felt "boardgame-data")
(declare-function boardgame-board-get-objects "boardgame-data")
(declare-function boardgame-board-get-top-object "boardgame-data")
(declare-function boardgame-board-all-objects "boardgame-data")
(declare-function boardgame-board-modified-p "boardgame-data")
(declare-function boardgame-object-x "boardgame-data")
(declare-function boardgame-object-y "boardgame-data")
(declare-function boardgame-object-glyph "boardgame-data")
(declare-function boardgame-object-fg "boardgame-data")
(declare-function boardgame-object-bg "boardgame-data")

;; Forward declarations for `boardgame-object.el'
(declare-function boardgame-object-stack-indicator "boardgame-object")
(declare-function boardgame-object-resolve-glyph "boardgame-object")
(declare-function boardgame-object-resolve-face "boardgame-object")

;; -----------------------------------------------------------------------------
;; Faces for Rendering
;; -----------------------------------------------------------------------------

(defface boardgame-felt-face
  '((t :inherit default))
  "Face used for standard felt background characters."
  :group 'boardgame)

(defface boardgame-indicator-face
  '((t :foreground "yellow" :weight bold))
  "Face used for stack quantity indicators to the left of stacked cells."
  :group 'boardgame)

;; -----------------------------------------------------------------------------
;; Coordinate <-> Buffer Position Mapping
;; -----------------------------------------------------------------------------

(defun boardgame-render-coord-to-pos (board x y)
  "Return 1-based buffer character position for coordinate (X, Y) on BOARD.
Each row consists of `width' characters plus a trailing newline."
  (let ((width (boardgame-board-width board)))
    (+ (* y (1+ width)) x 1)))

(defun boardgame-render-pos-to-coord (board pos)
  "Convert 1-based buffer character POS to cons cell (X . Y) on BOARD.
Returns nil if POS is outside valid grid boundaries (e.g. on newline)."
  (let* ((width (boardgame-board-width board))
         (height (boardgame-board-height board))
         (idx (1- pos))
         (row-stride (1+ width))
         (y (/ idx row-stride))
         (x (% idx row-stride)))
    (if (and (< y height) (< x width))
        (cons x y)
      nil)))

;; -----------------------------------------------------------------------------
;; Visual Cell Matrix Generation
;; -----------------------------------------------------------------------------

(defun boardgame-render--build-cell-matrix (board)
  "Compute the 2D visual representation matrix for BOARD.
Returns a vector of HEIGHT string rows, where each row has length WIDTH,
along with text properties for glyphs and stack count indicators."
  (let* ((width (boardgame-board-width board))
         (height (boardgame-board-height board))
         (felt-grid (boardgame-board-felt-grid board))
         ;; Initialize visual rows copying felt characters
         (rows (make-vector height nil)))
    (dotimes (y height)
      (let ((row-chars (make-vector width nil)))
        (dotimes (x width)
          (let ((f-char (if (< y (length felt-grid))
                            (aref (aref felt-grid y) x)
                          (boardgame-board-get-felt board x y))))
            (aset row-chars x (list :char f-char
                                    :face 'boardgame-felt-face
                                    :type :felt
                                    :x x :y y))))
        (aset rows y row-chars)))

    ;; Overlay stack indicators for cells containing objects
    (let ((all-objects (boardgame-board-all-objects board))
          (visited-coords (make-hash-table :test 'equal)))
      (dolist (obj all-objects)
        (let ((coord (cons (boardgame-object-x obj) (boardgame-object-y obj))))
          (unless (gethash coord visited-coords)
            (puthash coord t visited-coords)
            (let* ((x (car coord))
                   (y (cdr coord)))
              (when (and (>= x 0) (< x width) (>= y 0) (< y height))
                (let* ((objs (boardgame-board-get-objects board x y))
                       (cnt (length objs)))
                  ;; If cell has objects and x > 0, place stack indicator at (x-1, y)
                  (when (and (> cnt 0) (> x 0))
                    (let ((ind-char (boardgame-object-stack-indicator cnt)))
                      (when ind-char
                        (let ((row (aref rows y)))
                          (aset row (1- x)
                                (list :char ind-char
                                      :face 'boardgame-indicator-face
                                      :type :indicator
                                      :x (1- x) :y y))))))))))))

    ;; Overlay topmost object glyphs
    (let ((visited-obj-coords (make-hash-table :test 'equal)))
      (dolist (obj (boardgame-board-all-objects board))
        (let* ((x (boardgame-object-x obj))
               (y (boardgame-object-y obj))
               (coord (cons x y)))
          (unless (gethash coord visited-obj-coords)
            (puthash coord t visited-obj-coords)
            (when (and (>= x 0) (< x width) (>= y 0) (< y height))
              (let* ((objs (boardgame-board-get-objects board x y))
                     (glyph (boardgame-object-resolve-glyph objs))
                     (face-props (boardgame-object-resolve-face objs))
                     (char-code (if (> (length glyph) 0) (aref glyph 0) ?*))
                     (row (aref rows y)))
                (aset row x
                      (list :char char-code
                            :face (or face-props 'default)
                            :type :object
                            :objects objs
                            :x x :y y))))))))
    rows)))

;; -----------------------------------------------------------------------------
;; Full Board Buffer Render
;; -----------------------------------------------------------------------------

(defun boardgame-render-board-into-buffer (board buffer)
  "Render complete BOARD state into BUFFER.
Applies line truncation and proper text properties."
  (let* ((matrix (boardgame-render--build-cell-matrix board))
         (height (length matrix))
         (inhibit-read-only t))
    (with-current-buffer buffer
      (erase-buffer)
      (dotimes (y height)
        (let* ((row (aref matrix y))
               (width (length row))
               (line-str (make-string width ?\s)))
          (dotimes (x width)
            (let* ((cell (aref row x))
                   (c (plist-get cell :char)))
              (aset line-str x c)))
          (dotimes (x width)
            (let* ((cell (aref row x))
                   (f (plist-get cell :face))
                   (props (list 'face f
                                'boardgame-x (plist-get cell :x)
                                'boardgame-y (plist-get cell :y)
                                'boardgame-cell-type (plist-get cell :type))))
              (when (plist-get cell :objects)
                (setq props (append props (list 'boardgame-objects (plist-get cell :objects)))))
              (add-text-properties x (1+ x) props line-str)))
          (insert line-str "\n")))
      (goto-char (point-min))
      buffer)))

;; -----------------------------------------------------------------------------
;; Targeted Cell Update (Optimized redraw)
;; -----------------------------------------------------------------------------

(defun boardgame-render-cell (board buffer x y)
  "Update single cell at (X, Y) on BOARD in BUFFER.
Also re-evaluates the stack indicator at (X-1, Y)."
  (when (and (>= x 0) (< x (boardgame-board-width board))
             (>= y 0) (< y (boardgame-board-height board)))
    (let ((inhibit-read-only t)
          (objs (boardgame-board-get-objects board x y)))
      (with-current-buffer buffer
        (save-excursion
          ;; Update object glyph or felt at (x, y)
          (let ((pos (boardgame-render-coord-to-pos board x y)))
            (goto-char pos)
            (delete-char 1)
            (if objs
                (let* ((glyph (boardgame-object-resolve-glyph objs))
                       (char-code (if (> (length glyph) 0) (aref glyph 0) ?*))
                       (face-props (boardgame-object-resolve-face objs))
                       (str (string char-code)))
                  (add-text-properties 0 1
                                       (list 'face (or face-props 'default)
                                             'boardgame-x x 'boardgame-y y
                                             'boardgame-cell-type :object
                                             'boardgame-objects objs)
                                       str)
                  (insert str))
              (let* ((felt-c (boardgame-board-get-felt board x y))
                     (str (string felt-c)))
                (add-text-properties 0 1
                                     (list 'face 'boardgame-felt-face
                                           'boardgame-x x 'boardgame-y y
                                           'boardgame-cell-type :felt)
                                     str)
                (insert str))))

          ;; Update indicator at (x-1, y) if x > 0
          (when (> x 0)
            (let* ((ind-pos (boardgame-render-coord-to-pos board (1- x) y))
                   (ind-objs (boardgame-board-get-objects board (1- x) y)))
              ;; Only render indicator if (x-1, y) does not have its own object
              (unless ind-objs
                (goto-char ind-pos)
                (delete-char 1)
                (if (> (length objs) 0)
                    (let* ((ind-char (boardgame-object-stack-indicator (length objs)))
                           (str (string ind-char)))
                      (add-text-properties 0 1
                                           (list 'face 'boardgame-indicator-face
                                                 'boardgame-x (1- x) 'boardgame-y y
                                                 'boardgame-cell-type :indicator)
                                           str)
                      (insert str))
                  (let* ((felt-c (boardgame-board-get-felt board (1- x) y))
                         (str (string felt-c)))
                    (add-text-properties 0 1
                                         (list 'face 'boardgame-felt-face
                                               'boardgame-x (1- x) 'boardgame-y y
                                               'boardgame-cell-type :felt)
                                         str)
                    (insert str)))))))))))

;;; boardgame-render.el ends here
