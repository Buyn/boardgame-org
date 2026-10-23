;;; boardgame-org-frame.el --- Dedicated Emacs frame & 3-window layout management -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 4 and Section 12.11 of boardgame-org-interface.md:
;; "Starting the game interface must open a dedicated Emacs frame for the game session.
;; The game frame must be divided into:
;; - Board area (~80% of the frame width)
;; - Side log (~20% of frame width, upper ~80% of column)
;; - Status area (lower ~20% of column)"

;;; Code:

(require 'boardgame-org-core)
(require 'boardgame-org-log)
(require 'boardgame-org-status)

(defvar boardgame-game-frames nil
  "List of live Emacs frames dedicated to boardgame sessions.")

;;;###autoload
(defun boardgame-setup-game-frame (board-buffer)
  "Create or configure a dedicated Emacs frame with 3-window layout for BOARD-BUFFER.
Returns a plist (:frame FRAME :board-win WIN :log-win WIN :status-win WIN)."
  (let* ((wname (or (boardgame-world-name) "Boardgame"))
         (frame-name (format "boardgame.org: %s" wname))
         (new-frame (make-frame `((name . ,frame-name)
                                  (minibuffer . t)
                                  (width . 120)
                                  (height . 36))))
         (log-buf (boardgame-get-or-create-log-buffer))
         (status-buf (boardgame-get-or-create-status-buffer)))
    (add-to-list 'boardgame-game-frames new-frame)
    (select-frame new-frame)
    (delete-other-windows)
    ;; 1. Current window becomes the board window
    (let* ((board-win (selected-window))
           (total-width (window-total-width board-win))
           (board-cols (max 20 (/ (* total-width boardgame-board-window-width-percent) 100)))
           (right-win (split-window board-win board-cols t)))
      (set-window-buffer board-win board-buffer)
      ;; 2. Split right-win vertically: upper ~80% log, lower ~20% status
      (let* ((total-height (window-total-height right-win))
             (log-lines (max 5 (/ (* total-height boardgame-log-window-height-percent) 100)))
             (status-win (split-window right-win log-lines nil)))
        (set-window-buffer right-win log-buf)
        (set-window-buffer status-win status-buf)
        (select-window board-win)
        (list :frame new-frame
              :board-win board-win
              :log-win right-win
              :status-win status-win)))))

;;;###autoload
(defun boardgame-switch-board-in-frame (board-buffer &optional frame)
  "Switch the board window in FRAME (defaults to selected frame) to BOARD-BUFFER."
  (let ((target-frame (or frame (selected-frame))))
    (with-selected-frame target-frame
      (let ((board-win (frame-first-window target-frame)))
        (when board-win
          (set-window-buffer board-win board-buffer)
          (setq boardgame-current-board-buffer board-buffer))))))

(provide 'boardgame-org-frame)
;;; boardgame-org-frame.el ends here
