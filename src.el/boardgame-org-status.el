;;; boardgame-org-status.el --- Real-time status area buffer for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 12.11 of boardgame-org-interface.md:
;; "The status window displays the current game status using a separate buffer.
;; It is not a section of the log file and must not be rendered as part of
;; the log buffer."

;;; Code:

(require 'boardgame-org-core)

(defvar boardgame-status-buffer-name "*boardgame-status*"
  "Name of the status window buffer.")

;;;###autoload
(defun boardgame-get-or-create-status-buffer ()
  "Get or create the separate status buffer."
  (let ((buf (get-buffer-create boardgame-status-buffer-name)))
    (with-current-buffer buf
      (setq buffer-read-only t)
      (hl-line-mode -1))
    buf))

;;;###autoload
(defun boardgame-status-refresh (&optional board cursor-x cursor-y top-object drawing-info)
  "Update the contents of the status buffer."
  (let ((buf (boardgame-get-or-create-status-buffer))
        (wname (or (boardgame-world-name) "world"))
        (bname (if board (boardgame-board-filename board) "None"))
        (cx (or cursor-x 0))
        (cy (or cursor-y 0)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "=== GAME STATUS ===\n" 'face 'bold))
        (insert (format "World:  %s\n" (propertize wname 'face 'font-lock-keyword-face)))
        (insert (format "Board:  %s\n" (propertize bname 'face 'font-lock-function-name-face)))
        (insert (format "Cursor: (%c, %d) [%c%d]\n"
                        (+ ?A cx) (1+ cy)
                        (+ ?A cx) (1+ cy)))
        (if top-object
            (progn
              (insert (format "Object: %s %s\n"
                              (boardgame-object-glyph top-object)
                              (boardgame-object-name top-object)))
              (insert (format "Type:   %s\n" (boardgame-object-type top-object))))
          (insert "Object: (empty felt)\n"))
        (when drawing-info
          (insert (format "Draw:   %s\n" (propertize (or (plist-get drawing-info :tool) "Inactive")
                                                     'face 'font-lock-warning-face)))
          (when (plist-get drawing-info :glyph)
            (insert (format "Glyph:  '%s'  FG:%s BG:%s\n"
                            (plist-get drawing-info :glyph)
                            (or (plist-get drawing-info :fg) "default")
                            (or (plist-get drawing-info :bg) "default")))))
        (insert "-------------------\n")
        (insert "[?] Menu  [m] Move  [H] Hand\n")
        (insert "[S] Stack [U] Unstack [d] Draw\n")
        (goto-char (point-min))))))

(provide 'boardgame-org-status)
;;; boardgame-org-status.el ends here
