;;; boardgame-window.el --- Window layout and frame management -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Dedicated frame creation, 80/20 window splitting, and buffer layout management
;; for boardgame.org.
;;
;; Invariants:
;; - The dedicated game frame preserves pre-existing user frames and windows.
;; - The layout allocates 80% horizontal width to the board window and 20% to
;;   the side area.
;; - The side area is split vertically: 80% height for the log window, and 20%
;;   for the persistent status area (when enabled).
;; - In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;;   internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

;; Forward variable declarations
(defvar boardgame-board-width-ratio)
(defvar boardgame-log-height-ratio)
(defvar boardgame-status-area-enabled)
(defvar boardgame-current-board-buffer)
(defvar boardgame-current-world-directory)

;; Forward function declarations for stub buffers in `boardgame-mode.el'
(declare-function boardgame-get-board-stub-buffer "boardgame-mode")
(declare-function boardgame-get-log-stub-buffer "boardgame-mode")
(declare-function boardgame-get-status-stub-buffer "boardgame-mode")

;; -----------------------------------------------------------------------------
;; Dimension and Layout Calculations
;; -----------------------------------------------------------------------------

(defun boardgame-window-calculate-split-size (total-size ratio)
  "Calculate primary window size for TOTAL-SIZE given RATIO.
Returns an integer representing the allocated size (minimum 1)."
  (max 1 (round (* total-size ratio))))

(defun boardgame-window-calculate-sizes (total-size ratio)
  "Calculate primary and secondary window sizes for TOTAL-SIZE given RATIO.
Returns a cons cell (PRIMARY . SECONDARY) where the sum
PRIMARY + SECONDARY equals TOTAL-SIZE."
  (let* ((primary (boardgame-window-calculate-split-size total-size ratio))
         (secondary (- total-size primary)))
    (cons primary secondary)))

(defun boardgame-window-calculate-width (total-width &optional ratio)
  "Calculate board window width from TOTAL-WIDTH and optional RATIO.
RATIO defaults to `boardgame-board-width-ratio'."
  (boardgame-window-calculate-split-size total-width (or ratio boardgame-board-width-ratio)))

(defun boardgame-window-calculate-height (total-height &optional ratio)
  "Calculate log window height from TOTAL-HEIGHT and optional RATIO.
RATIO defaults to `boardgame-log-height-ratio'."
  (boardgame-window-calculate-split-size total-height (or ratio boardgame-log-height-ratio)))

(defun boardgame-window-calculate-layout (frame-width frame-height &optional width-ratio height-ratio)
  "Calculate window dimensions for FRAME-WIDTH and FRAME-HEIGHT.
WIDTH-RATIO defaults to `boardgame-board-width-ratio'.
HEIGHT-RATIO defaults to `boardgame-log-height-ratio'.
Returns a plist (:board-width BW :side-width SW
                 :log-height LH :status-height SH)."
  (let* ((w (boardgame-window-calculate-sizes frame-width (or width-ratio boardgame-board-width-ratio)))
         (h (boardgame-window-calculate-sizes frame-height (or height-ratio boardgame-log-height-ratio))))
    (list :board-width (car w)
          :side-width (cdr w)
          :log-height (car h)
          :status-height (cdr h))))

;; -----------------------------------------------------------------------------
;; Dedicated Frame Management
;; -----------------------------------------------------------------------------

(defun boardgame-window--make-frame-parameters (&optional name)
  "Construct frame parameter alist for a dedicated boardgame frame.
Optional NAME overrides default frame title."
  (let* ((term (let ((t-val (getenv "TERM")))
                 (if (or (null t-val) (string-equal t-val "") (string-equal t-val "dumb"))
                     "vt100"
                   t-val)))
         (params (list (cons 'name (or name "boardgame.org"))
                       (cons 'boardgame-frame t))))
    (if (and noninteractive (not (display-graphic-p)))
        (append params (list (cons 'tty-type term)))
      params)))

(defun boardgame-window-create-frame (&optional name)
  "Create and return a new dedicated Emacs frame for boardgame.org.
Optional NAME specifies frame title."
  (make-frame (boardgame-window--make-frame-parameters name)))

(defun boardgame-frame-p (&optional frame)
  "Return non-nil if FRAME is a dedicated boardgame.org frame.
FRAME defaults to the selected frame."
  (let ((target (or frame (selected-frame))))
    (and (frame-live-p target)
         (frame-parameter target 'boardgame-frame))))

;; -----------------------------------------------------------------------------
;; Window Splitting and Layout Setup
;; -----------------------------------------------------------------------------

(defun boardgame-window-setup-windows (frame &optional board-buf log-buf status-buf)
  "Set up the 80/20 window layout on FRAME with the given buffers.
BOARD-BUF, LOG-BUF, and STATUS-BUF default to stub buffers.
Returns a plist (:frame FRAME :board-window W-BOARD :log-window W-LOG
:status-window W-STATUS)."
  (let* ((root (frame-root-window frame))
         (total-width (window-total-width root))
         (board-width (boardgame-window-calculate-width total-width boardgame-board-width-ratio))
         ;; Allow splitting even in compact environments (e.g., small terminals or batch ERT)
         (window-min-width 1)
         (window-min-height 1)
         (side-window (split-window root board-width 'right))
         (side-height (window-total-height side-window))
         (log-height (boardgame-window-calculate-height side-height boardgame-log-height-ratio))
         (status-window (when (and boardgame-status-area-enabled (> side-height 1))
                          (split-window side-window log-height 'below)))
         (b-buf (or board-buf (boardgame-get-board-stub-buffer)))
         (l-buf (or log-buf (boardgame-get-log-stub-buffer)))
         (s-buf (or status-buf (boardgame-get-status-stub-buffer))))
    ;; Assign buffers to their respective windows
    (set-window-buffer root b-buf)
    (set-window-buffer side-window l-buf)
    (when status-window
      (set-window-buffer status-window s-buf))
    ;; Associate windows with frame parameters for quick access
    (set-frame-parameter frame 'boardgame-board-window root)
    (set-frame-parameter frame 'boardgame-log-window side-window)
    (set-frame-parameter frame 'boardgame-status-window status-window)
    ;; Set global active board buffer
    (setq boardgame-current-board-buffer b-buf)
    ;; Ensure focus is placed on the board window in the game frame
    (set-frame-selected-window frame root)
    (list :frame frame
          :board-window root
          :log-window side-window
          :status-window status-window)))

(defun boardgame-window-initialize (&optional world-directory)
  "Initialize dedicated game frame and window layout for WORLD-DIRECTORY.
Creates a dedicated Emacs frame, configures windows according to
the 80/20 layout, and returns the created game frame."
  (when world-directory
    (setq boardgame-current-world-directory world-directory))
  (let* ((frame (boardgame-window-create-frame))
         (_layout (boardgame-window-setup-windows frame)))
    (select-frame-set-input-focus frame)
    frame))

;; -----------------------------------------------------------------------------
;; Frame Window Accessors
;; -----------------------------------------------------------------------------

(defun boardgame-window-board-window (&optional frame)
  "Return the board window for FRAME (defaults to selected frame)."
  (frame-parameter (or frame (selected-frame)) 'boardgame-board-window))

(defun boardgame-window-log-window (&optional frame)
  "Return the log window for FRAME (defaults to selected frame)."
  (frame-parameter (or frame (selected-frame)) 'boardgame-log-window))

(defun boardgame-window-status-window (&optional frame)
  "Return the status window for FRAME (defaults to selected frame)."
  (frame-parameter (or frame (selected-frame)) 'boardgame-status-window))

;;; boardgame-window.el ends here
