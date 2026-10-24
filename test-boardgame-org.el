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
  (let ((result (boardgame--normalize-path "test")))
    (should (string-suffix-p "test" result))))

(ert-deftest boardgame--sanitize-filename ()
  "Test filename sanitization."
  (should (string= "test_name" (boardgame--sanitize-filename "test name")))
  (should (string= "test_name_123" (boardgame--sanitize-filename "test name 123"))))


;;; Template Tests

(ert-deftest boardgame--board-template ()
  "Test board template generation."
  (let ((template (boardgame--board-template "Test" 10 5 "")))
    (should (string-match "Board: Test" template))
    (should (string-match ":WIDTH: 10" template))
    (should (string-match ":HEIGHT: 5" template))))

(ert-deftest boardgame--object-template ()
  "Test object template generation."
  (let ((template (boardgame--object-template "TestObject")))
    (should (string-match "\\* TestObject" template))
    (should (string-match ":OBJECT_TYPE: unspecified" template))))

(ert-deftest boardgame--marker-template ()
  "Test navigation marker template generation."
  (let ((template (boardgame--marker-template "Marker" 5 10 "Dungeon.org")))
    (should (string-match "\\* Marker" template))
    (should (string-match ":GLYPH: \\^" template))
    (should (string-match ":DESTINATION_BOARD: Dungeon.org" template))))

(ert-deftest boardgame--container-template ()
  "Test container template generation."
  (let ((template (boardgame--container-template "TestContainer")))
    (should (string-match "\\* TestContainer" template))
    (should (string-match ":CONTAINER_TYPE: permanent" template))))


;;; Load Tests

(ert-deftest boardgame-load-persistence ()
  "Test package loading and basic functionality."
  (should (functionp 'boardgame-init-world))
  (should (functionp 'boardgame-create-board))
  (should (functionp 'boardgame-open-board))
  (should (functionp 'boardgame-save-board))
  (should (functionp 'boardgame-close-board))
  (should (functionp 'boardgame-create-object))
  (should (functionp 'boardgame-add-object))
  (should (functionp 'boardgame-delete-object))
  (should (functionp 'boardgame-drawing-mode))
  (should (functionp 'boardgame-navigate)))

(provide 'test-boardgame-org)
;;; test-boardgame-org.el ends here
