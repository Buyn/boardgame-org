;;; boardgame-container.el --- Permanent container Org document manager -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Permanent container Org document manager for boardgame.org.
;;
;; Implements §3.2 of `boardgame-org.md', §10.2-10.5 of `boardgame-org-interface.md',
;; and Stage 6 of `boardgame-implementation-plan.md':
;; - Organizes references to independent objects without consolidating or deleting
;;   the objects' individual Org files.
;; - Drawing operations: top, bottom, random.
;; - Shuffling container references.
;; - Laying out contents on surrounding free cells.
;; - Containers remain persistent objects even when empty.
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
(declare-function boardgame-board-width "boardgame-data")
(declare-function boardgame-board-height "boardgame-data")
(declare-function boardgame-board-get-objects "boardgame-data")
(declare-function boardgame-board-add-object "boardgame-data")
(declare-function boardgame-board-remove-object "boardgame-data")
(declare-function boardgame-board-file "boardgame-data")
(declare-function boardgame-coord-valid-p "boardgame-data")

;; Forward declarations for `boardgame-board.el'
(declare-function boardgame-board-current-coord "boardgame-board")
(declare-function boardgame-board-refresh "boardgame-board")

;; Forward declarations for `boardgame-world.el'
(declare-function boardgame-world-resolve-board "boardgame-world")

;; Forward declarations for `boardgame-log.el'
(declare-function boardgame-log-append "boardgame-log")

;; Forward declarations for `boardgame-draw.el'
(declare-function boardgame-draw-resolve-glyph "boardgame-draw")

;; -----------------------------------------------------------------------------
;; Container File Helpers
;; -----------------------------------------------------------------------------

(defun boardgame-container--resolve-path (file world-dir)
  "Resolve FILE relative to WORLD-DIR if not absolute."
  (if (file-name-absolute-p file)
      file
    (expand-file-name file (or world-dir boardgame-current-world-directory default-directory))))

(defun boardgame-container--read-entries (container-file)
  "Read list of contained item entry plists from CONTAINER-FILE.
Each element is a plist (:name NAME :file FILE :glyph GLYPH :type TYPE :content CONTENT)."
  (let ((entries nil))
    (when (file-exists-p container-file)
      (with-temp-buffer
        (org-mode)
        (insert-file-contents container-file)
        (goto-char (point-min))
        ;; Only scan for 3-star headings (*** Item: Name or *** Name)
        (while (re-search-forward "^\\*\\*\\* \\(?:Item:[ \t]*\\)?\\(.*?\\)[ \t]*$" nil t)
          (let* ((item-name (match-string 1))
                 (props (org-entry-properties (point)))
                 (item-file (or (cdr (assoc "OBJECT_FILE" props))
                                (cdr (assoc "FILE" props))))
                 (glyph (or (cdr (assoc "GLYPH" props))
                            (boardgame-draw-resolve-glyph item-name ?*)))
                 (type (or (cdr (assoc "OBJECT_TYPE" props))
                           (cdr (assoc "TYPE" props))
                           "card"))
                 (content (org-get-entry)))
            (push (list :name item-name
                        :file item-file
                        :glyph (if (characterp glyph) (string glyph) glyph)
                        :type type
                        :content content)
                  entries)))))
    (nreverse entries)))

(defun boardgame-container--write-entries (container-file name id glyph entries &optional cprops)
  "Rewrite CONTAINER-FILE with updated ENTRIES without touching standalone files.
Preserves container header and property drawer."
  (make-directory (file-name-directory container-file) t)
  (with-temp-file container-file
    (insert (format "* Container: %s\n" name))
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" id))
    (insert (format ":NAME: %s\n" name))
    (insert ":OBJECT_TYPE: container\n")
    (insert (format ":GLYPH: %s\n" (or glyph "C")))
    (insert (format ":COUNT: %d\n" (length entries)))
    (dolist (p cprops)
      (unless (member (upcase (car p)) '("ID" "NAME" "OBJECT_TYPE" "GLYPH" "COUNT" "CATEGORY"))
        (insert (format ":%s: %s\n" (upcase (car p)) (cdr p)))))
    (insert ":END:\n\n")
    (insert "** Contents\n")
    (dolist (entry entries)
      (insert (format "*** Item: %s\n" (plist-get entry :name)))
      (insert ":PROPERTIES:\n")
      (when (plist-get entry :file)
        (insert (format ":OBJECT_FILE: %s\n" (plist-get entry :file))))
      (when (plist-get entry :glyph)
        (insert (format ":GLYPH: %s\n" (plist-get entry :glyph))))
      (when (plist-get entry :type)
        (insert (format ":OBJECT_TYPE: %s\n" (plist-get entry :type))))
      (insert ":END:\n")
      (when (and (plist-get entry :content)
                 (not (string-blank-p (plist-get entry :content))))
        (insert (plist-get entry :content) "\n")))))

;; -----------------------------------------------------------------------------
;; Container Lifecycle & Management
;; -----------------------------------------------------------------------------

;;;###autoload
(defun boardgame-container-create (id name &optional glyph world-dir)
  "Create a permanent container Org document at containers/ID.org.
Returns the relative file path."
  (let* ((wdir (or world-dir boardgame-current-world-directory default-directory))
         (rel-path (format "containers/%s.org" id))
         (full-path (expand-file-name rel-path wdir))
         (gly (or glyph "C")))
    (unless (file-exists-p full-path)
      (make-directory (file-name-directory full-path) t)
      (with-temp-file full-path
        (insert (format "* Container: %s\n" name))
        (insert ":PROPERTIES:\n")
        (insert (format ":ID: %s\n" id))
        (insert (format ":NAME: %s\n" name))
        (insert ":OBJECT_TYPE: container\n")
        (insert (format ":GLYPH: %s\n" gly))
        (insert ":COUNT: 0\n")
        (insert ":END:\n\n")
        (insert "** Contents\n")))
    rel-path))

;;;###autoload
(defun boardgame-container-add-object (container-obj object &optional world-dir)
  "Add OBJECT (a `boardgame-object' struct or standalone file) into CONTAINER-OBJ.
Does NOT consolidate or delete the object's standalone file.
Removes object from board if placed.
Returns non-nil on success."
  (let* ((wdir (or world-dir boardgame-current-world-directory default-directory))
         (c-file (boardgame-container--resolve-path (boardgame-object-file container-obj) wdir))
         (entries (boardgame-container--read-entries c-file))
         (obj-file (if (stringp object) object (boardgame-object-file object)))
         (obj-name (if (stringp object) (file-name-base object) (boardgame-object-name object)))
         (obj-glyph (if (stringp object) "*" (or (boardgame-object-glyph object) "*")))
         (obj-type (if (stringp object) "card" (or (boardgame-object-type object) "card")))
         (obj-content (if (stringp object) "" (boardgame-object-content object))))
    (unless (file-exists-p c-file)
      (error "Container file does not exist: %s" c-file))
    ;; If object has a standalone file, read properties if possible
    (when (and obj-file (file-exists-p (boardgame-container--resolve-path obj-file wdir)))
      (let ((full-obj-path (boardgame-container--resolve-path obj-file wdir)))
        (with-temp-buffer
          (org-mode)
          (insert-file-contents full-obj-path)
          (goto-char (point-min))
          (when (re-search-forward "^[ \t]*\\*[ \t]+\\(?:.*?\\)[ \t]*$" nil t)
            (org-back-to-heading t)
            (setq obj-name (or (org-get-heading t t t t) (file-name-base full-obj-path)))
            (let ((props (org-entry-properties (point))))
              (when (assoc "GLYPH" props) (setq obj-glyph (cdr (assoc "GLYPH" props))))
              (when (assoc "OBJECT_TYPE" props) (setq obj-type (cdr (assoc "OBJECT_TYPE" props)))))))))
    (let ((new-entry (list :name obj-name
                           :file obj-file
                           :glyph obj-glyph
                           :type obj-type
                           :content obj-content)))
      (setq entries (append entries (list new-entry)))
      (boardgame-container--write-entries c-file
                                          (boardgame-object-name container-obj)
                                          (file-name-base c-file)
                                          (boardgame-object-glyph container-obj)
                                          entries
                                          (boardgame-object-properties container-obj))
      (boardgame-log-append (format "Added '%s' to container '%s'" obj-name (boardgame-object-name container-obj))
                            wdir "Container")
      t)))

;;;###autoload
(defun boardgame-container-draw-top (container-obj &optional world-dir)
  "Draw the top item from CONTAINER-OBJ.
Removes item reference from container without deleting its standalone Org file.
Returns the drawn item entry plist or nil if empty."
  (let* ((wdir (or world-dir boardgame-current-world-directory default-directory))
         (c-file (boardgame-container--resolve-path (boardgame-object-file container-obj) wdir))
         (entries (boardgame-container--read-entries c-file)))
    (if (null entries)
        (progn
          (message "Container '%s' is empty" (boardgame-object-name container-obj))
          nil)
      (let ((drawn (car entries))
            (rest (cdr entries)))
        (boardgame-container--write-entries c-file
                                            (boardgame-object-name container-obj)
                                            (file-name-base c-file)
                                            (boardgame-object-glyph container-obj)
                                            rest
                                            (boardgame-object-properties container-obj))
        (boardgame-log-append (format "Drew top item '%s' from container '%s'"
                                      (plist-get drawn :name) (boardgame-object-name container-obj))
                              wdir "Container")
        drawn))))

;;;###autoload
(defun boardgame-container-draw-bottom (container-obj &optional world-dir)
  "Draw the bottom item from CONTAINER-OBJ.
Removes item reference without deleting standalone Org file.
Returns the drawn item entry plist or nil if empty."
  (let* ((wdir (or world-dir boardgame-current-world-directory default-directory))
         (c-file (boardgame-container--resolve-path (boardgame-object-file container-obj) wdir))
         (entries (boardgame-container--read-entries c-file)))
    (if (null entries)
        (progn
          (message "Container '%s' is empty" (boardgame-object-name container-obj))
          nil)
      (let* ((rev (reverse entries))
             (drawn (car rev))
             (rest (reverse (cdr rev))))
        (boardgame-container--write-entries c-file
                                            (boardgame-object-name container-obj)
                                            (file-name-base c-file)
                                            (boardgame-object-glyph container-obj)
                                            rest
                                            (boardgame-object-properties container-obj))
        (boardgame-log-append (format "Drew bottom item '%s' from container '%s'"
                                      (plist-get drawn :name) (boardgame-object-name container-obj))
                              wdir "Container")
        drawn))))

;;;###autoload
(defun boardgame-container-draw-random (container-obj &optional world-dir)
  "Draw a randomly selected item from CONTAINER-OBJ.
Removes item reference without deleting standalone Org file.
Returns the drawn item entry plist or nil if empty."
  (let* ((wdir (or world-dir boardgame-current-world-directory default-directory))
         (c-file (boardgame-container--resolve-path (boardgame-object-file container-obj) wdir))
         (entries (boardgame-container--read-entries c-file)))
    (if (null entries)
        (progn
          (message "Container '%s' is empty" (boardgame-object-name container-obj))
          nil)
      (let* ((idx (random (length entries)))
             (drawn (nth idx entries))
             (rest (append (cl-subseq entries 0 idx) (cl-subseq entries (1+ idx)))))
        (boardgame-container--write-entries c-file
                                            (boardgame-object-name container-obj)
                                            (file-name-base c-file)
                                            (boardgame-object-glyph container-obj)
                                            rest
                                            (boardgame-object-properties container-obj))
        (boardgame-log-append (format "Drew random item '%s' from container '%s'"
                                      (plist-get drawn :name) (boardgame-object-name container-obj))
                              wdir "Container")
        drawn))))

;;;###autoload
(defun boardgame-container-shuffle (container-obj &optional world-dir)
  "Shuffle the order of items inside CONTAINER-OBJ."
  (let* ((wdir (or world-dir boardgame-current-world-directory default-directory))
         (c-file (boardgame-container--resolve-path (boardgame-object-file container-obj) wdir))
         (entries (boardgame-container--read-entries c-file)))
    (if (< (length entries) 2)
        (message "Container '%s' has fewer than 2 items to shuffle" (boardgame-object-name container-obj))
      (let* ((vec (vconcat entries))
             (n (length vec)))
        ;; Fisher-Yates shuffle
        (dotimes (i (1- n))
          (let* ((j (+ i (random (- n i))))
                 (tmp (aref vec i)))
            (aset vec i (aref vec j))
            (aset vec j tmp)))
        (boardgame-container--write-entries c-file
                                            (boardgame-object-name container-obj)
                                            (file-name-base c-file)
                                            (boardgame-object-glyph container-obj)
                                            (append vec nil)
                                            (boardgame-object-properties container-obj))
        (boardgame-log-append (format "Shuffled %d items in container '%s'"
                                      n (boardgame-object-name container-obj))
                              wdir "Container")
        (message "Shuffled %d items in '%s'" n (boardgame-object-name container-obj))))))

;;;###autoload
(defun boardgame-container-layout-contents (container-obj board &optional world-dir)
  "Lay out all items from CONTAINER-OBJ on previously free cells around CONTAINER-OBJ on BOARD.
Places each item into an adjacent free cell without overwriting unrelated objects.
Leaves unplaced items in the container if there is insufficient space."
  (let* ((wdir (or world-dir boardgame-current-world-directory default-directory))
         (c-file (boardgame-container--resolve-path (boardgame-object-file container-obj) wdir))
         (entries (boardgame-container--read-entries c-file))
         (cx (boardgame-object-x container-obj))
         (cy (boardgame-object-y container-obj))
         ;; Find candidate free neighbor cells (radius 1..5)
         (free-cells nil)
         (placed-count 0))
    (dolist (radius '(1 2 3 4 5))
      (dolist (dy (number-sequence (- radius) radius))
        (dolist (dx (number-sequence (- radius) radius))
          (when (or (= (abs dx) radius) (= (abs dy) radius))
            (let ((nx (+ cx dx))
                  (ny (+ cy dy)))
              (when (and (boardgame-coord-valid-p board nx ny)
                         (null (boardgame-board-get-objects board nx ny))
                         (not (member (cons nx ny) free-cells)))
                (push (cons nx ny) free-cells)))))))
    (setq free-cells (nreverse free-cells))
    ;; Place entries into free cells
    (let ((remaining entries))
      (while (and remaining free-cells)
        (let* ((entry (pop remaining))
               (cell (pop free-cells))
               (nx (car cell))
               (ny (cdr cell))
               (item-obj (boardgame-object-create
                          :name (plist-get entry :name)
                          :x nx
                          :y ny
                          :glyph (plist-get entry :glyph)
                          :file (plist-get entry :file)
                          :type (plist-get entry :type)
                          :content (plist-get entry :content))))
          (boardgame-board-add-object board item-obj)
          (setq placed-count (1+ placed-count))))
      ;; Update container with remaining entries
      (boardgame-container--write-entries c-file
                                          (boardgame-object-name container-obj)
                                          (file-name-base c-file)
                                          (boardgame-object-glyph container-obj)
                                          remaining
                                          (boardgame-object-properties container-obj))
      (boardgame-log-append (format "Laid out %d items from container '%s' on board"
                                    placed-count (boardgame-object-name container-obj))
                            wdir "Container")
      (when remaining
        (message "Warning: %d items could not be placed due to insufficient space" (length remaining)))
      placed-count)))

;;;###autoload
(defun boardgame-container-draw-to-board (container-obj target-x target-y &optional draw-type board world-dir)
  "Draw one object from CONTAINER-OBJ and place it onto BOARD at (TARGET-X, TARGET-Y).
DRAW-TYPE may be :top, :bottom, or :random (defaults to :top).
Standalone object file is preserved on disk throughout the operation.
Returns the newly placed `boardgame-object`."
  (let* ((target-board (or board
                           (and (boundp 'boardgame-board--data) boardgame-board--data)
                           (and boardgame-current-board-buffer
                                (buffer-live-p boardgame-current-board-buffer)
                                (buffer-local-value 'boardgame-board--data boardgame-current-board-buffer))))
         (wdir (or world-dir boardgame-current-world-directory default-directory))
         (dtype (or draw-type :top))
         (entry (cond
                 ((eq dtype :bottom) (boardgame-container-draw-bottom container-obj wdir))
                 ((eq dtype :random) (boardgame-container-draw-random container-obj wdir))
                 (t (boardgame-container-draw-top container-obj wdir)))))
    (unless entry
      (error "Cannot draw from empty container '%s'" (boardgame-object-name container-obj)))
    (let ((placed-obj (boardgame-object-create
                       :name (plist-get entry :name)
                       :x target-x
                       :y target-y
                       :glyph (plist-get entry :glyph)
                       :file (plist-get entry :file)
                       :type (plist-get entry :type)
                       :content (plist-get entry :content))))
      (when target-board
        (boardgame-board-add-object target-board placed-obj)
        (when (and boardgame-current-board-buffer (buffer-live-p boardgame-current-board-buffer))
          (boardgame-board-refresh boardgame-current-board-buffer)))
      placed-obj)))

;;; boardgame-container.el ends here