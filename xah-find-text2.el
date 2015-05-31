
(defun xah-find-text (φsearch-str1 φinput-dir φpath-regex φfixed-case-search-p φprintContext-p)
  "Report files that contain string.
By default, not case sensitive, and print surrounding text.
If `universal-argument' is called first, prompt to ask."
  (interactive
   (let (
         (ξdefault-input
          (if (use-region-p)
              (buffer-substring-no-properties (region-beginning) (region-end))
            (current-word))))
     (list
      (read-string (format "Search string (default %s): " ξdefault-input) nil 'query-replace-history ξdefault-input)
      (ido-read-directory-name "Directory: " default-directory default-directory "MUSTMATCH")
      (read-from-minibuffer "Path regex: " nil nil nil 'dired-regexp-history)
      (if current-prefix-arg (y-or-n-p "Fixed case in search?") nil )
      (if current-prefix-arg (y-or-n-p "Print surrounding Text?") t ))))

  (let* (
         (case-fold-search (not φfixed-case-search-p))
         (ξcount 0)
         (ξoutputBufferName "*xah-find output*")
         ξoutputBufferBuffer
         ξp1 ; context begin position
         ξp2 ; context end position
         ξp3 ; match begin position
         ξp4 ; match end position
         )

    (setq φinput-dir (file-name-as-directory φinput-dir)) ; normalize dir path

    (when (get-buffer ξoutputBufferName) (kill-buffer ξoutputBufferName))
    (setq ξoutputBufferBuffer (generate-new-buffer ξoutputBufferName))

    (princ
     (concat
      "-*- coding: utf-8 -*-" "\n"
      "Datetime: " (xah-find--current-date-time-string) "\n"
      "Result of: xah-find-text\n"
      (format "Directory ［%s］\n" φinput-dir )
      (format "Path regex ［%s］\n" φpath-regex )
      (format "Search string ［%s］\n" φsearch-str1 )
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
      )
     ξoutputBufferBuffer)

    (mapc
     (lambda (ξpath)
       (setq ξcount 0)
       (with-temp-buffer
         (insert-file-contents ξpath)
         (while (search-forward φsearch-str1 nil "NOERROR")
           (setq ξcount (1+ ξcount))
           (setq ξp3 (- (point) (length φsearch-str1)))
           (setq ξp4 (point))
           (put-text-property ξp3 ξp4 'face (list :background "yellow"))
           (setq ξp1 (max 1 (- (match-beginning 0) xah-find-context-char-count-before )))
           (setq ξp2 (min (point-max) (+ (match-end 0) xah-find-context-char-count-after )))
           (put-text-property ξp1 ξp2 'face (list :background "yellow"))
           (when φprintContext-p
             (princ
              (concat "\n［" (buffer-substring ξp1 ξp2 ) "］\n\n" )

              ξoutputBufferBuffer
              )))
         (when (> ξcount 0)
           (princ
            (concat "• " (number-to-string ξcount) " " (propertize ξpath 'face (list :background "pink")))

            ξoutputBufferBuffer ))))

     (xah-find--filter-list
      (lambda (x)
        (not (xah-find--ignore-dir-p x)))
      (find-lisp-find-files φinput-dir φpath-regex)))

    (progn
      (switch-to-buffer ξoutputBufferBuffer)
      (put-text-property 1 20 'face 'highlight) ; works
      )))
