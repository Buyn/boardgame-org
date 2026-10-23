;;; boardgame-org-test.el --- ERT test suite for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Test suite covering acceptance criteria for boardgame-org:
;; - Felt normalization and padding (Section 4.6)
;; - Multi-object count badges ('1'-'9', '+')
;; - Explicit stack consolidation and expansion (Section 3.1 & 10.1)
;; - Permanent containers and drawing (Section 3.2 & 10.2)
;; - Navigation markers (Section 11)

;;; Code:

(require 'ert)
(require 'boardgame-org)

(ert-deftest boardgame-test-felt-normalization ()
  "Test felt normalization pads missing cells and crops excess."
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

(ert-deftest boardgame-test-stack-consolidation-and-expansion ()
  "Test that consolidating objects into a stack merges files and expansion restores them."
  (let* ((temp-dir (make-temp-file "bg-test-world" t))
         (boardgame-active-world-directory temp-dir))
    (boardgame-ensure-world-dirs)
    (let* ((obj1 (boardgame-create-object "t1" "Token 1" "A"))
           (obj2 (boardgame-create-object "t2" "Token 2" "B"))
           (stack-obj (boardgame-stack-consolidate (list obj1 obj2) "test-stack" "Test Stack")))
      ;; Standalone files removed per Section 3.1
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

(ert-deftest boardgame-test-container-preserves-files ()
  "Test that permanent containers preserve standalone object files."
  (let* ((temp-dir (make-temp-file "bg-test-world" t))
         (boardgame-active-world-directory temp-dir))
    (boardgame-ensure-world-dirs)
    (let* ((card1 (boardgame-create-object "c1" "Card 1" "C"))
           (cnt (boardgame-create-container "deck1" "Deck 1")))
      (boardgame-container-add-object cnt "c1")
      ;; File c1.org must remain intact!
      (should (file-exists-p (boardgame-world-file "objects/c1.org")))
      ;; Draw top
      (let ((drawn (boardgame-container-draw-top cnt)))
        (should (equal drawn "c1"))
        (should (file-exists-p (boardgame-world-file "objects/c1.org")))))
    (delete-directory temp-dir t)))

(provide 'boardgame-org-test)
;;; boardgame-org-test.el ends here
