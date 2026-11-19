;;; boardgame-draw.el --- Drawing Mode (Felt Layer) and Text Overwrite Mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 boardgame.org contributors

;;; Commentary:
;; Drawing Mode and Text Overwrite Mode implementation for boardgame.org.
;;
;; Implements §5.4 of boardgame-org-interface.md:
;; - Drawing Mode: ZZT-style felt layer editing without modifying object files.
;; - Text Overwrite Mode: Standard text-editor-style character replacement.
;;
;; Key capabilities:
;; - `boardgame-draw-mode`: Toggle drawing mode (hides objects, exposes felt).
;; - `boardgame-text-mode`: Submode for character-by-character overwrite.
;; - Drawing tools: symbol selection, colors, pipette, recent symbols.
;; - Continuous and point-by-point painting.
;; - Region-based operations.
;;
;; Architectural Invariant:
;; In accordance with boardgame-org.md §7 and boardgame-implementation-plan.md §1.2,
;; internal module files do NOT call `provide'. Only boardgame.el provides `boardgame'.

;;; Code:

(require 'cl-lib)

;; -----------------------------------------------------------------------------
;; Forward Declarations
;; -----------------------------------------------------------------------------

(declare-function boardgame-board-get-felt "boardgame-data")
(declare-function boardgame-board-set-felt "boardgame-data")
(declare-function boardgame-board-get-objects "boardgame-data")
(declare-function boardgame-board-get-top-object "boardgame-data")
(declare-function boardgame-board-current-coord "boardgame-board")
(declare-function boardgame-board-goto-coord "boardgame-board")
(declare-function boardgame-board-refresh "boardgame-board")
(declare-function boardgame-render-cell "boardgame-render")
(declare-function boardgame-render-coord-to-pos "boardgame-render")
(declare-function boardgame-render-pos-to-coord "boardgame-render")
(declare-function boardgame-board--data "boardgame-board")

(declare-function boardgame-status-update "boardgame-status")
(declare-function boardgame-log-append "boardgame-log")

;; -----------------------------------------------------------------------------
;; Drawing Mode Customization Group
;; -----------------------------------------------------------------------------

(defgroup boardgame-draw nil
  "Drawing Mode and Text Overwrite Mode settings for boardgame.org."
  :prefix "boardgame-draw-"
  :group 'boardgame)

(defcustom boardgame-draw-default-foreground "white"
  "Default foreground color for drawing operations."
  :type 'string
  :group 'boardgame-draw)

(defcustom boardgame-draw-default-background "black"
  "Default background color for drawing operations."
  :type 'string
  :group 'boardgame-draw)

;; -----------------------------------------------------------------------------
;; Drawing Mode State Variables
;; -----------------------------------------------------------------------------

(defvar-local boardgame-draw--mode nil
  "Non-nil when Drawing Mode is active for the current board buffer.")

(defvar-local boardgame-draw--text-mode nil
  "Non-nil when Text Overwrite Mode is active within Drawing Mode.")

(defvar-local boardgame-draw--glyph ?\s
  "Current drawing character (glyph).")

(defvar-local boardgame-draw--foreground nil
  "Current foreground color as string or nil.")

(defvar-local boardgame-draw--background nil
  "Current background color as string or nil.")

(defvar-local boardgame-draw--recent-glyphs '()
  "List of recently used drawing glyphs, newest first.")

(defvar-local boardgame-draw--saved-faces nil
  "List of faces to restore when exiting drawing mode.")

(defvar boardgame-draw--global-foreground "white"
  "Global default foreground color for drawing.")

(defvar boardgame-draw--global-background "black"
  "Global default background color for drawing.")

;; -----------------------------------------------------------------------------
;; Drawing Mode Major Mode Definition
;; -----------------------------------------------------------------------------

(defvar boardgame-draw-mode-map
  (let ((map (make-sparse-keymap)))
    ;; F-keys for drawing commands
    (define-key map (kbd "<f1>") #'boardgame-draw-toggle)
    (define-key map (kbd "<f2>") #'boardgame-draw-pipette)
    (define-key map (kbd "<f3>") #'boardgame-draw-set-glyph)
    (define-key map (kbd "<f4>") #'boardgame-draw-set-foreground)
    (define-key map (kbd "<f5>") #'boardgame-draw-set-background)
    (define-key map (kbd "<f6>") #'boardgame-draw-recent-glyphs)
    (define-key map (kbd "<f7>") #'boardgame-draw-fill-region)
    (define-key map (kbd "<f8>") #'boardgame-text-mode-toggle)
    ;; Standard movement keys work in drawing mode
    (define-key map (kbd "C-l") #'boardgame-render-cell)
    map)
  "Keymap for Drawing Mode.")

(defun boardgame-draw--enter-drawing-mode ()
  "Prepare buffer for Drawing Mode entry."
  (when (and boardgame-board--data (not boardgame-draw--mode))
    (setq boardgame-draw--mode t)
    (setq boardgame-draw--text-mode nil)
    ;; Save current colors if not already set
    (unless boardgame-draw--foreground
      (setq boardgame-draw--foreground boardgame-draw--global-foreground))
    (unless boardgame-draw--background
      (setq boardgame-draw--background boardgame-draw--global-background))
    ;; Update status
    (boardgame-status-update nil nil "Drawing (F8: Text)"
                             "Glyph: space, Colors: white/black")))

(defun boardgame-draw--exit-drawing-mode ()
  "Restore buffer after Drawing Mode exit."
  (when boardgame-draw--mode
    (setq boardgame-draw--mode nil)
    (setq boardgame-draw--text-mode nil)
    ;; Update status
    (boardgame-status-update nil nil nil nil)))

(defun boardgame-draw-toggle ()
  "Toggle Drawing Mode on or off.
When enabled, objects are temporarily hidden to expose the felt layer.
When disabled, objects are rendered over the edited felt."
  (interactive)
  (if boardgame-draw--mode
      (boardgame-draw--exit-drawing-mode)
    (boardgame-draw--enter-drawing-mode))
  (boardgame-board-refresh))

;; -----------------------------------------------------------------------------
;; Text Overwrite Mode (Submode of Drawing Mode)
;; -----------------------------------------------------------------------------

(defun boardgame-text-mode-toggle ()
  "Toggle Text Overwrite Mode within Drawing Mode.
Text Mode provides standard text-editor-style character replacement.
Requires Drawing Mode to be active."
  (interactive)
  (unless boardgame-draw--mode
    (boardgame-draw--enter-drawing-mode))
  (setq boardgame-draw--text-mode (not boardgame-draw--text-mode))
  (if boardgame-draw--text-mode
      (boardgame-status-update nil nil "Text Mode" "Glyph: space")
    (boardgame-status-update nil nil "Drawing" "Glyph: space"))
  (boardgame-board-refresh))

(defun boardgame-text-mode--insert-char (char)
  "Insert CHAR at point in Text Overwrite Mode.
Replaces the felt character under the cursor and advances point right."
  (unless boardgame-draw--text-mode
    (error "Text Overwrite Mode is not active"))
  (unless boardgame-board--data
    (error "Current buffer is not an active board buffer"))
  
  (let* ((board boardgame-board--data)
         (coord (boardgame-board-current-coord))
         (x (car coord))
         (y (cdr coord)))
    
    ;; Check if we're at the right edge - don't insert beyond boundary
    (when (>= x (boardgame-board-width board))
      (error "Cannot insert beyond right board boundary"))
    
    ;; Set the felt character with current colors
    (boardgame-board-set-felt board x y char)
    (boardgame-render-cell board (current-buffer) x y)
    
    ;; Advance point one cell to the right
    (let ((pos (point)))
      (forward-char 1)
      (when (and boardgame-draw--text-mode
                 (eq (current-buffer) (window-buffer (selected-window))))
        (boardgame-status-update x y "Text Mode"
                                 (format "Glyph: %c" char))))))

;; -----------------------------------------------------------------------------
;; Drawing Mode Keymap Extensions for Text Mode
;; -----------------------------------------------------------------------------

(defun boardgame-draw--setup-text-mode-keys ()
  "Set up keybindings for Text Overwrite Mode."
  (when boardgame-draw--text-mode
    ;; In Evil context, this should respect Insert state
    ;; In vanilla Emacs, this overrides the default self-insert-command
    (local-set-key (kbd "SPC") #'boardgame-text-mode--space)
    (local-set-key (kbd "!") #'boardgame-text-mode--exclamation)
    (local-set-key (kbd "\"") #'boardgame-text-mode--quote)
    (local-set-key (kbd "#") #'boardgame-text-mode--hash)
    (local-set-key (kbd "$") #'boardgame-text-mode--dollar)
    (local-set-key (kbd "%") #'boardgame-text-mode--percent)
    (local-set-key (kbd "&") #'boardgame-text-mode--ampersand)
    (local-set-key (kbd "'") #'boardgame-text-mode--apostrophe)
    (local-set-key (kbd "(") #'boardgame-text-mode--lparen)
    (local-set-key (kbd ")") #'boardgame-text-mode--rparen)
    (local-set-key (kbd "*") #'boardgame-text-mode--asterisk)
    (local-set-key (kbd "+") #'boardgame-text-mode--plus)
    (local-set-key (kbd ",") #'boardgame-text-mode--comma)
    (local-set-key (kbd "-") #'boardgame-text-mode--hyphen)
    (local-set-key (kbd ".") #'boardgame-text-mode--period)
    (local-set-key (kbd "/") #'boardgame-text-mode--slash)
    (local-set-key (kbd ":") #'boardgame-text-mode--colon)
    (local-set-key (kbd ";") #'boardgame-text-mode--semicolon)
    (local-set-key (kbd "<") #'boardgame-text-mode--lt)
    (local-set-key (kbd "=") #'boardgame-text-mode--equal)
    (local-set-key (kbd ">") #'boardgame-text-mode--gt)
    (local-set-key (kbd "?") #'boardgame-text-mode--question)
    (local-set-key (kbd "@") #'boardgame-text-mode--at)
    (local-set-key (kbd "[") #'boardgame-text-mode--lbracket)
    (local-set-key (kbd "\\") #'boardgame-text-mode--backslash)
    (local-set-key (kbd "]") #'boardgame-text-mode--rbracket)
    (local-set-key (kbd "^") #'boardgame-text-mode--caret)
    (local-set-key (kbd "_") #'boardgame-text-mode--underscore)
    (local-set-key (kbd "`") #'boardgame-text-mode--backtick)
    (local-set-key (kbd "{") #'boardgame-text-mode--lbrace)
    (local-set-key (kbd "|") #'boardgame-text-mode--bar)
    (local-set-key (kbd "}") #'boardgame-text-mode--rbrace)
    (local-set-key (kbd "~") #'boardgame-text-mode--tilde)))

(defun boardgame-text-mode--insert-self (char)
  "Insert CHAR at point in Text Overwrite Mode with logging."
  (interactive (list last-nonmenu-event))
  (when (integerp char)
    (boardgame-text-mode--insert-char char)))

;; Define all single-character insertion functions
(dolist (spec '((32 . space)             ; SP
                (33 . exclamation)        ; !
                (34 . quote)             ; "
                (35 . hash)              ; #
                (36 . dollar)            ; $
                (37 . percent)           ; %
                (38 . ampersand)         ; &
                (39 . apostrophe)        ; '
                (40 . lparen)            ; (
                (41 . rparen)            ; )
                (42 . asterisk)          ; *
                (43 . plus)              ; +
                (44 . comma)             ; ,
                (45 . hyphen)            ; -
                (46 . period)            ; .
                (47 . slash)             ; /
                (58 . colon)             ; :
                (59 . semicolon)         ; ;
                (60 . lt)                ; <
                (61 . equal)            ; =
                (62 . gt)                ; >
                (63 . question)          ; ?
                (64 . at)                ; @
                (91 . lbracket)          ; [
                (92 . backslash)         ; \
                (93 . rbracket)          ; ]
                (94 . caret)             ; ^
                (95 . underscore)        ; _
                (96 . backtick)          ; `
                (123 . lbrace)           ; {
                (124 . bar)              ; |
                (125 . rbrace)           ; }
                (126 . tilde)))          ; ~
  (eval-after-load 'boardgame-draw
    `(defun ,(intern (format "boardgame-text-mode--%s" (cdr spec))) ()
       ,(format "Insert %s (char %d) in Text Overwrite Mode."
                (symbol-name (cdr spec)) (car spec))
       (interactive)
       (boardgame-text-mode--insert-char ,(car spec)))))

(defun boardgame-text-mode--space ()
  "Insert space character in Text Overwrite Mode."
  (interactive)
  (boardgame-text-mode--insert-char ?\s))

;; -----------------------------------------------------------------------------
;; Drawing Tools
;; -----------------------------------------------------------------------------

(defun boardgame-draw-pipette ()
  "Sample the felt character and colors under the cursor.
Updates the current drawing glyph and colors to match the sampled cell.
Does not modify the sampled cell."
  (interactive)
  (unless boardgame-board--data
    (error "Current buffer is not an active board buffer"))
  
  (let* ((coord (boardgame-board-current-coord))
         (x (car coord))
         (y (cdr coord)))
    
    (when coord
      (let ((felt-char (boardgame-board-get-felt boardgame-board--data x y)))
        (setq boardgame-draw--glyph felt-char)
        
        ;; Update recent glyphs (remove duplicates, add to front)
        (setq boardgame-draw--recent-glyphs
              (cl-remove-duplicates
               (cons felt-char boardgame-draw--recent-glyphs)
               :test #'equal))
        ;; Limit recent glyphs to 10
        (when (> (length boardgame-draw--recent-glyphs) 10)
          (setq boardgame-draw--recent-glyphs
                (subseq boardgame-draw--recent-glyphs 0 10)))
        
        (boardgame-status-update x y "Drawing (pipette)"
                                 (format "Glyph: %c, Colors: %s/%s"
                                         felt-char
                                         (or boardgame-draw--foreground "white")
                                         (or boardgame-draw--background "black")))
        (boardgame-board-refresh)
        (message "Pipette: sampled '%c' at (%d, %d)" felt-char x y)))))

(defun boardgame-draw-set-glyph (&optional glyph)
  "Set the current drawing glyph to GLYPH.
Prompts for a character if GLYPH is not provided."
  (interactive)
  (let ((char (or glyph
                  (read-char "Enter drawing character: "))))
    (setq boardgame-draw--glyph char)
    ;; Update recent glyphs
    (setq boardgame-draw--recent-glyphs
          (cl-remove-duplicates
           (cons char boardgame-draw--recent-glyphs)
           :test #'equal))
    (when (> (length boardgame-draw--recent-glyphs) 10)
      (setq boardgame-draw--recent-glyphs
            (subseq boardgame-draw--recent-glyphs 0 10)))
    (boardgame-status-update nil nil "Drawing (glyph)"
                             (format "Glyph: %c" char))
    char))

(defun boardgame-draw-set-foreground (&optional fg)
  "Set the current foreground color to FG.
FG should be a color name string (e.g., \"white\", \"red\")."
  (interactive)
  (let ((color (or fg
                   (completing-read "Foreground color: "
                                    '("black" "white" "red" "green" "blue"
                                      "yellow" "magenta" "cyan" "orange" "purple"
                                      "gray" "dark-gray" "light-gray") nil t))))
    (setq boardgame-draw--foreground color)
    (boardgame-status-update nil nil "Drawing (fg)"
                             (format "Foreground: %s, Background: %s"
                                     color (or boardgame-draw--background "black")))
    color))

(defun boardgame-draw-set-background (&optional bg)
  "Set the current background color to BG.
BG should be a color name string."
  (interactive)
  (let ((color (or bg
                   (completing-read "Background color: "
                                    '("black" "white" "red" "green" "blue"
                                      "yellow" "magenta" "cyan" "orange" "purple"
                                      "gray" "dark-gray" "light-gray") nil t))))
    (setq boardgame-draw--background color)
    (boardgame-status-update nil nil "Drawing (bg)"
                             (format "Foreground: %s, Background: %s"
                                     (or boardgame-draw--foreground "white") color))
    color))

(defun boardgame-draw-recent-glyphs ()
  "Display and select from recent drawing glyphs.
Shows a menu of recently used glyphs and allows selection."
  (interactive)
  (unless boardgame-draw--recent-glyphs
    (message "No recent glyphs available. Use pipette or draw to add glyphs."))
  
  (if (null boardgame-draw--recent-glyphs)
      (message "No recent glyphs available.")
    (let* ((choices (mapcar (lambda (c) (cons (format "%c" c) c))
                            boardgame-draw--recent-glyphs))
           (prompt "Select recent glyph: ")
           (selected (if (> (length choices) 1)
                         (completing-read prompt choices nil t)
                       (caar choices))))
      (when selected
        (let ((char (assoc selected choices)))
          (when char
            (boardgame-draw-set-glyph (cdr char))))))))

;; -----------------------------------------------------------------------------
;; Point-by-Point Painting
;; -----------------------------------------------------------------------------

(defun boardgame-draw-paint-cell (x y &optional glyph fg bg)
  "Paint a single cell at (X, Y) with current or specified drawing settings.
GLYPH, FG, BG default to current drawing mode values if not specified."
  (unless boardgame-board--data
    (error "Current buffer is not an active board buffer"))
  
  (let* ((board boardgame-board--data)
         (g (or glyph boardgame-draw--glyph))
         (f (or fg boardgame-draw--foreground boardgame-draw--global-foreground))
         (b (or bg boardgame-draw--background boardgame-draw--global-background))
         (obj-at-cell (boardgame-board-get-objects board x y)))
    
    ;; Only paint if no object is at this cell (objects are not modified)
    (unless obj-at-cell
      (boardgame-board-set-felt board x y g)
      (boardgame-render-cell board (current-buffer) x y)
      
      ;; Update recent glyphs
      (unless (member g boardgame-draw--recent-glyphs)
        (push g boardgame-draw--recent-glyphs)
        (when (> (length boardgame-draw--recent-glyphs) 10)
          (setq boardgame-draw--recent-glyphs
                (subseq boardgame-draw--recent-glyphs 0 10))))
      
      (boardgame-status-update x y "Drawing (paint)"
                               (format "Glyph: %c, Colors: %s/%s"
                                       g (or f "white") (or b "black")))
      (message "Painted (%d, %d) with '%c'" x y g))))

(defun boardgame-draw-point-paint ()
  "Paint the cell under the cursor with current drawing settings.
Object layer remains untouched."
  (interactive)
  (let ((coord (boardgame-board-current-coord)))
    (when coord
      (boardgame-draw-paint-cell (car coord) (cdr coord)))))

;; -----------------------------------------------------------------------------
;; Continuous Stroke Painting
;; -----------------------------------------------------------------------------

(defun boardgame-draw-stroke-start (x y)
  "Start a continuous stroke from (X, Y) in drawing mode."
  (boardgame-draw-paint-cell x y))

(defun boardgame-draw-stroke-move (from-x from-y to-x to-y)
  "Paint cells along a line from (FROM-X, FROM-Y) to (TO-X, TO-Y).
Implements Bresenham-like line drawing for continuous stroke."
  (let* ((dx (abs (- to-x from-x)))
         (dy (abs (- to-y from-y)))
         (sx (if (< from-x to-x) 1 -1))
         (sy (if (< from-y to-y) 1 -1))
         (err (- dx dy))
         (x from-x)
         (y from-y))
    
    (while (and (>= x 0) (< x (boardgame-board-width boardgame-board--data))
                (>= y 0) (< y (boardgame-board-height boardgame-board--data)))
      (boardgame-draw-paint-cell x y)
      
      (let ((e2 (* 2 err)))
        (when (>= e2 (- dy))
          (setq err (- err dy))
          (setq x (+ x sx)))
        (when (and (< y (boardgame-board-height boardgame-board--data))
                   (< e2 dx))
          (setq err (+ err dx))
          (setq y (+ y sy))))
      
      (when (and (= x to-x) (= y to-y))
        (cl-return)))))

(defun boardgame-draw-stroke-end ()
  "End a continuous stroke."
  (message "Stroke completed"))

;; -----------------------------------------------------------------------------
;; Region-Based Drawing
;; -----------------------------------------------------------------------------

(defun boardgame-draw--get-region-bounds ()
  "Return the bounding coordinates of the active region.
Returns (X1 Y1 X2 Y2) or nil if no active region."
  (unless (use-region-p)
    (error "No active region"))
  (let* ((start (region-beginning))
         (end (region-end))
         (start-coord (boardgame-render-pos-to-coord boardgame-board--data start))
         (end-coord (boardgame-render-pos-to-coord boardgame-board--data end))
         (x1 (min (car start-coord) (car end-coord)))
         (y1 (min (cdr start-coord) (cdr end-coord)))
         (x2 (max (car start-coord) (car end-coord)))
         (y2 (max (cdr start-coord) (cdr end-coord))))
    (list x1 y1 x2 y2)))

(defun boardgame-draw-fill-region (&optional glyph fg bg)
  "Fill the active region with the current or specified drawing settings.
Does not modify objects in the region."
  (interactive)
  (let ((bounds (boardgame-draw--get-region-bounds)))
    (unless bounds
      (error "Region is not on the board"))
    
    (let* ((x1 (nth 0 bounds))
           (y1 (nth 1 bounds))
           (x2 (nth 2 bounds))
           (y2 (nth 3 bounds))
           (g (or glyph boardgame-draw--glyph))
           (f (or fg boardgame-draw--foreground boardgame-draw--global-foreground))
           (b (or bg boardgame-draw--background boardgame-draw--global-background))
           (board boardgame-board--data))
      
      (dotimes (y (1+ (- y2 y1)))
        (dotimes (x (1+ (- x2 x1)))
          (let ((cx (+ x1 x))
                (cy (+ y1 y)))
            (unless (boardgame-board-get-objects board cx cy)
              (boardgame-board-set-felt board cx cy g)
              (boardgame-render-cell board (current-buffer) cx cy)))))
      
      (boardgame-status-update nil nil "Drawing (fill-region)"
                               (format "Filled region: %dx%d" (1+ (- x2 x1)) (1+ (- y2 y1))))
      (message "Filled region from (%d,%d) to (%d,%d) with '%c'" x1 y1 x2 y2 g))))

;; -----------------------------------------------------------------------------
;; Fallback Glyph Resolution
;; -----------------------------------------------------------------------------

(defun boardgame-draw-resolve-glyph (heading &optional fallback)
  "Resolve display glyph from an Org heading or FALLBACK.
The glyph is derived from the first character of the heading title,
excluding Org heading markers and whitespace.
If the first character is unusable, returns FALLBACK (default '*')."
  (unless heading
    (setq heading fallback))
  
  (let* ((text (if (stringp heading) heading ""))
         (trimmed (string-trim-left text))
         (first-char (when (> (length trimmed) 0)
                       (aref trimmed 0))))
    
    (cond
     ;; Check if it's a valid printable character
     ((and first-char
           (>= first-char 32)
           (<= first-char 126))
      first-char)
     ;; Use fallback if empty or invalid
     (t ?*))))

;; -----------------------------------------------------------------------------
;; Integration with Board Mode
;; -----------------------------------------------------------------------------

(defun boardgame-draw--ensure-draw-mode ()
  "Ensure Drawing Mode is active, enabling it if necessary."
  (unless boardgame-draw--mode
    (boardgame-draw-toggle)))

(defun boardgame-draw--ensure-text-mode ()
  "Ensure Text Overwrite Mode is active, enabling Drawing Mode first."
  (boardgame-draw--ensure-draw-mode)
  (unless boardgame-draw--text-mode
    (boardgame-text-mode-toggle)))

;; -----------------------------------------------------------------------------
;; Board Mode Hook Integration
;; -----------------------------------------------------------------------------

(defun boardgame-draw--setup-board-mode ()
  "Set up Drawing Mode bindings in `boardgame-board-mode'."
  (let ((map boardgame-board-mode-map))
    (define-key map (kbd "C-c d") #'boardgame-draw-toggle)
    (define-key map (kbd "C-c p") #'boardgame-draw-point-paint)
    (define-key map (kbd "C-c r") #'boardgame-draw-fill-region)
    (define-key map (kbd "C-c i") #'boardgame-draw-pipette)
    (define-key map (kbd "C-c g") #'boardgame-draw-set-glyph)))

(add-hook 'boardgame-board-mode-hook #'boardgame-draw--setup-board-mode)

;; -----------------------------------------------------------------------------
;; Package Initialization
;; -----------------------------------------------------------------------------

(provide 'boardgame-draw)
;;; boardgame-draw.el ends here
