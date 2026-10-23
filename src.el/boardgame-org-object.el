;;; boardgame-org-object.el --- Object documents, properties, and execution -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 7 of boardgame-org-interface.md and Section 2 of
;; boardgame-org.md:
;; - Object representation as independent Org documents
;; - Creation, property querying, deletion, and placement
;; - Source block execution on objects and boards

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'subr-x)
(require 'boardgame-org-core)

;;;###autoload
(defun boardgame-load-object (rel-file-path)
  "Parse standalone object Org file at REL-FILE-PATH into a `boardgame-object`."
  (let ((full-path (boardgame-world-file rel-file-path)))
    (if (not (file-exists-p full-path))
        (let ((fallback-id (file-name-sans-extension (file-name-nondirectory rel-file-path))))
          (boardgame-object-create :id fallback-id :name fallback-id :glyph "♟" :type 'token :file-path rel-file-path))
      (with-temp-buffer
        (insert-file-contents full-path)
        (org-mode)
        (goto-char (point-min))
        (let* ((props (org-entry-properties (point-min)))
               (oid (or (cdr (assoc "ID" props))
                        (file-name-sans-extension (file-name-nondirectory rel-file-path))))
               (heading (progn (re-search-forward "^\\*+\\s-+\\(.*\\)$" nil t)
                               (or (match-string-no-properties 1) oid)))
               (glyph (or (cdr (assoc "GLYPH" props))
                          (if (> (length heading) 0) (substring heading 0 1) "*")))
               (raw-type (or (cdr (assoc "TYPE" props)) (cdr (assoc "OBJECT_TYPE" props)) "token"))
               (type (intern raw-type))
               (fg (cdr (assoc "FOREGROUND" props)))
               (bg (cdr (assoc "BACKGROUND" props)))
               (desc ""))
          (goto-char (point-min))
          (when (re-search-forward "^\\*+\\s-+.*$" nil t)
            (forward-line 1)
            (let ((start (point)))
              (when (re-search-forward "^\\(\\*+\\s-+\\|#\\+begin_src\\)" nil t)
                (goto-char (match-beginning 0)))
              (setq desc (string-trim (buffer-substring-no-properties start (point))))))
          (boardgame-object-create
           :id oid
           :name heading
           :glyph glyph
           :type type
           :description desc
           :foreground fg
           :background bg
           :properties props
           :file-path rel-file-path))))))

;;;###autoload
(defun boardgame-create-object (id name glyph &optional type foreground background description)
  "Create a new object document in objects/ and return `boardgame-object`."
  (let* ((rel-path (format "objects/%s.org" id))
         (full-path (boardgame-world-file rel-path))
         (obj-type (or type 'token)))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert ":PROPERTIES:\n")
      (insert (format ":ID: %s\n" id))
      (insert (format ":NAME: %s\n" name))
      (insert (format ":GLYPH: %s\n" glyph))
      (insert (format ":TYPE: %s\n" obj-type))
      (when foreground (insert (format ":FOREGROUND: %s\n" foreground)))
      (when background (insert (format ":BACKGROUND: %s\n" background)))
      (insert ":END:\n\n")
      (insert (format "* %s\n" name))
      (when description
        (insert description "\n")))
    (boardgame-object-create
     :id id
     :name name
     :glyph glyph
     :type obj-type
     :description description
     :foreground foreground
     :background background
     :file-path rel-path)))

;;; Source Block Execution (Section 7.4)

;;;###autoload
(defun boardgame-execute-object-block (object)
  "Execute the source block belonging to OBJECT."
  (interactive)
  (unless object
    (error "No object provided to execute block"))
  (let ((full-path (boardgame-world-file (boardgame-object-file-path object))))
    (if (not (file-exists-p full-path))
        (message "Object file '%s' does not exist." (boardgame-object-file-path object))
      (with-temp-buffer
        (insert-file-contents full-path)
        (goto-char (point-min))
        (if (re-search-forward "#\\+begin_src\\s-+\\(?:emacs-lisp\\|elisp\\)[^\n]*\n\\(\\(?:.\\|\n\\)*?\\)#\\+end_src" nil t)
            (let* ((code (match-string-no-properties 1))
                   (result (eval (read (format "(progn %s)" code)) t)))
              (when (fboundp 'boardgame-log)
                (boardgame-log (format "Executed Block: %s" (boardgame-object-name object))
                               `(("Code" . ,code)
                                 ("Result" . ,(format "%s" result)))))
              (message "Executed block for '%s' -> %s" (boardgame-object-name object) result)
              result)
          (message "No executable source block found in '%s'." (boardgame-object-name object)))))))

;;;###autoload
(defun boardgame-execute-board-block ()
  "Execute a source block associated with the active board."
  (interactive)
  (unless (and (boundp 'boardgame--current-board) boardgame--current-board)
    (error "No active board loaded"))
  (let ((full-path (boardgame-world-file (boardgame-board-file-path boardgame--current-board))))
    (if (not (file-exists-p full-path))
        (message "Board file '%s' does not exist." full-path)
      (with-temp-buffer
        (insert-file-contents full-path)
        (goto-char (point-min))
        (if (re-search-forward "#\\+begin_src\\s-+\\(?:emacs-lisp\\|elisp\\)[^\n]*\n\\(\\(?:.\\|\n\\)*?\\)#\\+end_src" nil t)
            (let* ((code (match-string-no-properties 1))
                   (result (eval (read (format "(progn %s)" code)) t)))
              (when (fboundp 'boardgame-log)
                (boardgame-log (format "Board Block Executed: %s" (boardgame-board-filename boardgame--current-board))
                               `(("Code" . ,code)
                                 ("Result" . ,(format "%s" result)))))
              (message "Executed board block -> %s" result)
              result)
          (message "No executable source block found in board Org file."))))))

;;; Property Query & Object Management

;;;###autoload
(defun boardgame-query-object-property (prop-name)
  "Query property PROP-NAME of top object at cursor."
  (interactive "sProperty name: ")
  (let* ((placed (and (boundp 'boardgame--current-board)
                      (boundp 'boardgame--cursor-x)
                      (boundp 'boardgame--cursor-y)
                      (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y)))
         (top (car (last placed)))
         (obj (and top (cdr (assoc (boardgame-placed-object-id top) (bound-and-true-p boardgame--current-objects-alist))))))
    (if (null obj)
        (message "No object under cursor.")
      (let ((val (or (cdr (assoc prop-name (boardgame-object-properties obj)))
                     "unspecified")))
        (message "%s: %s = %s" (boardgame-object-name obj) prop-name val)
        val))))

;;;###autoload
(defun boardgame-delete-object ()
  "Remove top object under cursor from board and remove file if standalone."
  (interactive)
  (let* ((placed (and (boundp 'boardgame--current-board)
                      (boundp 'boardgame--cursor-x)
                      (boundp 'boardgame--cursor-y)
                      (boardgame-board-objects-at boardgame--current-board boardgame--cursor-x boardgame--cursor-y)))
         (top (car (last placed)))
         (obj (and top (cdr (assoc (boardgame-placed-object-id top) (bound-and-true-p boardgame--current-objects-alist))))))
    (if (null top)
        (message "No object under cursor to delete.")
      (setf (boardgame-board-placed-objects boardgame--current-board)
            (delete top (boardgame-board-placed-objects boardgame--current-board)))
      (when (and obj (boardgame-object-file-path obj))
        (let ((fpath (boardgame-world-file (boardgame-object-file-path obj))))
          (when (and (file-exists-p fpath)
                     (string-prefix-p (boardgame-world-file "objects/") fpath))
            (delete-file fpath))))
      (when (fboundp 'boardgame-refresh-board) (boardgame-refresh-board))
      (when (fboundp 'boardgame-save-board) (boardgame-save-board))
      (message "Deleted object '%s'." (if obj (boardgame-object-name obj) (boardgame-placed-object-id top))))))

;;;###autoload
(defun boardgame-add-object (object-id x y)
  "Place existing object OBJECT-ID onto active board at coordinates X, Y."
  (interactive "sObject ID: \nnX: \nnY: ")
  (unless (and (boundp 'boardgame--current-board) boardgame--current-board)
    (error "No board loaded"))
  (let* ((placed (boardgame-placed-create :object-id object-id :x x :y y :layer 0))
         (obj (boardgame-load-object (format "objects/%s.org" object-id))))
    (push placed (boardgame-board-placed-objects boardgame--current-board))
    (push (cons object-id obj) boardgame--current-objects-alist)
    (when (fboundp 'boardgame-refresh-board) (boardgame-refresh-board))
    (message "Placed '%s' at (%d, %d)." object-id x y)))

(provide 'boardgame-org-object)
;;; boardgame-org-object.el ends here
