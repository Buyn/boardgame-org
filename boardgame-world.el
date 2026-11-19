;;; boardgame-world.el --- World directory management and session state -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; World directory resolution, initialization, active-board tracking,
;; and world-switching routines for boardgame.org.
;;
;; Implements §3 and §4.6 of boardgame-org-interface.md:
;;  - Resolving world directories and log file paths.
;;  - Maintaining `boardgame-current-board-buffer' with strict precedence.
;;  - Switching worlds safely (unsaved-change handling stub).
;;
;; Architectural Invariant:
;; In accordance with `boardgame-org.md' §7 and
;; `boardgame-implementation-plan.md' §1.2, internal module files do NOT
;; call `provide'. Only `boardgame.el' provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; Forward declarations for variables defined in boardgame.el
(defvar boardgame-default-world-directory)
(defvar boardgame-current-board-buffer)
(defvar boardgame-current-world-directory)

;; Forward declarations for functions in other modules
(declare-function boardgame-log-get-buffer "boardgame-log" (world-dir))

;; -----------------------------------------------------------------------------
;; World Directory Utilities
;; -----------------------------------------------------------------------------

(defun boardgame-world-name (world-dir)
  "Return the base name of WORLD-DIR (last path component)."
  (file-name-nondirectory (directory-file-name world-dir)))

(defun boardgame-world-log-filename (world-dir)
  "Return the log file path for WORLD-DIR.
Follows the convention: WORLD-DIR/<world-name>-log.org."
  (let ((name (boardgame-world-name world-dir)))
    (expand-file-name (concat name "-log.org") world-dir)))

(defun boardgame-world-valid-p (world-dir)
  "Return non-nil when WORLD-DIR is a valid, existing world directory."
  (and (stringp world-dir)
       (file-directory-p world-dir)))

(defun boardgame-world-subdirectories ()
  "Return the list of standard sub-directory names for a new world."
  '("boards" "objects" "hands" "containers"))

;; -----------------------------------------------------------------------------
;; World Initialization
;; -----------------------------------------------------------------------------

(defun boardgame-world-create-structure (world-dir)
  "Create standard sub-directory structure inside WORLD-DIR.
Creates boards/, objects/, hands/, containers/ when missing."
  (dolist (sub (boardgame-world-subdirectories))
    (let ((path (expand-file-name sub world-dir)))
      (unless (file-directory-p path)
        (make-directory path t)))))

(defun boardgame-world-initialize (world-dir)
  "Initialize WORLD-DIR as a new world if not already set up.
Creates required sub-directories.  Does not overwrite existing contents."
  (make-directory world-dir t)
  (boardgame-world-create-structure world-dir))

;; -----------------------------------------------------------------------------
;; Active Board Tracking
;; -----------------------------------------------------------------------------

(defun boardgame-world-resolve-board (explicit-buffer)
  "Resolve the active board buffer from EXPLICIT-BUFFER or globals.
Resolution precedence (highest to lowest):
  1. EXPLICIT-BUFFER when non-nil and live.
  2. Frame-associated board buffer for the selected frame.
  3. `boardgame-current-board-buffer' global variable.
Returns the resolved buffer or nil."
  (cond
   ((and explicit-buffer (buffer-live-p explicit-buffer))
    explicit-buffer)
   ((let ((frame-buf (frame-parameter (selected-frame)
                                      'boardgame-active-board-buffer)))
      (and frame-buf (buffer-live-p frame-buf)))
    (frame-parameter (selected-frame) 'boardgame-active-board-buffer))
   ((and boardgame-current-board-buffer
         (buffer-live-p boardgame-current-board-buffer))
    boardgame-current-board-buffer)
   (t nil)))

(defun boardgame-world-set-active-board (buffer &optional frame)
  "Set BUFFER as the active board for FRAME and globally.
FRAME defaults to the selected frame.
Updates both the frame parameter and `boardgame-current-board-buffer'."
  (let ((target-frame (or frame (selected-frame))))
    (set-frame-parameter target-frame 'boardgame-active-board-buffer buffer)
    (setq boardgame-current-board-buffer buffer)))

;; -----------------------------------------------------------------------------
;; World Resolution and Activation
;; -----------------------------------------------------------------------------

(defun boardgame-world-prompt-directory ()
  "Prompt the user to select or enter a world directory path.
Returns the selected directory path string."
  (read-directory-name "World directory: " boardgame-default-world-directory
                        nil nil))

(defun boardgame-world-activate (world-dir)
  "Activate WORLD-DIR as the current world.
Sets `boardgame-current-world-directory'.  Initializes structure if new."
  (unless (boardgame-world-valid-p world-dir)
    (boardgame-world-initialize world-dir))
  (setq boardgame-current-world-directory world-dir))

(defun boardgame-world-resolve-and-activate (&optional world-dir)
  "Determine and activate a world directory.
Resolution order:
  1. WORLD-DIR argument when provided and valid.
  2. `boardgame-default-world-directory' when valid.
  3. Interactive prompt (skipped in batch/noninteractive mode).
Returns the activated world directory path, or nil in batch mode."
  (let ((dir (or (and world-dir (boardgame-world-valid-p world-dir) world-dir)
                 (and (boundp 'boardgame-default-world-directory)
                      boardgame-default-world-directory
                      (boardgame-world-valid-p
                       boardgame-default-world-directory)
                      boardgame-default-world-directory)
                 (unless noninteractive
                   (boardgame-world-prompt-directory)))))
    (when dir
      (boardgame-world-activate dir))
    dir))

;; -----------------------------------------------------------------------------
;; World Switching
;; -----------------------------------------------------------------------------

(defun boardgame-world-unsaved-boards ()
  "Return list of live board buffers with unsaved changes in current world."
  (let ((result nil))
    (dolist (buf (buffer-list))
      (when (and (buffer-live-p buf)
                 (buffer-modified-p buf)
                 (buffer-local-value 'boardgame-current-world-directory buf))
        (push buf result)))
    result))

(defun boardgame-world-switch (new-world-dir)
  "Switch the active world to NEW-WORLD-DIR.
Checks for unsaved board buffers and prompts before switching.
Returns non-nil on success, nil when user aborted."
  (let ((unsaved (boardgame-world-unsaved-boards)))
    (when (or (null unsaved)
              (yes-or-no-p
               (format "%d unsaved board(s). Switch world anyway? "
                       (length unsaved))))
      (boardgame-world-activate new-world-dir)
      t)))

;;; boardgame-world.el ends here
