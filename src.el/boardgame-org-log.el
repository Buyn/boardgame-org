;;; boardgame-org-log.el --- Shared persistent world log for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Implements Section 12 of boardgame-org-interface.md:
;; "Each world has one persistent log stored as a regular Org file named
;; (world name)-log.org. All game frames displaying boards from the same world
;; share the same log file and log buffer. Each new top-level log entry begins
;; with a level-one Org heading (* Entry title)."

;;; Code:

(require 'org)
(require 'boardgame-org-core)

(defvar boardgame-shared-log-buffer nil
  "Buffer visiting the active world's persistent Org log file.")

(defun boardgame-log-file-path ()
  "Return full path to the active world's persistent log file."
  (let ((wname (boardgame-world-name)))
    (boardgame-world-file (format "%s-log.org" wname))))

;;;###autoload
(defun boardgame-get-or-create-log-buffer ()
  "Get or open the persistent Org log buffer for the active world."
  (let ((log-file (boardgame-log-file-path)))
    (if (and boardgame-shared-log-buffer
             (buffer-live-p boardgame-shared-log-buffer)
             (equal (buffer-file-name boardgame-shared-log-buffer) log-file))
        boardgame-shared-log-buffer
      (unless (file-exists-p log-file)
        (with-temp-file log-file
          (insert (format "#+TITLE: World Log: %s\n" (boardgame-world-name)))
          (insert (format "#+DATE: %s\n" (format-time-string "[%Y-%m-%d %H:%M:%S]")))
          (insert "#+STARTUP: showeverything\n\n")
          (insert "* World Initialized\n")
          (insert (format "Persistent log for world '%s' started.\n\n" (boardgame-world-name)))))
      (let ((buf (find-file-noselect log-file)))
        (with-current-buffer buf
          (org-mode)
          (setq visual-line-mode t)
          (setq word-wrap t))
        (setq boardgame-shared-log-buffer buf)
        buf))))

;;;###autoload
(defun boardgame-log (title &optional subtitle-alist body)
  "Append a structured entry to the persistent world log.
TITLE becomes a level-1 Org heading (* TITLE).
SUBTITLE-ALIST is a list of (SUBTITLE-NAME . CONTENT) converted into
level-2 headings (** SUBTITLE-NAME).
BODY is optional freeform Org text."
  (when boardgame-active-world-directory
    (let ((buf (boardgame-get-or-create-log-buffer)))
      (with-current-buffer buf
        (save-excursion
          (goto-char (point-max))
          (unless (bolp) (insert "\n"))
          (insert (format "\n* %s\n" title))
          (insert (format ":LOGGED_AT: %s\n\n" (format-time-string "[%Y-%m-%d %H:%M:%S]")))
          (when subtitle-alist
            (dolist (item subtitle-alist)
              (insert (format "** %s\n" (car item)))
              (insert (format "%s\n\n" (cdr item)))))
          (when body
            (insert (format "%s\n\n" body)))))
      ;; Move log window point to the bottom if visible
      (dolist (win (get-buffer-window-list buf nil t))
        (with-selected-window win
          (goto-char (point-max))
          (recenter -1))))))

;;;###autoload
(defun boardgame-log-save ()
  "Save the shared persistent log buffer to disk if modified."
  (when (and boardgame-shared-log-buffer
             (buffer-live-p boardgame-shared-log-buffer)
             (buffer-modified-p boardgame-shared-log-buffer))
    (with-current-buffer boardgame-shared-log-buffer
      (let ((f (buffer-file-name)))
        (if f
            (progn
              (write-region (point-min) (point-max) f nil 'quiet)
              (set-buffer-modified-p nil))
          (save-buffer))))))


(provide 'boardgame-org-log)
;;; boardgame-org-log.el ends here
