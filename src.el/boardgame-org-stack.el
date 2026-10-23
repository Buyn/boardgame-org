;;; boardgame-org-stack.el --- Stack consolidation and expansion for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 10.1 of boardgame-org-interface.md and Section 3.1 of boardgame-org.md:
;; "The resulting stack object gets the '$' character as the default character to display,
;; on a white background in black font color. Standalone object files are removed
;; after successful consolidation."

;;; Code:

(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-object)

(defun boardgame-stack-serialize (stack-object)
  "Serialize STACK-OBJECT with consolidated subheadings for stacked items."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-object-id stack-object)))
    (insert (format ":NAME: %s\n" (boardgame-object-name stack-object)))
    (insert ":TYPE: stack\n")
    (insert ":GLYPH: $\n")
    (insert ":FOREGROUND: black\n")
    (insert ":BACKGROUND: white\n")
    (insert ":IS_STACK: t\n")
    (insert (format ":STACK_SIZE: %d\n"
                    (length (boardgame-object-stacked-items stack-object))))
    (insert ":END:\n\n")
    (insert (format "* %s\n" (boardgame-object-name stack-object)))
    (insert "Consolidated Org document containing merged game objects.\n\n")
    (insert "* Stack Items\n")
    (dolist (item (boardgame-object-stacked-items stack-object))
      (insert (format "** %s %s\n"
                      (or (cdr (assoc "GLYPH" item)) "$")
                      (or (cdr (assoc "NAME" item)) "Item")))
      (insert ":PROPERTIES:\n")
      (dolist (p item)
        (insert (format ":%s: %s\n" (car p) (cdr p))))
      (insert ":END:\n\n"))
    (buffer-string)))

(defun boardgame-stack-consolidate (objects stack-id stack-name)
  "Combine OBJECTS into a new stack with STACK-ID and STACK-NAME.
The resulting stack displays the '$' glyph on a white background in black font color.
Deletes former standalone Org files per Section 3.1 and 10.1."
  (let* ((file-path (format "stacks/%s.org" stack-id))
         (stacked-items
          (mapcar
           (lambda (obj)
             `(("ID" . ,(boardgame-object-id obj))
               ("ORIGINAL_ID" . ,(boardgame-object-id obj))
               ("NAME" . ,(boardgame-object-name obj))
               ("GLYPH" . ,(boardgame-object-glyph obj))
               ("TYPE" . ,(symbol-name (boardgame-object-type obj)))
               ("VALUE" . ,(or (boardgame-object-value obj) ""))))
           objects))
         (stack-obj (boardgame-object-create
                     :id stack-id
                     :name stack-name
                     :glyph "$"
                     :foreground "black"
                     :background "white"
                     :type 'stack
                     :file-path file-path
                     :stacked-items stacked-items)))
    ;; 1. Write the new consolidated stack file
    (let ((full-path (boardgame-world-file file-path)))
      (make-directory (file-name-directory full-path) t)
      (with-temp-file full-path
        (insert (boardgame-stack-serialize stack-obj))))
    ;; 2. INVARIANT: Delete former standalone Org files
    (dolist (obj objects)
      (boardgame-object-delete-file obj))
    stack-obj))

(defun boardgame-stack-expand (stack-object)
  "Expand STACK-OBJECT back into independent objects and standalone Org files."
  (let ((reconstructed nil))
    (dolist (item (boardgame-object-stacked-items stack-object))
      (let* ((id (or (cdr (assoc "ORIGINAL_ID" item))
                     (cdr (assoc "ID" item))
                     (format "obj-%s" (format-time-string "%Y%m%d%H%M%S"))))
             (name (or (cdr (assoc "NAME" item)) "Restored Object"))
             (glyph (or (cdr (assoc "GLYPH" item)) "♟"))
             (type (intern (or (cdr (assoc "TYPE" item)) "card")))
             (file-path (format "objects/%s.org" id))
             (obj (boardgame-object-create
                   :id id
                   :name name
                   :glyph glyph
                   :type type
                   :file-path file-path
                   :properties item)))
        (boardgame-object-save-file obj)
        (push obj reconstructed)))
    (boardgame-object-delete-file stack-object)
    (nreverse reconstructed)))

(provide 'boardgame-org-stack)
;;; boardgame-org-stack.el ends here
