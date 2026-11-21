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

;; Stage 2 forward declarations
(declare-function boardgame-board-create "boardgame-data")(declare-function boardgame-board-p "boardgame-data")
(declare-function boardgame-board-name "boardgame-data")
(declare-function boardgame-board-width "boardgame-data")
(declare-function boardgame-board-height "boardgame-data")
(declare-function boardgame-board-felt-default "boardgame-data")
(declare-function boardgame-board-properties "boardgame-data")
(declare-function boardgame-board-get-felt "boardgame-data")
(declare-function boardgame-board-set-felt "boardgame-data")
(declare-function boardgame-board-felt-string "boardgame-data")
(declare-function boardgame-board-get-objects "boardgame-data")
(declare-function boardgame-board-get-top-object "boardgame-data")
(declare-function boardgame-board-add-object "boardgame-data")
(declare-function boardgame-board-remove-object "boardgame-data")
(declare-function boardgame-board-move-object "boardgame-data")
(declare-function boardgame-board-all-objects "boardgame-data")
(declare-function boardgame-board-create-empty "boardgame-data")
(declare-function boardgame-object-create "boardgame-data")
(declare-function boardgame-object-name "boardgame-data")
(declare-function boardgame-object-x "boardgame-data")
(declare-function boardgame-object-y "boardgame-data")
(declare-function boardgame-object-glyph "boardgame-data")
(declare-function boardgame-felt-normalize "boardgame-serialize")
(declare-function boardgame-felt-normalize-string "boardgame-serialize")
(declare-function boardgame-serialize-parse-property-drawer "boardgame-serialize")
(declare-function boardgame-deserialize-board "boardgame-serialize")
(declare-function boardgame-deserialize-board-file "boardgame-serialize")
(declare-function boardgame-serialize-board "boardgame-serialize")
(declare-function boardgame-serialize-board-to-buffer "boardgame-serialize")
(declare-function boardgame-serialize-board-to-file "boardgame-serialize")

;; Stage 4 forward declarations

;; Stage 5 forward declarations
(declare-function boardgame-draw-toggle "boardgame-draw")
(declare-function boardgame-draw-point-paint "boardgame-draw")
(declare-function boardgame-draw-fill-region "boardgame-draw")
(declare-function boardgame-draw-pipette "boardgame-draw")
(declare-function boardgame-draw-set-glyph "boardgame-draw")
(declare-function boardgame-draw-resolve-glyph "boardgame-draw")
(declare-function boardgame-object-indicator-for-count "boardgame-object")
(declare-function boardgame-object-stack-indicator "boardgame-object")
(declare-function boardgame-object-indicator-string "boardgame-object")
(declare-function boardgame-object-topmost "boardgame-object")
(declare-function boardgame-object-resolve-glyph "boardgame-object")
(declare-function boardgame-render-board-into-buffer "boardgame-render")
(declare-function boardgame-render-coord-to-pos "boardgame-render")
(declare-function boardgame-render-pos-to-coord "boardgame-render")
(declare-function boardgame-render-cell "boardgame-render")
(declare-function boardgame-board-setup-buffer "boardgame-board")
(declare-function boardgame-board-refresh "boardgame-board")
(declare-function boardgame-board-goto-coord "boardgame-board")
(declare-function boardgame-board-current-coord "boardgame-board")
(declare-function boardgame-board-open-file "boardgame-board")
(declare-function boardgame-open-test-world "boardgame-board")
(declare-function boardgame-test-world-directory "boardgame-board")

;; -----------------------------------------------------------------------------
;; Architectural Invariant Tests
;; -----------------------------------------------------------------------------

(ert-deftest boardgame-test-single-public-feature ()
  "Verify single public feature provision and private internal modules (§1.2)."
  ;; boardgame.el must be the sole feature provider
  (should (featurep 'boardgame))
  ;; Internal modules must NOT register independent features
  (should-not (featurep 'boardgame-mode))
  (should-not (featurep 'boardgame-window))
  (should-not (featurep 'boardgame-data))
  (should-not (featurep 'boardgame-serialize))
  (should-not (featurep 'boardgame-world))
  (should-not (featurep 'boardgame-log))
  (should-not (featurep 'boardgame-status))
  (should-not (featurep 'boardgame-object))
  (should-not (featurep 'boardgame-render))
  (should-not (featurep 'boardgame-board)))

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

;; -----------------------------------------------------------------------------
;; Stage 2 Tests: In-Memory Data Model, Parsing & Org Serialization
;; -----------------------------------------------------------------------------

(ert-deftest boardgame-test-felt-normalization ()
  "Unit Test 2.1: Verify ragged felt normalization across dimensions."
  ;; Test 1: Ragged list of lines (short, long, empty)
  (let* ((width 8)
         (height 4)
         (ragged '("abc" "1234567890extra" "" "hello"))
         (norm (boardgame-felt-normalize ragged width height ?\.)))
    ;; Exactly height rows returned
    (should (= (length norm) height))
    ;; Every row has exact width
    (dolist (row norm)
      (should (= (length row) width)))
    ;; Check individual rows:
    ;; Row 0: "abc" padded with 5 dots
    (should (string= (nth 0 norm) "abc....."))
    ;; Row 1: "1234567890extra" clipped to width 8
    (should (string= (nth 1 norm) "12345678"))
    ;; Row 2: "" filled with 8 dots
    (should (string= (nth 2 norm) "........"))
    ;; Row 3: "hello" padded with 3 dots
    (should (string= (nth 3 norm) "hello...")))

  ;; Test 2: Input with fewer rows than height (missing rows filled)
  (let* ((norm-short (boardgame-felt-normalize '("##") 5 3 ?#)))
    (should (= (length norm-short) 3))
    (should (string= (nth 0 norm-short) "#####"))
    (should (string= (nth 1 norm-short) "#####"))
    (should (string= (nth 2 norm-short) "#####")))

  ;; Test 3: Input with more rows than height (extra rows clipped)
  (let* ((norm-tall (boardgame-felt-normalize '("a" "b" "c" "d" "e") 4 2 ?\.)))
    (should (= (length norm-tall) 2))
    (should (string= (nth 0 norm-tall) "a..."))
    (should (string= (nth 1 norm-tall) "b...")))

  ;; Test 4: String input with newlines and normalized-string output
  (let* ((multiline "row1\nrow2-long-extra\n\nrow4")
         (norm-str (boardgame-felt-normalize-string multiline 6 4 ?~)))
    (should (string= norm-str "row1~~\nrow2-l\n~~~~~~\nrow4~~"))))

(ert-deftest boardgame-test-property-drawer-parsing ()
  "Unit Test 2.2: Verify Org header and property drawer parsing."
  (let* ((org-header
          (concat
           "* Board: Dungeon Depths\n"
           ":PROPERTIES:\n"
           ":BOARD_WIDTH: 65\n"
           ":BOARD_HEIGHT: 32\n"
           ":FELT_DEFAULT: ~\n"
           ":CUSTOM_CREATOR: Wizard\n"
           ":END:\n\n"
           "** Felt\n"
           "#+begin_src felt\n"
           "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
           "#+end_src\n"))
         (board (boardgame-deserialize-board org-header)))
    ;; Verify extracted name
    (should (string= (boardgame-board-name board) "Dungeon Depths"))
    ;; Verify extracted dimensions
    (should (= (boardgame-board-width board) 65))
    (should (= (boardgame-board-height board) 32))
    ;; Verify extracted default felt character
    (should (equal (boardgame-board-felt-default board) "~"))
    ;; Verify custom properties retained
    (should (assoc "CUSTOM_CREATOR" (boardgame-board-properties board)))
    (should (string= (cdr (assoc "CUSTOM_CREATOR" (boardgame-board-properties board)))
                     "Wizard"))))

(ert-deftest boardgame-test-data-model-operations ()
  "Unit Test: Verify in-memory felt grid, coordinate lookup, and object stacking."
  (let ((board (boardgame-board-create-empty "Test Space" 10 5 ?.)))
    ;; 1. Check initial dimensions and default felt
    (should (= (boardgame-board-width board) 10))
    (should (= (boardgame-board-height board) 5))
    (should (= (boardgame-board-get-felt board 0 0) ?\.))
    (should (= (boardgame-board-get-felt board 9 4) ?\.))

    ;; 2. Set and get felt cell
    (boardgame-board-set-felt board 3 2 ?#)
    (should (= (boardgame-board-get-felt board 3 2) ?#))
    ;; Adjacent cells remain unchanged
    (should (= (boardgame-board-get-felt board 3 1) ?\.))

    ;; 3. Object placement and stacking at same coordinate
    (let ((card-1 (boardgame-object-create :name "Card A" :x 4 :y 2 :glyph "A"))
          (card-2 (boardgame-object-create :name "Card B" :x 4 :y 2 :glyph "B")))
      (boardgame-board-add-object board card-1)
      (boardgame-board-add-object board card-2)

      ;; Multiple objects at (4, 2)
      (let ((stacked (boardgame-board-get-objects board 4 2)))
        (should (= (length stacked) 2))
        ;; Topmost object is card-2 (most recently added on top)
        (should (eq (car stacked) card-2))
        (should (eq (boardgame-board-get-top-object board 4 2) card-2)))

      ;; Move card-2 to (6, 1)
      (boardgame-board-move-object board card-2 6 1)
      (should (= (length (boardgame-board-get-objects board 4 2)) 1))
      (should (eq (boardgame-board-get-top-object board 4 2) card-1))
      (should (eq (boardgame-board-get-top-object board 6 1) card-2))

      ;; Remove card-1
      (boardgame-board-remove-object board card-1)
      (should-not (boardgame-board-get-objects board 4 2))
      (should-not (boardgame-board-get-top-object board 4 2)))))

(ert-deftest boardgame-test-roundtrip-serialization ()
  "Integration Test 2.3: Verify lossless round-trip Org board serialization."
  (let* ((source-text
          (concat
           "* Board: Adventure Arena\n"
           ":PROPERTIES:\n"
           ":BOARD_WIDTH: 20\n"
           ":BOARD_HEIGHT: 5\n"
           ":FELT_DEFAULT: .\n"
           ":END:\n\n"
           "** Felt\n"
           ":PROPERTIES:\n"
           ":CUSTOM_ID: felt\n"
           ":END:\n\n"
           "#+begin_src felt\n"
           "....................\n"
           "....#####...........\n"
           "....#...#...........\n"
           "....#####...........\n"
           "....................\n"
           "#+end_src\n\n"
           "** Objects\n"
           ":PROPERTIES:\n"
           ":CUSTOM_ID: objects\n"
           ":END:\n\n"
           "*** Dragon Card\n"
           ":PROPERTIES:\n"
           ":OBJECT_FILE: objects/dragon.org\n"
           ":OBJECT_TYPE: card\n"
           ":X: 4\n"
           ":Y: 1\n"
           ":GLYPH: D\n"
           ":END:\n\n"
           "*** Gold Token\n"
           ":PROPERTIES:\n"
           ":OBJECT_FILE: objects/gold.org\n"
           ":OBJECT_TYPE: token\n"
           ":X: 8\n"
           ":Y: 2\n"
           ":GLYPH: $\n"
           ":END:\n"))
         (temp-file (make-temp-file "boardgame-roundtrip-" nil ".org"))
         (temp-buffer (generate-new-buffer "*boardgame-test-roundtrip*")))
    (unwind-protect
        (progn
          ;; 1. Write source Org document to file
          (with-temp-file temp-file
            (insert source-text))

          ;; 2. Deserialize board from file into in-memory model
          (let ((board (boardgame-deserialize-board-file temp-file)))
            (should (boardgame-board-p board))
            (should (string= (boardgame-board-name board) "Adventure Arena"))
            (should (= (boardgame-board-width board) 20))
            (should (= (boardgame-board-height board) 5))
            (should (= (boardgame-board-get-felt board 4 1) ?#))
            (should (= (boardgame-board-get-felt board 0 0) ?\.))
            (should (= (length (boardgame-board-all-objects board)) 2))
            (let ((dragon (boardgame-board-get-top-object board 4 1))
                  (gold (boardgame-board-get-top-object board 8 2)))
              (should dragon)
              (should (string= (boardgame-object-name dragon) "Dragon Card"))
              (should (string= (boardgame-object-glyph dragon) "D"))
              (should gold)
              (should (string= (boardgame-object-name gold) "Gold Token"))
              (should (string= (boardgame-object-glyph gold) "$")))

            ;; 3. Serialize back into a temporary buffer
            (boardgame-serialize-board-to-buffer board temp-buffer)

            ;; 4. Assert that serialized Org text is identical to source document
            (with-current-buffer temp-buffer
              (should (string= (buffer-string) source-text)))

            ;; 5. Assert mutual invertibility: deserialize(serialize(state)) == state
            (let* ((re-serialized (boardgame-serialize-board board))
                   (re-board (boardgame-deserialize-board re-serialized)))
              (should (string= (boardgame-board-name re-board)
                               (boardgame-board-name board)))
              (should (= (boardgame-board-width re-board)
                         (boardgame-board-width board)))
              (should (= (boardgame-board-height re-board)
                         (boardgame-board-height board)))
              (should (string= (boardgame-board-felt-string re-board)
                               (boardgame-board-felt-string board)))
              (should (= (length (boardgame-board-all-objects re-board))
                         (length (boardgame-board-all-objects board)))))))

      ;; Cleanup
      (when (file-exists-p temp-file)
        (delete-file temp-file))
      (when (buffer-live-p temp-buffer)
        (kill-buffer temp-buffer)))))

;; Stage 3 forward declarations
(declare-function boardgame-world-name "boardgame-world" (world-dir))
(declare-function boardgame-world-log-filename "boardgame-world" (world-dir))
(declare-function boardgame-world-valid-p "boardgame-world" (world-dir))
(declare-function boardgame-world-activate "boardgame-world" (world-dir))
(declare-function boardgame-world-resolve-board "boardgame-world"
                  (explicit-buffer))
(declare-function boardgame-world-set-active-board "boardgame-world"
                  (buffer &optional frame))
(declare-function boardgame-log-get-buffer "boardgame-log" (world-dir))
(declare-function boardgame-log-buffer-name "boardgame-log" (world-dir))
(declare-function boardgame-log-append "boardgame-log"
                  (message &optional world-dir source-name))
(declare-function boardgame-log-current-buffer "boardgame-log" ())
(declare-function boardgame-log-forget-world "boardgame-log" (world-dir))
(declare-function boardgame-status-update "boardgame-status"
                  (&optional x y mode-label object-info frame))
(declare-function boardgame-status-clear "boardgame-status" (&optional frame))
(declare-function boardgame-status--build-content "boardgame-status"
                  (x y mode-label object-info world-dir))

;; -----------------------------------------------------------------------------
;; Stage 3 Tests: World Management, Session State, and Unified Logging
;; -----------------------------------------------------------------------------

(ert-deftest boardgame-test-log-filename-resolution ()
  "Unit Test 3.1: Log path resolves to <world-path>/<world-name>-log.org."
  ;; Test 1: Simple directory path
  (let* ((world-dir "/tmp/my-world")
         (expected "/tmp/my-world/my-world-log.org")
         (result (boardgame-world-log-filename world-dir)))
    (should (string= result expected)))

  ;; Test 2: Trailing slash is handled correctly
  (let* ((world-dir "/tmp/dungeon-quest/")
         (result (boardgame-world-log-filename world-dir)))
    (should (string= result
                     "/tmp/dungeon-quest/dungeon-quest-log.org")))

  ;; Test 3: Nested path resolves correctly
  (let* ((world-dir "/home/user/games/pirate-adventure")
         (result (boardgame-world-log-filename world-dir)))
    (should (string=
             result
             "/home/user/games/pirate-adventure/pirate-adventure-log.org")))

  ;; Test 4: World name extraction
  (should (string= (boardgame-world-name "/tmp/test-world") "test-world"))
  (should (string= (boardgame-world-name "/tmp/test-world/") "test-world"))

  ;; Test 5: Log buffer name follows *<world-name>-log* pattern
  (should (string= (boardgame-log-buffer-name "/tmp/test-world")
                   "*test-world-log*")))

(ert-deftest boardgame-test-active-board-precedence ()
  "Unit Test 3.2: Active board resolution respects explicit > frame > global."
  (let ((buf-explicit (generate-new-buffer "*boardgame-test-explicit*"))
        (buf-global (generate-new-buffer "*boardgame-test-global*"))
        (saved-current boardgame-current-board-buffer))
    (unwind-protect
        (progn
          ;; Set up global fallback
          (setq boardgame-current-board-buffer buf-global)
          ;; Clear any frame association
          (set-frame-parameter (selected-frame)
                               'boardgame-active-board-buffer nil)

          ;; 1. Explicit live buffer: returns explicit buffer
          (should (eq (boardgame-world-resolve-board buf-explicit)
                      buf-explicit))

          ;; 2. With nil explicit: returns global fallback
          (should (eq (boardgame-world-resolve-board nil) buf-global))

          ;; 3. Frame-associated buffer takes precedence over global
          (set-frame-parameter (selected-frame)
                               'boardgame-active-board-buffer buf-explicit)
          (should (eq (boardgame-world-resolve-board nil) buf-explicit))

          ;; 4. When explicit is dead: does not return it
          (kill-buffer buf-explicit)
          (set-frame-parameter (selected-frame)
                               'boardgame-active-board-buffer nil)
          (should (eq (boardgame-world-resolve-board nil) buf-global))

          ;; 5. When both dead: returns nil
          (kill-buffer buf-global)
          (setq boardgame-current-board-buffer nil)
          (should-not (boardgame-world-resolve-board nil)))

      ;; Cleanup
      (when (buffer-live-p buf-explicit) (kill-buffer buf-explicit))
      (when (buffer-live-p buf-global) (kill-buffer buf-global))
      (set-frame-parameter (selected-frame)
                           'boardgame-active-board-buffer nil)
      (setq boardgame-current-board-buffer saved-current))))

(ert-deftest boardgame-test-multi-board-shared-log ()
  "Integration Test 3.3: Two boards share one log buffer for the same world."
  (let* ((world-dir (make-temp-file "boardgame-test-world-" t))
         (buf-board-a (generate-new-buffer "*boardgame-test-board-a*"))
         (buf-board-b (generate-new-buffer "*boardgame-test-board-b*"))
         (log-buf nil))
    (unwind-protect
        (progn
          ;; 1. Retrieve log buffer for the world
          (setq log-buf (boardgame-log-get-buffer world-dir))
          (should (buffer-live-p log-buf))

          ;; 2. Second call returns the same buffer (shared)
          (should (eq log-buf (boardgame-log-get-buffer world-dir)))

          ;; 3. Append message from board A
          (boardgame-log-append "Board A: Player moved" world-dir "Board-A")
          ;; 4. Append message from board B
          (boardgame-log-append "Board B: Card drawn" world-dir "Board-B")

          ;; 5. Both messages appear in the shared log buffer
          (with-current-buffer log-buf
            (let ((text (buffer-string)))
              (should (string-match-p "Board A: Player moved" text))
              (should (string-match-p "Board B: Card drawn" text))
              ;; Board A entry appears before Board B (sequential order)
              (should (< (string-match "Board A" text)
                         (string-match "Board B" text)))))

          ;; 6. A second world gets a different log buffer
          (let* ((world-dir-2 (make-temp-file "boardgame-test-world2-" t))
                 (log-buf-2 (boardgame-log-get-buffer world-dir-2)))
            (unwind-protect
                (progn
                  (should (buffer-live-p log-buf-2))
                  (should-not (eq log-buf log-buf-2)))
              (boardgame-log-forget-world world-dir-2)
              (when (buffer-live-p log-buf-2) (kill-buffer log-buf-2))
              (delete-directory world-dir-2 t))))

      ;; Cleanup
      (boardgame-log-forget-world world-dir)
      (when (buffer-live-p buf-board-a) (kill-buffer buf-board-a))
      (when (buffer-live-p buf-board-b) (kill-buffer buf-board-b))
      (when (and log-buf (buffer-live-p log-buf)) (kill-buffer log-buf))
      (delete-directory world-dir t))))

;; -----------------------------------------------------------------------------
;; Stage 4 Tests: Board Rendering, Object Stacking, Root Test World Setup,
;;                and Non-Wrapping Navigation
;; -----------------------------------------------------------------------------

(ert-deftest boardgame-test-stack-indicator-calculation ()
  "Unit Test 4.1: Verify generated stack indicator character outputs (1..9, +)."
  ;; Verify counts 1, 5, 9, 12 as specified in plan DoD
  (let ((objs-1 (list (boardgame-object-create :name "O1")))
        (objs-5 (mapcar (lambda (i) (boardgame-object-create :name (format "O%d" i))) (number-sequence 1 5)))
        (objs-9 (mapcar (lambda (i) (boardgame-object-create :name (format "O%d" i))) (number-sequence 1 9)))
        (objs-12 (mapcar (lambda (i) (boardgame-object-create :name (format "O%d" i))) (number-sequence 1 12))))
    ;; Indicator calculation from object lists
    (should (eq (boardgame-object-stack-indicator objs-1) ?1))
    (should (eq (boardgame-object-stack-indicator objs-5) ?5))
    (should (eq (boardgame-object-stack-indicator objs-9) ?9))
    (should (eq (boardgame-object-stack-indicator objs-12) ?+))

    ;; Indicator strings
    (should (string= (boardgame-object-indicator-string objs-1) "1"))
    (should (string= (boardgame-object-indicator-string objs-5) "5"))
    (should (string= (boardgame-object-indicator-string objs-9) "9"))
    (should (string= (boardgame-object-indicator-string objs-12) "+"))

    ;; Indicator calculation directly from integer counts
    (should (eq (boardgame-object-indicator-for-count 1) ?1))
    (should (eq (boardgame-object-indicator-for-count 5) ?5))
    (should (eq (boardgame-object-indicator-for-count 9) ?9))
    (should (eq (boardgame-object-indicator-for-count 12) ?+))
    (should (eq (boardgame-object-indicator-for-count 0) nil))
    (should (eq (boardgame-object-indicator-for-count -1) nil))))

(ert-deftest boardgame-test-layering-visibility ()
  "Unit Test 4.2: Renderer selects top object glyph at (10, 10)."
  (let* ((board (boardgame-board-create-empty "Layering Board" 20 20 "."))
         (obj-bottom (boardgame-object-create :name "Shield" :x 10 :y 10 :glyph "S"))
         (obj-middle (boardgame-object-create :name "Sword"  :x 10 :y 10 :glyph "/"))
         (obj-top    (boardgame-object-create :name "Crown"  :x 10 :y 10 :glyph "C"))
         (buf (generate-new-buffer "*boardgame-test-layering*")))
    (unwind-protect
        (progn
          ;; Add objects in bottom-to-top order
          (boardgame-board-add-object board obj-bottom)
          (boardgame-board-add-object board obj-middle)
          (boardgame-board-add-object board obj-top)

          ;; The top object must be obj-top with glyph "C"
          (should (eq (boardgame-board-get-top-object board 10 10) obj-top))
          (should (string= (boardgame-object-resolve-glyph
                            (boardgame-board-get-objects board 10 10))
                           "C"))

          ;; Render into buffer
          (boardgame-render-board-into-buffer board buf)
          (with-current-buffer buf
            ;; Check character rendered at (10, 10)
            (let ((pos (boardgame-render-coord-to-pos board 10 10)))
              (should (= (char-after pos) ?C)))
            ;; Check stack indicator rendered at (9, 10) directly to the left (count=3 -> ?3)
            (let ((ind-pos (boardgame-render-coord-to-pos board 9 10)))
              (should (= (char-after ind-pos) ?3)))))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(ert-deftest boardgame-test-test-world-loading ()
  "Integration Test 4.3: Execute boardgame-open-test-world and verify navigation."
  (let ((orig-frames (frame-list))
        (created-buf nil))
    (unwind-protect
        (progn
          ;; Execute developer command
          (setq created-buf (boardgame-open-test-world))
          (should (buffer-live-p created-buf))

          (with-current-buffer created-buf
            ;; 1. Major mode is boardgame-board-mode
            (should (eq major-mode 'boardgame-board-mode))

            ;; 2. Line wrapping is disabled (truncate-lines is t)
            (should (eq truncate-lines t))

            ;; 3. Board dimensions are 150x60
            (let ((board boardgame-board--data))
              (should board)
              (should (= (boardgame-board-width board) 150))
              (should (= (boardgame-board-height board) 60))

              ;; 4. Check stack indicator in test-world/board.org
              ;; At (25, 10) there are 5 objects -> stack indicator at (24, 10) should be '5'
              (let ((ind-pos (boardgame-render-coord-to-pos board 24 10)))
                (should (= (char-after ind-pos) ?5)))
              ;; At (50, 20) there are 12 objects -> stack indicator at (49, 20) should be '+'
              (let ((ind-pos (boardgame-render-coord-to-pos board 49 20)))
                (should (= (char-after ind-pos) ?+)))

              ;; 5. Smooth non-wrapping navigation / scrolling to (120, 45)
              (let ((pos (boardgame-board-goto-coord 120 45 created-buf)))
                (should (= (point) pos))
                (let ((cur-coord (boardgame-board-current-coord created-buf)))
                  (should (equal cur-coord '(120 . 45)))))))))
      ;; Cleanup created buffers and frames
      (when (buffer-live-p created-buf) (kill-buffer created-buf))
      (dolist (f (frame-list))
        (unless (memq f orig-frames)
          (delete-frame f)))))



;; -----------------------------------------------------------------------------
;; Stage 5 Tests: Drawing Mode (Felt Layer) and Text Overwrite Mode
;; -----------------------------------------------------------------------------

(ert-deftest boardgame-test-pipette-sampling ()
  "Unit Test 5.1: Pipette samples character and color under cursor."
  (let* ((board (boardgame-board-create-empty "Pipette Test" 10 10 ?\.))
         (buf (generate-new-buffer "*boardgame-test-pipette*"))
         (board-buf (boardgame-board-setup-buffer board)))
    (unwind-protect
        (progn
          (boardgame-board-set-felt board 3 2 ?#)
          (with-current-buffer board-buf
            (setq-local boardgame-draw--mode t)
            (setq-local boardgame-draw--glyph ?\s)
            (setq-local boardgame-draw--foreground nil)
            (setq-local boardgame-draw--background nil)
            (setq-local boardgame-draw--recent-glyphs '()))
          (boardgame-board-goto-coord 3 2 board-buf)
          (with-current-buffer board-buf (boardgame-draw-pipette))
          (with-current-buffer board-buf
            (should (eq boardgame-draw--glyph ?#))
            (should (member ?# boardgame-draw--recent-glyphs))))
      (when (buffer-live-p board-buf) (kill-buffer board-buf))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(ert-deftest boardgame-test-recent-symbol-history ()
  "Unit Test 5.2: Recent symbol queue maintains correct order without duplicates."
  (let* ((board (boardgame-board-create-empty "Recent Test" 10 10 ?\.))
         (buf (generate-new-buffer "*boardgame-test-recent*"))
         (board-buf (boardgame-board-setup-buffer board)))
    (unwind-protect
        (progn
          (with-current-buffer board-buf
            (setq-local boardgame-draw--mode t)
            (setq-local boardgame-draw--recent-glyphs '()))
          (with-current-buffer board-buf
            (dolist (char '(?! ?@ ?# ?$ ?%))
              (boardgame-draw-set-glyph char)))
          (with-current-buffer board-buf
            (let ((recent boardgame-draw--recent-glyphs))
              (should (eq (car recent) ?%))
              (should (eq (nth 1 recent) ?$))
              (should (eq (nth 2 recent) ?#))
              (should (eq (nth 3 recent) ?@))
              (should (eq (nth 4 recent) ?!))
              (should (= (length recent) 5)))))
      (when (buffer-live-p board-buf) (kill-buffer board-buf))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(ert-deftest boardgame-test-glyph-extraction-fallback ()
  "Unit Test: Verify glyph extraction from Org headings with fallback rules."
  (should (eq (boardgame-draw-resolve-glyph "Card Dragon" ?*) ?C))
  (should (eq (boardgame-draw-resolve-glyph "" ?*) ?*))
  (should (eq (boardgame-draw-resolve-glyph nil ?*) ?*))
  (should (eq (boardgame-draw-resolve-glyph "*** Magic Spell" ?*) ?*))
  (should (eq (boardgame-draw-resolve-glyph "   Card" ?*) ?C)))

(ert-deftest boardgame-test-fill-region ()
  "Unit Test: Fill region replaces felt cells in a rectangle."
  (let* ((board (boardgame-board-create-empty "Fill Region Test" 20 20 ?\.))
         (buf (generate-new-buffer "*boardgame-test-fill*"))
         (board-buf (boardgame-board-setup-buffer board)))
    (unwind-protect
        (progn
          (with-current-buffer board-buf
            (transient-mark-mode 1)
            (boardgame-draw-toggle)
            (boardgame-draw-set-glyph ?#)
            (let ((start (boardgame-render-coord-to-pos board 3 3))
                  (end (boardgame-render-coord-to-pos board 5 4)))
              (goto-char start)
              (set-mark end)
              (activate-mark)
              (should (use-region-p))
              (boardgame-draw-fill-region)))
          (dotimes (x 3)
            (dotimes (y 2)
              (should (eq (boardgame-board-get-felt board (+ 3 x) (+ 3 y)) ?#))))
          (should (eq (boardgame-board-get-felt board 2 3) ?\.))
          (should (eq (boardgame-board-get-felt board 6 3) ?\.)))
      (when (buffer-live-p board-buf) (kill-buffer board-buf))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(ert-deftest boardgame-test-drawing-mode-stack-integration ()
  "Integration Test: Drawing mode respects object layering."
  (let* ((board (boardgame-board-create-empty "Stack Drawing" 20 20 ?\.))
         (buf (generate-new-buffer "*boardgame-test-stack-draw*"))
         (board-buf (boardgame-board-setup-buffer board)))
    (unwind-protect
        (progn
          (with-current-buffer board-buf
            (let ((obj1 (boardgame-object-create :name "Bottom" :x 5 :y 5 :glyph "B"))
                  (obj2 (boardgame-object-create :name "Middle" :x 5 :y 5 :glyph "M"))
                  (obj3 (boardgame-object-create :name "Top"    :x 5 :y 5 :glyph "T")))
              (boardgame-board-add-object board obj1)
              (boardgame-board-add-object board obj2)
              (boardgame-board-add-object board obj3)
              (should (= (boardgame-board-object-count-at board 5 5) 3)))
            (boardgame-draw-toggle)
            (should boardgame-draw--mode)
            (boardgame-board-goto-coord 5 5 board-buf)
            (boardgame-draw-point-paint)
            (should (= (boardgame-board-object-count-at board 5 5) 3))
            (boardgame-draw-paint-cell 7 7)
            (should (eq (boardgame-board-get-felt board 7 7) ?\s))
            (should (eq (boardgame-board-get-objects board 7 7) nil))
            (boardgame-draw-toggle)
            (should-not boardgame-draw--mode)
            (should (= (boardgame-board-object-count-at board 5 5) 3))))
      (when (buffer-live-p board-buf) (kill-buffer board-buf))
      (when (buffer-live-p buf) (kill-buffer buf)))))

(ert-deftest boardgame-test-text-mode-integration ()
  "Unit Test: Text Overwrite Mode replaces felt without affecting objects."
  (let* ((board (boardgame-board-create-empty "Text Mode Test" 10 10 ?\.))
         (buf (generate-new-buffer "*boardgame-test-text-mode*"))
         (board-buf (boardgame-board-setup-buffer board)))
    (unwind-protect
        (progn
          (with-current-buffer board-buf
            (boardgame-draw-toggle)
            (should boardgame-draw--mode)
            (boardgame-text-mode-toggle)
            (should boardgame-draw--text-mode)
            (boardgame-board-goto-coord 3 2 board-buf)
            (boardgame-draw-set-glyph ?#)
            (boardgame-text-mode--insert-char ?X)
            (should (eq (boardgame-board-get-felt board 3 2) ?X))
            (should (= (point) (boardgame-render-coord-to-pos board 4 2)))))
      (when (buffer-live-p board-buf) (kill-buffer board-buf))
      (when (buffer-live-p buf) (kill-buffer buf)))))

;; -----------------------------------------------------------------------------
;; Stage 6 Tests: Hands, Stacks, and Permanent Containers
;; -----------------------------------------------------------------------------

(ert-deftest boardgame-test-stack-file-consolidation ()
  "Unit Test 6.2: Stack consolidation merges Org documents and deletes standalone files."
  (let* ((tmp-dir (make-temp-file "boardgame-test-stack-" t))
         (obj-dir (expand-file-name "objects" tmp-dir))
         (stack-file (expand-file-name "stacks/test-stack.org" tmp-dir))
         (file1 (expand-file-name "card1.org" obj-dir))
         (file2 (expand-file-name "card2.org" obj-dir))
         (file3 (expand-file-name "card3.org" obj-dir)))
    (unwind-protect
        (progn
          (make-directory obj-dir t)
          ;; Create three standalone object Org files
          (with-temp-file file1
            (insert "* Card Alpha\n:PROPERTIES:\n:GLYPH: A\n:OBJECT_TYPE: card\n:END:\nFirst card description.\n"))
          (with-temp-file file2
            (insert "* Card Beta\n:PROPERTIES:\n:GLYPH: B\n:OBJECT_TYPE: card\n:END:\nSecond card description.\n"))
          (with-temp-file file3
            (insert "* Card Gamma\n:PROPERTIES:\n:GLYPH: G\n:OBJECT_TYPE: card\n:END:\nThird card description.\n"))
          ;; Verify they exist on disk
          (should (file-exists-p file1))
          (should (file-exists-p file2))
          (should (file-exists-p file3))

          ;; Perform stack consolidation
          (boardgame-stack-consolidate-files (list file1 file2 file3) stack-file "Consolidated Test Stack" "test-stack")

          ;; 1. Consolidated stack file must exist
          (should (file-exists-p stack-file))
          ;; 2. Original three files must no longer exist on disk
          (should-not (file-exists-p file1))
          (should-not (file-exists-p file2))
          (should-not (file-exists-p file3))

          ;; 3. Check stack file contents
          (with-temp-buffer
            (insert-file-contents stack-file)
            (goto-char (point-min))
            (should (search-forward "Card Alpha" nil t))
            (goto-char (point-min))
            (should (search-forward "Card Beta" nil t))
            (goto-char (point-min))
            (should (search-forward "Card Gamma" nil t))
            (goto-char (point-min))
            (should (search-forward ":GLYPH: $" nil t))))
      (when (file-exists-p tmp-dir)
        (delete-directory tmp-dir t)))))

(ert-deftest boardgame-test-container-draw-file-preservation ()
  "Integration Test 6.3: Drawing from container preserves standalone object Org files."
  (let* ((tmp-dir (make-temp-file "boardgame-test-container-" t))
         (obj-dir (expand-file-name "objects" tmp-dir))
         (c-dir (expand-file-name "containers" tmp-dir))
         (file1 (expand-file-name "item1.org" obj-dir))
         (file2 (expand-file-name "item2.org" obj-dir))
         (c-file (expand-file-name "deck.org" c-dir))
         (board (boardgame-board-create-empty "Container Test" 20 20 ?\.)))
    (unwind-protect
        (progn
          (make-directory obj-dir t)
          (make-directory c-dir t)
          ;; Create two standalone object Org files
          (with-temp-file file1
            (insert "* Potion of Healing\n:PROPERTIES:\n:GLYPH: H\n:OBJECT_TYPE: potion\n:END:\nHeals 5 HP.\n"))
          (with-temp-file file2
            (insert "* Scroll of Fire\n:PROPERTIES:\n:GLYPH: S\n:OBJECT_TYPE: scroll\n:END:\nCasts fireball.\n"))

          ;; Create container and add the two objects
          (let ((c-rel (boardgame-container-create "deck" "Test Deck" "D" tmp-dir)))
            (setf (boardgame-board-file board) (expand-file-name "board.org" tmp-dir))
            (let ((c-obj (boardgame-object-create
                          :name "Test Deck"
                          :x 5 :y 5
                          :glyph "D"
                          :file c-rel
                          :type "container")))
              (boardgame-board-add-object board c-obj)
              ;; Add objects to container
              (boardgame-container-add-object c-obj file1 tmp-dir)
              (boardgame-container-add-object c-obj file2 tmp-dir)

              ;; Verify both files exist
              (should (file-exists-p file1))
              (should (file-exists-p file2))

              ;; Draw top object onto board at (6, 5)
              (let ((drawn-obj (boardgame-container-draw-to-board c-obj 6 5 :top board tmp-dir)))
                (should drawn-obj)
                (should (string-equal (boardgame-object-name drawn-obj) "Potion of Healing"))
                (should (= (boardgame-object-x drawn-obj) 6))
                (should (= (boardgame-object-y drawn-obj) 5))

                ;; Crucial invariant: BOTH standalone files must remain intact on disk
                (should (file-exists-p file1))
                (should (file-exists-p file2))))))
      (when (file-exists-p tmp-dir)
        (delete-directory tmp-dir t)))))

(ert-deftest boardgame-test-hand-place-and-take ()
  "Integration Test: Verify place-on-board and take operations with hand Org file."
  (let* ((tmp-dir (make-temp-file "boardgame-test-hand-" t))
         (hand-file (expand-file-name "hand.org" tmp-dir))
         (board (boardgame-board-create-empty "Hand Test" 20 20 ?\.))
         (board-buf (boardgame-board-setup-buffer board))
         (boardgame-current-world-directory tmp-dir)
         (boardgame-active-hand-file hand-file))
    (unwind-protect
        (progn
          (setf (boardgame-board-file board) (expand-file-name "board.org" tmp-dir))
          (setq boardgame-current-board-buffer board-buf)
          ;; Initialize hand file with subtrees
          (with-temp-file hand-file
            (insert "* Hand: Player Hand\n:PROPERTIES:\n:HAND_OWNER: Player1\n:END:\n\n** Subtrees\n*** Sword of Light\n:PROPERTIES:\n:GLYPH: S\n:OBJECT_TYPE: weapon\n:END:\nA radiant sword.\n"))

          ;; Open hand file in buffer
          (let ((hand-buf (find-file-noselect hand-file)))
            (unwind-protect
                (with-current-buffer hand-buf
                  (goto-char (point-min))
                  (search-forward "Sword of Light")
                  (org-back-to-heading)
                  ;; Place on board at (3, 3)
                  (boardgame-place-on-board board 3 3))
              (when (buffer-live-p hand-buf)
                (kill-buffer hand-buf))))

          ;; Verify placed object on board
          (let ((objs (boardgame-board-get-objects board 3 3)))
            (should (= (length objs) 1))
            (let* ((placed (car objs))
                   (standalone-file (expand-file-name (boardgame-object-file placed) tmp-dir)))
              (should (string-equal (boardgame-object-name placed) "Sword of Light"))
              (should (string-equal (boardgame-object-glyph placed) "S"))
              ;; Standalone file was created in objects/
              (should (file-exists-p standalone-file))

              ;; Now take it back into hand
              (with-current-buffer board-buf
                (boardgame-board-goto-coord 3 3 board-buf)
                (boardgame-hand-take 3 3))

              ;; Object removed from board
              (should (null (boardgame-board-get-objects board 3 3)))
              ;; Standalone file deleted
              (should-not (file-exists-p standalone-file))

              ;; Transferred back into hand file
              (with-temp-buffer
                (insert-file-contents hand-file)
                (goto-char (point-min))
                (should (search-forward "Sword of Light" nil t))))))
      (when (buffer-live-p board-buf) (kill-buffer board-buf))
      (when (file-exists-p tmp-dir) (delete-directory tmp-dir t)))))

;;; test-boardgame-org.el ends here
