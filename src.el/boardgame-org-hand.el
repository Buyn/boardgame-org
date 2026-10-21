;;; boardgame-org-hand.el --- Player hand management for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Player hand persistence and operations according to Section 4.5.

;;; Code:

(require 'org)
(require 'boardgame-org-core)

(defun boardgame-org-hand-serialize (hand)
  "Serialize HAND to an Org document string."
  (with-temp-buffer
    (insert ":PROPERTIES:\n")
    (insert (format ":ID: %s\n" (boardgame-org-hand-id hand)))
    (insert (format ":NAME: %s\n" (boardgame-org-hand-name hand)))
    (insert (format ":PLAYER: %s\n" (boardgame-org-hand-player hand)))
    (insert (format ":ITEM_COUNT: %d\n" (length (boardgame-org-hand-object-ids hand))))
    (insert ":END:\n\n")
    (insert (format "* %s (%s)\n"
                    (boardgame-org-hand-name hand)
                    (boardgame-org-hand-player hand)))
    (insert "Game objects currently held in player hand.\n\n")
    (insert "* Hand Items\n")
    (dolist (id (boardgame-org-hand-object-ids hand))
      (insert (format "- [[file:objects/%s.org][%s]]\n" id id)))
    (buffer-string)))

(defun boardgame-org-hand-parse-buffer (file-path)
  "Parse a player hand Org document from current buffer."
  (let* ((props (boardgame-org-parse-property-drawer))
         (id (or (cdr (assoc "ID" props)) (file-name-base file-path)))
         (name (or (cdr (assoc "NAME" props)) "Player Hand"))
         (player (or (cdr (assoc "PLAYER" props)) "Player 1"))
         items)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\[\\[file:objects/\\([^.]+\\)\\.org\\]\\[\\([^]]*\\)\\]\\]" nil t)
        (push (match-string 1) items)))
    (boardgame-org-hand-create
     :id id
     :name name
     :player player
     :object-ids (nreverse items)
     :file-path file-path)))

(defun boardgame-org-hand-save (hand)
  "Save HAND to disk."
  (let ((full-path (boardgame-org-world-file (boardgame-org-hand-file-path hand))))
    (make-directory (file-name-directory full-path) t)
    (with-temp-file full-path
      (insert (boardgame-org-hand-serialize hand)))))

(defun boardgame-org-hand-add (hand object-id)
  "Add OBJECT-ID to HAND and save."
  (setf (boardgame-org-hand-object-ids hand)
        (append (boardgame-org-hand-object-ids hand) (list object-id)))
  (boardgame-org-hand-save hand)
  hand)

(defun boardgame-org-hand-remove (hand object-id)
  "Remove OBJECT-ID from HAND and save."
  (setf (boardgame-org-hand-object-ids hand)
        (delete object-id (boardgame-org-hand-object-ids hand)))
  (boardgame-org-hand-save hand)
  hand)

(provide 'boardgame-org-hand)
;;; boardgame-org-hand.el ends here
