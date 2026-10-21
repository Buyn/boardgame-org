;;; boardgame-org-container.el --- Permanent container operations for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 3.2 of boardgame-org.md:
;; "Permanent Container: Organization Without Consolidation.
;; Its defining property is that it changes the arrangement and location of
;; objects without merging their standalone Org documents.
;; 1. Object removed from former position.
;; 2. Standalone Org file remains intact.
;; 3. Container records membership and position.
;; 4. Container persists even when empty."

;;; Code:

(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-object)

(defun boardgame-org-container-serialize (container)
  "Serialize permanent CONTAINER preserving references to standalone files."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-org-object-id container)))
    (insert (format ":NAME: %s\n" (boardgame-org-object-name container)))
    (insert ":TYPE: container\n")
    (insert (format ":GLYPH: %s\n" (boardgame-org-object-glyph container)))
    (insert ":IS_CONTAINER: t\n")
    (insert (format ":ITEM_COUNT: %d\n"
                    (length (boardgame-org-object-contained-ids container))))
    (insert ":END:\n\n")
    (insert (format "* %s\n" (boardgame-org-object-name container)))
    (insert (or (boardgame-org-object-description container)
                "Permanent container organizing independent game objects.\n"))
    (insert "\n* Container Members\n")
    (dolist (item-id (boardgame-org-object-contained-ids container))
      (insert (format "- [[file:objects/%s.org][%s]]\n" item-id item-id)))
    (buffer-string)))

(defun boardgame-org-container-parse-buffer (file-path)
  "Parse a permanent container Org document from current buffer."
  (let* ((props (boardgame-org-parse-property-drawer))
         (id (or (cdr (assoc "ID" props)) (file-name-base file-path)))
         (name (or (cdr (assoc "NAME" props)) "Card Deck"))
         (glyph (or (cdr (assoc "GLYPH" props)) "🎴"))
         members)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\[\\[file:objects/\\([^.]+\\)\\.org\\]\\[\\([^]]*\\)\\]\\]" nil t)
        (push (match-string 1) members)))
    (boardgame-org-object-create
     :id id
     :name name
     :glyph glyph
     :type 'container
     :file-path file-path
     :properties props
     :contained-ids (nreverse members))))

(defun boardgame-org-container-shuffle (container)
  "Shuffle the order of members in CONTAINER in-place."
  (let ((items (copy-sequence (boardgame-org-object-contained-ids container))))
    (cl-loop for i from (1- (length items)) downto 1
             for j = (random (1+ i))
             do (cl-rotatef (nth i items) (nth j items)))
    (setf (boardgame-org-object-contained-ids container) items)
    (boardgame-org-container-save container)
    container))

(defun boardgame-org-container-draw (container)
  "Draw the top object ID from CONTAINER without deleting its standalone file."
  (let ((items (boardgame-org-object-contained-ids container)))
    (if (null items)
        (error "Container %s is empty" (boardgame-org-object-name container))
      (let ((drawn (car items)))
        (setf (boardgame-org-object-contained-ids container) (cdr items))
        (boardgame-org-container-save container)
        drawn))))

(defun boardgame-org-container-add (container object-id)
  "Add OBJECT-ID into CONTAINER without merging its file."
  (let ((items (boardgame-org-object-contained-ids container)))
    (setf (boardgame-org-object-contained-ids container)
          (append items (list object-id)))
    (boardgame-org-container-save container)
    container))

(defun boardgame-org-container-save (container)
  "Save CONTAINER to its Org file."
  (let ((full-path (boardgame-org-world-file (boardgame-org-object-file-path container))))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (boardgame-org-container-serialize container)))))

(provide 'boardgame-org-container)
;;; boardgame-org-container.el ends here
