;;; boardgame-data.el --- In-memory data model and coordinate mapping -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; In-memory data structures and coordinate mapping for boardgame.org.
;;
;; Provides:
;; - `boardgame-board' struct: Represents dimensions, properties, felt grid/table,
;;   and object registry.
;; - `boardgame-object' struct: Represents a game object on the board with
;;   coordinates, glyph, and metadata.
;; - Coordinate helpers and operations for felt cells and layered objects.
;;
;; Architectural Invariant:
;; In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;; internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; -----------------------------------------------------------------------------
;; Struct Definitions
;; -----------------------------------------------------------------------------

(cl-defstruct (boardgame-object
               (:constructor boardgame-object-create)
               (:copier nil))
  "In-memory representation of an object on a game board."
  (name "Object" :type string)
  (x 0 :type integer)
  (y 0 :type integer)
  (glyph "*" :type string)
  (file nil :type (or null string))
  (type "unspecified" :type string)
  (fg nil :type (or null string))
  (bg nil :type (or null string))
  (properties nil :type list)
  (content nil :type (or null string)))

(cl-defstruct (boardgame-board
               (:constructor boardgame-board-create)
               (:copier nil))
  "In-memory representation of a tabletop game board."
  (name "Untitled Board" :type string)
  (file nil :type (or null string))
  (width 80 :type integer)
  (height 24 :type integer)
  (felt-default "." :type (or string character integer))
  (properties nil :type list)
  (felt-grid (make-vector 0 "") :type vector)
  (felt-table (make-hash-table :test 'equal) :type hash-table)
  (objects-table (make-hash-table :test 'equal) :type hash-table)
  (objects-list nil :type list)
  (modified-p nil :type boolean))

;; -----------------------------------------------------------------------------
;; Character and String Conversions
;; -----------------------------------------------------------------------------

(defun boardgame--to-char (val)
  "Convert VAL (character, integer, or string) to a character code."
  (cond ((characterp val) val)
        ((integerp val) val)
        ((and (stringp val) (> (length val) 0)) (aref val 0))
        (t ?\.)))

(defun boardgame--to-string (val)
  "Convert VAL (character, integer, or string) to a 1-character string."
  (cond ((stringp val)
         (if (> (length val) 0) (substring val 0 1) "."))
        ((or (characterp val) (integerp val)) (string val))
        (t ".")))

(defun boardgame-board-felt-default-char (board)
  "Return the default felt character for BOARD as a character code."
  (boardgame--to-char (boardgame-board-felt-default board)))

(defun boardgame-board-felt-default-string (board)
  "Return the default felt character for BOARD as a 1-character string."
  (boardgame--to-string (boardgame-board-felt-default board)))

;; -----------------------------------------------------------------------------
;; Coordinate Mapping Helpers
;; -----------------------------------------------------------------------------

(defun boardgame-coord (x y)
  "Construct a coordinate pair for X and Y."
  (cons x y))

(defun boardgame-coord-x (coord)
  "Return the X coordinate from COORD pair."
  (car coord))

(defun boardgame-coord-y (coord)
  "Return the Y coordinate from COORD pair."
  (cdr coord))

(defun boardgame-coord-valid-p (board x y)
  "Return non-nil if (X, Y) falls within declared bounds of BOARD."
  (and (integerp x)
       (integerp y)
       (>= x 0)
       (< x (boardgame-board-width board))
       (>= y 0)
       (< y (boardgame-board-height board))))

;; -----------------------------------------------------------------------------
;; Board Initialization
;; -----------------------------------------------------------------------------

(defun boardgame-board-create-empty (name width height &optional felt-default)
  "Create a new in-memory `boardgame-board' with declared dimensions.
NAME is the board title, WIDTH and HEIGHT are positive dimensions,
and FELT-DEFAULT is the initial background character (defaults to '.')."
  (let* ((def-char (boardgame--to-char (or felt-default ?\.)))
         (def-str (string def-char))
         (empty-row (make-string width def-char))
         (grid (make-vector height ""))
         (f-table (make-hash-table :test 'equal))
         (o-table (make-hash-table :test 'equal)))
    (dotimes (y height)
      (aset grid y (copy-sequence empty-row))
      (dotimes (x width)
        (puthash (cons x y) def-char f-table)))
    (boardgame-board-create
     :name (or name "Untitled Board")
     :width width
     :height height
     :felt-default def-str
     :felt-grid grid
     :felt-table f-table
     :objects-table o-table
     :objects-list nil
     :modified-p nil)))

;; -----------------------------------------------------------------------------
;; Felt Layer Operations
;; -----------------------------------------------------------------------------

(defun boardgame-board-get-felt (board x y)
  "Return the felt character code at (X, Y) on BOARD.
If (X, Y) is out of bounds, returns the board's default felt character."
  (if (boardgame-coord-valid-p board x y)
      (let ((cached (gethash (cons x y) (boardgame-board-felt-table board))))
        (or cached
            (aref (aref (boardgame-board-felt-grid board) y) x)))
    (boardgame-board-felt-default-char board)))

(defun boardgame-board-set-felt (board x y char)
  "Set felt character at (X, Y) on BOARD to CHAR.
Updates both `felt-grid' matrix and `felt-table' hash-table.
Marks BOARD as modified."
  (when (boardgame-coord-valid-p board x y)
    (let* ((c-code (boardgame--to-char char))
           (grid (boardgame-board-felt-grid board))
           (row (aref grid y)))
      (aset row x c-code)
      (puthash (cons x y) c-code (boardgame-board-felt-table board))
      (setf (boardgame-board-modified-p board) t)
      c-code)))

(defun boardgame-board-felt-lines (board)
  "Return felt grid of BOARD as a list of string rows."
  (append (boardgame-board-felt-grid board) nil))

(defun boardgame-board-felt-string (board)
  "Return the complete felt grid of BOARD as a newline-delimited string."
  (string-join (boardgame-board-felt-lines board) "\n"))

;; -----------------------------------------------------------------------------
;; Object Layer Operations
;; -----------------------------------------------------------------------------

(defun boardgame-board-get-objects (board x y)
  "Return list of objects located at (X, Y) on BOARD.
Topmost object appears first in the returned list."
  (gethash (cons x y) (boardgame-board-objects-table board) nil))

(defun boardgame-board-get-top-object (board x y)
  "Return the topmost visible object at (X, Y) on BOARD, or nil if empty."
  (car (boardgame-board-get-objects board x y)))

(defun boardgame-board-all-objects (board)
  "Return a list of all objects currently placed on BOARD in order."
  (boardgame-board-objects-list board))

(defun boardgame-board-object-count-at (board x y)
  "Return the count of objects currently stacked at (X, Y) on BOARD."
  (length (boardgame-board-get-objects board x y)))

(defun boardgame-board-add-object (board object &optional at-bottom)
  "Add OBJECT to BOARD at its declared coordinates.
When AT-BOTTOM is non-nil, places OBJECT underneath existing objects;
otherwise places OBJECT on top.
Updates `objects-table' and `objects-list', marking BOARD as modified."
  (let* ((coord (cons (boardgame-object-x object) (boardgame-object-y object)))
         (table (boardgame-board-objects-table board))
         (current (gethash coord table nil)))
    (if at-bottom
        (puthash coord (append current (list object)) table)
      (puthash coord (cons object current) table))
    (setf (boardgame-board-objects-list board)
          (append (boardgame-board-objects-list board) (list object)))
    (setf (boardgame-board-modified-p board) t)
    object))

(defun boardgame-board-remove-object (board object)
  "Remove OBJECT from BOARD.
Updates `objects-table' and `objects-list', marking BOARD as modified."
  (let* ((coord (cons (boardgame-object-x object) (boardgame-object-y object)))
         (table (boardgame-board-objects-table board))
         (current (gethash coord table nil))
         (new-list (delq object current)))
    (if new-list
        (puthash coord new-list table)
      (remhash coord table))
    (setf (boardgame-board-objects-list board)
          (delq object (boardgame-board-objects-list board)))
    (setf (boardgame-board-modified-p board) t)
    object))

(defun boardgame-board-move-object (board object new-x new-y)
  "Move OBJECT on BOARD to coordinates (NEW-X, NEW-Y).
Updates coordinate mappings in `objects-table' and marks BOARD modified."
  (let* ((old-coord (cons (boardgame-object-x object) (boardgame-object-y object)))
         (new-coord (cons new-x new-y))
         (table (boardgame-board-objects-table board))
         (old-list (gethash old-coord table nil))
         (new-old-list (delq object old-list)))
    (if new-old-list
        (puthash old-coord new-old-list table)
      (remhash old-coord table))
    (setf (boardgame-object-x object) new-x)
    (setf (boardgame-object-y object) new-y)
    (puthash new-coord (cons object (gethash new-coord table nil)) table)
    (setf (boardgame-board-modified-p board) t)
    object))

;;; boardgame-data.el ends here
