;;; boardgame-hand.el --- Player hand management and universal Org heading transfers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Player hand management and universal Org heading transfers for boardgame.org.
;;
;; Implements §2.3 of `boardgame-org.md', §9 of `boardgame-org-interface.md',
;; and Stage 6 of `boardgame-implementation-plan.md':
;; - Hand Org file management (`test-world/hand.org` or configured active hand).
;; - `boardgame-hand-place-on-board': Extracts an Org heading and subtree from
;;   an Org buffer, creates a standalone object Org file in `objects/`, resolves
;;   visual glyph (from first character of heading, :GLYPH: property, or fallback '*'),
;;   places it on the active board at the cursor, and cuts the subtree from the source.
;; - `boardgame-hand-take': Transfers the object under cursor on the board into
;;   the active hand subtree and removes the standalone file once safe.
;; - Container/Stack take semantics: If cursor is over a container or stack,
;;   takes the top item rather than the container or stack itself.
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

(defcustom boardgame-active-hand-file "hand.org"
  "File name or relative path of the active hand Org document."
  :type 'string
  :group 'boardgame)

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

;; Forward declarations for `boardgame-world.el'
(declare-function boardgame-world-resolve-board "boardgame-world")

;; Forward declarations for `boardgame-log.el'
(declare-function boardgame-log-append "boardgame-log")

;; Forward declarations for `boardgame-draw.el'
(declare-function boardgame-draw-resolve-glyph "boardgame-draw")

;; Forward declarations for `boardgame-container.el'
(declare-function boardgame-container-draw-top "boardgame-container")

;; Forward declarations for `boardgame-stack.el'
(declare-function boardgame-stack-expand "boardgame-stack")

;; -----------------------------------------------------------------------------
;; Active Hand Resolution
;; -----------------------------------------------------------------------------

(defun boardgame-hand-get-file (&optional world-dir)
  "Return the absolute path to the active hand file.
Resolves relative to WORLD-DIR or `boardgame-current-world-directory'."
  (let ((wdir (or world-dir boardgame-current-world-directory default-directory))
        (hfile (or boardgame-active-hand-file "hand.org")))
    (if (file-name-absolute-p hfile)
        hfile
      (let ((primary (expand-file-name hfile wdir))
            (sub-hands (expand-file-name (concat "hands/" hfile) wdir)))
        (cond
         ((file-exists-p primary) primary)
         ((file-exists-p sub-hands) sub-hands)
         (t primary))))))

;;;###autoload
(defun boardgame-open-hand (&optional world-dir)
  "Open the active hand's Org file in a regular Emacs buffer."
  (interactive)
  (let ((hand-file (boardgame-hand-get-file world-dir)))
    (unless (file-exists-p hand-file)
      (make-directory (file-name-directory hand-file) t)
      (with-temp-file hand-file
        (insert "* Hand: Player Hand\n")
        (insert ":PROPERTIES:\n:HAND_OWNER: Player\n:END:\n\n")
        (insert "** Subtrees\n")))
    (find-file-other-window hand-file)))

;; -----------------------------------------------------------------------------
;; Placing Headings on the Board
;; -----------------------------------------------------------------------------

;;;###autoload
(defun boardgame-place-on-board (&optional target-board target-x target-y)
  "Transfer current Org heading and its subtree from ANY Org buffer to active board.
Creates a standalone object Org file in objects/ and registers it on TARGET-BOARD.
Derives display glyph from :GLYPH: property or first character of heading title (fallback '*').
Removes the heading subtree from the source Org buffer only after successful creation."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (error "Must be called within an Org-mode buffer"))
  (let* ((board-buf (boardgame-world-resolve-board nil))
         (board (or target-board
                    (and board-buf (buffer-live-p board-buf)
                         (buffer-local-value 'boardgame-board--data board-buf))))
         (world-dir (or boardgame-current-world-directory
                        (and board (boardgame-board-file board)
                             (file-name-directory (boardgame-board-file board)))
                        default-directory)))
    (unless board
      (error "No active board buffer available to receive object"))
    ;; Determine target coordinate
    (let* ((coord (if (and target-x target-y)
                      (cons target-x target-y)
                    (with-current-buffer (or board-buf (current-buffer))
                      (or (boardgame-board-current-coord) (cons 0 0)))))
           (x (car coord))
           (y (cdr coord)))
      (org-back-to-heading t)
      (let* ((heading-text (org-get-heading t t t t))
             (clean-title (string-trim (or heading-text "Object")))
             (props (org-entry-properties))
             (prop-glyph (cdr (assoc "GLYPH" props)))
             (glyph (or prop-glyph (string (boardgame-draw-resolve-glyph clean-title ?*))))
             (obj-type (or (cdr (assoc "OBJECT_TYPE" props)) (cdr (assoc "TYPE" props)) "card"))
             (fg (cdr (assoc "FG" props)))
             (bg (cdr (assoc "BG" props)))
             (obj-id (or (cdr (assoc "ID" props))
                         (format "obj-%s" (format-time-string "%Y%m%d%H%M%S"))))
             (rel-file (format "objects/%s.org" obj-id))
             (target-file (expand-file-name rel-file world-dir))
             ;; Capture entire subtree content
             (subtree-content (save-excursion
                                (org-back-to-heading t)
                                (let ((beg (point)))
                                  (org-end-of-subtree t t)
                                  (buffer-substring-no-properties beg (point))))))
        ;; 1. Write standalone object Org file
        (make-directory (file-name-directory target-file) t)
        (let ((entry-body (org-get-entry)))
          (with-temp-file target-file
            (insert (format "* %s\n" clean-title))
            (insert ":PROPERTIES:\n")
            (insert (format ":ID: %s\n" obj-id))
            (insert (format ":OBJECT_TYPE: %s\n" obj-type))
            (insert (format ":GLYPH: %s\n" glyph))
            (when fg (insert (format ":FG: %s\n" fg)))
            (when bg (insert (format ":BG: %s\n" bg)))
            (dolist (p props)
              (unless (member (upcase (car p)) '("ID" "OBJECT_TYPE" "TYPE" "GLYPH" "FG" "BG" "CATEGORY"))
                (insert (format ":%s: %s\n" (upcase (car p)) (cdr p)))))
            (insert ":END:\n\n")
            (when (and entry-body (not (string-blank-p entry-body)))
              (insert entry-body "\n"))))
        ;; 2. Create in-memory object and add to board
        (let ((new-obj (boardgame-object-create
                        :name clean-title
                        :x x
                        :y y
                        :glyph glyph
                        :file rel-file
                        :type obj-type
                        :fg fg
                        :bg bg
                        :properties props
                        :content subtree-content)))
          (boardgame-board-add-object board new-obj)
          (when (and board-buf (buffer-live-p board-buf))
            (boardgame-board-refresh board-buf)))
        ;; 3. Cut subtree from source Org buffer
        (org-cut-subtree)
        (boardgame-log-append (format "Placed '%s' on board at (%d, %d)" clean-title x y)
                              world-dir "Hand")
        (message "Placed '%s' (%s) on board at (%d, %d)" clean-title glyph x y)))))

;; -----------------------------------------------------------------------------
;; Taking Objects from Board into Hand
;; -----------------------------------------------------------------------------

;;;###autoload
(defun boardgame-hand-take (&optional target-x target-y)
  "Transfer object under board cursor (or at TARGET-X, TARGET-Y) into active hand.
If cursor is over a container or stack, extracts its top item instead of taking the container.
For ordinary objects, inserts the object into the hand Org file and physically deletes
the standalone object file."
  (interactive)
  (let* ((board-buf (boardgame-world-resolve-board nil)))
    (unless (and board-buf (buffer-live-p board-buf))
      (error "No active board buffer available"))
    (with-current-buffer board-buf
      (unless (bound-and-true-p boardgame-board--data)
        (error "Current buffer has no board data"))
      (let* ((board boardgame-board--data)
             (world-dir (or boardgame-current-world-directory
                            (and (boardgame-board-file board)
                                 (file-name-directory (boardgame-board-file board)))
                            default-directory))
             (coord (if (and target-x target-y)
                        (cons target-x target-y)
                      (boardgame-board-current-coord)))
             (x (car coord))
             (y (cdr coord))
             (objs (and coord (boardgame-board-get-objects board x y)))
             (top-obj (car objs)))
        (unless top-obj
          (error "No object to take at (%d, %d)" x y))
        (let ((hand-file (boardgame-hand-get-file world-dir)))
          (make-directory (file-name-directory hand-file) t)
          (unless (file-exists-p hand-file)
            (with-temp-file hand-file
              (insert "* Hand: Player Hand\n:PROPERTIES:\n:HAND_OWNER: Player\n:END:\n\n** Subtrees\n")))
          (cond
           ;; Case 1: Taking from a permanent container
           ((string-equal (boardgame-object-type top-obj) "container")
            (let ((drawn (boardgame-container-draw-top top-obj world-dir)))
              (unless drawn
                (error "Container '%s' is empty" (boardgame-object-name top-obj)))
              ;; Insert into hand Org file
              (boardgame-hand--insert-item-into-file hand-file
                                                     (plist-get drawn :name)
                                                     (plist-get drawn :glyph)
                                                     (plist-get drawn :type)
                                                     (plist-get drawn :file)
                                                     (plist-get drawn :content))
              (message "Took '%s' from container '%s' into hand"
                       (plist-get drawn :name) (boardgame-object-name top-obj))))

           ;; Case 2: Taking from a consolidated stack
           ((string-equal (boardgame-object-type top-obj) "stack")
            (let ((restored (boardgame-stack-expand top-obj board)))
              (if (null restored)
                  (error "Stack '%s' had no items" (boardgame-object-name top-obj))
                ;; Take the topmost restored item into hand
                (let ((drawn (car restored)))
                  (boardgame-hand--insert-item-into-file hand-file
                                                         (boardgame-object-name drawn)
                                                         (boardgame-object-glyph drawn)
                                                         (boardgame-object-type drawn)
                                                         nil
                                                         (boardgame-object-content drawn))
                  (boardgame-board-remove-object board drawn)
                  (let ((fpath (and (boardgame-object-file drawn)
                                    (expand-file-name (boardgame-object-file drawn) world-dir))))
                    (when (and fpath (file-exists-p fpath))
                      (delete-file fpath)))
                  (message "Took top item '%s' from stack into hand"
                           (boardgame-object-name drawn))))))

           ;; Case 3: Ordinary object
           (t
            (let* ((obj-name (boardgame-object-name top-obj))
                   (glyph (boardgame-object-glyph top-obj))
                   (type (boardgame-object-type top-obj))
                   (rel-file (boardgame-object-file top-obj))
                   (full-file (and rel-file (expand-file-name rel-file world-dir)))
                   (content (or (boardgame-object-content top-obj) "")))
              ;; If standalone file exists, read complete content from file
              (when (and full-file (file-exists-p full-file))
                (with-temp-buffer
                  (insert-file-contents full-file)
                  (setq content (buffer-string))))
              ;; 1. Insert into active hand
              (boardgame-hand--insert-item-into-file hand-file obj-name glyph type nil content)
              ;; 2. Remove object from board
              (boardgame-board-remove-object board top-obj)
              ;; 3. Safely delete standalone file if it exists in objects/
              (when (and full-file (file-exists-p full-file)
                         (string-prefix-p (expand-file-name "objects" world-dir) full-file))
                (delete-file full-file))
              (boardgame-log-append (format "Took '%s' from board into hand" obj-name)
                                    world-dir "Hand")
              (message "Took '%s' into hand" obj-name))))
          ;; Refresh board buffer
          (boardgame-board-refresh board-buf))))))

(defun boardgame-hand--insert-item-into-file (hand-file name glyph type ofile content)
  "Insert an item into HAND-FILE under the first parent heading or ** Subtrees.
Preserves item as a complete Org subtree."
  (let ((buf (find-buffer-visiting hand-file)))
    (if buf
        (with-current-buffer buf
          (save-excursion
            (goto-char (point-min))
            (if (re-search-forward "^\\*\\* \\(?:Subtrees\\|Items\\|Hand Items\\)[ \t]*$" nil t)
                (forward-line 1)
              (goto-char (point-max))
              (insert "\n** Subtrees\n"))
            (insert (format "*** %s\n" name))
            (insert ":PROPERTIES:\n")
            (when ofile (insert (format ":OBJECT_FILE: %s\n" ofile)))
            (when glyph (insert (format ":GLYPH: %s\n" glyph)))
            (when type (insert (format ":OBJECT_TYPE: %s\n" type)))
            (insert ":END:\n")
            (when (and content (not (string-blank-p content)))
              (insert content "\n"))
            (save-buffer)))
      (with-temp-buffer
        (if (file-exists-p hand-file)
            (insert-file-contents hand-file)
          (insert "* Hand: Player Hand\n:PROPERTIES:\n:HAND_OWNER: Player\n:END:\n\n** Subtrees\n"))
        (goto-char (point-min))
        (if (re-search-forward "^\\*\\* \\(?:Subtrees\\|Items\\|Hand Items\\)[ \t]*$" nil t)
            (forward-line 1)
          (goto-char (point-max))
          (insert "\n** Subtrees\n"))
        (insert (format "*** %s\n" name))
        (insert ":PROPERTIES:\n")
        (when ofile (insert (format ":OBJECT_FILE: %s\n" ofile)))
        (when glyph (insert (format ":GLYPH: %s\n" glyph)))
        (when type (insert (format ":OBJECT_TYPE: %s\n" type)))
        (insert ":END:\n")
        (when (and content (not (string-blank-p content)))
          (insert content "\n"))
        (write-region (point-min) (point-max) hand-file nil 'quiet)))))

;;; boardgame-hand.el ends here