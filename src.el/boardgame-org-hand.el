;;; boardgame-org-hand.el --- Player hand management and universal Org heading transfers -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 9 of boardgame-org-interface.md:
;; "Hands: Org-Based Stacks. A hand is a regular Org file.
;; Commands for transferring items are available in ordinary Org buffers.
;; Placing a heading on the board derives the display symbol from the heading's
;; first character (fallback '*').
;; Taking an item while the cursor is over a container or stack takes the
;; top item contained within it."

;;; Code:

(require 'org)
(require 'boardgame-org-core)
(require 'boardgame-org-object)

(defun boardgame-get-active-hand-file ()
  "Return full path to the active hand file."
  (let ((rel (or boardgame-active-hand-file "hands/player1.org")))
    (boardgame-world-file rel)))

;;;###autoload
(defun boardgame-open-hand ()
  "Open the active hand's Org file in a regular Emacs buffer."
  (interactive)
  (let ((hand-file (boardgame-get-active-hand-file)))
    (unless (file-exists-p hand-file)
      (make-directory (file-name-directory hand-file) t)
      (with-temp-file hand-file
        (insert "#+TITLE: Player Hand\n")
        (insert "* Hand Items\n")))
    (find-file-other-window hand-file)))

;;;###autoload
(defun boardgame-place-heading-on-board ()
  "Transfer current Org heading and its subtree from ANY Org buffer to active board.
Creates a standalone object Org file and places it on the board at current cursor."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (error "Must be called within an Org-mode buffer"))
  (unless (and boardgame-current-board-buffer (buffer-live-p boardgame-current-board-buffer))
    (error "No active board buffer available to receive object"))
  (org-back-to-heading t)
  (let* ((heading-text (org-get-heading t t t t))
         (element (org-element-at-point))
         (props (org-entry-properties))
         ;; Section 9.4.1: derive symbol from first character or fallback '*'
         (prop-glyph (cdr (assoc "GLYPH" props)))
         (clean-title (string-trim heading-text))
         (derived-glyph (if (and clean-title (> (length clean-title) 0))
                            (substring clean-title 0 1)
                          "*"))
         (glyph (or prop-glyph derived-glyph "*"))
         (obj-id (or (cdr (assoc "ID" props))
                     (format "obj-%s" (format-time-string "%Y%m%d%H%M%S"))))
         (subtree-content (org-get-entry))
         (target-file (format "objects/%s.org" obj-id))
         (target-full-path (boardgame-world-file target-file)))
    ;; 1. Write standalone object file
    (make-directory (file-name-directory target-full-path) t)
    (with-temp-file target-full-path
      (insert ":PROPERTIES:\n")
      (insert (format ":ID: %s\n" obj-id))
      (insert (format ":NAME: %s\n" clean-title))
      (insert (format ":GLYPH: %s\n" glyph))
      (insert ":TYPE: card\n")
      (insert ":END:\n\n")
      (insert (format "* %s\n" clean-title))
      (when subtree-content
        (insert subtree-content "\n")))
    ;; 2. Place on active board
    (with-current-buffer boardgame-current-board-buffer
      (let* ((board (bound-and-true-p boardgame--current-board))
             (cx (or (bound-and-true-p boardgame--cursor-x) 0))
             (cy (or (bound-and-true-p boardgame--cursor-y) 0))
             (placed (boardgame-placed-create :object-id obj-id :x cx :y cy :layer 0))
             (obj (boardgame-object-create
                   :id obj-id :name clean-title :glyph glyph :type 'card :file-path target-file)))
        (push placed (boardgame-board-placed-objects board))
        (push (cons obj-id obj) boardgame--current-objects-alist)
        (when (fboundp 'boardgame-save-board) (boardgame-save-board))
        (when (fboundp 'boardgame-refresh-board) (boardgame-refresh-board))))
    ;; 3. Cut heading subtree from source Org buffer
    (org-cut-subtree)
    (when (fboundp 'boardgame-log)
      (boardgame-log "Heading Placed on Board"
                     `(("Object" . ,clean-title)
                       ("Glyph" . ,glyph))))
    (message "Transferred '%s' (%s) to active board." clean-title glyph)))

(provide 'boardgame-org-hand)
;;; boardgame-org-hand.el ends here
