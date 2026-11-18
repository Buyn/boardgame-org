;;; boardgame-mode.el --- Major modes for boardgame.org -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Major mode definitions and temporary stub buffer management for boardgame.org.
;;
;; Provides:
;; - `boardgame-board-mode': Major mode for board buffers with enforced line truncation.
;; - `boardgame-log-mode': Major mode for shared world log with natural text wrapping.
;; - `boardgame-status-mode': Major mode for the persistent status area.
;; - Stub buffer creation functions for Stage 1 initialization.
;;
;; Architectural Invariant:
;; In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;; internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

;; -----------------------------------------------------------------------------
;; Major Modes
;; -----------------------------------------------------------------------------

(defvar boardgame-board-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap for `boardgame-board-mode'.")

(define-derived-mode boardgame-board-mode nil "Boardgame-Board"
  "Major mode for displaying and interacting with a tabletop game board.
Enforces non-wrapping lines (`truncate-lines' set to t) so each character
cell corresponds to a stable coordinate."
  :group 'boardgame
  (setq-local truncate-lines t)
  (setq-local auto-hscroll-mode t))

(defvar boardgame-log-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap for `boardgame-log-mode'.")

(define-derived-mode boardgame-log-mode nil "Boardgame-Log"
  "Major mode for the shared world game log.
Allows natural text wrapping (`truncate-lines' set to nil) for
readable messages."
  :group 'boardgame
  (setq-local truncate-lines nil)
  (setq-local word-wrap t))

(defvar boardgame-status-mode-map
  (let ((map (make-sparse-keymap)))
    map)
  "Keymap for `boardgame-status-mode'.")

(define-derived-mode boardgame-status-mode nil "Boardgame-Status"
  "Major mode for the persistent contextual status area."
  :group 'boardgame
  (setq-local truncate-lines t))

;; -----------------------------------------------------------------------------
;; Temporary Stub Buffer Management (Stage 1)
;; -----------------------------------------------------------------------------

(defconst boardgame-board-stub-buffer-name "*boardgame-board-stub*"
  "Buffer name for the temporary board stub buffer.")

(defconst boardgame-log-stub-buffer-name "*boardgame-log-stub*"
  "Buffer name for the temporary shared log stub buffer.")

(defconst boardgame-status-stub-buffer-name "*boardgame-status-stub*"
  "Buffer name for the temporary status stub buffer.")

(defun boardgame-get-board-stub-buffer ()
  "Return or create the temporary board stub buffer in `boardgame-board-mode'."
  (let ((buf (get-buffer-create boardgame-board-stub-buffer-name)))
    (with-current-buffer buf
      (unless (eq major-mode 'boardgame-board-mode)
        (boardgame-board-mode))
      (when (= (buffer-size) 0)
        (insert "================================================================================\n"
                "  boardgame.org - Game Board (Stage 1 Stub)\n"
                "================================================================================\n"
                "Line truncation is active (truncate-lines = t).\n"
                "Live board rendering will replace this stub in Stage 4.\n")))
    buf))

(defun boardgame-get-log-stub-buffer ()
  "Return or create the temporary log stub buffer in `boardgame-log-mode'."
  (let ((buf (get-buffer-create boardgame-log-stub-buffer-name)))
    (with-current-buffer buf
      (unless (eq major-mode 'boardgame-log-mode)
        (boardgame-log-mode))
      (when (= (buffer-size) 0)
        (insert "========================================\n"
                "  boardgame.org - Shared Log (Stage 1 Stub)\n"
                "========================================\n"
                "Natural wrapping is active (truncate-lines = nil).\n"
                "Unified world logging will replace this stub in Stage 3.\n")))
    buf))

(defun boardgame-get-status-stub-buffer ()
  "Return or create the temporary status stub buffer in `boardgame-status-mode'."
  (let ((buf (get-buffer-create boardgame-status-stub-buffer-name)))
    (with-current-buffer buf
      (unless (eq major-mode 'boardgame-status-mode)
        (boardgame-status-mode))
      (when (= (buffer-size) 0)
        (insert "========================================\n"
                "  Status (Stage 1 Stub)\n"
                "========================================\n"
                "Coordinates: (0, 0)\n"
                "Mode: Idle\n")))
    buf))

;;; boardgame-mode.el ends here
