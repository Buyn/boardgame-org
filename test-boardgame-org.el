;;; test-boardgame-org.el --- ERT test suite for boardgame.org -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; ERT Automated Verification Suite for boardgame.org.
;; Run test cases using:
;;   (load-file "~/Dev/emacs/boardgame-org/test-boardgame-org.el")
;;   (ert "^boardgame-test")

;;; Code:

(require 'ert)

;; Ensure boardgame root package is loaded
(unless (featurep 'boardgame)
  (let ((dir (file-name-directory (or load-file-name
                                     buffer-file-name
                                     default-directory))))
    (load (expand-file-name "boardgame" dir) nil t)))

;; Forward declarations for byte-compiler
(defvar boardgame-board-stub-buffer-name)
(defvar boardgame-log-stub-buffer-name)
(defvar boardgame-status-stub-buffer-name)
(defvar boardgame-current-board-buffer)
(declare-function boardgame-window-calculate-sizes "boardgame-window")
(declare-function boardgame-window-calculate-width "boardgame-window")
(declare-function boardgame-window-calculate-height "boardgame-window")
(declare-function boardgame-window-calculate-layout "boardgame-window")
(declare-function boardgame-window-board-window "boardgame-window")
(declare-function boardgame-window-log-window "boardgame-window")
(declare-function boardgame-window-status-window "boardgame-window")
(declare-function boardgame-frame-p "boardgame-window")
(declare-function boardgame-board-mode "boardgame-mode")
(declare-function boardgame-log-mode "boardgame-mode")
(declare-function boardgame-status-mode "boardgame-mode")
(declare-function boardgame-get-board-stub-buffer "boardgame-mode")
(declare-function boardgame-get-log-stub-buffer "boardgame-mode")
(declare-function boardgame-get-status-stub-buffer "boardgame-mode")
(declare-function boardgame-start "boardgame")

;; -----------------------------------------------------------------------------
;; Architectural Invariant Tests
;; -----------------------------------------------------------------------------

(ert-deftest boardgame-test-single-public-feature ()
  "Verify single public feature provision and private internal modules (§1.2)."
  ;; boardgame.el must be the sole feature provider
  (should (featurep 'boardgame))
  ;; Internal modules must NOT register independent features
  (should-not (featurep 'boardgame-mode))
  (should-not (featurep 'boardgame-window)))

;; -----------------------------------------------------------------------------
;; Stage 1 Tests
;; -----------------------------------------------------------------------------

(ert-deftest boardgame-test-window-calculation ()
  "Unit Test 1.1: Verify window width and height allocation formulas."
  ;; Test 1: Standard 100-column frame with 80% horizontal ratio
  (let ((w (boardgame-window-calculate-sizes 100 0.8)))
    (should (= (car w) 80))
    (should (= (cdr w) 20))
    (should (= (+ (car w) (cdr w)) 100)))

  ;; Test 2: Standard 80-column frame with default boardgame-board-width-ratio (0.8)
  (let ((width (boardgame-window-calculate-width 80)))
    (should (= width 64))
    (should (= (- 80 width) 16)))

  ;; Test 3: Standard 50-line side area with 80% vertical ratio
  (let ((h (boardgame-window-calculate-sizes 50 0.8)))
    (should (= (car h) 40))
    (should (= (cdr h) 10))
    (should (= (+ (car h) (cdr h)) 50)))

  ;; Test 4: Default height calculation with boardgame-log-height-ratio (0.8)
  (let ((height (boardgame-window-calculate-height 25)))
    (should (= height 20))
    (should (= (- 25 height) 5)))

  ;; Test 5: Layout plist calculation across arbitrary dimensions
  (let ((layout (boardgame-window-calculate-layout 120 40)))
    (should (= (plist-get layout :board-width) 96))
    (should (= (plist-get layout :side-width) 24))
    (should (= (plist-get layout :log-height) 32))
    (should (= (plist-get layout :status-height) 8))
    (should (= (+ (plist-get layout :board-width) (plist-get layout :side-width)) 120))
    (should (= (+ (plist-get layout :log-height) (plist-get layout :status-height)) 40)))

  ;; Test 6: Odd frame dimensions must sum to total dimension without losing cells
  (let ((layout-odd (boardgame-window-calculate-layout 101 47)))
    (should (= (+ (plist-get layout-odd :board-width)
                  (plist-get layout-odd :side-width))
               101))
    (should (= (+ (plist-get layout-odd :log-height)
                  (plist-get layout-odd :status-height))
               47)))

  ;; Test 7: Custom user ratios
  (should (= (boardgame-window-calculate-width 100 0.7) 70))
  (should (= (boardgame-window-calculate-height 100 0.6) 60)))

(ert-deftest boardgame-test-buffer-modes ()
  "Unit Test 1.2: Verify major modes and hooks set buffer-local variables."
  ;; Test board mode: truncate-lines must be t
  (with-temp-buffer
    (boardgame-board-mode)
    (should (eq major-mode 'boardgame-board-mode))
    (should (eq truncate-lines t)))

  ;; Test log mode: truncate-lines must be nil (natural wrapping)
  (with-temp-buffer
    (boardgame-log-mode)
    (should (eq major-mode 'boardgame-log-mode))
    (should (null truncate-lines)))

  ;; Test status mode: truncate-lines must be t
  (with-temp-buffer
    (boardgame-status-mode)
    (should (eq major-mode 'boardgame-status-mode))
    (should (eq truncate-lines t)))

  ;; Test major mode hooks execution
  (let ((board-hook-run nil)
        (log-hook-run nil))
    (add-hook 'boardgame-board-mode-hook (lambda () (setq board-hook-run t)))
    (add-hook 'boardgame-log-mode-hook (lambda () (setq log-hook-run t)))
    (unwind-protect
        (progn
          (with-temp-buffer
            (boardgame-board-mode)
            (should board-hook-run)
            (should (eq truncate-lines t)))
          (with-temp-buffer
            (boardgame-log-mode)
            (should log-hook-run)
            (should (null truncate-lines))))
      (remove-hook 'boardgame-board-mode-hook (lambda () (setq board-hook-run t)))
      (remove-hook 'boardgame-log-mode-hook (lambda () (setq log-hook-run t)))))

  ;; Test stub buffer constructors
  (unwind-protect
      (let ((b-buf (boardgame-get-board-stub-buffer))
            (l-buf (boardgame-get-log-stub-buffer))
            (s-buf (boardgame-get-status-stub-buffer)))
        (should (buffer-live-p b-buf))
        (should (buffer-live-p l-buf))
        (should (buffer-live-p s-buf))
        (with-current-buffer b-buf
          (should (eq major-mode 'boardgame-board-mode))
          (should (eq truncate-lines t)))
        (with-current-buffer l-buf
          (should (eq major-mode 'boardgame-log-mode))
          (should (null truncate-lines)))
        (with-current-buffer s-buf
          (should (eq major-mode 'boardgame-status-mode))
          (should (eq truncate-lines t))))
    (dolist (name (list boardgame-board-stub-buffer-name
                        boardgame-log-stub-buffer-name
                        boardgame-status-stub-buffer-name))
      (when (get-buffer name)
        (kill-buffer name)))))

(ert-deftest boardgame-test-frame-initialization ()
  "Integration Test 1.3: Verify dedicated frame, window tree layout, and stub buffers."
  (let* ((initial-frames (frame-list))
         (initial-frame (selected-frame))
         (initial-windows (window-list initial-frame))
         (initial-active-buffer boardgame-current-board-buffer)
         (game-frame nil))
    (unwind-protect
        (progn
          ;; Execute startup entry point
          (setq game-frame (boardgame-start))

          ;; 1. Verify dedicated frame creation
          (should (frame-live-p game-frame))
          (should-not (eq game-frame initial-frame))
          (should (= (length (frame-list)) (1+ (length initial-frames))))
          (should (boardgame-frame-p game-frame))

          ;; 2. Verify pre-existing frame was not modified
          (should (frame-live-p initial-frame))
          (should (equal (window-list initial-frame) initial-windows))

          ;; 3. Verify exactly 3 distinct windows are created on the game frame
          (let ((windows (window-list game-frame 'no-minibuf)))
            (should (= (length windows) 3)))

          ;; 4. Verify window-tree hierarchy:
          ;; Root split (horizontal): Board window on left, Side area subtree on right.
          ;; Side area split (vertical): Log window on top, Status window on bottom.
          (let* ((tree (window-tree game-frame))
                 (root-node (car tree)))
            ;; Root combination must be horizontal (DIR is nil in Emacs window-tree)
            (should (consp root-node))
            (let ((w-board (nth 2 root-node))
                  (side-node (nth 3 root-node)))
              ;; Left child is the board window
              (should (windowp w-board))
              (should (eq (window-buffer w-board)
                          (get-buffer boardgame-board-stub-buffer-name)))

              ;; Right child is the side area combination
              (should (consp side-node))
              (let ((w-log (nth 2 side-node))
                    (w-status (nth 3 side-node)))
                ;; Top side child is the log window
                (should (windowp w-log))
                (should (eq (window-buffer w-log)
                            (get-buffer boardgame-log-stub-buffer-name)))

                ;; Bottom side child is the status window
                (should (windowp w-status))
                (should (eq (window-buffer w-status)
                            (get-buffer boardgame-status-stub-buffer-name))))))

          ;; 5. Verify window accessors
          (should (windowp (boardgame-window-board-window game-frame)))
          (should (windowp (boardgame-window-log-window game-frame)))
          (should (windowp (boardgame-window-status-window game-frame)))

          ;; 6. Verify global active board buffer is updated
          (should (eq boardgame-current-board-buffer
                      (get-buffer boardgame-board-stub-buffer-name))))

      ;; Teardown & cleanup to maintain test idempotency
      (when (and game-frame (frame-live-p game-frame))
        (delete-frame game-frame))
      (setq boardgame-current-board-buffer initial-active-buffer)
      (dolist (name (list boardgame-board-stub-buffer-name
                          boardgame-log-stub-buffer-name
                          boardgame-status-stub-buffer-name))
        (when (get-buffer name)
          (kill-buffer name))))))

;;; test-boardgame-org.el ends here
