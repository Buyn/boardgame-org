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

(cl-defstruct (boardgame-object (:constructor boardgame-object--raw-create))
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

;;;###autoload
(defun boardgame-object-create (&rest args)
  "Create and return a `boardgame-object`.
Supports both keyword arguments:
  (:id ID :name NAME :glyph GLYPH [:type TYPE ...])
and positional arguments:
  (ID NAME GLYPH &optional TYPE FOREGROUND BACKGROUND DESCRIPTION).
When called with positional arguments, creates the corresponding Org file
in objects/ if `boardgame-create-object` is available."
  (if (and args (keywordp (car args)))
      (apply #'boardgame-object--raw-create args)
    (let ((id (nth 0 args))
          (name (nth 1 args))
          (glyph (nth 2 args))
          (type (or (nth 3 args) 'token))
          (fg (nth 4 args))
          (bg (nth 5 args))
          (desc (nth 6 args)))
      (if (and (fboundp 'boardgame-create-object)
               (not (eq (symbol-function 'boardgame-create-object) #'boardgame-object-create)))
          (boardgame-create-object id name glyph type fg bg desc)
        (let* ((rel-path (format "objects/%s.org" id))
               (full-path (boardgame-world-file rel-path)))
          (make-directory (file-name-directory full-path) t)
          (with-temp-file full-path
            (insert ":PROPERTIES:\n")
            (insert (format ":ID: %s\n" id))
            (insert (format ":NAME: %s\n" name))
            (insert (format ":GLYPH: %s\n" glyph))
            (insert (format ":TYPE: %s\n" type))
            (when fg (insert (format ":FOREGROUND: %s\n" fg)))
            (when bg (insert (format ":BACKGROUND: %s\n" bg)))
            (insert ":END:\n\n")
            (insert (format "* %s\n" name))
            (when desc (insert desc "\n")))
          (boardgame-object--raw-create
           :id id :name name :glyph glyph :type type
           :foreground fg :background bg :description desc
           :file-path rel-path))))))

;;;###autoload
(defalias 'boardgame-create-object #'boardgame-object-create)


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

;;;###autoload
(defun boardgame-ensure-world-dirs ()
  "Ensure standard subdirectories exist in the active world directory."
  (dolist (dir '("boards" "objects" "stacks" "containers" "hands" "docs"))
    (let ((target (boardgame-world-file dir)))
      (unless (file-directory-p target)
        (make-directory target t)))))

;;;###autoload
(defun boardgame-container-create (id name &optional glyph)
  "Create or wrap permanent container at containers/ID.org."
  (if (fboundp 'boardgame-create-container)
      (boardgame-create-container id name glyph)
    (let* ((rel-path (format "containers/%s.org" id))
           (full-path (boardgame-world-file rel-path))
           (gly (or glyph "⊔")))
      (make-directory (file-name-directory full-path) t)
      (with-temp-file full-path
        (insert (format "#+TITLE: Container: %s\n" name))
        (insert ":PROPERTIES:\n")
        (insert (format ":ID: %s\n" id))
        (insert (format ":NAME: %s\n" name))
        (insert ":TYPE: container\n")
        (insert (format ":GLYPH: %s\n" gly))
        (insert ":END:\n\n")
        (insert "* Contents\n"))
      (boardgame-object-create
       :id id
       :name name
       :glyph gly
       :type 'container
       :file-path rel-path
       :contained-ids nil))))


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
