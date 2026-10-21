;;; boardgame-org-core.el --- Core structures and world configuration for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Keywords: games, org, tabletop
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Core configuration, in-memory structures (structs), and Git-based
;; version control helpers according to boardgame-org.md architecture.

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'subr-x)

(defgroup boardgame-org nil
  "Text-based tabletop environment in Emacs with Org-mode persistence."
  :group 'games
  :prefix "boardgame-org-")

(defcustom boardgame-org-world-directory
  (expand-file-name "~/boardgame-world/")
  "Default directory containing the boardgame-org world files."
  :type 'directory
  :group 'boardgame-org)

(defcustom boardgame-org-default-felt-symbol "."
  "Default character used to fill empty felt grid cells."
  :type 'string
  :group 'boardgame-org)

(defcustom boardgame-org-auto-commit t
  "When non-nil, automatically create a Git commit after successful save."
  :type 'boolean
  :group 'boardgame-org)

;;; Core Structures

(cl-defstruct (boardgame-org-object (:constructor boardgame-org-object-create))
  "Represents an independently existing game object."
  id
  name
  glyph
  type            ; 'card, 'die, 'token, 'pawn, 'container, 'stack
  description
  properties      ; alist of (KEY . VALUE)
  file-path       ; relative or absolute path to .org file
  (face-up t)
  color
  value
  sides           ; for dice
  contained-ids   ; for containers (list of object IDs)
  stacked-items)  ; for stacks (list of alists with consolidated object data)

(cl-defstruct (boardgame-org-placed (:constructor boardgame-org-placed-create))
  "Represents an object placed on the board felt."
  object-id
  x
  y
  (layer 0))

(cl-defstruct (boardgame-org-board (:constructor boardgame-org-board-create))
  "In-memory representation of a boardgame-org tabletop."
  id
  name
  (width 16)
  (height 10)
  (default-felt ".")
  felt-grid       ; vector of strings or 2D vector of characters
  placed-objects  ; list of `boardgame-org-placed`
  file-path)

(cl-defstruct (boardgame-org-hand (:constructor boardgame-org-hand-create))
  "In-memory representation of a player hand."
  id
  name
  player
  object-ids      ; list of object IDs in hand
  file-path)

;;; World Directory and Git Recovery Helpers

(defun boardgame-org-world-file (relative-path)
  "Return full path to RELATIVE-PATH within `boardgame-org-world-directory`."
  (expand-file-name relative-path boardgame-org-world-directory))

(defun boardgame-org-ensure-world-dirs ()
  "Ensure standard subdirectories exist in world directory."
  (dolist (dir '("boards" "objects" "stacks" "containers" "hands" "docs"))
    (let ((target (boardgame-org-world-file dir)))
      (unless (file-directory-p target)
        (make-directory target t)))))

(defun boardgame-org-git-commit (message)
  "Create a Git commit in the world directory with MESSAGE if under VC."
  (when (and boardgame-org-auto-commit
             (file-directory-p (boardgame-org-world-file ".git")))
    (let ((default-directory boardgame-org-world-directory))
      (call-process "git" nil nil nil "add" ".")
      (call-process "git" nil nil nil "commit" "-m" message)
      (message "boardgame-org: Committed world state: %s" message))))

(provide 'boardgame-org-core)
;;; boardgame-org-core.el ends here
