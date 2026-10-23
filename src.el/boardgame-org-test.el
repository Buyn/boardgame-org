;;; boardgame-org-test.el --- ERT test suite for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Comprehensive ERT test suite for boardgame-org covering:
;; - Felt dimension normalization, padding and clipping (Section 4.6)
;; - Persistent world log file and structured Org headings (Section 12)
;; - Stack consolidation, file deletion and '$' glyph (Section 10.1)
;; - Permanent containers and object file preservation (Section 10.2)
;; - Navigation markers and parameterized navigation (Section 11)
;;
;; Running tests:
;;   (load-file "src.el/boardgame-org-test.el")
;;   (ert "^boardgame-test")

;;; Code:

;; Ensure package directory is automatically in `load-path` when loaded via `load-file` or `load`
(eval-and-compile
  (let* ((raw-dir (file-name-directory
                   (or load-file-name
                       buffer-file-name
                       (and (boundp 'byte-compile-current-file) byte-compile-current-file)
                       default-directory)))
         (base-dir (if raw-dir (file-name-as-directory (expand-file-name raw-dir)) default-directory))
         (src-dir (cond
                   ((file-exists-p (expand-file-name "boardgame-org-core.el" base-dir))
                    base-dir)
                   ((file-exists-p (expand-file-name "src.el/boardgame-org-core.el" base-dir))
                    (file-name-as-directory (expand-file-name "src.el" base-dir)))
                   (t base-dir))))
    (when (and src-dir (file-directory-p src-dir))
      (add-to-list 'load-path src-dir))))

(require 'ert)
(require 'cl-lib)
(require 'org)

;; Force fresh load of all modular components to ensure definitions are updated in active Emacs sessions
(dolist (pkg '(boardgame-org-core
               boardgame-org-log
               boardgame-org-status
               boardgame-org-frame
               boardgame-org-board
               boardgame-org-drawing
               boardgame-org-marker
               boardgame-org-object
               boardgame-org-stack
               boardgame-org-container
               boardgame-org-hand
               boardgame-org))
  (load (symbol-name pkg) nil t)
  (require pkg))

;;; Test Helper Functions

(defun boardgame--test-run-stack-consolidation ()
  "Core logic for stack consolidation, file cleanup, '$' glyph and expansion."
  (let* ((temp-dir (make-temp-file "bg-test-world" t))
         (boardgame-active-world-directory temp-dir))
    (boardgame-ensure-world-dirs)
    (let* ((obj1 (boardgame-object-create "t1" "Token 1" "A"))
           (obj2 (boardgame-object-create "t2" "Token 2" "B"))
           (stack-obj (boardgame-stack-consolidate (list obj1 obj2) "test-stack" "Test Stack")))
      ;; Standalone files removed per Section 3.1 & 10.1
      (should-not (file-exists-p (boardgame-world-file "objects/t1.org")))
      (should-not (file-exists-p (boardgame-world-file "objects/t2.org")))
      ;; Stack file created with '$' glyph
      (should (file-exists-p (boardgame-world-file "stacks/test-stack.org")))
      (should (equal (boardgame-object-glyph stack-obj) "$"))
      ;; Now expand stack back
      (let ((restored (boardgame-stack-expand stack-obj)))
        (should (= (length restored) 2))
        (should (file-exists-p (boardgame-world-file "objects/t1.org")))
        (should (file-exists-p (boardgame-world-file "objects/t2.org")))
        (should-not (file-exists-p (boardgame-world-file "stacks/test-stack.org")))))
    (delete-directory temp-dir t)))

;;; Test Definitions

(ert-deftest boardgame-test-felt-normalization ()
  "Test felt dimension padding and excess truncation."
  (let* ((raw "###\n#\n")
         (grid (boardgame-normalize-felt raw 4 3 ".")))
    ;; Height must be 3
    (should (= (length grid) 3))
    ;; Row 0: "###."
    (should (equal (aref (aref grid 0) 0) "#"))
    (should (equal (aref (aref grid 0) 1) "#"))
    (should (equal (aref (aref grid 0) 2) "#"))
    (should (equal (aref (aref grid 0) 3) "."))
    ;; Row 1: "#..."
    (should (equal (aref (aref grid 1) 0) "#"))
    (should (equal (aref (aref grid 1) 1) "."))
    ;; Row 2: "...."
    (should (equal (aref (aref grid 2) 0) "."))))

(ert-deftest boardgame-test-container-preserves-files ()
  "Test Section 10.2: containers organize objects without deleting their files."
  (let* ((temp-dir (make-temp-file "bg-test-world" t))
         (boardgame-active-world-directory temp-dir))
    (boardgame-ensure-world-dirs)
    (let* ((card1 (boardgame-object-create "c1" "Card 1" "C"))
           (cnt (boardgame-container-create "deck1" "Deck 1")))
      (boardgame-container-add-object cnt "c1")
      ;; File c1.org must remain intact per Section 10.2
      (should (file-exists-p (boardgame-world-file "objects/c1.org")))
      ;; Draw top
      (let ((drawn (boardgame-container-draw-top cnt)))
        (should (equal drawn "c1"))
        (should (file-exists-p (boardgame-world-file "objects/c1.org")))))
    (delete-directory temp-dir t)))

(ert-deftest boardgame-test-persistent-log ()
  "Test Section 12: persistent world log file and structured Org headings."
  (let* ((temp-dir (make-temp-file "bg-test-world" t))
         (boardgame-active-world-directory temp-dir)
         (boardgame-shared-log-buffer nil))
    (boardgame-ensure-world-dirs)
    ;; Append structured log entries
    (boardgame-log "Player Action" '(("Dice" . "Rolled 6") ("Target" . "Castle")) "Player advances 6 steps.")
    (boardgame-log-save)
    ;; Check persistent log file exists: <world-name>-log.org
    (let ((log-file (boardgame-world-file (format "%s-log.org" (boardgame-world-name)))))
      (should (file-exists-p log-file))
      (with-temp-buffer
        (insert-file-contents log-file)
        (goto-char (point-min))
        ;; Verify level-1 heading
        (should (re-search-forward "^\\*\\s-+Player Action" nil t))
        ;; Verify level-2 headings
        (should (re-search-forward "^\\*\\*\\s-+Dice" nil t))
        (should (re-search-forward "^\\*\\*\\s-+Target" nil t))))
    ;; Cleanup buffer
    (when (and boardgame-shared-log-buffer (buffer-live-p boardgame-shared-log-buffer))
      (kill-buffer boardgame-shared-log-buffer))
    (delete-directory temp-dir t)))

(ert-deftest boardgame-test-stack-consolidation-and-glyph ()
  "Test Section 10.1: stack consolidation removes standalone files and uses ’$’."
  (boardgame--test-run-stack-consolidation))

(ert-deftest boardgame-test-stack-consolidation-and-expansion ()
  "Test that consolidating objects into a stack merges files and expansion restores them."
  (boardgame--test-run-stack-consolidation))

(ert-deftest boardgame-test-marker-navigation ()
  "Test Section 11: marker creation and parameterized coordinate navigation."
  (let* ((temp-dir (make-temp-file "bg-test-world" t))
         (boardgame-active-world-directory temp-dir))
    (boardgame-ensure-world-dirs)
    (let ((marker-obj (boardgame-marker-generate "main.org" 5 8)))
      (should (equal (boardgame-object-glyph marker-obj) "^"))
      (should (file-exists-p (boardgame-world-file (boardgame-object-file-path marker-obj))))
      (with-temp-buffer
        (insert-file-contents (boardgame-world-file (boardgame-object-file-path marker-obj)))
        (goto-char (point-min))
        (should (re-search-forward ":DESTINATION_BOARD:\\s-+main\\.org" nil t))
        (should (re-search-forward ":DESTINATION_X:\\s-+5" nil t))
        (should (re-search-forward ":DESTINATION_Y:\\s-+8" nil t))))
    (delete-directory temp-dir t)))

(provide 'boardgame-org-test)
;;; boardgame-org-test.el ends here
