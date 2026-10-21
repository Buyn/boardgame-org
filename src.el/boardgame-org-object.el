;;; boardgame-org-object.el --- Object persistence and file lifecycle for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 2 of boardgame-org.md:
;; "An Object Is a File. An independently existing object has its own Org file.
;; When that object ceases to exist as an independent object because it has been
;; incorporated into another representation, its former standalone file must be removed."

;;; Code:

(require 'org)
(require 'boardgame-org-core)

(defun boardgame-org-parse-property-drawer ()
  "Parse current Org buffer's top-level property drawer into an alist."
  (save-excursion
    (goto-char (point-min))
    (let (props)
      (when (re-search-forward "^:PROPERTIES:" nil t)
        (while (and (forward-line 1)
                    (not (looking-at-p "^:END:")))
          (when (looking-at "^:\\([A-Za-z0-9_-]+\\):[ \t]*\\(.*\\)$")
            (push (cons (upcase (match-string 1))
                        (string-trim (match-string 2)))
                  props))))
      (nreverse props))))

(defun boardgame-org-object-from-buffer (file-path)
  "Create a `boardgame-org-object` by reading the current Org buffer."
  (let* ((props (boardgame-org-parse-property-drawer))
         (id (or (cdr (assoc "ID" props))
                 (file-name-base file-path)))
         (name (or (cdr (assoc "NAME" props))
                   (save-excursion
                     (goto-char (point-min))
                     (if (re-search-forward "^\\*+[ \t]+\\(.*\\)$" nil t)
                         (match-string 1)
                       id))))
         (glyph (or (cdr (assoc "GLYPH" props)) "♟"))
         (type-str (or (cdr (assoc "TYPE" props)) "token"))
         (type (intern (downcase type-str)))
         (face-up (not (string= (cdr (assoc "FACE_UP" props)) "nil")))
         (val (cdr (assoc "VALUE" props)))
         (sides (when (cdr (assoc "SIDES" props))
                  (string-to-number (cdr (assoc "SIDES" props))))))
    (boardgame-org-object-create
     :id id
     :name name
     :glyph glyph
     :type type
     :file-path file-path
     :properties props
     :face-up face-up
     :value val
     :sides sides
     :description (boardgame-org-object--extract-body))))

(defun boardgame-org-object--extract-body ()
  "Extract description text following the primary heading."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^\\*+[ \t]+.*$" nil t)
        (let ((start (forward-line 1)))
          (string-trim (buffer-substring-no-properties (point) (point-max))))
      "")))

(defun boardgame-org-object-load-file (file-path)
  "Load and parse an object from FILE-PATH."
  (with-temp-buffer
    (insert-file-contents file-path)
    (org-mode)
    (boardgame-org-object-from-buffer file-path)))

(defun boardgame-org-object-serialize (object)
  "Serialize OBJECT to a standard Org-mode string with property drawer."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-org-object-id object)))
    (insert (format ":NAME: %s\n" (boardgame-org-object-name object)))
    (insert (format ":TYPE: %s\n" (boardgame-org-object-type object)))
    (insert (format ":GLYPH: %s\n" (boardgame-org-object-glyph object)))
    (insert (format ":FACE_UP: %s\n" (if (boardgame-org-object-face-up object) "t" "nil")))
    (when (boardgame-org-object-value object)
      (insert (format ":VALUE: %s\n" (boardgame-org-object-value object))))
    (when (boardgame-org-object-sides object)
      (insert (format ":SIDES: %d\n" (boardgame-org-object-sides object))))
    (dolist (pair (boardgame-org-object-properties object))
      (unless (member (car pair) '("ID" "NAME" "TYPE" "GLYPH" "FACE_UP" "VALUE" "SIDES"))
        (insert (format ":%s: %s\n" (car pair) (cdr pair)))))
    (insert ":END:\n\n")
    (insert (format "* %s\n" (boardgame-org-object-name object)))
    (when (boardgame-org-object-description object)
      (insert (boardgame-org-object-description object) "\n"))
    (buffer-string)))

(defun boardgame-org-object-save-file (object)
  "Write OBJECT to its persistent `file-path`."
  (let ((full-path (boardgame-org-world-file (boardgame-org-object-file-path object))))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (boardgame-org-object-serialize object)))))

(defun boardgame-org-object-delete-file (object)
  "Enforce invariant: delete OBJECT's standalone Org file."
  (let ((full-path (boardgame-org-world-file (boardgame-org-object-file-path object))))
    (when (file-exists-p full-path)
      (delete-file full-path))))

(provide 'boardgame-org-object)
;;; boardgame-org-object.el ends here
