;;; test-boardgame-org.el --- Tests for boardgame-org  -*- lexical-binding: t; -*-

;; Copyright (C) 2024-2026 Free Software Foundation, Inc.

;; Author: Boardgame Org Contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (org "9.6"))
;; Keywords: games, extensions, org-mode

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

;; Unit tests for boardgame-org module.

;;; Code:

(require 'ert)
(require 'boardgame-org)


;;; Utility Tests

(ert-deftest boardgame--normalize-path ()
  "Test path normalization."
  (should (string-suffix-p "test" (boardgame--normalize-path "test/")))
  (should (string-suffix-p "test" (boardgame--normalize-path "test"))))

(ert-deftest boardgame--sanitize-filename ()
  "Test filename sanitization."
  (should (string= "test_name" (boardgame--sanitize-filename "test name")))
  (should (string= "test_name_123" (boardgame--sanitize-filename "test name 123"))))


;;; World Initialization Tests

(ert-deftest boardgame-init-world ()
  "Test world initialization."
  (let ((temp-dir (make-temp-file "boardgame-test-" t)))
    (boardgame-init-world temp-dir)
    (should (file-directory-p temp-dir))
    (should (file-directory-p (expand-file-name "boards" temp-dir)))
    (should (file-directory-p (expand-file-name "objects" temp-dir)))
    (should (file-directory-p (expand-file-name "hands" temp-dir)))
    (should (file-directory-p (expand-file-name "containers" temp-dir)))
    ;; Cleanup
    (delete-directory temp-dir t)))


;;; Board Tests

(ert-deftest boardgame--board-template ()
  "Test board template generation."
  (let ((template (boardgame--board-template "Test" 10 5 "")))
    (should (string-match "Board: Test" template))
    (should (string-match ":WIDTH: 10" template))
    (should (string-match ":HEIGHT: 5" template))))


;;; Object Tests

(ert-deftest boardgame--object-template ()
  "Test object template generation."
  (let ((template (boardgame--object-template "TestObject")))
    (should (string-match "\\* TestObject" template))
    (should (string-match ":OBJECT_TYPE: unspecified" template))))


;;; Navigation Marker Tests

(ert-deftest boardgame--marker-template ()
  "Test navigation marker template generation."
  (let ((template (boardgame--marker-template "Marker" 5 10 "Dungeon.org")))
    (should (string-match "\\* Marker" template))
    (should (string-match ":GLYPH: \\^" template))
    (should (string-match ":DESTINATION_BOARD: Dungeon.org" template))))


;;; Integration Tests

(ert-deftest boardgame-world-lifecycle ()
  "Test complete world lifecycle."
  (let ((temp-dir (make-temp-file "boardgame-int-" t)))
    ;; Initialize world
    (boardgame-init-world temp-dir)
    
    ;; Create a board
    (let ((board-file (expand-file-name "test-board.org"
                                        (expand-file-name "boards" temp-dir))))
      (boardgame-create-board "TestBoard" 20 10)
      (should (file-exists-p board-file)))
    
    ;; Cleanup
    (boardgame-close-frame)
    (delete-directory temp-dir t)))


;;; Load Tests

(ert-deftest boardgame-load-persistence ()
  "Test board load/save round-trip."
  (let ((temp-dir (make-temp-file "boardgame-load-" t))
        (board-file))
    (boardgame-init-world temp-dir)
    
    (setq board-file (expand-file-name "round-trip.org"
                                       (expand-file-name "boards" temp-dir)))
    
    ;; Create board
    (boardgame-create-board "RoundTrip" 10 5)
    
    ;; Save and reload
    (boardgame-save-board)
    
    ;; Verify file exists
    (should (file-exists-p board-file))
    
    ;; Cleanup
    (boardgame-close-frame)
    (delete-directory temp-dir t)))

(provide 'test-boardgame-org)
;;; test-boardgame-org.el ends here
