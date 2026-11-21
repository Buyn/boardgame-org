;;; boardgame.el --- Text-based tabletop game engine for Emacs -*- lexical-binding: t; -*-

;; Author: boardgame.org contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: games, org
;; URL: https://github.com/buyn/boardgame-org

;;; Commentary:
;; `boardgame.org' is a text-based tabletop game engine for Emacs using Org-mode
;; documents for human-readable state persistence, object identity, and session logging.
;;
;; Module Loading & Public Feature Invariant:
;; In compliance with `boardgame-org.md' §7 and `boardgame-implementation-plan.md' §1.2:
;; - Individual internal module files (e.g. `boardgame-mode.el', `boardgame-window.el')
;;   do NOT execute independent `provide' calls.
;; - This root file `boardgame.el' acts as the master entry point, loading all internal
;;   modules sequentially.
;; - `boardgame.el' is the SOLE file in the package that executes `(provide 'boardgame)'.

;;; Code:

;; -----------------------------------------------------------------------------
;; Customization Group and Global Options
;; -----------------------------------------------------------------------------

(defgroup boardgame nil
  "Text-based tabletop game engine for Emacs using Org-mode."
  :prefix "boardgame-"
  :group 'games)

(defcustom boardgame-default-world-directory nil
  "Default directory for game worlds.
When nil, the user is prompted to select or create a world upon startup."
  :type '(choice (const :tag "None" nil) directory)
  :group 'boardgame)

(defcustom boardgame-board-width-ratio 0.8
  "Fraction of horizontal frame width allocated to the board window (default 80%)."
  :type 'float
  :group 'boardgame)

(defcustom boardgame-log-height-ratio 0.8
  "Fraction of side-area vertical height allocated to the log window (default 80%)."
  :type 'float
  :group 'boardgame)

(defcustom boardgame-status-area-enabled t
  "Whether to allocate a status window below the side-log window."
  :type 'boolean
  :group 'boardgame)

;; -----------------------------------------------------------------------------
;; Global State Variables
;; -----------------------------------------------------------------------------

(defvar boardgame-current-board-buffer nil
  "Buffer of the active game board targeted by implicit commands.")

(defvar boardgame-current-world-directory nil
  "Directory path of the currently active world.")

;; -----------------------------------------------------------------------------
;; Internal Module Loading Protocol
;; -----------------------------------------------------------------------------

(eval-and-compile
  (defvar boardgame--directory
    (file-name-directory (or (and (boundp 'load-file-name) load-file-name)
                             (and (boundp 'buffer-file-name) buffer-file-name)
                             (and (boundp 'byte-compile-current-file) byte-compile-current-file)
                             default-directory))
    "Internal directory path of the boardgame package."))

(defun boardgame--load-module (module-name)
  "Load internal MODULE-NAME from package directory without feature registration."
  (let ((file (expand-file-name module-name boardgame--directory)))
    (load file nil t)))

;; Internal module loading for Stages 1, 2, 3, 4, 5 & 6
(boardgame--load-module "boardgame-mode")
(boardgame--load-module "boardgame-window")
(boardgame--load-module "boardgame-data")
(boardgame--load-module "boardgame-serialize")
(boardgame--load-module "boardgame-world")
(boardgame--load-module "boardgame-log")
(boardgame--load-module "boardgame-status")
(boardgame--load-module "boardgame-object")
(boardgame--load-module "boardgame-render")
(boardgame--load-module "boardgame-board")
(boardgame--load-module "boardgame-draw")
(boardgame--load-module "boardgame-stack")
(boardgame--load-module "boardgame-container")
(boardgame--load-module "boardgame-hand")

(declare-function boardgame-window-initialize "boardgame-window" (&optional world-directory))
(declare-function boardgame-world-resolve-and-activate "boardgame-world" (&optional world-dir))
(declare-function boardgame-log-get-buffer "boardgame-log" (world-dir))
(declare-function boardgame-draw-toggle "boardgame-draw")
(declare-function boardgame-draw-point-paint "boardgame-draw")
(declare-function boardgame-draw-fill-region "boardgame-draw")
(declare-function boardgame-draw-pipette "boardgame-draw")
(declare-function boardgame-draw-set-glyph "boardgame-draw")

;; -----------------------------------------------------------------------------
;; Primary Interactive Entry Point
;; -----------------------------------------------------------------------------

;;;###autoload
(defun boardgame-start (&optional world-directory)
  "Start the boardgame.org engine in a dedicated frame.
If WORLD-DIRECTORY is specified, activate that world directory.
Otherwise use `boardgame-default-world-directory' or prompt.
Spawns a dedicated frame, preserving existing user frames."
  (interactive)
  (let ((dir (boardgame-world-resolve-and-activate world-directory)))
    (boardgame-window-initialize dir)))

;; -----------------------------------------------------------------------------
;; Sole Public Feature Provision
;; -----------------------------------------------------------------------------

(provide 'boardgame)

;;; boardgame.el ends here
