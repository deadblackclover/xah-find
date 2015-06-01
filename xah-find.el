;;; xah-find.el --- find replace in pure emacs lisp. Purpose similar to unix grep/sed.

;; Copyright © 2012-2015 by Xah Lee

;; Author: Xah Lee ( http://xahlee.org/ )
;; Version: 2.1.0
;; Created: 02 April 2012
;; Keywords: convenience, extensions, files, tools, unix

;; This file is not part of GNU Emacs.

;;; License:

;; You can redistribute this program and/or modify it under the terms of the GNU General Public License version 2.

;;; Commentary:

;; Provides emacs commands for find/replace on multiple files, written entirely in emacs lisp.

;; This package provides the follow functions:

;; xah-find-text
;; xah-find-text-regex
;; xah-find-count
;; xah-find-replace-text
;; xah-find-replace-text-regex

;; Features:

;; • Pure emacs lisp. No dependencies on unix/linux grep/sed/find. Especially useful on Windows.

;; • Output is highlighted and clickable for jumping to occurence.

;; • Reliably Find/Replace string that contains newline chars.

;; • Reliably Find/Replace string that contains lots Unicode chars. See http://xahlee.info/comp/unix_uniq_unicode_bug.html and http://ergoemacs.org/emacs/emacs_grep_problem.html

;; • Reliably Find/Replace string that contains lots escape slashes or backslashes. For example, regex in source code, Microsoft Windows's path.

;; • Using emacs regex, not bash/perl etc regex.

;; These commands treats find/replace string as sequence of chars, not as lines as in grep/sed, so it's much more easier to find or replace a block of text, especially programing language source code.

;; The printed report is also not based on lines. Instead, visual separator are used for easy reading.

;; For each occurance or replacement, n chars will be printed before and after. The number of chars to show is defined by `xah-find-context-char-count-before' and `xah-find-context-char-count-after'

;; each “block of text” in output is one occurrence.
;; for example, if a line in a file has 2 occurrences, then the same line will be reported twice, as 2 “blocks”.
;; so, the number of blocks corresponds exactly to the number of occurrences.

;; Ignore directories.
;; Add the following in your init:

;; (setq
;;  xah-find-dir-ignore-regex-list
;;  [
;;   "\\.git/"
;;    ; more path regex here
;;   ])

;; TODO:
;; • add tab key to jump to results. consider other, check prev/next tradition in debugger or such
;; • add link jump to file, location
;; • make sure ^L displays as line
;; The output isn't beautiful. May be hard to read.
;; File path in output isn't clickable. (use M-x `ffap' for now.)
;; Highlighting is clunky (am using `highlight-lines-matching-regexp' instead of coding my own text properties)

;; I've been using this for 2 years, about every week, on linux (and Windows), on 5 thousand HTML files.

;; Do you find it useful? Help me make it better.
;; Buy Xah Emacs Tutorial
;; http://ergoemacs.org/emacs/buy_xah_emacs_tutorial.html

;;; INSTALL

;; To install manually, place this file in the directory 〔~/.emacs.d/lisp/〕

;; Then, place the following code in your emacs init file

;; (add-to-list 'load-path "~/.emacs.d/lisp/")
;; (autoload 'xah-find-text "xah-find" "find replace" t)
;; (autoload 'xah-find-text-regex "xah-find" "find replace" t)
;; (autoload 'xah-find-replace-text "xah-find" "find replace" t)
;; (autoload 'xah-find-replace-text-regex "xah-find" "find replace" t)
;; (autoload 'xah-find-count "xah-find" "find replace" t)

;;; HISTORY

;; version 2.1.0, 2015-05-30 Complete rewrite.
;; version 1.0, 2012-04-02 First version.

;;; TODO:
;; 2015-05-20 the feeble find-lisp-find-files is becoming a efficiency pain. It uses one regex to list all files, then you have to filter dir. And, there's no alternative except some “modern” API third-party shiny thing


;;; Code:

(require 'find-lisp) ; in emacs

(defcustom xah-find-context-char-count-before 100 "Number of characters to print before search string."
  :group 'xah-find
  )
(setq xah-find-context-char-count-before 100)

(defcustom xah-find-context-char-count-after 30 "Number of characters to print after search string."
  :group 'xah-find
  )
(setq xah-find-context-char-count-after 30)

(defcustom xah-find-dir-ignore-regex-list nil "A list or vector of regex patterns, if match, that directory will be ignored. Case is dependent on current value of `case-fold-search'"
  :group 'xah-find
  )
(setq
 xah-find-dir-ignore-regex-list
 [
  "\\.git/"

  "xahlee_info/php-doc/"
  "xahlee_info/node_api/"
  "xahlee_info/java8_doc/"
  "xahlee_info/css_transitions/"
  "xahlee_info/css3_spec_bg/"
  "xahlee_info/css_3_color_spec/"
  "xahlee_info/REC-SVG11-20110816/"
  "xahlee_info/python_doc_3.3.3/"
  "xahlee_info/python_doc_2.7.6/"
  "xahlee_info/jquery_doc/"
  "xahlee_info/javascript_ecma-262_5.1_2011/"
  "xahlee_info/git-bottomup/"
  "xahlee_info/dom-whatwg/"
  "xahlee_info/css_2.1_spec/"
  "xahlee_info/clojure-doc-1.6/"

  ])

(defcustom xah-find-file-separator nil "A string as visual separator." :group 'xah-find )
(setq xah-find-file-separator "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" )

(defcustom xah-find-occur-separator nil "A string as visual separator." :group 'xah-find )
(setq xah-find-occur-separator "──────────────────────────────────────────────────────────────────────\n" )



(defun xah-find--filter-list (φpredicate φsequence)
  "Return a new list such that φpredicate is true on all members of φsequence.
URL `http://ergoemacs.org/emacs/elisp_filter_list.html'
Version 2015-05-23"
  (delete
   "e3824ad41f2ec1ed"
   (mapcar
    (lambda (ξx)
      (if (funcall φpredicate ξx)
          ξx
        "e3824ad41f2ec1ed" ))
    φsequence)))

(defun xah-find--ignore-dir-p (φpath)
  "Return true if φpath should be ignored. Else, nil."
  (catch 'exit25001
    (mapc
     (lambda (x)
       (when (string-match x φpath) (throw 'exit25001 x)))
     xah-find-dir-ignore-regex-list)
    nil
    ))



;; (defun xah-find--display-formfeed-as-line ()
;;   "Modify a display-table that displays page-breaks prettily.
;; If the buffer inside ΦWINDOW has `page-break-lines-mode' enabled,
;; its display table will be modified as necessary."
;;   ;; code borrowed from Steve Purcell's https://github.com/purcell/page-break-lines GPL
;;   (progn
;;     (unless buffer-display-table
;;       (setq buffer-display-table (make-display-table)))
;;     (let* (
;;            (ξlinechar 9472)
;;            (ξglyph (make-glyph-code ξlinechar))
;;            (ξnew-display-entry (vconcat (make-list 60 ξglyph))))
;;       (unless (equal ξnew-display-entry (elt buffer-display-table ?\^L))
;;         (aset buffer-display-table ?\^L ξnew-display-entry)))))



(defvar xah-find-keymap nil "Keybinding for `xah-find.el output'")
(progn
  (setq xah-find-keymap (make-sparse-keymap))
  (define-key xah-find-keymap (kbd "TAB") 'xah-find-next-match)
  (define-key xah-find-keymap (kbd "<S-tab>") 'xah-find-previous-match)
  (define-key xah-find-keymap (kbd "<backtab>") 'xah-find-previous-match)
  (define-key xah-find-keymap (kbd "M-n") 'xah-find-next-file)
  (define-key xah-find-keymap (kbd "M-p") 'xah-find-previous-file)
  (define-key xah-find-keymap (kbd "RET") 'xah-find--jump-to-place)
  (define-key xah-find-keymap (kbd "<mouse-1>") 'xah-find--mouse-jump-to-place))

(defun xah-find-next-match ()
  "Put cursor to next occurrence."
  (interactive)
  (search-forward "❨" nil "NOERROR" ))

(defun xah-find-previous-match ()
  "Put cursor to previous occurrence."
  (interactive)
  (search-backward "❩" nil "NOERROR" )
  (left-char))

(defun xah-find-next-file ()
  "Put cursor to next file."
  (interactive)
  (search-forward "❮" nil "NOERROR" ))

(defun xah-find-previous-file ()
  "Put cursor to previous file."
  (interactive)
  (search-backward "❯" nil "NOERROR" )
  (left-char))

(defun xah-find--mouse-jump-to-place (φevent)
  "visit the file."
  (interactive "e")
  (let* ((ξwindow (posn-window (event-end φevent)))
         (ξpos (posn-point (event-end φevent)))
         (ξfpath (get-text-property ξpos 'xah-find-fpath))
         (ξpos-jump-to (get-text-property ξpos 'xah-find-pos)))
    (when (not (null ξfpath))
      (progn
        (find-file-other-window ξfpath)
        (when ξpos-jump-to (goto-char ξpos-jump-to))))))

(defun xah-find--jump-to-place ()
  "visit the file."
  (interactive)
  (let ((ξfpath (get-text-property (point) 'xah-find-fpath))
        (ξpos-jump-to (get-text-property (point) 'xah-find-pos)))
    (when (not (null ξfpath))
      (progn
        (find-file-other-window ξfpath)
        (when ξpos-jump-to (goto-char ξpos-jump-to))))))


(defun xah-find--backup-suffix (φs)
  "Return a string of the form 「~‹φs›~‹date time stamp›~」"
  (concat "~" φs (format-time-string "%Y%m%dT%H%M%S") "~"))

(defun xah-find--current-date-time-string ()
  "Returns current date-time string in this format 「2012-04-05T21:08:24-07:00」"
  (concat
   (format-time-string "%Y-%m-%dT%T")
   ((lambda (ξx) (format "%s:%s" (substring ξx 0 3) (substring ξx 3 5))) (format-time-string "%z"))))

(defun xah-find--print-header (φbufferObj φcmd φinput-dir φpath-regex φsearch-str &optional φreplace-str )
  "Print things"
  (princ
   (concat
    "-*- coding: utf-8 -*-" "\n"
    "Datetime: " (xah-find--current-date-time-string) "\n"
    "Result of: " φcmd "\n"
    (format "Directory ❮%s❯\n" φinput-dir )
    (format "Path regex ［%s］\n" φpath-regex )
    (format "Search string ❨%s❩\n" φsearch-str )
    (when φreplace-str (format "Replace string ❬%s❭\n" φreplace-str))
    xah-find-file-separator
    )
   φbufferObj))

;; (defun xah-find--print-occur-block (φp1 φp2 φbuff)
;;   "print "
;;   (princ
;;    (concat
;;     (buffer-substring-no-properties (max 1 (- φp1 xah-find-context-char-count-before )) φp1 )
;;     "❨"
;;     (buffer-substring-no-properties φp1 φp2 )
;;     "❩"
;;     (buffer-substring-no-properties φp2 (min (point-max) (+ φp2 xah-find-context-char-count-after )))
;;     "\n"
;;     xah-find-occur-separator)
;;    φbuff))

(defun xah-find--occur-output (φp1 φp2 φfpath φbuff &optional φno-context-string-p)
  "print to output, with text properties"
  (let (
        (ξp3 (max 1 (- φp1 xah-find-context-char-count-before )))
        (ξp4 (min (point-max) (+ φp2 xah-find-context-char-count-after )))
        ξtextBefore
        ξtextMiddle
        ξtextAfter)
    (put-text-property φp1 φp2 'face (list :background "yellow"))
    (put-text-property φp1 φp2 'xah-find-fpath φfpath)
    (put-text-property φp1 φp2 'xah-find-pos φp1)
    (add-text-properties φp1 φp2 '(mouse-face highlight))

    (setq ξtextBefore (buffer-substring ξp3 φp1 ))
    (setq ξtextMiddle (buffer-substring φp1 φp2 ))
    (setq ξtextAfter (buffer-substring φp2 ξp4))
    (with-current-buffer φbuff
      (if φno-context-string-p
          (insert "❨" ξtextMiddle "❩" "\n" xah-find-occur-separator )
        (insert ξtextBefore "❨" ξtextMiddle "❩" ξtextAfter "\n" xah-find-occur-separator )))))

;; (defun xah-find--print-replace-block (φp1 φp2 φbuff)
;;   "print "
;;   (princ (concat "❬" (buffer-substring-no-properties φp1 φp2 ) "❭" "\n" xah-find-occur-separator) φbuff))

(defun xah-find--print-file-count (φfilepath4287 φcount8086 φbuffObj32)
  "Print file path and count"
  (princ (format "%d ❮%s❯\n%s" φcount8086 φfilepath4287 xah-find-file-separator) φbuffObj32))

;; (defun xah-find--highlight-output (φbuffer &optional φsearch-str φreplace-str)
;;   "switch to φbuffer and highlight stuff"
;;   (let ((ξsearch (concat "❨" φsearch-str "❩"))
;;         (ξrep (concat "❬" φreplace-str "❭")))
;;     (switch-to-buffer φbuffer)
;;     (fundamental-mode)
;;     (progn
;;       (goto-char 1)
;;       (while (search-forward-regexp "❨\\([^❩]+?\\)❩" nil "NOERROR")
;;         (put-text-property
;;          (match-beginning 0)
;;          (match-end 0)
;;          'face (list :background "yellow"))))
;;     (progn
;;       (goto-char 1)
;;       (while (search-forward-regexp "❬\\([^❭]+?\\)❭" nil "NOERROR")
;;         (put-text-property
;;          (match-beginning 0)
;;          (match-end 0)
;;          'face (list :background "green"))))
;;     (progn
;;       (goto-char 1)
;;       (while (search-forward "❮" nil "NOERROR")
;;         (put-text-property
;;          (line-beginning-position)
;;          (line-end-position)
;;          'face (list :background "pink"))))
;;     (goto-char 1)
;;     (search-forward-regexp "━+" nil "NOERROR")
;;     (use-local-map xah-find-keymap)))

(defun xah-find--switch-to-output (φbuffer)
  "switch to φbuffer and highlight stuff"
  (let (p3 p4)
    (switch-to-buffer φbuffer)
    (progn
      (goto-char 1)
      (while (search-forward "❮" nil "NOERROR")
        (setq p3 (point))
        (search-forward "❯" nil "NOERROR")
        (setq p4 (- (point) 1))
        (put-text-property p3 p4 'xah-find-fpath (buffer-substring-no-properties p3 p4))
        (add-text-properties p3 p4 '(mouse-face highlight))
        (put-text-property (line-beginning-position) (line-end-position) 'face (list :background "pink"))))

    (goto-char 1)
    (search-forward "━" nil "NOERROR")
    (search-forward "❨" nil "NOERROR")
    (use-local-map xah-find-keymap)))



;;;###autoload
(defun xah-find-count (φsearch-str φcount-expr φcount-number φinput-dir φpath-regex)
  "Report how many occurances of a string, of a given dir.
Similar to `rgrep', but written in pure elisp.
Case sensitivity is determined by `case-fold-search'. Call `toggle-case-fold-search' to change.
\\{xah-find-keymap}"
  (interactive
   (let* ( ξoperator)
     (list
      (read-string (format "Search string (default %s): " (current-word)) nil 'query-replace-history (current-word))
      (setq ξoperator
            (ido-completing-read
             "Report on:"
             '("greater than" "greater or equal to" "equal" "not equal" "less than" "less or equal to" )))
      (read-string (format "Count %s: "  ξoperator) "0")
      (ido-read-directory-name "Directory: " default-directory default-directory "MUSTMATCH")
      (read-from-minibuffer "Path regex: " "\\.html$" nil nil 'dired-regexp-history))))
  (let* ((ξoutBufName "*xah-find output*")
         ξoutBufObj
         (ξcountOperator
          (cond
           ((string-equal "less than" φcount-expr ) '<)
           ((string-equal "less or equal to" φcount-expr ) '<=)
           ((string-equal "greater than" φcount-expr ) '>)
           ((string-equal "greater or equal to" φcount-expr ) '>=)
           ((string-equal "equal" φcount-expr ) '=)
           ((string-equal "not equal" φcount-expr ) '/=)
           (t (error "count expression 「%s」 is wrong!" φcount-expr ))))
         (ξcountNumber (string-to-number φcount-number)))
    (when (get-buffer ξoutBufName) (kill-buffer ξoutBufName))
    (setq ξoutBufObj (generate-new-buffer ξoutBufName))
    (xah-find--print-header ξoutBufObj "xah-find-count" φinput-dir φpath-regex φsearch-str )
    (mapc
     (lambda (ξf)
       (let ((ξcount 0))
         (with-temp-buffer
           (insert-file-contents ξf)
           (goto-char 1)
           (while (search-forward φsearch-str nil "NOERROR") (setq ξcount (1+ ξcount)))
           (when (funcall ξcountOperator ξcount ξcountNumber)
             (xah-find--print-file-count ξf ξcount ξoutBufObj)))))
     (xah-find--filter-list (lambda (x) (not (xah-find--ignore-dir-p x))) (find-lisp-find-files φinput-dir φpath-regex)))
    (xah-find--switch-to-output ξoutBufObj)))

;;;###autoload
(defun xah-find-text (φsearch-str1 φinput-dir φpath-regex φfixed-case-search-p φprintContext-p)
  "Report files that contain string.
By default, not case sensitive, and print surrounding text.
If `universal-argument' is called first, prompt to ask.
\\{xah-find-keymap}"
  (interactive
   (let ((ξdefault-input (if (use-region-p) (buffer-substring-no-properties (region-beginning) (region-end)) (current-word))))
     (list
      (read-string (format "Search string (default %s): " ξdefault-input) nil 'query-replace-history ξdefault-input)
      (ido-read-directory-name "Directory: " default-directory default-directory "MUSTMATCH")
      (read-from-minibuffer "Path regex: " "\\.html$" nil nil 'dired-regexp-history)
      (if current-prefix-arg (y-or-n-p "Fixed case in search?") nil )
      (if current-prefix-arg (y-or-n-p "Print surrounding Text?") t ))))
  (let* ((case-fold-search (not φfixed-case-search-p))
         (ξcount 0)
         (ξoutBufName "*xah-find output*")
         ξoutBufObj
         )
    (setq φinput-dir (file-name-as-directory φinput-dir)) ; normalize dir path
    (when (get-buffer ξoutBufName) (kill-buffer ξoutBufName))
    (setq ξoutBufObj (generate-new-buffer ξoutBufName))
    (xah-find--print-header ξoutBufObj "xah-find-text" φinput-dir φpath-regex φsearch-str1  )
    (mapc
     (lambda (ξpath)
       (setq ξcount 0)
       (with-temp-buffer
         (insert-file-contents ξpath)
         (while (search-forward φsearch-str1 nil "NOERROR")
           (setq ξcount (1+ ξcount))
           (when φprintContext-p (xah-find--occur-output (match-beginning 0) (match-end 0) ξpath ξoutBufObj)))
         (when (> ξcount 0) (xah-find--print-file-count ξpath ξcount ξoutBufObj))))
     (xah-find--filter-list (lambda (x) (not (xah-find--ignore-dir-p x))) (find-lisp-find-files φinput-dir φpath-regex)))
    (xah-find--switch-to-output ξoutBufObj)))

;;;###autoload
(defun xah-find-replace-text (φsearch-str φreplace-str φinput-dir φpath-regex φwrite-to-file-p φfixed-case-search-p φfixed-case-replace-p &optional φbackup-p)
  "Find/Replace string in all files of a directory.
Search string can span multiple lines.
No regex.
\\{xah-find-keymap}"
  (interactive
   (list
    (read-string (format "Search string (default %s): " (current-word)) nil 'query-replace-history (current-word))
    (read-string (format "Replace string: ") nil 'query-replace-history)
    (ido-read-directory-name "Directory: " default-directory default-directory "MUSTMATCH")
    (read-from-minibuffer "Path regex: " "\\.html$" nil nil 'dired-regexp-history)
    (y-or-n-p "Write changes to file?")
    (y-or-n-p "Fixed case in search?")
    (y-or-n-p "Fixed case in replacement?")
    (y-or-n-p "Make backup?")))
  (let ((ξoutBufName "*xah-find output*")
        ξoutBufObj
        (ξbackupSuffix (xah-find--backup-suffix "xf")))
    (when (get-buffer ξoutBufName) (kill-buffer ξoutBufName))
    (setq ξoutBufObj (generate-new-buffer ξoutBufName))
    (xah-find--print-header ξoutBufObj "xah-find-replace-text" φinput-dir φpath-regex φsearch-str φreplace-str )
    (mapc
     (lambda (ξf)
       (let ((case-fold-search (not φfixed-case-search-p))
             (ξcount 0))
         (with-temp-buffer
           (insert-file-contents ξf)
           (while (search-forward φsearch-str nil t)
             (setq ξcount (1+ ξcount))
             (replace-match φreplace-str φfixed-case-replace-p "literalreplace")
             (xah-find--occur-output (match-beginning 0) (point) ξf ξoutBufObj))
           (when (> ξcount 0)
             (when φwrite-to-file-p
               (when φbackup-p (copy-file ξf (concat ξf ξbackupSuffix) t))
               (write-region 1 (point-max) ξf))
             (xah-find--print-file-count ξf ξcount ξoutBufObj )))))
     (xah-find--filter-list (lambda (x) (not (xah-find--ignore-dir-p x))) (find-lisp-find-files φinput-dir φpath-regex)))
    (xah-find--switch-to-output ξoutBufObj)))

;;;###autoload
(defun xah-find-text-regex (φsearch-regex φinput-dir φpath-regex φfixed-case-search-p φprint-context-level )
  "Report files that contain a string pattern, similar to `rgrep'.
\\{xah-find-keymap}"
  (interactive
   (list
    (read-string (format "Search regex (default %s): " (current-word)) nil 'query-replace-history (current-word))
    (ido-read-directory-name "Directory: " default-directory default-directory "MUSTMATCH")
    (read-from-minibuffer "Path regex: " "\\.html$" nil nil 'dired-regexp-history)
    (y-or-n-p "Fixed case search?")
    (ido-completing-read "Print context level: " '("with context string" "just matched pattern" "none" ))))
  (let ((ξcount 0)
        (ξoutBufName "*xah-find output*")
        ξoutBufObj
        (ξpos1 1) ; beginning of line
        (ξpos2 1))
    (setq φinput-dir (file-name-as-directory φinput-dir)) ; add ending slash
    (when (get-buffer ξoutBufName) (kill-buffer ξoutBufName))
    (setq ξoutBufObj (generate-new-buffer ξoutBufName))
    (xah-find--print-header ξoutBufObj "xah-find-text-regex" φinput-dir φpath-regex φsearch-regex  )
    (mapc
     (lambda (ξfp)
       (setq ξcount 0)
       (with-temp-buffer
         (insert-file-contents ξfp)
         (setq case-fold-search (not φfixed-case-search-p))
         (while (search-forward-regexp φsearch-regex nil t)
           (setq ξcount (1+ ξcount))
           (cond
            ((equal φprint-context-level "none") nil)
            ((equal φprint-context-level "just matched pattern")
             (xah-find--occur-output (match-beginning 0) (match-end 0) ξfp ξoutBufObj))
            ((equal φprint-context-level "with context string")
             (xah-find--occur-output (match-beginning 0) (match-end 0) ξfp ξoutBufObj t))))
         (when (> ξcount 0) (xah-find--print-file-count ξfp ξcount ξoutBufObj))))
     (xah-find--filter-list (lambda (x) (not (xah-find--ignore-dir-p x))) (find-lisp-find-files φinput-dir φpath-regex)))
    (xah-find--switch-to-output ξoutBufObj)))

;;;###autoload
(defun xah-find-replace-text-regex (φregex φreplace-str φinput-dir φpath-regex φwrite-to-file-p φfixed-case-search-p φfixed-case-replace-p)
  "Find/Replace by regex in all files of a directory.
φregex is a regex pattern.
φreplace-str is replacement string.
φinput-dir is input directory to search (includes all nested subdirectories).
φpath-regex is a regex to filter file paths.
φwrite-to-file-p, when true, write to file, else, print a report of changes only.
φfixed-case-search-p sets `case-fold-search' for this operation.
φfixed-case-replace-p, if true, then the letter-case in replacement is literal. (this is relevant only if φfixed-case-search-p is true.)
\\{xah-find-keymap}"
  (interactive
   (list
    (read-regexp "Find regex: " )
    (read-string (format "Replace string: ") nil 'query-replace-history)
    (ido-read-directory-name "Directory: " default-directory default-directory "MUSTMATCH")
    (read-from-minibuffer "Path regex: " "\\.html$" nil nil 'dired-regexp-history)
    (y-or-n-p "Write changes to file?")
    (y-or-n-p "Fixed case in search?")
    (y-or-n-p "Fixed case in replacement?")))
  (let ((ξoutBufName "*xah-find output*")
        ξoutBufObj
        (ξbackupSuffix (xah-find--backup-suffix "xfr")))
    (when (get-buffer ξoutBufName) (kill-buffer ξoutBufName))
    (setq ξoutBufObj (generate-new-buffer ξoutBufName))
    (xah-find--print-header ξoutBufObj "xah-find-replace-text-regex" φinput-dir φpath-regex φregex φreplace-str )
    (mapc
     (lambda (ξfp)
       (let ((ξcount 0))
         (with-temp-buffer
           (insert-file-contents ξfp)
           (setq case-fold-search (not φfixed-case-search-p))
           (while (re-search-forward φregex nil t)
             (setq ξcount (1+ ξcount))
             ;; (xah-find--print-occur-block (match-beginning 0) (match-end 0) ξoutBufObj)
             (xah-find--occur-output (match-beginning 0) (match-end 0) ξfp ξoutBufObj t)
             (replace-match φreplace-str φfixed-case-replace-p)
             (xah-find--occur-output (match-beginning 0) (point) ξfp ξoutBufObj))
           (when (> ξcount 0)
             (xah-find--print-file-count ξfp ξcount ξoutBufObj)
             (when φwrite-to-file-p (copy-file ξfp (concat ξfp ξbackupSuffix) t) (write-region 1 (point-max) ξfp))))))
     (xah-find--filter-list (lambda (x) (not (xah-find--ignore-dir-p x))) (find-lisp-find-files φinput-dir φpath-regex)))
    (xah-find--switch-to-output ξoutBufObj)))

(provide 'xah-find)

;; Local Variables:
;; coding: utf-8
;; End:

;;; xah-find.el ends here
