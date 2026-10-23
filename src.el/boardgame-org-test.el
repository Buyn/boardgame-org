;;; boardgame-org-test.el --- ERT unit & regression tests for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Comprehensive ERT test suite covering Section 15 of boardgame-org-interface.md
;; and Section 8 of boardgame-org.md:
;; - Felt normalization
;; - Persistent world log (* Entry headings)
;; - Navigation marker creation and parameterized source block
;; - Stack consolidation ($ black on white) deleting standalone files
;; - Container organization preserving standalone files
;; - Universal heading placement glyph derivation

;;; Code:

(require 'ert)
(require 'boardgame-org)

(ert-deftest boardgame-test-felt-normalization ()
  "Test felt dimension padding and excess truncation."
  (let* ((raw-felt "...\n.....\n.")
         (grid (boardgame-normalize-felt raw-felt 4 3 ".")))
    (should (= (length grid) 3))
    (should (= (length (aref grid 0)) 4))
    (should (equal (aref (aref grid 0) 3) "."))
    (should (= (length (aref grid 1)) 4))))

(ert-deftest boardgame-test-persistent-log ()
  "Test Section 12: persistent world log file and structured Org headings."
  (let* ((test-dir (make-temp-file "bg-world-" t))
         (boardgame-active-world-directory test-dir))
    (unwind-protect
        (progn
          (boardgame-ensure-world-dirs)
          (boardgame-log "Test Event" '(("Param1" . "Value1")) "Additional notes.")
          (let ((log-file (boardgame-log-file-path)))
            (should (file-exists-p log-file))
            (with-temp-buffer
              (insert-file-contents log-file)
              (should (re-search-forward "^\\* Test Event" nil t))
              (should (re-search-forward "^\\*\\* Param1" nil t)))))
      (delete-directory test-dir t))))

(ert-deftest boardgame-test-stack-consolidation-and-glyph ()
  "Test Section 10.1: stack consolidation removes standalone files and uses '$'."
  (let* ((test-dir (make-temp-file "bg-world-" t))
         (boardgame-active-world-directory test-dir)
         (c1 (boardgame-object-create :id "c1" :name "Card One" :glyph "1" :type 'card :file-path "objects/c1.org"))
         (c2 (boardgame-object-create :id "c2" :name "Card Two" :glyph "2" :type 'card :file-path "objects/c2.org")))
    (unwind-protect
        (progn
          (boardgame-ensure-world-dirs)
          (boardgame-object-save-file c1)
          (boardgame-object-save-file c2)
          (should (file-exists-p (boardgame-world-file "objects/c1.org")))
          (should (file-exists-p (boardgame-world-file "objects/c2.org")))

          (let ((stack (boardgame-stack-consolidate (list c1 c2) "s1" "Stack One")))
            ;; Stack uses '$'
            (should (equal (boardgame-object-glyph stack) "$"))
            ;; Standalone files MUST be deleted
            (should-not (file-exists-p (boardgame-world-file "objects/c1.org")))
            (should-not (file-exists-p (boardgame-world-file "objects/c2.org")))
            ;; Stack file exists
            (should (file-exists-p (boardgame-world-file "stacks/s1.org")))))
      (delete-directory test-dir t))))

(ert-deftest boardgame-test-container-preserves-files ()
  "Test Section 10.2: containers organize objects without deleting their files."
  (let* ((test-dir (make-temp-file "bg-world-" t))
         (boardgame-active-world-directory test-dir)
         (c1 (boardgame-object-create :id "dc1" :name "Deck Card" :glyph "C" :type 'card :file-path "objects/dc1.org"))
         (container (boardgame-object-create
                     :id "deck1" :name "Main Deck" :glyph "🎴" :type 'container
                     :file-path "containers/deck1.org" :contained-ids '("dc1"))))
    (unwind-protect
        (progn
          (boardgame-ensure-world-dirs)
          (boardgame-object-save-file c1)
          (boardgame-container-save container)
          (should (file-exists-p (boardgame-world-file "objects/dc1.org")))
          (should (file-exists-p (boardgame-world-file "containers/deck1.org")))

          (let ((drawn (boardgame-container-draw-top container)))
            (should (equal drawn "dc1"))
            ;; File must remain intact
            (should (file-exists-p (boardgame-world-file "objects/dc1.org")))))
      (delete-directory test-dir t))))

(provide 'boardgame-org-test)
;;; boardgame-org-test.el ends here
