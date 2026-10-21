;;; boardgame-org-stack.el --- Stack consolidation and expansion for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 3.1 of boardgame-org.md:
;; "Stack: Consolidation of Org Documents. When several objects are explicitly combined:
;; 1. Identify selected objects.
;; 2. Relevant Org content is incorporated into a stack document.
;; 3. Stack preserves order and properties.
;; 4. Original objects cease to exist as independent objects.
;; 5. Former standalone Org files are removed."

;;; Code:

(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-object)

(defun boardgame-org-stack-serialize (stack-object)
  "Serialize STACK-OBJECT with consolidated subheadings for stacked items."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-org-object-id stack-object)))
    (insert (format ":NAME: %s\n" (boardgame-org-object-name stack-object)))
    (insert ":TYPE: stack\n")
    (insert ":GLYPH: 🂠\n")
    (insert ":IS_STACK: t\n")
    (insert (format ":STACK_SIZE: %d\n"
                    (length (boardgame-org-object-stacked-items stack-object))))
    (insert ":END:\n\n")
    (insert (format "* %s\n" (boardgame-org-object-name stack-object)))
    (insert "Consolidated Org document containing merged game objects.\n\n")
    (insert "* Stack Items\n")
    (dolist (item (boardgame-org-object-stacked-items stack-object))
      (insert (format "** %s %s\n"
                      (or (cdr (assoc "GLYPH" item)) "🂠")
                      (or (cdr (assoc "NAME" item)) "Item")))
      (insert ":PROPERTIES:\n")
      (dolist (p item)
        (insert (format ":%s: %s\n" (car p) (cdr p))))
      (insert ":END:\n\n"))
    (buffer-string)))

(defun boardgame-org-stack-parse-buffer (file-path)
  "Parse a consolidated stack Org document from current buffer."
  (let* ((props (boardgame-org-parse-property-drawer))
         (id (or (cdr (assoc "ID" props)) (file-name-base file-path)))
         (name (or (cdr (assoc "NAME" props)) "Card Stack"))
         items)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "^\\*\\*[ \t]+\\(.*\\)$" nil t)
        (let ((sub-props (boardgame-org-parse-property-drawer)))
          (push sub-props items))))
    (boardgame-org-object-create
     :id id
     :name name
     :glyph "🂠"
     :type 'stack
     :file-path file-path
     :properties props
     :stacked-items (nreverse items))))

(defun boardgame-org-stack-consolidate (objects stack-id stack-name)
  "Combine OBJECTS into a new stack with STACK-ID and STACK-NAME.
Deletes the standalone Org files of the consolidated objects per Section 3.1."
  (let* ((file-path (format "stacks/%s.org" stack-id))
         (stacked-items
          (mapcar
           (lambda (obj)
             `(("ID" . ,(boardgame-org-object-id obj))
               ("ORIGINAL_ID" . ,(boardgame-org-object-id obj))
               ("NAME" . ,(boardgame-org-object-name obj))
               ("GLYPH" . ,(boardgame-org-object-glyph obj))
               ("TYPE" . ,(symbol-name (boardgame-org-object-type obj)))
               ("VALUE" . ,(or (boardgame-org-object-value obj) ""))))
           objects))
         (stack-obj (boardgame-org-object-create
                     :id stack-id
                     :name stack-name
                     :glyph "🂠"
                     :type 'stack
                     :file-path file-path
                     :stacked-items stacked-items)))
    ;; 1. Write the new consolidated stack file
    (let ((full-path (boardgame-org-world-file file-path)))
      (make-directory (file-name-directory full-path) t)
      (with-temp-file full-path
        (insert (boardgame-org-stack-serialize stack-obj))))
    ;; 2. INVARIANT: Delete former standalone Org files
    (dolist (obj objects)
      (boardgame-org-object-delete-file obj))
    stack-obj))

(defun boardgame-org-stack-expand (stack-object)
  "Expand STACK-OBJECT back into independent objects.
Reconstructs standalone Org files and removes the stack file per Section 3.1."
  (let ((reconstructed nil))
    (dolist (item (boardgame-org-object-stacked-items stack-object))
      (let* ((id (or (cdr (assoc "ORIGINAL_ID" item))
                     (cdr (assoc "ID" item))
                     (format "obj-%s" (make-temp-name ""))))
             (name (or (cdr (assoc "NAME" item)) "Restored Object"))
             (glyph (or (cdr (assoc "GLYPH" item)) "♟"))
             (type (intern (or (cdr (assoc "TYPE" item)) "card")))
             (file-path (format "objects/%s.org" id))
             (obj (boardgame-org-object-create
                   :id id
                   :name name
                   :glyph glyph
                   :type type
                   :file-path file-path
                   :properties item)))
        ;; Reconstruct standalone file
        (boardgame-org-object-save-file obj)
        (push obj reconstructed)))
    ;; Delete the consolidated stack file
    (boardgame-org-object-delete-file stack-object)
    (nreverse reconstructed)))

(provide 'boardgame-org-stack)
;;; boardgame-org-stack.el ends here
