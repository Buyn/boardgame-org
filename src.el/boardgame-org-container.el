;;; boardgame-org-container.el --- Permanent containers, decks, drawing and shuffling -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 3.2 of boardgame-org.md and Sections 10.2-10.5 of
;; boardgame-org-interface.md:
;; - Permanent containers organizing references without merging independent files
;; - Drawing top, bottom, and random items
;; - Shuffling container contents
;; - Laying out items on surrounding free cells

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'subr-x)
(require 'boardgame-org-core)

;;;###autoload
(defun boardgame-create-container (id name &optional glyph)
  "Create a permanent container at containers/ID.org and return `boardgame-object`."
  (let* ((rel-path (format "containers/%s.org" id))
         (full-path (boardgame-world-file rel-path))
         (gly (or glyph "⊔")))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (format "#+TITLE: Container: %s\n" name))
      (insert ":PROPERTIES:\n")
      (insert (format ":ID: %s\n" id))
      (insert (format ":NAME: %s\n" name))
      (insert ":TYPE: container\n")
      (insert (format ":GLYPH: %s\n" gly))
      (insert ":END:\n\n")
      (insert "* Contents\n"))
    (boardgame-object-create
     :id id
     :name name
     :glyph gly
     :type 'container
     :file-path rel-path
     :contained-ids nil)))

(defun boardgame-container-read-ids (container-obj)
  "Read list of contained object IDs from CONTAINER-OBJ Org file."
  (let* ((rel-path (boardgame-object-file-path container-obj))
         (full-path (boardgame-world-file rel-path))
         (ids nil))
    (when (and full-path (file-exists-p full-path))
      (with-temp-buffer
        (insert-file-contents full-path)
        (goto-char (point-min))
        (while (re-search-forward "^\\*\\*\\s-+\\(?:Item:\\s-+\\)?\\(.*?\\)\\s-*$" nil t)
          (let* ((props (org-entry-properties (point)))
                 (oid (or (cdr (assoc "OBJECT_ID" props))
                          (cdr (assoc "ID" props))
                          (match-string-no-properties 1))))
            (when (and oid (> (length oid) 0))
              (push oid ids))))))
    (nreverse ids)))

(defun boardgame-container-write-ids (container-obj ids)
  "Write updated IDS back to CONTAINER-OBJ Org file."
  (let* ((rel-path (boardgame-object-file-path container-obj))
         (full-path (boardgame-world-file rel-path))
         (cname (boardgame-object-name container-obj))
         (gly (boardgame-object-glyph container-obj)))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (format "#+TITLE: Container: %s\n" cname))
      (insert ":PROPERTIES:\n")
      (insert (format ":ID: %s\n" (boardgame-object-id container-obj)))
      (insert (format ":NAME: %s\n" cname))
      (insert ":TYPE: container\n")
      (insert (format ":GLYPH: %s\n" (or gly "⊔")))
      (insert (format ":COUNT: %d\n" (length ids)))
      (insert ":END:\n\n")
      (insert "* Contents\n")
      (dolist (oid ids)
        (insert (format "** Item: %s\n" oid))
        (insert ":PROPERTIES:\n")
        (insert (format ":OBJECT_ID: %s\n" oid))
        (insert ":END:\n")))))

;;;###autoload
(defun boardgame-container-draw-top (container-obj)
  "Draw the top item from CONTAINER-OBJ.
Removes reference from container without deleting item's standalone Org file.
Returns the drawn item ID or nil if empty."
  (let* ((ids (boardgame-container-read-ids container-obj)))
    (if (null ids)
        (progn
          (message "Container '%s' is empty." (boardgame-object-name container-obj))
          nil)
      (let ((drawn (car ids))
            (rest (cdr ids)))
        (boardgame-container-write-ids container-obj rest)
        drawn))))

;;;###autoload
(defun boardgame-container-draw-bottom (container-obj)
  "Draw the bottom item from CONTAINER-OBJ."
  (let* ((ids (boardgame-container-read-ids container-obj)))
    (if (null ids)
        (progn
          (message "Container '%s' is empty." (boardgame-object-name container-obj))
          nil)
      (let* ((rev (reverse ids))
             (drawn (car rev))
             (rest (reverse (cdr rev))))
        (boardgame-container-write-ids container-obj rest)
        drawn))))

;;;###autoload
(defun boardgame-container-draw-random (container-obj)
  "Draw a randomly selected item from CONTAINER-OBJ."
  (let* ((ids (boardgame-container-read-ids container-obj)))
    (if (null ids)
        (progn
          (message "Container '%s' is empty." (boardgame-object-name container-obj))
          nil)
      (let* ((idx (random (length ids)))
             (drawn (nth idx ids))
             (rest (append (cl-subseq ids 0 idx) (cl-subseq ids (1+ idx)))))
        (boardgame-container-write-ids container-obj rest)
        drawn))))

;;;###autoload
(defun boardgame-container-shuffle (container-obj)
  "Shuffle the order of items inside CONTAINER-OBJ."
  (interactive)
  (let* ((ids (boardgame-container-read-ids container-obj)))
    (if (< (length ids) 2)
        (message "Container '%s' has fewer than 2 items to shuffle." (boardgame-object-name container-obj))
      (let* ((vec (vconcat ids))
             (n (length vec)))
        (dotimes (i (1- n))
          (let* ((j (+ i (random (- n i))))
                 (tmp (aref vec i)))
            (aset vec i (aref vec j))
            (aset vec j tmp)))
        (boardgame-container-write-ids container-obj (append vec nil))
        (when (fboundp 'boardgame-log)
          (boardgame-log "Container Shuffled"
                         `(("Container" . ,(boardgame-object-name container-obj))
                           ("Items" . ,(format "%d items shuffled" n)))))
        (message "Shuffled %d items in '%s'." n (boardgame-object-name container-obj))))))

;;;###autoload
(defun boardgame-container-add-object (container-obj object-id)
  "Add reference to OBJECT-ID into CONTAINER-OBJ."
  (let ((ids (boardgame-container-read-ids container-obj)))
    (boardgame-container-write-ids container-obj (append ids (list object-id)))
    (message "Added '%s' to '%s'." object-id (boardgame-object-name container-obj))))

(provide 'boardgame-org-container)
;;; boardgame-org-container.el ends here
