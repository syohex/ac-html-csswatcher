;;; ac-html-csswatcher.el --- css/less class/id completion with `ac-html'

;; Copyright (C) 2015 Olexandr Sydorchuck

;; Author: Olexandr Sydorchuck  <olexandr.syd@gmail.com>
;; Version: 0.1.1
;; Keywords: html, css, less, auto-complete
;; Package-Requires: ((ac-html "0.3"))
;; URL: https://github.com/osv/ac-html-csswatcher

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; Prefix: ac-html-csswatcher-

;;; Commentary:

;; Preinstall:
;;
;; Install `csswatcher':
;;
;;   sudo cpan i CSS::Watcher
;;
;; Note:
;;
;; Please, keep CSS::Watcher up-to-date.
;; Recommended version of csswatcher is 0.4.0 (run `csswatcher -v'). Update:
;;
;;   sudo cpan i CSS::Watcher
;; 
;; Configuration, Emacs:
;;
;;   (require 'ac-html-csswatcher)
;;   (ac-html-csswatcher-setup)
;;
;; Configuration, project:
;;
;; File ".csswatcher" may indicate root of your project and used for set ignored files:
;;
;;   % cat .csswatcher
;;   # ignore all css
;;   ignore: \.css$
;;   # except app.css
;;   use: app\.css
;;
;; Otherwise projectile way used for root directory.
;;
;; So if you use `ac-html-bootstrap' and don't want to parse your bootstrap.css 
;; create in your project file .csswatcher with line:
;;
;;   ignore: bootstrap
;;
;; Note: completion will regenerated by csswatcher after saving css, less,
;; opening html files, or manually by `ac-html-csswatcher-refresh'.
;;
;;; Code:

(require 'ac-html)

(defvar ac-html-csswatcher-source-dir nil
  "This is variable bounded as alist in `ac-html-source-dirs',
 value is computed by csswatcher programm.")
(make-variable-buffer-local 'ac-html-csswatcher-source-dir)

(defcustom ac-html-csswatcher-command "/home/anon/work/css_watcher/csswatcher"
  "The \"csswatcher\" command to be run."
  :type 'string
  :group 'ac-html-csswatcher)

(defcustom ac-html-csswatcher-command-args '()
  "The extra arguments to pass to  ac-html-csswatcher-command'.
For example you can set --logfile, --pidfile, --debug, --outputdir."
  :type 'list
  :group 'ac-html-csswatcher)

;;; log util
(defvar ac-html-csswatcher-debug nil)
(defvar ac-html-csswatcher-log-buf-name "*ac-html-csswatcher debug*")
(defun ac-html-csswatcher-log-buf ()
  (get-buffer-create ac-html-csswatcher-log-buf-name))
(defsubst AC-HTML-CSSWATCHER-LOG (&rest messages)
  (ignore-errors
    (when ac-html-csswatcher-debug
      (require 'pp)
      (let* ((str (or (ignore-errors (apply 'format messages))
                      (pp-to-string (car messages))))
             (strn (concat str "\n")))
        (with-current-buffer (ac-html-csswatcher-log-buf)
          (goto-char (point-max))
          (insert strn))
        str))))

(defun ac-html-csswatcher-setup-html-stuff-async ()
  "Asynchronous call \"csswatcher\".
Set `ac-html-csswatcher-source-dir' with returned by csswatcher value after \"ACSOURCE: \""
  (when (buffer-file-name)
    (lexical-let ((csswatcher-process-name (concat "csswatcher-" (md5 (buffer-file-name))))
                  (csswatcher-output-bufffer (generate-new-buffer-name "*csswatcher-output*"))
                  (args (append ac-html-csswatcher-command-args (list buffer-file-name))))
      (AC-HTML-CSSWATCHER-LOG "=> Start process [%s]\n to buffer: %s" csswatcher-process-name csswatcher-output-bufffer)
      (set-process-sentinel
       (apply 'start-process
              csswatcher-process-name
              csswatcher-output-bufffer
              ac-html-csswatcher-command
              args)
       (lambda (proc event)
         (when (and (string= event "finished\n")
                    (= (process-exit-status proc) 0))
           (AC-HTML-CSSWATCHER-LOG "=> Process finished [%s]" proc)
           (setq ac-html-csswatcher-source-dir
                 (with-current-buffer csswatcher-output-bufffer
                   (when (string-match "PROJECT: \\(.*\\)$" (buffer-string))
                     (let ((project-dir (match-string 1 (buffer-string))))
                       (message "[csswatcher] parsed %s" project-dir)
                       (AC-HTML-CSSWATCHER-LOG "Project located: %s" project-dir))                       
                     (when (string-match "ACSOURCE: \\(.*\\)$" (buffer-string))
                       (match-string 1 (buffer-string))))))
           (AC-HTML-CSSWATCHER-LOG "Set ac-html-csswatcher-source-dir to %s\n"
                                   ac-html-csswatcher-source-dir proc )
           (kill-buffer csswatcher-output-bufffer)))))))

;;;###autoload
(defun ac-html-csswatcher-refresh ()
  "Interactive version of `ac-html-csswatcher-setup-html-stuff-async' with nice name.

Refresh csswatcher."
  (interactive)
  (ac-html-csswatcher-setup-html-stuff-async))

;;;###autoload
(defun ac-html-csswatcher+ ()
  "Enable csswatcher for this buffer, csswatcher called after each current buffer save."
  (interactive)
  (make-local-variable 'ac-html-source-dirs)
  (unless (assoc "Project" ac-html-source-dirs)
    (setq ac-html-source-dirs (cons (cons "Project" 'ac-html-csswatcher-source-dir) ac-html-source-dirs)))
  (ac-html-csswatcher-setup-html-stuff-async))

;;;###autoload
(defun ac-html-csswatcher-setup ()
  "1. Enable for web, html, haml etc hooks `ac-html-csswatcher+'

2. Setup `after-save-hook' for CSS modes.
Currently we suport only `css-mode' and `less-mode', but later style, sass, scsc etc will be included
when `csswatcher' support them."
  (mapc #'(lambda (mode)
            (add-hook mode 'ac-html-csswatcher+))
        '(html-mode-hook
          web-mode-hook
          slim-mode-hook
          jade-mode-hook
          haml-mode-hook))

  (mapc #'(lambda (mode)
            (add-hook mode
                      (lambda ()
                        (add-hook 'after-save-hook
                                  'ac-html-csswatcher-setup-html-stuff-async nil 'make-it-local))))
        '(css-mode-hook
          less-mode-hook)))

(provide 'ac-html-csswatcher)
;;; ac-html-csswatcher.el ends here
