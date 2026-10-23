;;; boardgame-org-stack.el --- Stack consolidation, Org document merging and expansion -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 3.1 of boardgame-org.md and Section 10.1 of
;; boardgame-org-interface.md:
;; - Explicit consolidation of multiple objects into a single Org document
;; - Deletion of former standalone object files upon consolidation
;; - Distinct visual representation: '$' on white background with black text
;; - Expansion back to independent standalone object Org files

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'subr-x)
(require 'boardgame-org-core)

;;;###autoload
(defun boardgame-stack-consolidate (objects stack-id stack-name)
  "Consolidate OBJECTS into a single Org document at stacks/STACK-ID.org.
Removes former standalone object files per Section 3.1 & 10.1.
Returns the newly created stack `boardgame-object`."
  (let* ((rel-path (format "stacks/%s.org" stack-id))
         (full-path (boardgame-world-file rel-path))
         (consolidated-items nil))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (format "#+TITLE: Stack: %s\n" stack-name))
      (insert ":PROPERTIES:\n")
      (insert (format ":ID: %s\n" stack-id))
      (insert (format ":NAME: %s\n" stack-name))
      (insert ":TYPE: stack\n")
      (insert ":GLYPH: $\n")
      (insert ":FOREGROUND: black\n")
      (insert ":BACKGROUND: white\n")
      (insert (format ":ITEM_COUNT: %d\n" (length objects)))
      (insert ":END:\n\n")
      (dolist (obj objects)
        (let* ((oid (boardgame-object-id obj))
               (oname (boardgame-object-name obj))
               (oglyph (or (boardgame-object-glyph obj) "*"))
               (otype (or (boardgame-object-type obj) 'token))
               (orig-fpath (and (boardgame-object-file-path obj)
                                (boardgame-world-file (boardgame-object-file-path obj))))
               (body-content ""))
          (when (and orig-fpath (file-exists-p orig-fpath))
            (with-temp-buffer
              (insert-file-contents orig-fpath)
              (setq body-content (buffer-string)))
            ;; Remove former standalone file once read
            (when (string-prefix-p (boardgame-world-file "objects/") orig-fpath)
              (delete-file orig-fpath)))
          (push (list :id oid :name oname :glyph oglyph :type otype :content body-content)
                consolidated-items)
          (insert (format "* Item: %s\n" oname))
          (insert ":PROPERTIES:\n")
          (insert (format ":ORIGINAL_ID: %s\n" oid))
          (insert (format ":GLYPH: %s\n" oglyph))
          (insert (format ":TYPE: %s\n" otype))
          (insert ":END:\n\n")
          (if (> (length body-content) 0)
              (insert body-content "\n\n")
            (insert (format "Consolidated item %s\n\n" oname))))))
    (boardgame-object-create
     :id stack-id
     :name stack-name
     :glyph "$"
     :type 'stack
     :foreground "black"
     :background "white"
     :file-path rel-path
     :stacked-items (nreverse consolidated-items))))

;;;###autoload
(defun boardgame-stack-expand (stack-object)
  "Expand STACK-OBJECT back into independent standalone object files.
Deletes the consolidated stack Org document upon expansion.
Returns a list of restored `boardgame-object` structs."
  (let* ((rel-path (boardgame-object-file-path stack-object))
         (full-path (boardgame-world-file rel-path))
         (restored-objects nil))
    (unless (file-exists-p full-path)
      (error "Stack file '%s' does not exist" full-path))
    (with-temp-buffer
      (insert-file-contents full-path)
      (org-mode)
      (goto-char (point-min))
      (while (re-search-forward "^\\* Item:\\s-+\\(.*\\)$" nil t)
        (let* ((item-name (match-string-no-properties 1))
               (props (org-entry-properties (point)))
               (oid (or (cdr (assoc "ORIGINAL_ID" props))
                        (format "obj-%s-%d" (boardgame-object-id stack-object) (length restored-objects))))
               (glyph (or (cdr (assoc "GLYPH" props))
                          (if (> (length item-name) 0) (substring item-name 0 1) "*")))
               (type (intern (or (cdr (assoc "TYPE" props)) "token")))
               (target-rel (format "objects/%s.org" oid))
               (target-full (boardgame-world-file target-rel)))
          ;; Write back to independent file
          (make-directory (file-name-directory target-full) t)
          (with-temp-file target-full
            (insert ":PROPERTIES:\n")
            (insert (format ":ID: %s\n" oid))
            (insert (format ":NAME: %s\n" item-name))
            (insert (format ":GLYPH: %s\n" glyph))
            (insert (format ":TYPE: %s\n" type))
            (insert ":END:\n\n")
            (insert (format "* %s\n" item-name))
            (insert "Restored from consolidated stack.\n"))
          (push (boardgame-object-create
                 :id oid
                 :name item-name
                 :glyph glyph
                 :type type
                 :file-path target-rel)
                restored-objects))))
    ;; Remove stack file
    (when (file-exists-p full-path)
      (delete-file full-path))
    (nreverse restored-objects)))

(provide 'boardgame-org-stack)
;;; boardgame-org-stack.el ends here
