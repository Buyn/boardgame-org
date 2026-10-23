;;; boardgame-org.el --- Tabletop game engine for Emacs  -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Free Software Foundation, Inc.

;; Author: Boardgame Org Contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org "9.6"))
;; Keywords: games, extensions, org-mode
;; URL: https://github.com/boardgame-org/boardgame-org

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; boardgame-org is an Emacs Lisp tabletop game engine inspired by ZZT and
;; character-based board games. It uses Org-mode documents for persistent
;; representation of game objects and board state.

;; Core concepts:
;; - World: a directory containing boards, objects, hands, containers
;; - Board: a rectangular character-based game space with felt and objects
;; - Object: a game entity represented by an independent Org document
;; - Hand: an ordered collection of cards/objects represented by an Org file
;; - Container: a persistent object that organizes references to other objects
;; - Stack: an explicitly created consolidation of objects into one Org document

;;; Code:


;;; User Options

(defgroup boardgame-org nil
  "Tabletop game engine for Emacs."
  :group 'games
  :prefix "boardgame-")

(defcustom boardgame-default-world-directory nil
  "Default directory for the active world.
When set to a valid existing world directory, `boardgame-start' will
use it automatically when called without arguments.
When set to a non-existent directory, `boardgame-start' will offer
to create a new world there.
When nil, `boardgame-start' will prompt for world selection."
  :type '(choice (directory :tag "World directory")
                 (const :tag "No default (prompt)" nil))
  :group 'boardgame-org)

(defcustom boardgame-frame-width-ratio 0.8
  "Proportion of frame width to allocate to the board window.
The remaining proportion goes to the log/status area."
  :type 'number
  :group 'boardgame-org)

(defcustom boardgame-log-height-ratio 0.8
  "Proportion of the log/status column to allocate to the log window."
  :type 'number
  :group 'boardgame-org)

(defcustom boardgame-auto-commit-to-git t
  "If non-nil, automatically commit world changes to version control."
  :type 'boolean
  :group 'boardgame-org)


;;; Internal Variables

(defvar boardgame-current-world-directory nil
  "Current active world directory, or nil if no world is active.")

(defvar boardgame-current-board-buffer nil
  "The currently active board buffer.
This is the target for implicit board commands when no explicit
board argument is provided.")

(defvar boardgame-current-hand-file nil
  "The currently active hand Org file, or nil if no hand is active.")

(defvar boardgame-game-frame nil
  "The dedicated game frame, or nil if no game is running.")

(defvar boardgame-side-log-buffer nil
  "The shared world-level log buffer for the active world.")

(defvar boardgame-drawing-mode nil
  "Non-nil if drawing mode is currently enabled.")


;;; Utility Functions

(defun boardgame--world-p (directory)
  "Check if DIRECTORY is a valid boardgame world directory."
  (and (directory-name-p directory)
       (file-directory-p directory)
       (file-readable-p directory)))

(defun boardgame--normalize-path (path)
  "Return the canonicalized absolute name of PATH."
  (expand-file-name (file-truename path)))

(defun boardgame--ensure-dir (directory)
  "Ensure DIRECTORY exists, creating it if necessary."
  (unless (file-directory-p directory)
    (make-directory directory t))
  directory)

(defun boardgame--world-name (directory)
  "Extract the world name from DIRECTORY."
  (file-name-nondirectory (directory-file-name directory)))

(defun boardgame--log-filename (world-name)
  "Return the log filename for WORLD-NAME."
  (concat world-name "-log.org"))

(defun boardgame--sanitize-filename (name)
  "Convert NAME to a filesystem-safe filename."
  (replace-regexp-in-string "[^a-zA-Z0-9_-]" "_" name))

(defun boardgame--safe-read (file)
  "Read FILE safely, returning nil on error."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents file)
      (buffer-string))))

(defun boardgame--time-stamp ()
  "Return a formatted timestamp string."
  (format-time-string "%Y-%m-%d %H:%M:%S"))


;;; Logging Interface

(defun boardgame-log-entry (title &rest content)
  "Create a new top-level log entry with TITLE and CONTENT.

CONTENT is a list of (heading-level . text) pairs, where heading-level
is 2, 3, etc. for nested subsections."
  (when (buffer-live-p boardgame-side-log-buffer)
    (with-current-buffer boardgame-side-log-buffer
      (save-excursion
        (goto-char (point-max))
        (unless (bolp) (insert "\n"))
        (insert "* " title "\n")
        (dolist (pair content)
          (let ((level (car pair))
                (text (cdr pair)))
            (insert (make-string level ?*) " " text "\n")))))))

(defun boardgame-log-append (title &rest content)
  "Append subsections to an existing log entry with TITLE.

If no entry with TITLE exists, create a new one."
  (when (buffer-live-p boardgame-side-log-buffer)
    (with-current-buffer boardgame-side-log-buffer
      (let ((pos (boardgame--find-log-entry title)))
        (goto-char (or pos (point-max)))
        (when (not pos)
          (insert "* " title "\n"))
        (dolist (pair content)
          (let ((level (car pair))
                (text (cdr pair)))
            (insert (make-string level ?*) " " text "\n")))))))

(defun boardgame--find-log-entry (title)
  "Find the start of a log entry with TITLE, or nil if not found."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (format "^\\*+ %s$" (regexp-quote title)) nil t)
      (match-beginning 0))))

(defun boardgame-log-message (format-string &rest args)
  "Log a simple message using FORMAT-STRING and ARGS."
  (apply #'boardgame-log-entry (apply #'format format-string args)))


;;; Initialization

(defun boardgame-init-world (directory)
  "Initialize BOARDGAME in DIRECTORY.
Creates the world directory structure and opens the game frame."
  (setq directory (boardgame--normalize-path directory))
  (boardgame--ensure-dir directory)
  
  ;; Initialize world state
  (setq boardgame-current-world-directory directory)
  
  ;; Create world directories if needed
  (dolist (subdir '("boards" "objects" "hands" "containers"))
    (boardgame--ensure-dir (expand-file-name subdir directory)))
  
  ;; Open or create log file
  (let* ((world-name (boardgame--world-name directory))
         (log-file (expand-file-name (boardgame--log-filename world-name) directory))
         (buffer (get-buffer-create boardgame-side-log-buffer)))
    (with-current-buffer buffer
      (unless (file-exists-p log-file)
        (insert (format "* World Log for %s\n\n" world-name))
        (write-region (point-min) (point-max) log-file)))
    (setq boardgame-side-log-buffer buffer))
  
  ;; Open game frame
  (boardgame-open-frame)
  
  ;; Open default board if any
  (boardgame--maybe-open-default-board)
  
  (boardgame-log-entry "World Initialized"
                       '(2 . (format "Directory: %s" directory))
                       '(2 . (format "World Name: %s" world-name)))
  
  (message "Boardgame world initialized: %s" directory))

(defun boardgame-open-frame ()
  "Open a dedicated game frame with board and log windows."
  (let ((frame (make-frame))
        (board-buffer (get-buffer-create "*Boardgame Board*"))
        (log-buffer (get-buffer-create "*Boardgame Log*")))
    
    (setq boardgame-game-frame frame)
    
    (with-selected-frame frame
      ;; Configure frame
      (modify-frame-parameters frame
                               '((name . "Boardgame")
                                 (width . 120)
                                 (height . 40)))
      
      ;; Create window layout
      (let* ((log-width (floor (* (frame-width) (- 1 boardgame-frame-width-ratio)))))
        
        ;; Split vertically for board and log/status
        (split-window-right)
        (set-window-buffer (next-window) board-buffer)
        (set-window-buffer (selected-window) log-buffer)
        
        ;; Set window sizes
        (set-window-text-width (selected-window) log-width)
        
        (select-window (get-lru-window))
        (set-window-buffer (selected-window) board-buffer)
        
        (select-window (get-lru-window)))))
  
  (message "Boardgame frame opened"))

(defun boardgame--maybe-open-default-board ()
  "Open the first available board as default, if any."
  (when boardgame-current-world-directory
    (let* ((boards-dir (expand-file-name "boards" boardgame-current-world-directory))
           (boards (directory-files boards-dir t "\\.org$")))
      (when boards
        (boardgame-open-board (car boards))))))

(defun boardgame-close-frame ()
  "Close the game frame and clean up state."
  (when boardgame-game-frame
    (delete-frame boardgame-game-frame)
    (setq boardgame-game-frame nil))
  (setq boardgame-current-world-directory nil
        boardgame-current-board-buffer nil
        boardgame-drawing-mode nil)
  (message "Boardgame frame closed"))


;;; World Management

(defun boardgame-start (&optional world-directory)
  "Start boardgame-org with WORLD-DIRECTORY.
When WORLD-DIRECTORY is nil, use `boardgame-default-world-directory'.
If that is also nil or invalid, prompt the user for world selection."
  (interactive)
  (let ((directory (or world-directory
                       (and boardgame-default-world-directory
                            (file-directory-p boardgame-default-world-directory)
                            boardgame-default-world-directory))))
    
    (cond
     ;; Explicit directory provided
     ((and world-directory (not (file-directory-p world-directory)))
      (if (y-or-n-p (format "Directory %s does not exist. Create it?" world-directory))
          (boardgame-init-world world-directory)
        (user-error "World directory not found: %s" world-directory)))
      
     ((and world-directory (not (boardgame--world-p world-directory)))
      (user-error "Invalid world directory: %s" world-directory))
      
     ;; Use default directory
     (directory
      (boardgame-init-world directory))
      
     ;; Prompt for world selection
     (t
      (let* ((default-dir (or default-directory (getenv "HOME")))
             (dir (read-directory-name "Select or create world directory: "
                                       default-dir default-dir t)))
        (boardgame-init-world dir))))))

(defun boardgame-switch-world (directory)
  "Switch to a different world DIRECTORY."
  (interactive
   (list (read-directory-name "Switch to world directory: "
                              boardgame-current-world-directory
                              boardgame-current-world-directory t)))
  (when boardgame-current-board-buffer
    (boardgame-save-board boardgame-current-board-buffer))
  (boardgame-close-frame)
  (boardgame-start directory))


;;; Board Management

(defun boardgame-create-board (name &optional width height)
  "Create a new board with NAME, WIDTH and HEIGHT.
Default dimensions are 80x24."
  (interactive
   (let ((name (read-string "Board name: ")))
     (list name
           (string-to-number (read-string "Width (default 80): " "" nil 80))
           (string-to-number (read-string "Height (default 24): " "" nil 24)))))
  (let* ((world-dir boardgame-current-world-directory)
         (boards-dir (expand-file-name "boards" world-dir))
         (file (expand-file-name (concat name ".org") boards-dir))
         (w (or width 80))
         (h (or height 24)))
    
    (when (file-exists-p file)
      (user-error "Board file already exists: %s" file))
    
    (let* ((felt (make-string (* w h) ?\.))
           (org-content (boardgame--board-template name w h felt)))
      (with-temp-file file
        (insert org-content))
      
      (let ((buffer (find-file-noselect file)))
        (boardgame--setup-board-buffer buffer name)
        (setq boardgame-current-board-buffer buffer)
        (boardgame-render-board buffer)
        (boardgame-log-entry "Board Created"
                             '(2 . (format "Name: %s" name))
                             '(2 . (format "Dimensions: %dx%d" w h)))
        (message "Board created: %s" file)))))

(defun boardgame--board-template (name width height felt)
  "Return the Org template for a board with NAME, WIDTH, HEIGHT, and FELT."
  (format "# -*- org -*-\n* Board: %s\n:PROPERTIES:\n:WIDTH: %d\n:HEIGHT: %d\n:END:\n\n** Felt\n:PROPERTIES:\n:CUSTOM_ID: felt\n:END:\n\n#+BEGIN_FELT\n%s\n#+END_FELT\n\n** Objects\n:PROPERTIES:\n:CUSTOM_ID: objects\n:END:\n\n" name width height felt))

(defun boardgame-open-board (file)
  "Open an existing board from FILE."
  (interactive
   (list (expand-file-name
          (read-file-name "Open board: "
                          (expand-file-name "boards" boardgame-current-world-directory)
                          nil t nil
                          (lambda (f) (string-suffix-p ".org" f))))))
  (let ((buffer (find-file-noselect file)))
    (boardgame--setup-board-buffer buffer (file-name-base (file-name-nondirectory file)))
    (setq boardgame-current-board-buffer buffer)
    (boardgame-render-board buffer)
    (message "Board opened: %s" file)))

(defun boardgame--setup-board-buffer (buffer name)
  "Setup BUFFER as a board buffer with NAME."
  (with-current-buffer buffer
    (boardgame-org-mode)
    (setq-local buffer-file-name (buffer-file-name buffer))
    (boardgame-log-entry "Board Opened" '(2 . (format "File: %s" (buffer-file-name buffer))))
    buffer))

(defun boardgame-save-board (&optional board-buffer)
  "Save BOARD-BUFFER to its file."
  (let ((buf (or board-buffer boardgame-current-board-buffer)))
    (when buf
      (with-current-buffer buf
        (write-file (buffer-file-name buf))
        (boardgame-log-entry "Board Saved" '(2 . (format "File: %s" (buffer-file-name buf))))
        (message "Board saved: %s" (buffer-file-name buf))))))

(defun boardgame-close-board (&optional board-buffer)
  "Close BOARD-BUFFER after handling unsaved changes."
  (let ((buf (or board-buffer boardgame-current-board-buffer)))
    (when buf
      (when (buffer-modified-p buf)
        (unless (y-or-n-p (format "Buffer %s has unsaved changes. Close anyway?" buf))
          (user-error "Board close aborted")))
      (kill-buffer buf)
      (when (eq buf boardgame-current-board-buffer)
        (setq boardgame-current-board-buffer nil))
      (message "Board closed: %s" (buffer-name buf)))))

(defun boardgame-refresh-board (&optional board-buffer)
  "Refresh the display of BOARD-BUFFER from its current state."
  (let ((buf (or board-buffer boardgame-current-board-buffer)))
    (when buf
      (boardgame-render-board buf)
      (message "Board refreshed"))))

(defun boardgame-render-board (&optional board-buffer)
  "Render the contents of BOARD-BUFFER to its buffer."
  (let ((buf (or board-buffer boardgame-current-board-buffer)))
    (when buf
      (with-current-buffer buf
        (let* ((width (or (boardgame--get-property "WIDTH") 80))
               (height (or (boardgame--get-property "HEIGHT") 24))
               (felt (boardgame--get-felt-content width height)))
          (erase-buffer)
          (insert (boardgame--format-board width height felt))
          (goto-char (point-min)))))))

(defun boardgame--get-property (prop)
  "Get the value of property PROP from the current buffer."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (format ":PROPERTIES:\n.*:%s: \\(.*?\\)\n.*:END:" (regexp-quote prop)) nil t)
      (match-string 1))))

(defun boardgame--get-felt-content (width height)
  "Extract the felt content from the current board, padding to WIDTH x HEIGHT."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "#\\+BEGIN_FELT" nil t)
      (let ((start (point)))
        (when (re-search-forward "#\\+END_FELT" nil t)
          (let ((content (buffer-substring start (line-beginning-position))))
            ;; Pad to dimensions
            (boardgame--pad-felt content width height)))))))

(defun boardgame--pad-felt (felt width height)
  "Pad FELT string to WIDTH x HEIGHT."
  (let* ((current-len (length felt))
         (expected (* width height))
         (padding (max 0 (- expected current-len))))
    (concat felt (make-string padding ?\.))))

(defun boardgame--format-board (width height felt)
  "Format FELT string as a board with WIDTH x HEIGHT."
  (with-temp-buffer
    (insert felt)
    (goto-char (point-min))
    (let ((lines '()))
      (dotimes (_ height)
        (push (buffer-substring (point) (min (point) (+ (point) width))) lines)
        (forward-char width))
      (string-join (nreverse lines) "\n"))))


;;; Drawing Mode

(defvar boardgame-drawing-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'boardgame-drawing-commit)
    (define-key map (kbd "C-c C-k") #'boardgame-drawing-cancel)
    (define-key map (kbd "C-c C-p") #'boardgame-drawing-pipette)
    map)
  "Keymap for boardgame drawing mode.")

(define-minor-mode boardgame-drawing-mode
  "Drawing mode for editing the board's felt layer."
  :lighter " Draw"
  :keymap boardgame-drawing-mode-map
  (if boardgame-drawing-mode
      (progn
        (setq boardgame-drawing-mode t)
        (boardgame-render-board boardgame-current-board-buffer)
        (message "Drawing mode enabled"))
    (setq boardgame-drawing-mode nil)
    (boardgame-render-board boardgame-current-board-buffer)
    (message "Drawing mode disabled")))

(defun boardgame-drawing-pipette ()
  "Sample the character and colors at point."
  (interactive)
  (when boardgame-drawing-mode
    (message "Pipette: sample implementation needed")))

(defun boardgame-drawing-commit ()
  "Commit drawing changes."
  (interactive)
  (boardgame-drawing-mode 0)
  (boardgame-save-board))

(defun boardgame-drawing-cancel ()
  "Cancel drawing changes."
  (interactive)
  (boardgame-drawing-mode 0)
  (boardgame-render-board))


;;; Object Management

(defun boardgame-create-object (name)
  "Create a new object with NAME."
  (interactive "sObject name: ")
  (let* ((world-dir boardgame-current-world-directory)
         (objects-dir (expand-file-name "objects" world-dir))
         (file (expand-file-name (concat (boardgame--sanitize-filename name) ".org") objects-dir)))
    
    (when (file-exists-p file)
      (user-error "Object file already exists: %s" file))
    
    (let* ((org-content (boardgame--object-template name)))
      (with-temp-file file
        (insert org-content))
      (boardgame-log-entry "Object Created"
                           '(2 . (format "Name: %s" name))
                           '(2 . (format "File: %s" file)))
      (message "Object created: %s" file))))

(defun boardgame--object-template (name)
  "Return the Org template for an object with NAME."
  (format "# -*- org -*-\n* %s\n:PROPERTIES:\n:OBJECT_TYPE: unspecified\n:GLYPH: %s\n:FOREGROUND: white\n:BACKGROUND: unspecified\n:END:\n\n** Description\n\n\n** Source Blocks\n\n" name (string-to-char name)))

(defun boardgame-add-object (object-file x y)
  "Add OBJECT-FILE to the board at coordinates X, Y."
  (interactive
   (list (expand-file-name
          (read-file-name "Select object: "
                          (expand-file-name "objects" boardgame-current-world-directory)
                          nil t nil
                          (lambda (f) (string-suffix-p ".org" f))))
         (read-number "X coordinate: " 0)
         (read-number "Y coordinate: " 0)))
  (when boardgame-current-board-buffer
    (with-current-buffer boardgame-current-board-buffer
      ;; TODO: Add object reference to board Org structure
      (boardgame-log-entry "Object Added"
                           '(2 . (format "Object: %s" (file-name-nondirectory object-file)))
                           '(2 . (format "Position: (%d, %d)" x y)))
      (boardgame-render-board)
      (message "Object added to board"))))

(defun boardgame-delete-object (x y)
  "Delete the object at coordinates X, Y."
  (interactive
   (list (read-number "X coordinate: " 0)
         (read-number "Y coordinate: " 0)))
  (when boardgame-current-board-buffer
    (with-current-buffer boardgame-current-board-buffer
      ;; TODO: Remove object reference from board
      (boardgame-log-entry "Object Deleted"
                           '(2 . (format "Position: (%d, %d)" x y)))
      (boardgame-render-board)
      (message "Object deleted from board"))))


;;; Hands

(defvar boardgame-hands-directory nil
  "Directory containing hand files for the current world.")

(defun boardgame-open-hand (hand-file)
  "Open an existing hand from HAND-FILE."
  (interactive
   (list (expand-file-name
          (read-file-name "Open hand: "
                          (expand-file-name "hands" boardgame-current-world-directory)
                          nil t nil
                          (lambda (f) (string-suffix-p ".org" f))))))
  (find-file hand-file)
  (setq boardgame-current-hand-file hand-file)
  (boardgame-log-entry "Hand Opened" '(2 . (format "File: %s" hand-file))))

(defun boardgame-take-object (object-file)
  "Take OBJECT-FILE from the board into the active hand."
  (interactive
   (list (expand-file-name
          (read-file-name "Select object to take: "
                          (expand-file-name "objects" boardgame-current-world-directory)
                          nil t nil
                          (lambda (f) (string-suffix-p ".org" f))))))
  (when boardgame-current-hand-file
    ;; TODO: Move object content to hand file
    (boardgame-log-entry "Object Taken"
                         '(2 . (format "Object: %s" (file-name-nondirectory object-file)))
                         '(2 . (format "Hand: %s" boardgame-current-hand-file)))))

(defun boardgame-place-on-board (heading-buffer heading-pos)
  "Place the Org Heading from HANDING-BUFFER at HEADING-POS on the board."
  (interactive
   (list (current-buffer)
         (point)))
  (when boardgame-current-board-buffer
    ;; TODO: Extract heading and create object file
    (boardgame-log-entry "Object Placed on Board"
                         '(2 . (format "Source: %s" (buffer-name heading-buffer))))))


;;; Container Commands

(defun boardgame-create-container (name)
  "Create a new permanent container with NAME."
  (interactive "sContainer name: ")
  (let* ((world-dir boardgame-current-world-directory)
         (containers-dir (expand-file-name "containers" world-dir))
         (file (expand-file-name (concat (boardgame--sanitize-filename name) ".org") containers-dir)))
    
    (when (file-exists-p file)
      (user-error "Container file already exists: %s" file))
    
    (let* ((org-content (boardgame--container-template name)))
      (with-temp-file file
        (insert org-content))
      (boardgame-log-entry "Container Created"
                           '(2 . (format "Name: %s" name))
                           '(2 . (format "File: %s" file)))
      (message "Container created: %s" file))))

(defun boardgame--container-template (name)
  "Return the Org template for a container."
  (format "# -*- org -*-\n* %s\n:PROPERTIES:\n:CONTAINER_TYPE: permanent\n:GLYPH: []\n:FOREGROUND: cyan\n:BACKGROUND: black\n:END:\n\n** Contents\n\n** Source Blocks\n\n" name))


;;; Navigation Markers

(defun boardgame-create-marker (x y)
  "Create a navigation marker at coordinates X, Y."
  (interactive
   (list (read-number "X coordinate: " 0)
         (read-number "Y coordinate: " 0)))
  (let* ((world-dir boardgame-current-world-directory)
         (objects-dir (expand-file-name "objects" world-dir))
         (board-file (buffer-file-name boardgame-current-board-buffer))
         (board-name (file-name-nondirectory board-file))
         (object-name (format "Marker %s (%d, %d)" board-name x y))
         (file (expand-file-name (concat (boardgame--sanitize-filename object-name) ".org") objects-dir)))
    
    (when (file-exists-p file)
      (user-error "Marker file already exists: %s" file))
    
    (let* ((org-content (boardgame--marker-template object-name x y board-name)))
      (with-temp-file file
        (insert org-content))
      (boardgame-add-object file x y)
      (boardgame-log-entry "Marker Created"
                           '(2 . (format "Name: %s" object-name))
                           '(2 . (format "Position: (%d, %d)" x y))
                           '(2 . (format "Destination: %s (%d, %d)" board-name x y)))
      (message "Navigation marker created: %s" file))))

(defun boardgame--marker-template (name x y destination-board)
  "Return the Org template for a navigation marker."
  (format "# -*- org -*-\n* %s\n:PROPERTIES:\n:OBJECT_TYPE: marker\n:GLYPH: ^\n:FOREGROUND: white\n:DESTINATION_BOARD: %s\n:DESTINATION_X: %d\n:DESTINATION_Y: %d\n:END:\n\n** Description\nNavigation marker\n\n** Source Blocks\n#+BEGIN_SRC emacs-lisp\n(boardgame-navigate \"%s\" %d %d)\n#+END_SRC\n" name destination-board x y destination-board x y))

(defun boardgame-navigate (board-file x y)
  "Navigate to BOARD-FILE at coordinates X, Y."
  (interactive
   (list (expand-file-name
          (read-file-name "Select board: "
                          (expand-file-name "boards" boardgame-current-world-directory)
                          nil t nil
                          (lambda (f) (string-suffix-p ".org" f))))
         (read-number "X coordinate: " 0)
         (read-number "Y coordinate: " 0)))
  (let ((board-buf (find-file-noselect board-file)))
    (boardgame--setup-board-buffer board-buf (file-name-base (file-name-nondirectory board-file)))
    (setq boardgame-current-board-buffer board-buf)
    (boardgame-render-board board-buf)
    (boardgame-log-entry "Navigated"
                         '(2 . (format "Board: %s" board-file))
                         '(2 . (format "Position: (%d, %d)" x y)))
    (message "Navigated to %s at (%d, %d)" board-file x y)))


;;; Main Mode

(define-derived-mode boardgame-org-mode org-mode "Boardgame"
  "Major mode for editing boardgame Org files."
  :group 'boardgame-org
  (setq buffer-read-only nil))


;;; Provide Module

(provide 'boardgame-org)
;;; boardgame-org.el ends here
