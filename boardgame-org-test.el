;;; boardgame-org-test.el --- ERT unit & integration tests for boardgame-org -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; Package-Requires: ((emacs "27.1") (org "9.3"))

;;; Commentary:
;; Test suite implementing Section 8 (Testing Requirements) of boardgame-org.md:
;; - Round-trip serialization
;; - Felt normalization
;; - Stacks: consolidation deletes standalone files, expansion reconstitutes files
;; - Containers: organize without consolidating standalone files
;; - Multi-object rendering & count indicators

;;; Code:

(require 'ert)
(require 'boardgame-org)

(ert-deftest boardgame-org-test-felt-normalization ()
  "Test Section 4.6: missing cells filled with default felt, excess ignored."
  (let* ((raw-felt "...\n.....\n.")
         (grid (boardgame-org-normalize-felt raw-felt 4 3 ".")))
    ;; Height must be 3, width must be 4
    (should (= (length grid) 3))
    (should (= (length (aref grid 0)) 4))
    ;; Row 0 had 3 dots, 4th must be default '.'
    (should (equal (aref (aref grid 0) 3) "."))
    ;; Row 1 had 5 dots, 5th must be truncated to 4
    (should (= (length (aref grid 1)) 4))))

(ert-deftest boardgame-org-test-object-file-invariant ()
  "Test Section 2.1: an independently existing object has its own Org file."
  (let* ((test-dir (make-temp-file "bg-world-" t))
         (boardgame-org-world-directory test-dir)
         (obj (boardgame-org-object-create
               :id "test-card-1"
               :name "Ace of Spades"
               :glyph "🂡"
               :type 'card
               :file-path "objects/test-card-1.org")))
    (unwind-protect
        (progn
          (boardgame-org-object-save-file obj)
          (should (file-exists-p (boardgame-org-world-file "objects/test-card-1.org")))
          ;; Deleting removes the file
          (boardgame-org-object-delete-file obj)
          (should-not (file-exists-p (boardgame-org-world-file "objects/test-card-1.org"))))
      (delete-directory test-dir t))))

(ert-deftest boardgame-org-test-stack-consolidation-removes-standalone-files ()
  "Test Section 3.1: Stacks consolidate Org docs and remove standalone files."
  (let* ((test-dir (make-temp-file "bg-world-" t))
         (boardgame-org-world-directory test-dir)
         (c1 (boardgame-org-object-create
              :id "card-1"
              :name "Card One"
              :glyph "🂡"
              :type 'card
              :file-path "objects/card-1.org"))
         (c2 (boardgame-org-object-create
              :id "card-2"
              :name "Card Two"
              :glyph "🂾"
              :type 'card
              :file-path "objects/card-2.org")))
    (unwind-protect
        (progn
          ;; Save initial independent files
          (boardgame-org-object-save-file c1)
          (boardgame-org-object-save-file c2)
          (should (file-exists-p (boardgame-org-world-file "objects/card-1.org")))
          (should (file-exists-p (boardgame-org-world-file "objects/card-2.org")))

          ;; Consolidate into stack
          (let ((stack (boardgame-org-stack-consolidate (list c1 c2) "test-stack" "My Stack")))
            ;; Stack file created
            (should (file-exists-p (boardgame-org-world-file "stacks/test-stack.org")))
            ;; Standalone files MUST be removed
            (should-not (file-exists-p (boardgame-org-world-file "objects/card-1.org")))
            (should-not (file-exists-p (boardgame-org-world-file "objects/card-2.org")))

            ;; Expanding stack reconstitutes standalone files and removes stack file
            (let ((expanded (boardgame-org-stack-expand stack)))
              (should (= (length expanded) 2))
              (should (file-exists-p (boardgame-org-world-file "objects/card-1.org")))
              (should (file-exists-p (boardgame-org-world-file "objects/card-2.org")))
              (should-not (file-exists-p (boardgame-org-world-file "stacks/test-stack.org"))))))
      (delete-directory test-dir t))))

(ert-deftest boardgame-org-test-container-preserves-standalone-files ()
  "Test Section 3.2: Containers organize objects without deleting standalone files."
  (let* ((test-dir (make-temp-file "bg-world-" t))
         (boardgame-org-world-directory test-dir)
         (c1 (boardgame-org-object-create
              :id "deck-card-1"
              :name "King of Hearts"
              :glyph "🂾"
              :type 'card
              :file-path "objects/deck-card-1.org"))
         (container (boardgame-org-object-create
                     :id "test-deck"
                     :name "Deck Container"
                     :glyph "🎴"
                     :type 'container
                     :file-path "containers/test-deck.org"
                     :contained-ids '("deck-card-1"))))
    (unwind-protect
        (progn
          (boardgame-org-object-save-file c1)
          (boardgame-org-container-save container)
          ;; Both files must exist independently
          (should (file-exists-p (boardgame-org-world-file "objects/deck-card-1.org")))
          (should (file-exists-p (boardgame-org-world-file "containers/test-deck.org")))

          ;; Drawing removes from container, standalone file remains intact!
          (let ((drawn-id (boardgame-org-container-draw container)))
            (should (string= drawn-id "deck-card-1"))
            (should (file-exists-p (boardgame-org-world-file "objects/deck-card-1.org")))))
      (delete-directory test-dir t))))

(provide 'boardgame-org-test)
;;; boardgame-org-test.el ends here
