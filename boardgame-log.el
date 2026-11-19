;;; boardgame-log.el --- Shared world session log management -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Unified session log buffer management for boardgame.org.
;;
;; Implements §4.5 and §5.3 of boardgame-org-interface.md:
;;  - One shared log buffer per active world.
;;  - Log buffer named after the world: <world>-log.org.
;;  - Appending messages from any board writes to the shared log.
;;  - Log lines auto-scroll to follow the latest entry.
;;
;; Architectural Invariant:
;; In accordance with `boardgame-org.md' §7 and
;; `boardgame-implementation-plan.md' §1.2, internal module files do NOT
;; call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; Forward declarations for variables defined in boardgame.el
(defvar boardgame-current-world-directory)

;; Forward declarations for functions in boardgame-world.el
(declare-function boardgame-world-name "boardgame-world" (world-dir))
(declare-function boardgame-world-log-filename "boardgame-world" (world-dir))

;; -----------------------------------------------------------------------------
;; Log Buffer State
;; -----------------------------------------------------------------------------

(defvar boardgame-log--buffer-registry (make-hash-table :test 'equal)
  "Map from canonical world directory path to its shared log buffer.")

;; -----------------------------------------------------------------------------
;; Log Buffer Name
;; -----------------------------------------------------------------------------

(defun boardgame-log-buffer-name (world-dir)
  "Return the buffer name for the shared log of WORLD-DIR.
Buffer name follows the pattern: *<world-name>-log*."
  (let ((name (boardgame-world-name world-dir)))
    (concat "*" name "-log*")))

;; -----------------------------------------------------------------------------
;; Buffer Creation and Retrieval
;; -----------------------------------------------------------------------------

(defun boardgame-log--make-buffer (world-dir)
  "Create and configure a new log buffer for WORLD-DIR.
Applies `boardgame-log-mode' and sets truncate-lines to nil."
  (let* ((buf-name (boardgame-log-buffer-name world-dir))
         (buf (get-buffer-create buf-name)))
    (with-current-buffer buf
      (when (fboundp 'boardgame-log-mode)
        (boardgame-log-mode))
      (setq buffer-read-only nil))
    buf))

(defun boardgame-log-get-buffer (world-dir)
  "Return the shared log buffer for WORLD-DIR, creating it if needed.
Caches the buffer in `boardgame-log--buffer-registry'.
All calls with the same WORLD-DIR return the same buffer."
  (let* ((key (expand-file-name world-dir))
         (existing (gethash key boardgame-log--buffer-registry)))
    (if (and existing (buffer-live-p existing))
        existing
      (let ((buf (boardgame-log--make-buffer world-dir)))
        (puthash key buf boardgame-log--buffer-registry)
        buf))))

(defun boardgame-log-current-buffer ()
  "Return the shared log buffer for `boardgame-current-world-directory'.
Returns nil when no world is active."
  (and (boundp 'boardgame-current-world-directory)
       boardgame-current-world-directory
       (boardgame-log-get-buffer boardgame-current-world-directory)))

;; -----------------------------------------------------------------------------
;; Message Appending
;; -----------------------------------------------------------------------------

(defun boardgame-log--format-entry (message &optional source-name)
  "Format MESSAGE as a log entry string with optional SOURCE-NAME prefix.
Returns a string suitable for insertion into the log buffer."
  (let ((prefix (if source-name (format "[%s] " source-name) "")))
    (concat prefix message "\n")))

(defun boardgame-log-append (message &optional world-dir source-name)
  "Append MESSAGE to the shared log buffer for WORLD-DIR.
WORLD-DIR defaults to `boardgame-current-world-directory'.
SOURCE-NAME optionally labels the origin (e.g., board name).
Scrolls all log windows to follow the new entry."
  (let ((dir (or world-dir
                 (and (boundp 'boardgame-current-world-directory)
                      boardgame-current-world-directory))))
    (when dir
      (let ((buf (boardgame-log-get-buffer dir))
            (entry (boardgame-log--format-entry message source-name)))
        (with-current-buffer buf
          (setq buffer-read-only nil)
          (goto-char (point-max))
          (insert entry))
        ;; Auto-scroll all windows displaying this log buffer
        (boardgame-log--scroll-windows buf)))))

(defun boardgame-log--scroll-windows (buf)
  "Scroll all live windows displaying BUF to follow the latest entry."
  (walk-windows
   (lambda (win)
     (when (eq (window-buffer win) buf)
       (with-selected-window win
         (goto-char (point-max)))))
   nil t))

;; -----------------------------------------------------------------------------
;; Log Buffer Cleanup
;; -----------------------------------------------------------------------------

(defun boardgame-log-forget-world (world-dir)
  "Remove the log buffer registry entry for WORLD-DIR.
Does not kill the buffer; callers decide lifecycle."
  (remhash (expand-file-name world-dir)
            boardgame-log--buffer-registry))

(defun boardgame-log-clear-registry ()
  "Remove all dead buffer entries from `boardgame-log--buffer-registry'."
  (maphash
   (lambda (key buf)
     (unless (buffer-live-p buf)
       (remhash key boardgame-log--buffer-registry)))
   boardgame-log--buffer-registry))

;;; boardgame-log.el ends here
