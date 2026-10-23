;;; boardgame-org-object.el --- Object persistence, inspection, and execution -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 7 of boardgame-org-interface.md and Section 2 of boardgame-org.md:
;; "Each independent object is represented by an Org document containing a heading
;; named after the object. The document contains properties, glyph, colors, description,
;; and executable source blocks."

;;; Code:

(require 'org)
(require 'boardgame-org-core)

(defun boardgame-parse-property-drawer ()
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

(defun boardgame-object-from-buffer (file-path)
  "Create a `boardgame-object` by reading the current Org buffer."
  (let* ((props (boardgame-parse-property-drawer))
         (id (or (cdr (assoc "ID" props))
                 (file-name-base file-path)))
         (name (or (cdr (assoc "NAME" props))
                   (save-excursion
                     (goto-char (point-min))
                     (if (re-search-forward "^\\*+[ \t]+\\(.*\\)$" nil t)
                         (match-string 1)
                       id))))
         (glyph (or (cdr (assoc "GLYPH" props)) "♟"))
         (type-str (or (cdr (assoc "TYPE" props)) (cdr (assoc "OBJECT_TYPE" props)) "token"))
         (type (intern (downcase type-str)))
         (fg (cdr (assoc "FOREGROUND" props)))
         (bg (cdr (assoc "BACKGROUND" props)))
         (val (cdr (assoc "VALUE" props)))
         (sides (when (cdr (assoc "SIDES" props))
                  (string-to-number (cdr (assoc "SIDES" props))))))
    (boardgame-object-create
     :id id
     :name name
     :glyph glyph
     :type type
     :foreground fg
     :background bg
     :file-path file-path
     :properties props
     :value val
     :sides sides
     :description (boardgame-object--extract-body))))

(defun boardgame-object--extract-body ()
  "Extract description text following the primary heading."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^\\*+[ \t]+.*$" nil t)
        (let ((start (forward-line 1)))
          (string-trim (buffer-substring-no-properties (point) (point-max))))
      "")))

(defun boardgame-object-load-file (file-path)
  "Load and parse an object from FILE-PATH."
  (with-temp-buffer
    (insert-file-contents file-path)
    (org-mode)
    (boardgame-object-from-buffer file-path)))

(defun boardgame-object-serialize (object)
  "Serialize OBJECT to a standard Org-mode string with property drawer."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-object-id object)))
    (insert (format ":NAME: %s\n" (boardgame-object-name object)))
    (insert (format ":TYPE: %s\n" (boardgame-object-type object)))
    (insert (format ":GLYPH: %s\n" (boardgame-object-glyph object)))
    (when (boardgame-object-foreground object)
      (insert (format ":FOREGROUND: %s\n" (boardgame-object-foreground object))))
    (when (boardgame-object-background object)
      (insert (format ":BACKGROUND: %s\n" (boardgame-object-background object))))
    (when (boardgame-object-value object)
      (insert (format ":VALUE: %s\n" (boardgame-object-value object))))
    (when (boardgame-object-sides object)
      (insert (format ":SIDES: %d\n" (boardgame-object-sides object))))
    (dolist (pair (boardgame-object-properties object))
      (unless (member (car pair) '("ID" "NAME" "TYPE" "GLYPH" "FOREGROUND" "BACKGROUND" "VALUE" "SIDES"))
        (insert (format ":%s: %s\n" (car pair) (cdr pair)))))
    (insert ":END:\n\n")
    (insert (format "* %s\n" (boardgame-object-name object)))
    (when (boardgame-object-description object)
      (insert (boardgame-object-description object) "\n"))
    (buffer-string)))

(defun boardgame-object-save-file (object)
  "Write OBJECT to its persistent `file-path`."
  (let ((full-path (boardgame-world-file (boardgame-object-file-path object))))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (boardgame-object-serialize object)))))

(defun boardgame-object-delete-file (object)
  "Enforce invariant: delete OBJECT's standalone Org file."
  (let ((full-path (boardgame-world-file (boardgame-object-file-path object))))
    (when (file-exists-p full-path)
      (delete-file full-path))))

(defun boardgame-execute-object-block (object)
  "Execute the first source block in OBJECT's Org document."
  (let ((full-path (boardgame-world-file (boardgame-object-file-path object))))
    (unless (file-exists-p full-path)
      (error "Object file '%s' does not exist" full-path))
    (with-temp-buffer
      (insert-file-contents full-path)
      (org-mode)
      (goto-char (point-min))
      (if (re-search-forward "^#\\+begin_src[ \t]+emacs-lisp" nil t)
          (let ((start (point)))
            (if (re-search-forward "^#\\+end_src" nil t)
                (let* ((code (buffer-substring-no-properties start (match-beginning 0)))
                       (res (eval (read (format "(progn %s)" code)) t)))
                  (message "Executed %s: %s" (boardgame-object-name object) res)
                  res)
              (error "Malformed source block in %s" (boardgame-object-name object))))
        (message "No executable source block found in %s" (boardgame-object-name object))))))

(defun boardgame-execute-board-block (board)
  "Execute any top-level source block associated with BOARD."
  (let ((full-path (boardgame-world-file (boardgame-board-file-path board))))
    (with-temp-buffer
      (insert-file-contents full-path)
      (org-mode)
      (goto-char (point-min))
      (if (re-search-forward "^#\\+begin_src[ \t]+emacs-lisp" nil t)
          (let ((start (point)))
            (if (re-search-forward "^#\\+end_src" nil t)
                (eval (read (format "(progn %s)" (buffer-substring-no-properties start (match-beginning 0)))) t)
              (error "Malformed source block in board")))
        (message "No executable source block found in board")))))

(provide 'boardgame-org-object)
;;; boardgame-org-object.el ends here
