;;; boardgame-org.el --- Tabletop game engine for Emacs with Org persistence -*- lexical-binding: t; -*-

;; Author: Buyn <buyn.tex@gmail.com>
;; URL: https://github.com/Buyn/boardgame-org
;; Version: 2.0.0
;; Package-Requires: ((emacs "27.1") (org "9.3"))
;; Keywords: games, org, tabletop, emacs-lisp

;;; Commentary:
;; Root loader for boardgame-org. Automatically adds `src.el/` to `load-path`
;; and loads the package implementation.

;;; Code:

(eval-and-compile
  (let* ((this-dir (file-name-directory
                    (or load-file-name
                        buffer-file-name
                        (and (boundp 'byte-compile-current-file) byte-compile-current-file)
                        default-directory)))
         (src-dir (expand-file-name "src.el" this-dir)))
    (when (and src-dir (file-directory-p src-dir))
      (add-to-list 'load-path (file-name-as-directory src-dir)))))

;; Load the implementation from src.el
(load "boardgame-org" nil t)

(provide 'boardgame-org)
;;; boardgame-org.el ends here
