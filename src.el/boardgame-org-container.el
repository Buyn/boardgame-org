;;; boardgame-org-container.el --- Permanent container operations for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Implements Section 10.2 & 10.3 of boardgame-org-interface.md:
;; "Permanent Containers organize references to other objects without merging
;; their Org documents or deleting their independent files.
;; Supports drawing top/bottom/random, shuffling, and laying out contents."

;;; Code:

(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-object)

(defun boardgame-container-serialize (container)
  "Serialize permanent CONTAINER preserving references to standalone files."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-object-id container)))
    (insert (format ":NAME: %s\n" (boardgame-object-name container)))
    (insert ":TYPE: container\n")
    (insert (format ":GLYPH: %s\n" (boardgame-object-glyph container)))
    (insert ":IS_CONTAINER: t\n")
    (insert (format ":ITEM_COUNT: %d\n"
                    (length (boardgame-object-contained-ids container))))
    (insert ":END:\n\n")
    (insert (format "* %s\n" (boardgame-object-name container)))
    (insert (or (boardgame-object-description container)
                "Permanent container organizing independent game objects.\n"))
    (insert "\n* Container Members\n")
    (dolist (item-id (boardgame-object-contained-ids container))
      (insert (format "- [[file:objects/%s.org][%s]]\n" item-id item-id)))
    (buffer-string)))

(defun boardgame-container-shuffle (container)
  "Shuffle the order of members in CONTAINER in-place."
  (let ((items (copy-sequence (boardgame-object-contained-ids container))))
    (cl-loop for i from (1- (length items)) downto 1
             for j = (random (1+ i))
             do (cl-rotatef (nth i items) (nth j items)))
    (setf (boardgame-object-contained-ids container) items)
    (boardgame-container-save container)
    container))

(defun boardgame-container-draw-top (container)
  "Draw the top object ID from CONTAINER."
  (let ((items (boardgame-object-contained-ids container)))
    (if (null items)
        (error "Container %s is empty" (boardgame-object-name container))
      (let ((drawn (car items)))
        (setf (boardgame-object-contained-ids container) (cdr items))
        (boardgame-container-save container)
        drawn))))

(defun boardgame-container-draw-bottom (container)
  "Draw the bottom object ID from CONTAINER."
  (let ((items (boardgame-object-contained-ids container)))
    (if (null items)
        (error "Container %s is empty" (boardgame-object-name container))
      (let ((drawn (car (last items))))
        (setf (boardgame-object-contained-ids container) (butlast items))
        (boardgame-container-save container)
        drawn))))

(defun boardgame-container-draw-random (container)
  "Draw a random object ID from CONTAINER."
  (let ((items (boardgame-object-contained-ids container)))
    (if (null items)
        (error "Container %s is empty" (boardgame-object-name container))
      (let* ((idx (random (length items)))
             (drawn (nth idx items)))
        (setf (boardgame-object-contained-ids container)
              (append (cl-subseq items 0 idx) (cl-subseq items (1+ idx))))
        (boardgame-container-save container)
        drawn))))

(defun boardgame-container-save (container)
  "Save CONTAINER to its Org file."
  (let ((full-path (boardgame-world-file (boardgame-object-file-path container))))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (boardgame-container-serialize container)))))

(provide 'boardgame-org-container)
;;; boardgame-org-container.el ends here
