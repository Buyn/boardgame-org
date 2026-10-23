;;; boardgame-org-core.el --- Core variables, structs, and tracking for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Core configuration, structs, and global variables adhering to
;; boardgame-org.md and boardgame-org-interface.md.
;; Configured with standard MELPA/ELPA metadata and defaults to
;; the project-local ./world/ directory.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'subr-x)

(defgroup boardgame nil
  "Text-based tabletop environment in Emacs with Org-mode persistence."
  :group 'games
  :prefix "boardgame-")

;;; User Customizations

(defcustom boardgame-default-world-directory
  (expand-file-name "world" default-directory)
  "Default directory containing the active boardgame world.
Defaults to the project-local ./world/ directory."
  :type 'directory
  :group 'boardgame)

(defcustom boardgame-default-felt-symbol "."
  "Default character used to pad empty felt grid cells."
  :type 'string
  :group 'boardgame)

(defcustom boardgame-board-window-width-percent 80
  "Percentage of frame width allocated to the board window."
  :type 'integer
  :group 'boardgame)

(defcustom boardgame-log-window-height-percent 80
  "Percentage of the right side column height allocated to the log window."
  :type 'integer
  :group 'boardgame)

(defcustom boardgame-auto-commit t
  "When non-nil, automatically create a Git commit after a successful save."
  :type 'boolean
  :group 'boardgame)

;;; Global State Variables

(defvar boardgame-active-world-directory nil
  "Path to the currently active world directory.")

(defvar boardgame-current-board-buffer nil
  "Globally accessible variable identifying the active board buffer.
Required by Section 4.6 of boardgame-org-interface.md to resolve implicit
board command targets.")

(defvar boardgame-active-hand-file "hands/player1.org"
  "Relative or absolute file path to the currently active hand Org file.")

;;; Core Structs

(cl-defstruct (boardgame-object (:constructor boardgame-object-create))
  "Represents an independently existing game object."
  id
  name
  glyph
  type            ; 'token, 'card, 'die, 'marker, 'container, 'stack
  description
  foreground
  background
  properties      ; alist of (KEY . VALUE)
  file-path       ; relative path to .org file
  (face-up t)
  value
  sides           ; for dice
  contained-ids   ; for containers (list of object IDs)
  stacked-items)  ; for stacks (list of alists with consolidated object data)

(cl-defstruct (boardgame-placed (:constructor boardgame-placed-create))
  "Represents an object placed on the board felt."
  object-id
  x
  y
  (layer 0))

(cl-defstruct (boardgame-board (:constructor boardgame-board-create))
  "In-memory representation of a boardgame tabletop."
  id
  name
  filename        ; filename including extension (e.g. 'main.org')
  (width 16)
  (height 10)
  (default-felt ".")
  felt-grid       ; 2D vector of characters
  felt-fg-grid    ; 2D vector of foreground colors (optional)
  felt-bg-grid    ; 2D vector of background colors (optional)
  placed-objects  ; list of `boardgame-placed`
  file-path       ; full or relative path
  dirty-p)        ; non-nil if unsaved changes exist

(cl-defstruct (boardgame-hand (:constructor boardgame-hand-create))
  "In-memory representation of a player hand."
  id
  name
  player
  object-ids
  file-path)

;;; World Directory & File Helpers

(defun boardgame-world-name ()
  "Return clean world name derived from `boardgame-active-world-directory`."
  (if boardgame-active-world-directory
      (file-name-nondirectory (directory-file-name boardgame-active-world-directory))
    "world"))

(defun boardgame-world-file (relative-path)
  "Return full path to RELATIVE-PATH within `boardgame-active-world-directory`."
  (unless boardgame-active-world-directory
    (setq boardgame-active-world-directory (expand-file-name (or boardgame-default-world-directory "world"))))
  (expand-file-name relative-path boardgame-active-world-directory))

(defun boardgame-ensure-world-dirs ()
  "Ensure standard subdirectories exist in the active world directory."
  (dolist (dir '("boards" "objects" "stacks" "containers" "hands" "docs"))
    (let ((target (boardgame-world-file dir)))
      (unless (file-directory-p target)
        (make-directory target t)))))

(defun boardgame-git-commit (message)
  "Create a Git commit in the active world directory with MESSAGE if under VC."
  (when (and boardgame-auto-commit
             boardgame-active-world-directory
             (file-directory-p (boardgame-world-file ".git")))
    (let ((default-directory boardgame-active-world-directory))
      (call-process "git" nil nil nil "add" ".")
      (call-process "git" nil nil nil "commit" "-m" message)
      (message "boardgame-org: Committed world state: %s" message))))

(provide 'boardgame-org-core)
;;; boardgame-org-core.el ends here
