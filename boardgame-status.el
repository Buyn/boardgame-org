;;; boardgame-status.el --- Status window content and contextual display -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Status window updating and contextual state display for boardgame.org.
;;
;; Renders current coordinate, active sub-mode, and selected object metadata
;; in the status window as specified in §4.2 of boardgame-org-interface.md.
;;
;; Architectural Invariant:
;; In accordance with `boardgame-org.md' §7 and
;; `boardgame-implementation-plan.md' §1.2, internal module files do NOT
;; call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; Forward declarations for variables defined in boardgame.el
(defvar boardgame-current-board-buffer)
(defvar boardgame-current-world-directory)

;; Forward declarations for window accessors
(declare-function boardgame-window-status-window "boardgame-window"
                  (&optional frame))

;; -----------------------------------------------------------------------------
;; Status State
;; -----------------------------------------------------------------------------

(defvar boardgame-status--current-x 0
  "Cached board X coordinate displayed in the status window.")

(defvar boardgame-status--current-y 0
  "Cached board Y coordinate displayed in the status window.")

(defvar boardgame-status--mode-label ""
  "Current sub-mode label displayed in the status window (e.g., Drawing).")

(defvar boardgame-status--object-info ""
  "Formatted object metadata string shown in the status window.")

;; -----------------------------------------------------------------------------
;; Status Content Formatting
;; -----------------------------------------------------------------------------

(defun boardgame-status--format-coordinates (x y)
  "Return a formatted string for board coordinates X and Y."
  (format "Position: (%d, %d)" x y))

(defun boardgame-status--format-mode (label)
  "Return a formatted string for the sub-mode LABEL.
Returns an empty string when LABEL is nil or empty."
  (if (and label (not (string= label "")))
      (format "Mode: %s" label)
    ""))

(defun boardgame-status--format-object (info)
  "Return a formatted string for object INFO.
Returns an empty string when INFO is nil or empty."
  (if (and info (not (string= info "")))
      (format "Object: %s" info)
    ""))

(defun boardgame-status--build-content (x y mode-label object-info world-dir)
  "Build the full status window text from provided fields.
X, Y: board coordinates.
MODE-LABEL: current sub-mode string.
OBJECT-INFO: selected object metadata string.
WORLD-DIR: current world directory path.
Returns a multi-line string."
  (let ((lines
         (list
          (boardgame-status--format-coordinates x y)
          (boardgame-status--format-mode mode-label)
          (boardgame-status--format-object object-info)
          (if world-dir
              (format "World: %s"
                      (file-name-nondirectory
                       (directory-file-name world-dir)))
            ""))))
    (mapconcat (lambda (l) l)
               (cl-remove-if #'string-empty-p lines)
               "\n")))

;; -----------------------------------------------------------------------------
;; Status Buffer Update
;; -----------------------------------------------------------------------------

(defun boardgame-status-get-buffer (&optional frame)
  "Return the status buffer for FRAME, or nil if none.
Looks up the status window via frame parameter."
  (let* ((target (or frame (selected-frame)))
         (win (and (fboundp 'boardgame-window-status-window)
                   (boardgame-window-status-window target))))
    (and win (window-live-p win) (window-buffer win))))

(defun boardgame-status-render (content &optional frame)
  "Render CONTENT string into the status window for FRAME.
FRAME defaults to the selected frame.
Replaces the buffer content with CONTENT."
  (let ((buf (boardgame-status-get-buffer frame)))
    (when (and buf (buffer-live-p buf))
      (with-current-buffer buf
        (setq buffer-read-only nil)
        (erase-buffer)
        (insert content)
        (goto-char (point-min))))))

(defun boardgame-status-update (&optional x y mode-label object-info frame)
  "Update the status window with optional fields X, Y, MODE-LABEL, OBJECT-INFO.
FRAME defaults to the selected frame.
Uses cached values when arguments are omitted."
  (when x (setq boardgame-status--current-x x))
  (when y (setq boardgame-status--current-y y))
  (when mode-label (setq boardgame-status--mode-label mode-label))
  (when object-info (setq boardgame-status--object-info object-info))
  (let ((content
         (boardgame-status--build-content
          boardgame-status--current-x
          boardgame-status--current-y
          boardgame-status--mode-label
          boardgame-status--object-info
          (and (boundp 'boardgame-current-world-directory)
               boardgame-current-world-directory))))
    (boardgame-status-render content frame)))

(defun boardgame-status-clear (&optional frame)
  "Clear the status window for FRAME."
  (boardgame-status-render "" frame))

;;; boardgame-status.el ends here
