;;; boardgame-stack.el --- Multi-object Org document consolidation engine -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Multi-object Org document consolidation engine for boardgame.org.
;;
;; Implements §3.1 of `boardgame-org.md', §10.1 of `boardgame-org-interface.md',
;; and Stage 6 of `boardgame-implementation-plan.md':
;; - Explicit consolidation of multiple objects into a single Org document.
;; - Merging their Org contents into a single consolidated stack document.
;; - Representation on board with glyph '$' (black font, white background).
;; - Standalone Org files of incorporated objects are physically deleted from disk
;;   after successful consolidation.
;; - Expansion back to independent standalone object Org files if needed.
;;
;; In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;; internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'subr-x)

;; Forward declarations for variables defined in boardgame.el
(defvar boardgame-current-board-buffer)
(defvar boardgame-current-world-directory)

;; Forward declarations for `boardgame-data.el'
(declare-function boardgame-object-create "boardgame-data")
(declare-function boardgame-object-name "boardgame-data")
(declare-function boardgame-object-x "boardgame-data")
(declare-function boardgame-object-y "boardgame-data")
(declare-function boardgame-object-glyph "boardgame-data")
(declare-function boardgame-object-file "boardgame-data")
(declare-function boardgame-object-type "boardgame-data")
(declare-function boardgame-object-fg "boardgame-data")
(declare-function boardgame-object-bg "boardgame-data")
(declare-function boardgame-object-properties "boardgame-data")
(declare-function boardgame-object-content "boardgame-data")
(declare-function boardgame-board-get-objects "boardgame-data")
(declare-function boardgame-board-add-object "boardgame-data")
(declare-function boardgame-board-remove-object "boardgame-data")
(declare-function boardgame-board-file "boardgame-data")

;; Forward declarations for `boardgame-board.el'
(declare-function boardgame-board-current-coord "boardgame-board")
(declare-function boardgame-board-refresh "boardgame-board")
(declare-function boardgame-save-board "boardgame-board")

;; Forward declarations for `boardgame-world.el'
(declare-function boardgame-world-resolve-board "boardgame-world")

;; Forward declarations for `boardgame-log.el'
(declare-function boardgame-log-append "boardgame-log")

;; -----------------------------------------------------------------------------
;; Stack Consolidation Helpers
;; -----------------------------------------------------------------------------

(defun boardgame-stack--resolve-file-path (file world-dir)
  "Resolve FILE relative to WORLD-DIR if not absolute."
  (if (file-name-absolute-p file)
      file
    (expand-file-name file (or world-dir boardgame-current-world-directory default-directory))))

(defun boardgame-stack-consolidate-files (object-files stack-file &optional stack-name stack-id)
  "Consolidate standalone OBJECT-FILES into STACK-FILE.
STACK-NAME defaults to a formatted string.
Reads each object file, incorporates its content into STACK-FILE,
and physically deletes the original object files from disk.
Returns the list of consolidated items info."
  (when (< (length object-files) 1)
    (error "At least one object file required for stack consolidation"))
  (let* ((name (or stack-name (format "Stack (%d items)" (length object-files))))
         (sid (or stack-id (file-name-base stack-file)))
         (consolidated-items nil))
    ;; Read and verify all object files first before modifying/deleting anything
    (dolist (fpath object-files)
      (unless (file-exists-p fpath)
        (error "Object file does not exist: %s" fpath))
      (let ((body "")
            (obj-name "")
            (glyph "*")
            (type "token")
            (fg nil)
            (bg nil)
            (props nil))
        (with-temp-buffer
          (org-mode)
          (insert-file-contents fpath)
          (goto-char (point-min))
          (if (re-search-forward "^[ \t]*\\*[ \t]+\\(?:.*?\\)[ \t]*$" nil t)
              (progn
                (org-back-to-heading t)
                (setq obj-name (or (org-get-heading t t t t) (file-name-base fpath)))
                (setq props (org-entry-properties (point)))
                (setq glyph (or (cdr (assoc "GLYPH" props))
                                (if (> (length obj-name) 0) (substring obj-name 0 1) "*")))
                (setq type (or (cdr (assoc "OBJECT_TYPE" props)) (cdr (assoc "TYPE" props)) "token"))
                (setq fg (or (cdr (assoc "FG" props)) (cdr (assoc "FOREGROUND" props))))
                (setq bg (or (cdr (assoc "BG" props)) (cdr (assoc "BACKGROUND" props))))
                (setq body (buffer-string)))
            ;; Fallback if no org heading found
            (setq obj-name (file-name-base fpath))
            (setq body (buffer-string))))
        (push (list :file fpath
                    :name obj-name
                    :glyph glyph
                    :type type
                    :fg fg
                    :bg bg
                    :props props
                    :content body)
              consolidated-items)))
    (setq consolidated-items (nreverse consolidated-items))

    ;; Ensure destination directory exists
    (make-directory (file-name-directory stack-file) t)

    ;; Write consolidated stack file
    (with-temp-file stack-file
      (insert (format "* %s\n" name))
      (insert ":PROPERTIES:\n")
      (insert (format ":ID: %s\n" sid))
      (insert (format ":NAME: %s\n" name))
      (insert ":OBJECT_TYPE: stack\n")
      (insert ":GLYPH: $\n")
      (insert ":FG: black\n")
      (insert ":BG: white\n")
      (insert (format ":ITEM_COUNT: %d\n" (length consolidated-items)))
      (insert ":END:\n\n")
      (insert "** Stack Items\n")
      (dolist (item consolidated-items)
        (insert (format "*** %s\n" (plist-get item :name)))
        (insert ":PROPERTIES:\n")
        (insert (format ":ORIGINAL_FILE: %s\n" (file-name-nondirectory (plist-get item :file))))
        (insert (format ":GLYPH: %s\n" (plist-get item :glyph)))
        (insert (format ":OBJECT_TYPE: %s\n" (plist-get item :type)))
        (when (plist-get item :fg)
          (insert (format ":FG: %s\n" (plist-get item :fg))))
        (when (plist-get item :bg)
          (insert (format ":BG: %s\n" (plist-get item :bg))))
        (insert ":END:\n")
        (let ((content (plist-get item :content)))
          (when (and content (not (string-blank-p content)))
            (insert content "\n")))))

    ;; Delete original standalone object files from disk
    (dolist (item consolidated-items)
      (let ((fpath (plist-get item :file)))
        (when (file-exists-p fpath)
          (delete-file fpath))))

    consolidated-items))

;;;###autoload
(defun boardgame-stack-consolidate (objects stack-file-or-id &optional stack-name board)
  "Consolidate OBJECTS into a single Org document at STACK-FILE-OR-ID.
OBJECTS is a list of `boardgame-object' structs.
Original standalone files of incorporated objects are physically deleted from disk.
The resulting stack object is created and placed at the position of the first object.
Returns the newly created stack `boardgame-object'."
  (unless objects
    (error "No objects provided for stack consolidation"))
  (let* ((target-board (or board
                           (and (boundp 'boardgame-board--data) boardgame-board--data)
                           (and boardgame-current-board-buffer
                                (buffer-live-p boardgame-current-board-buffer)
                                (buffer-local-value 'boardgame-board--data boardgame-current-board-buffer))))
         (world-dir (or boardgame-current-world-directory
                        (and target-board (boardgame-board-file target-board)
                             (file-name-directory (boardgame-board-file target-board)))
                        default-directory))
         (first-obj (car objects))
         (x (boardgame-object-x first-obj))
         (y (boardgame-object-y first-obj))
         (stack-file (if (string-suffix-p ".org" stack-file-or-id)
                         (boardgame-stack--resolve-file-path stack-file-or-id world-dir)
                       (expand-file-name (format "stacks/%s.org" stack-file-or-id) world-dir)))
         (sname (or stack-name (format "Stack (%d items)" (length objects))))
         (sid (file-name-base stack-file))
         ;; Collect all standalone object files
         (obj-files nil))
    (dolist (obj objects)
      (let ((ofile (boardgame-object-file obj)))
        (if ofile
            (push (boardgame-stack--resolve-file-path ofile world-dir) obj-files)
          ;; If object had no file on disk, generate a temporary standalone file to consolidate
          (let* ((gen-name (format "obj-%s.org" (md5 (boardgame-object-name obj))))
                 (gen-path (expand-file-name (concat "objects/" gen-name) world-dir)))
            (make-directory (file-name-directory gen-path) t)
            (with-temp-file gen-path
              (insert (format "* %s\n" (boardgame-object-name obj)))
              (insert ":PROPERTIES:\n")
              (insert (format ":GLYPH: %s\n" (or (boardgame-object-glyph obj) "*")))
              (insert (format ":OBJECT_TYPE: %s\n" (or (boardgame-object-type obj) "token")))
              (when (boardgame-object-fg obj)
                (insert (format ":FG: %s\n" (boardgame-object-fg obj))))
              (when (boardgame-object-bg obj)
                (insert (format ":BG: %s\n" (boardgame-object-bg obj))))
              (insert ":END:\n")
              (when (boardgame-object-content obj)
                (insert (boardgame-object-content obj) "\n")))
            (push gen-path obj-files)))))
    (setq obj-files (nreverse obj-files))

    ;; Perform consolidation and file deletion
    (boardgame-stack-consolidate-files obj-files stack-file sname sid)

    ;; Create the in-memory stack object
    (let* ((rel-file (file-relative-name stack-file world-dir))
           (stack-obj (boardgame-object-create
                       :name sname
                       :x x
                       :y y
                       :glyph "$"
                       :file rel-file
                       :type "stack"
                       :fg "black"
                       :bg "white"
                       :properties `(("ID" . ,sid)
                                     ("ITEM_COUNT" . ,(number-to-string (length objects)))))))
      ;; Update board if provided
      (when target-board
        (dolist (obj objects)
          (boardgame-board-remove-object target-board obj))
        (boardgame-board-add-object target-board stack-obj)
        (when (and boardgame-current-board-buffer (buffer-live-p boardgame-current-board-buffer))
          (boardgame-board-refresh boardgame-current-board-buffer)))
      (boardgame-log-append (format "Consolidated %d objects into stack '%s'"
                                    (length objects) sname)
                            world-dir "Stack")
      stack-obj)))

;;;###autoload
(defun boardgame-stack-expand (stack-object &optional board)
  "Expand STACK-OBJECT back into independent standalone object files.
STACK-OBJECT is a `boardgame-object' struct.
Deletes the consolidated stack Org document upon expansion.
Returns a list of restored `boardgame-object' structs."
  (let* ((target-board (or board
                           (and (boundp 'boardgame-board--data) boardgame-board--data)
                           (and boardgame-current-board-buffer
                                (buffer-live-p boardgame-current-board-buffer)
                                (buffer-local-value 'boardgame-board--data boardgame-current-board-buffer))))
         (world-dir (or boardgame-current-world-directory
                        (and target-board (boardgame-board-file target-board)
                             (file-name-directory (boardgame-board-file target-board)))
                        default-directory))
         (stack-file (boardgame-stack--resolve-file-path (boardgame-object-file stack-object) world-dir))
         (x (boardgame-object-x stack-object))
         (y (boardgame-object-y stack-object))
         (restored-objects nil))
    (unless (file-exists-p stack-file)
      (error "Stack file does not exist: %s" stack-file))
    (with-temp-buffer
      (insert-file-contents stack-file)
      (goto-char (point-min))
      (while (re-search-forward "^\\*\\*\\* \\(.*?\\)[ \t]*$" nil t)
        (let* ((item-name (match-string 1))
               (props (org-entry-properties (point)))
               (orig-file (cdr (assoc "ORIGINAL_FILE" props)))
               (glyph (or (cdr (assoc "GLYPH" props))
                          (if (> (length item-name) 0) (substring item-name 0 1) "*")))
               (type (or (cdr (assoc "OBJECT_TYPE" props)) (cdr (assoc "TYPE" props)) "token"))
               (fg (cdr (assoc "FG" props)))
               (bg (cdr (assoc "BG" props)))
               (target-rel (concat "objects/" (or orig-file (format "obj-%s.org" (md5 item-name)))))
               (target-full (expand-file-name target-rel world-dir))
               (content (org-get-entry)))
          (make-directory (file-name-directory target-full) t)
          (with-temp-file target-full
            (insert (format "* %s\n" item-name))
            (insert ":PROPERTIES:\n")
            (insert (format ":GLYPH: %s\n" glyph))
            (insert (format ":OBJECT_TYPE: %s\n" type))
            (when fg (insert (format ":FG: %s\n" fg)))
            (when bg (insert (format ":BG: %s\n" bg)))
            (insert ":END:\n")
            (when content
              (insert content "\n")))
          (push (boardgame-object-create
                 :name item-name
                 :x x
                 :y y
                 :glyph glyph
                 :file target-rel
                 :type type
                 :fg fg
                 :bg bg)
                restored-objects))))
    (setq restored-objects (nreverse restored-objects))
    ;; Delete consolidated stack file
    (when (file-exists-p stack-file)
      (delete-file stack-file))
    ;; Update target board
    (when target-board
      (boardgame-board-remove-object target-board stack-object)
      (dolist (obj restored-objects)
        (boardgame-board-add-object target-board obj))
      (when (and boardgame-current-board-buffer (buffer-live-p boardgame-current-board-buffer))
        (boardgame-board-refresh boardgame-current-board-buffer)))
    (boardgame-log-append (format "Expanded stack '%s' into %d standalone objects"
                                  (boardgame-object-name stack-object) (length restored-objects))
                          world-dir "Stack")
    restored-objects))

;;;###autoload
(defun boardgame-stack-create-at-point ()
  "Consolidate all objects at the current board cursor into a Stack."
  (interactive)
  (let* ((board-buf (boardgame-world-resolve-board nil)))
    (unless (and board-buf (buffer-live-p board-buf))
      (error "No active board buffer available"))
    (with-current-buffer board-buf
      (unless (bound-and-true-p boardgame-board--data)
        (error "Current buffer has no board data"))
      (let* ((coord (boardgame-board-current-coord))
             (board boardgame-board--data)
             (objs (and coord (boardgame-board-get-objects board (car coord) (cdr coord)))))
        (unless (and objs (>= (length objs) 2))
          (error "Need at least 2 objects at cursor to consolidate into a stack"))
        (let* ((sid (format "stack-%s" (format-time-string "%Y%m%d%H%M%S")))
               (sname (read-string "Stack name: " (format "Stack (%d items)" (length objs)))))
          (boardgame-stack-consolidate objs sid sname board))))))

;;; boardgame-stack.el ends here