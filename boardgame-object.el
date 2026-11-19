;;; boardgame-object.el --- Object layering and visual resolution -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Object layering calculations, visual glyph resolution, and stack
;; quantity indicator calculation for boardgame.org.
;;
;; Implements §4.4, §5 of `boardgame-org.md' and Stage 4 of
;; `boardgame-implementation-plan.md':
;; - Multiple objects may occupy the same coordinate (x, y).
;; - Topmost object determines the rendered glyph and face.
;; - When objects occupy coordinate (x, y), a stack indicator is computed:
;;   digits 1-9 for counts 1-9, '+' for 10 or more.
;;   Omitted if count <= 0 or if indicator is suppressed (e.g. left boundary).
;;
;; In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;; internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; Forward declarations for `boardgame-data.el'
(declare-function boardgame-object-glyph "boardgame-data")
(declare-function boardgame-object-fg "boardgame-data")
(declare-function boardgame-object-bg "boardgame-data")
(declare-function boardgame-board-get-objects "boardgame-data")
(declare-function boardgame-board-get-top-object "boardgame-data")
(declare-function boardgame-board-object-count-at "boardgame-data")

;; -----------------------------------------------------------------------------
;; Stack Indicator Calculation
;; -----------------------------------------------------------------------------

(defun boardgame-object-indicator-for-count (count)
  "Return stack quantity indicator character for integer COUNT.
Returns ?1 through ?9 for counts 1-9, and ?+ for counts 10 or greater.
Returns nil when COUNT is less than or equal to 0."
  (cond
   ((<= count 0) nil)
   ((and (>= count 1) (<= count 9))
    (+ ?0 count))
   (t ?+)))

(defun boardgame-object-stack-indicator (objects-or-count)
  "Calculate the stack indicator character for OBJECTS-OR-COUNT.
OBJECTS-OR-COUNT may be a list of objects or an integer count.
Returns ?1 through ?9 for counts 1-9, ?+ for 10 or greater,
or nil if empty or non-positive."
  (let ((count (if (listp objects-or-count)
                   (length objects-or-count)
                 objects-or-count)))
    (boardgame-object-indicator-for-count count)))

(defun boardgame-object-indicator-string (objects-or-count)
  "Return stack indicator as a 1-character string, or nil if none."
  (let ((char (boardgame-object-stack-indicator objects-or-count)))
    (and char (string char))))

;; -----------------------------------------------------------------------------
;; Object Layering & Visual Glyph Resolution
;; -----------------------------------------------------------------------------

(defun boardgame-object-topmost (objects)
  "Return the topmost object from list of OBJECTS.
The first item in OBJECTS represents the topmost object."
  (car objects))

(defun boardgame-object-resolve-glyph (objects &optional fallback)
  "Resolve visual glyph for OBJECTS list at a cell.
FALLBACK is used if OBJECTS is empty or top object has no glyph."
  (let ((top (boardgame-object-topmost objects)))
    (if top
        (or (boardgame-object-glyph top) fallback "*")
      fallback)))

(defun boardgame-object-resolve-face (objects)
  "Resolve face attributes (fg and bg) for topmost in OBJECTS.
Returns a property list suitable for `face' or nil."
  (let ((top (boardgame-object-topmost objects)))
    (when top
      (let* ((fg (boardgame-object-fg top))
             (bg (boardgame-object-bg top))
             (face-props nil))
        (when (and fg (not (string-empty-p fg)))
          (setq face-props (append face-props (list :foreground fg))))
        (when (and bg (not (string-empty-p bg)))
          (setq face-props (append face-props (list :background bg))))
        face-props))))

;;; boardgame-object.el ends here
