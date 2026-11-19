;;; boardgame-board.el --- Board buffer management and navigation -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Board buffer creation, buffer display settings, line truncation settings,
;; navigation commands, and interactive board operations for boardgame.org.
;;
;; Key capabilities:
;; - `boardgame-board-open-file': Load Org board file and open in dedicated buffer.
;; - `boardgame-board-refresh': Refresh board buffer rendering.
;; - `boardgame-board-goto-coord': Navigate point to (x, y) without line wrapping.
;; - `boardgame-board-current-coord': Get (x . y) coordinate under point.
;; - `boardgame-open-test-world': Developer entry point activating test-world.
;; - Public board commands: `boardgame-open-board', `boardgame-save-board', etc.
;;
;; In accordance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2,
;; internal module files do NOT call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; Forward declarations for variables defined in boardgame.el
(defvar boardgame-current-board-buffer)
(defvar boardgame-current-world-directory)

;; Forward declarations for `boardgame-data.el'
(declare-function boardgame-board-p "boardgame-data")
(declare-function boardgame-board-name "boardgame-data")
(declare-function boardgame-board-file "boardgame-data")
(declare-function boardgame-board-width "boardgame-data")
(declare-function boardgame-board-height "boardgame-data")
(declare-function boardgame-board-get-objects "boardgame-data")
(declare-function boardgame-coord-valid-p "boardgame-data")

;; Forward declarations for `boardgame-serialize.el'
(declare-function boardgame-deserialize-board-file "boardgame-serialize")
(declare-function boardgame-serialize-board-to-file "boardgame-serialize")

;; Forward declarations for `boardgame-render.el'
(declare-function boardgame-render-board-into-buffer "boardgame-render")
(declare-function boardgame-render-coord-to-pos "boardgame-render")
(declare-function boardgame-render-pos-to-coord "boardgame-render")

;; Forward declarations for `boardgame-window.el'
(declare-function boardgame-window-initialize "boardgame-window")
(declare-function boardgame-window-board-window "boardgame-window")
(declare-function boardgame-window-log-window "boardgame-window")
(declare-function boardgame-window-status-window "boardgame-window")
(declare-function boardgame-frame-p "boardgame-window")

;; Forward declarations for `boardgame-world.el'
(declare-function boardgame-world-activate "boardgame-world")
(declare-function boardgame-world-set-active-board "boardgame-world")

;; Forward declarations for `boardgame-log.el'
(declare-function boardgame-log-get-buffer "boardgame-log")
(declare-function boardgame-log-append "boardgame-log")

;; Forward declarations for `boardgame-status.el'
(declare-function boardgame-status-update "boardgame-status")
(declare-function boardgame-status-get-buffer "boardgame-status")

;; -----------------------------------------------------------------------------
;; Buffer-local Variables
;; -----------------------------------------------------------------------------

(defvar-local boardgame-board--data nil
  "In-memory `boardgame-board' struct associated with this board buffer.")

;; -----------------------------------------------------------------------------
;; Coordinate Navigation
;; -----------------------------------------------------------------------------

(defun boardgame-board-current-coord (&optional buffer)
  "Return (X . Y) coordinate of point in BUFFER (defaults to current buffer).
Returns nil if point is outside valid board bounds."
  (let ((buf (or buffer (current-buffer))))
    (with-current-buffer buf
      (when boardgame-board--data
        (boardgame-render-pos-to-coord boardgame-board--data (point))))))

(defun boardgame-board-goto-coord (x y &optional buffer)
  "Move point to board coordinates (X, Y) in BUFFER.
Enforces bounds and native scrolling."
  (let ((buf (or buffer (current-buffer))))
    (with-current-buffer buf
      (unless boardgame-board--data
        (error "Current buffer is not an active board buffer"))
      (let ((board boardgame-board--data))
        (unless (boardgame-coord-valid-p board x y)
          (error "Coordinate (%d, %d) out of board bounds [0..%d, 0..%d]"
                 x y (1- (boardgame-board-width board)) (1- (boardgame-board-height board))))
        (let ((pos (boardgame-render-coord-to-pos board x y)))
          (goto-char pos)
          (boardgame-board--sync-status)
          pos)))))

(defun boardgame-board--sync-status ()
  "Synchronize status window with current board cursor position."
  (when (and (derived-mode-p 'boardgame-board-mode)
             boardgame-board--data)
    (let ((coord (boardgame-board-current-coord)))
      (when coord
        (let* ((x (car coord))
               (y (cdr coord))
               (objs (boardgame-board-get-objects boardgame-board--data x y))
               (obj-info (if objs
                             (format "Object: %s (total: %d)"
                                     (boardgame-object-name (car objs))
                                     (length objs))
                           "Empty cell")))
          (boardgame-status-update x y nil obj-info))))))

;; -----------------------------------------------------------------------------
;; Buffer Creation and Setup
;; -----------------------------------------------------------------------------

(defun boardgame-board-buffer-name (board-name)
  "Return buffer name for BOARD-NAME."
  (format "*boardgame: %s*" board-name))

(defun boardgame-board-setup-buffer (board)
  "Create and configure a buffer in `boardgame-board-mode' displaying BOARD."
  (let* ((buf-name (boardgame-board-buffer-name (boardgame-board-name board)))
         (buf (get-buffer-create buf-name)))
    (with-current-buffer buf
      (boardgame-board-mode)
      (setq-local boardgame-board--data board)
      (setq-local truncate-lines t)
      (setq-local auto-hscroll-mode t)
      (setq-local buffer-read-only t)
      (boardgame-render-board-into-buffer board buf)
      (add-hook 'post-command-hook #'boardgame-board--sync-status nil t))
    buf))

(defun boardgame-board-refresh (&optional buffer)
  "Re-render BUFFER from its in-memory `boardgame-board' data."
  (interactive)
  (let ((buf (or buffer (current-buffer))))
    (with-current-buffer buf
      (when boardgame-board--data
        (let ((saved-pos (point)))
          (boardgame-render-board-into-buffer boardgame-board--data buf)
          (goto-char (min saved-pos (point-max))))))))

(defun boardgame-board-open-file (file &optional frame)
  "Open Org board document FILE, deserialize into memory, and display in FRAME.
FRAME defaults to the selected frame or a dedicated game frame.
Returns the prepared board buffer."
  (let* ((expanded (expand-file-name file))
         (board (boardgame-deserialize-board-file expanded))
         (buf (boardgame-board-setup-buffer board))
         (target-frame (or (and frame (frame-live-p frame) frame)
                           (if (boardgame-frame-p)
                               (selected-frame)
                             nil))))
    (if target-frame
        (let ((win (boardgame-window-board-window target-frame)))
          (if (and win (window-live-p win))
              (set-window-buffer win buf)
            (set-window-buffer (frame-root-window target-frame) buf))
          (boardgame-world-set-active-board buf target-frame))
      (setq target-frame (boardgame-window-initialize (file-name-directory expanded)))
      (let ((win (boardgame-window-board-window target-frame)))
        (when win
          (set-window-buffer win buf))
        (boardgame-world-set-active-board buf target-frame)))
    (select-frame-set-input-focus target-frame)
    (with-current-buffer buf
      (goto-char (point-min)))
    buf))

;; -----------------------------------------------------------------------------
;; Root Test World Setup & Interactive Command
;; -----------------------------------------------------------------------------

(defvar boardgame--directory)

(defun boardgame-test-world-directory ()
  "Return absolute path to test-world directory in project root."
  (expand-file-name "test-world" boardgame--directory))

;;;###autoload
(defun boardgame-open-test-world ()
  "Launch dedicated game frame and open `test-world/board.org`.
Developer convenience command for interactive verification."
  (interactive)
  (let* ((world-dir (boardgame-test-world-directory))
         (board-file (expand-file-name "board.org" world-dir)))
    (unless (file-exists-p board-file)
      (setq world-dir (expand-file-name "test-world" default-directory))
      (setq board-file (expand-file-name "board.org" world-dir)))
    (boardgame-world-activate world-dir)
    (let* ((log-buf (boardgame-log-get-buffer world-dir))
           (frame (boardgame-window-create-frame "boardgame.org - Test World"))
           (board-buf (let ((b (boardgame-deserialize-board-file board-file)))
                        (boardgame-board-setup-buffer b))))
      (boardgame-window-setup-windows frame board-buf log-buf nil)
      (boardgame-world-set-active-board board-buf frame)
      (select-frame-set-input-focus frame)
      (with-current-buffer board-buf
        (goto-char (point-min)))
      board-buf)))

;; -----------------------------------------------------------------------------
;; Public Board Commands (Stubs / Implementations for Stage 4)
;; -----------------------------------------------------------------------------

;;;###autoload
(defun boardgame-open-board (file)
  "Open board from Org document FILE in active world."
  (interactive "fOpen board file: ")
  (boardgame-board-open-file file))

;;;###autoload
(defun boardgame-save-board (&optional buffer)
  "Save current in-memory board state in BUFFER to its Org file."
  (interactive)
  (let ((buf (or buffer (current-buffer))))
    (with-current-buffer buf
      (unless boardgame-board--data
        (error "Current buffer is not a game board"))
      (let ((file (boardgame-board-file boardgame-board--data)))
        (unless file
          (error "Board has no associated file"))
        (boardgame-serialize-board-to-file boardgame-board--data file)
        (message "Board saved to %s" file)))))

;;; boardgame-board.el ends here
