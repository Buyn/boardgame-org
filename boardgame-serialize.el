;;; boardgame-serialize.el --- Org document parser and serializer -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Org-mode document parser, felt normalizer, and lossless serializer
;; for boardgame.org.
;;
;; Invariants:
;; - Mutual invertibility: deserialize(serialize(state)) == state.
;; - Ragged felt input is normalized: rows shorter than declared width are
;;   padded with default felt characters; characters beyond width are clipped;
;;   rows beyond height are clipped; missing rows are filled with default felt.
;; - Human-editable persistence: generated Org documents remain clean,
;;   valid, and readable Org-mode syntax.
;; - In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;;   internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; Forward declarations for `boardgame-data.el' functions
(declare-function boardgame-board-create "boardgame-data")
(declare-function boardgame-board-name "boardgame-data")
(declare-function boardgame-board-width "boardgame-data")
(declare-function boardgame-board-height "boardgame-data")
(declare-function boardgame-board-felt-default "boardgame-data")
(declare-function boardgame-board-felt-default-string "boardgame-data")
(declare-function boardgame-board-felt-default-char "boardgame-data")
(declare-function boardgame-board-properties "boardgame-data")
(declare-function boardgame-board-all-objects "boardgame-data")
(declare-function boardgame-board-felt-string "boardgame-data")
(declare-function boardgame-board-add-object "boardgame-data")
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
(declare-function boardgame--to-char "boardgame-data")
(declare-function boardgame--to-string "boardgame-data")

;; -----------------------------------------------------------------------------
;; Felt Normalization
;; -----------------------------------------------------------------------------

(defun boardgame-felt-normalize-line (line width fill-char)
  "Normalize single LINE to WIDTH columns using FILL-CHAR.
Pads shorter lines and clips characters exceeding WIDTH."
  (let* ((safe-line (or line ""))
         (len (length safe-line)))
    (cond
     ((< len width)
      (concat safe-line (make-string (- width len) fill-char)))
     ((> len width)
      (substring safe-line 0 width))
     (t safe-line))))

(defun boardgame-felt-split-lines (content)
  "Split raw CONTENT into a list of string lines.
CONTENT may be a string, a list of strings, or a vector."
  (cond
   ((null content) nil)
   ((listp content) content)
   ((vectorp content) (append content nil))
   ((stringp content)
    (if (string-empty-p content)
        nil
      (split-string (string-trim-right content "[\r\n]+") "\r?\n")))
   (t nil)))

(defun boardgame-felt-normalize (content width height &optional default-char)
  "Normalize felt CONTENT to exactly HEIGHT rows of WIDTH characters.
CONTENT can be a multiline string, a list of strings, or a vector.
DEFAULT-CHAR defaults to '.'. Short rows are padded with DEFAULT-CHAR;
long rows are clipped to WIDTH; rows beyond HEIGHT are ignored;
missing rows up to HEIGHT are filled with DEFAULT-CHAR.
Returns a list of string rows."
  (let* ((fill-char (boardgame--to-char (or default-char ?\.)))
         (empty-row (make-string width fill-char))
         (raw-lines (boardgame-felt-split-lines content))
         (result nil))
    (dotimes (i height)
      (let ((raw (nth i raw-lines)))
        (push (if raw
                  (boardgame-felt-normalize-line raw width fill-char)
                empty-row)
              result)))
    (nreverse result)))

(defun boardgame-felt-normalize-string (content width height &optional default-char)
  "Normalize felt CONTENT and return as a single newline-separated string.
Accepts same arguments as `boardgame-felt-normalize'."
  (string-join (boardgame-felt-normalize content width height default-char) "\n"))

;; -----------------------------------------------------------------------------
;; Org Property Drawer Parsing and Formatting
;; -----------------------------------------------------------------------------

(defun boardgame-serialize-parse-property-drawer (text-or-buffer &optional start-pos end-pos)
  "Extract property drawer entries from TEXT-OR-BUFFER as an alist.
Optional START-POS and END-POS restrict search in buffer.
Property names are uppercase strings; property values are trimmed strings."
  (let ((properties nil))
    (with-temp-buffer
      (if (bufferp text-or-buffer)
          (insert-buffer-substring text-or-buffer start-pos end-pos)
        (insert (or text-or-buffer "")))
      (goto-char (point-min))
      (when (re-search-forward "^[ \t]*:PROPERTIES:[ \t]*$" nil t)
        (let ((drawer-start (point)))
          (when (re-search-forward "^[ \t]*:END:[ \t]*$" nil t)
            (let ((drawer-end (match-beginning 0)))
              (goto-char drawer-start)
              (while (re-search-forward
                      "^[ \t]*:\\([A-Za-z0-9_]+\\):[ \t]*\\(.*?\\)[ \t]*$"
                      drawer-end t)
                (let ((key (upcase (match-string 1)))
                      (val (match-string 2)))
                  (push (cons key val) properties))))))))
    (nreverse properties)))

;; -----------------------------------------------------------------------------
;; Org Deserialization (Parsing)
;; -----------------------------------------------------------------------------

(defun boardgame-serialize--parse-board-header ()
  "Parse board heading and properties drawer from current buffer.
Returns a plist (:name NAME :properties PROPS :heading-end POS)."
  (goto-char (point-min))
  (let ((name "Untitled Board")
        (heading-end (point-min))
        (props nil))
    (if (re-search-forward "^[ \t]*\\*[ \t]+\\(?:Board:[ \t]*\\)?\\(.*?\\)[ \t]*$" nil t)
        (progn
          (setq name (match-string 1))
          (setq heading-end (line-end-position))
          (forward-line 1)
          (setq props (boardgame-serialize-parse-property-drawer
                       (current-buffer) heading-end (point-max))))
      (goto-char (point-min))
      (when (re-search-forward "^#\\+TITLE:[ \t]*\\(.*?\\)[ \t]*$" nil t)
        (setq name (match-string 1)))
      (setq props (boardgame-serialize-parse-property-drawer
                   (current-buffer) (point-min) (point-max))))
    (list :name name :properties props :heading-end heading-end)))

(defun boardgame-serialize--extract-felt-block (width height def-char)
  "Extract and normalize felt source block from current buffer.
WIDTH, HEIGHT, and DEF-CHAR govern normalization."
  (goto-char (point-min))
  (let ((felt-content nil))
    (when (re-search-forward
           "^[ \t]*#\\+\\(?:begin_src\\|BEGIN_SRC\\)[ \t]*felt[ \t]*\n\\(\\(?:.\\|\n\\)*?\\)[ \t]*#\\+\\(?:end_src\\|END_SRC\\)"
           nil t)
      (setq felt-content (match-string 1)))
    (unless felt-content
      (goto-char (point-min))
      (when (re-search-forward
             "^[ \t]*\\*\\*+[ \t]+Felt[ \t]*\n\\(?:.\\|\n\\)*?#\\+\\(?:begin_src\\|BEGIN_SRC\\|BEGIN_FELT\\|begin_felt\\)[^\n]*\n\\(\\(?:.\\|\n\\)*?\\)[ \t]*#\\+\\(?:end_src\\|END_SRC\\|END_FELT\\|end_felt\\)"
             nil t)
        (setq felt-content (match-string 1))))
    (boardgame-felt-normalize felt-content width height def-char)))

(defun boardgame-serialize--extract-objects ()
  "Extract objects from `** Objects' section of current buffer.
Returns a list of `boardgame-object' structs."
  (goto-char (point-min))
  (let ((objects nil))
    (when (re-search-forward "^[ \t]*\\*\\*+[ \t]+Objects[ \t]*$" nil t)
      (let* ((section-start (point))
             (section-end (if (re-search-forward "^[ \t]*\\*\\{1,2\\}[ \t]+" nil t)
                              (match-beginning 0)
                            (point-max))))
        (goto-char section-start)
        (while (re-search-forward "^[ \t]*\\*\\*\\*+[ \t]+\\(.*?\\)[ \t]*$" section-end t)
          (let* ((obj-name (match-string 1))
                 (obj-head-end (line-end-position))
                 (next-obj (save-excursion
                             (if (re-search-forward "^[ \t]*\\*\\*\\*+[ \t]+" section-end t)
                                 (match-beginning 0)
                               section-end)))
                 (props (boardgame-serialize-parse-property-drawer
                         (current-buffer) obj-head-end next-obj))
                 (obj-file (or (cdr (assoc "OBJECT_FILE" props))
                               (cdr (assoc "FILE" props))))
                 (obj-type (or (cdr (assoc "OBJECT_TYPE" props))
                               (cdr (assoc "TYPE" props))
                               "unspecified"))
                 (x-str (or (cdr (assoc "X" props)) (cdr (assoc "POS_X" props)) "0"))
                 (y-str (or (cdr (assoc "Y" props)) (cdr (assoc "POS_Y" props)) "0"))
                 (glyph (or (cdr (assoc "GLYPH" props))
                            (if (> (length obj-name) 0)
                                (substring obj-name 0 1)
                              "*")))
                 (fg (cdr (assoc "FG" props)))
                 (bg (cdr (assoc "BG" props)))
                 (content nil))
            (save-excursion
              (goto-char obj-head-end)
              (when (re-search-forward "^[ \t]*:END:[ \t]*\n" next-obj t)
                (let ((body (buffer-substring (point) next-obj)))
                  (unless (string-blank-p body)
                    (setq content body)))))
            (push (boardgame-object-create
                   :name obj-name
                   :x (string-to-number x-str)
                   :y (string-to-number y-str)
                   :glyph glyph
                   :file obj-file
                   :type obj-type
                   :fg fg
                   :bg bg
                   :properties props
                   :content content)
                  objects)))))
    (nreverse objects)))

(defun boardgame-deserialize-board (source)
  "Parse SOURCE (string or buffer) into a `boardgame-board' struct."
  (with-temp-buffer
    (if (bufferp source)
        (insert-buffer-substring source)
      (insert (or source "")))
    (let* ((header-info (boardgame-serialize--parse-board-header))
           (name (plist-get header-info :name))
           (props (plist-get header-info :properties))
           (w-str (or (cdr (assoc "BOARD_WIDTH" props))
                      (cdr (assoc "WIDTH" props))
                      "80"))
           (h-str (or (cdr (assoc "BOARD_HEIGHT" props))
                      (cdr (assoc "HEIGHT" props))
                      "24"))
           (def-str (or (cdr (assoc "FELT_DEFAULT" props)) "."))
           (width (string-to-number w-str))
           (height (string-to-number h-str))
           (def-char (boardgame--to-char def-str))
           (normalized-rows (boardgame-serialize--extract-felt-block
                             width height def-char))
           (grid (vconcat normalized-rows))
           (f-table (make-hash-table :test 'equal))
           (o-table (make-hash-table :test 'equal))
           (objects (boardgame-serialize--extract-objects))
           (board (boardgame-board-create
                   :name name
                   :width width
                   :height height
                   :felt-default def-str
                   :properties props
                   :felt-grid grid
                   :felt-table f-table
                   :objects-table o-table
                   :objects-list nil
                   :modified-p nil)))
      (dotimes (y height)
        (let ((row (aref grid y)))
          (dotimes (x width)
            (puthash (cons x y) (aref row x) f-table))))
      (dolist (obj objects)
        (boardgame-board-add-object board obj))
      (setf (boardgame-board-modified-p board) nil)
      board)))

(defun boardgame-deserialize-board-file (file)
  "Load and deserialize board from Org document FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((board (boardgame-deserialize-board (current-buffer))))
      (setf (boardgame-board-file board) (expand-file-name file))
      board)))

;; -----------------------------------------------------------------------------
;; Org Serialization
;; -----------------------------------------------------------------------------

(defun boardgame-serialize-board (board)
  "Serialize BOARD struct to an Org-mode formatted document string."
  (let* ((name (boardgame-board-name board))
         (width (boardgame-board-width board))
         (height (boardgame-board-height board))
         (felt-def (boardgame-board-felt-default-string board))
         (props (boardgame-board-properties board))
         (objects (boardgame-board-all-objects board))
         (lines nil))
    ;; Heading & properties drawer
    (push (format "* Board: %s\n" name) lines)
    (push ":PROPERTIES:\n" lines)
    (push (format ":BOARD_WIDTH: %d\n" width) lines)
    (push (format ":BOARD_HEIGHT: %d\n" height) lines)
    (push (format ":FELT_DEFAULT: %s\n" felt-def) lines)
    (dolist (p props)
      (let ((key (car p))
            (val (cdr p)))
        (unless (member (upcase key)
                        '("BOARD_WIDTH" "BOARD_HEIGHT" "FELT_DEFAULT" "WIDTH" "HEIGHT"))
          (push (format ":%s: %s\n" (upcase key) val) lines))))
    (push ":END:\n\n" lines)

    ;; Felt section
    (push "** Felt\n" lines)
    (push ":PROPERTIES:\n:CUSTOM_ID: felt\n:END:\n\n" lines)
    (push "#+begin_src felt\n" lines)
    (push (boardgame-board-felt-string board) lines)
    (push "\n#+end_src\n\n" lines)

    ;; Objects section
    (push "** Objects\n" lines)
    (push ":PROPERTIES:\n:CUSTOM_ID: objects\n:END:\n" lines)
    (dolist (obj objects)
      (push (format "\n*** %s\n" (boardgame-object-name obj)) lines)
      (push ":PROPERTIES:\n" lines)
      (when (boardgame-object-file obj)
        (push (format ":OBJECT_FILE: %s\n" (boardgame-object-file obj)) lines))
      (when (boardgame-object-type obj)
        (push (format ":OBJECT_TYPE: %s\n" (boardgame-object-type obj)) lines))
      (push (format ":X: %d\n" (boardgame-object-x obj)) lines)
      (push (format ":Y: %d\n" (boardgame-object-y obj)) lines)
      (when (boardgame-object-glyph obj)
        (push (format ":GLYPH: %s\n" (boardgame-object-glyph obj)) lines))
      (when (boardgame-object-fg obj)
        (push (format ":FG: %s\n" (boardgame-object-fg obj)) lines))
      (when (boardgame-object-bg obj)
        (push (format ":BG: %s\n" (boardgame-object-bg obj)) lines))
      (dolist (p (boardgame-object-properties obj))
        (let ((key (car p))
              (val (cdr p)))
          (unless (member (upcase key)
                          '("OBJECT_FILE" "OBJECT_TYPE" "X" "Y" "GLYPH" "FG" "BG"
                            "POS_X" "POS_Y" "FILE" "TYPE"))
            (push (format ":%s: %s\n" (upcase key) val) lines))))
      (push ":END:\n" lines)
      (when (and (boardgame-object-content obj)
                 (not (string-blank-p (boardgame-object-content obj))))
        (push (boardgame-object-content obj) lines)
        (unless (string-suffix-p "\n" (boardgame-object-content obj))
          (push "\n" lines))))
    (apply #'concat (nreverse lines))))

(defun boardgame-serialize-board-to-buffer (board &optional buffer)
  "Serialize BOARD to BUFFER (defaults to current buffer).
Returns the buffer."
  (let ((target-buf (or buffer (current-buffer)))
        (content (boardgame-serialize-board board)))
    (with-current-buffer target-buf
      (erase-buffer)
      (insert content))
    target-buf))

(defun boardgame-serialize-board-to-file (board file)
  "Serialize BOARD and write to FILE.
Sets `file' field on BOARD and clears `modified-p' flag."
  (let ((content (boardgame-serialize-board board)))
    (with-temp-file file
      (insert content))
    (setf (boardgame-board-file board) (expand-file-name file))
    (setf (boardgame-board-modified-p board) nil)
    (expand-file-name file)))

;;; boardgame-serialize.el ends here
