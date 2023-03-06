(require 'package)
(setenv "HOME" "/home/rstudio")
(let* ((no-ssl (and (memq system-type '(windows-nt ms-dos))
                    (not (gnutls-available-p))))
       (proto (if no-ssl "http" "https")))
  (when no-ssl (warn "\
Your version of Emacs does not support SSL connections,
which is unsafe because it allows man-in-the-middle attacks.
There are two things you can do about this warning:
1. Install an Emacs version that does support SSL and be safe.
2. Remove this warning from your init file so you won't see it again."))
  (add-to-list 'package-archives (cons "melpa" (concat proto "://melpa.org/packages/")) t)
  ;; Comment/uncomment this line to enable MELPA Stable if desired.  See `package-archive-priorities`
  ;; and `package-pinned-packages`. Most users will not need or want to do this.
  ;;(add-to-list 'package-archives (cons "melpa-stable" (concat proto "://stable.melpa.org/packages/")) t)
  )
(package-initialize)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-enabled-themes '(dichromacy adwaita light-blue))
 '(custom-safe-themes
   '("1436985fac77baf06193993d88fa7d6b358ad7d600c1e52d12e64a2f07f07176" default))
 '(package-selected-packages
   '(nodejs-repl magit citeproc citeproc-org web-mode web-mode-edit-element dumb-jump god-mode ts paredit paredit-everywhere smartparens ob-ada-spark ob-applescript ob-async ob-axiom ob-bitfield ob-blockdiag ob-browser ob-cfengine3 ob-clojurescript ob-coffee ob-coffeescript ob-compile ob-crystal ob-cypher ob-dao ob-dart ob-deno ob-diagrams ob-dsq ob-elixir ob-elm ob-elvish ob-ess-julia ob-fsharp ob-go ob-graphql ob-haxe ob-html-chrome ob-http ob-hy ob-ipython ob-julia-vterm ob-kotlin ob-latex-as-png ob-lfe ob-mermaid ob-ml-marklogic ob-mongo ob-napkin ob-nim ob-php ob-powershell ob-prolog ob-redis ob-restclient ob-reticulate ob-rust ob-sagemath ob-smiles ob-sml ob-solidity ob-spice ob-sql-mode ob-svgbob ob-swift ob-swiftui ob-tmux ob-translate ob-typescript ob-uart company company-statistics dockerfile-mode dracula-theme ess ess-R-data-view ess-r-insert-obj ess-smart-equals ess-smart-underscore ess-view-data fold-this poly-R poly-ansible poly-erb poly-markdown poly-noweb poly-org poly-rst poly-ruby poly-slim poly-wdl polymode python-mode python-x smex)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )


(ido-mode t)
(global-set-key (kbd "M-x") 'smex)
(global-set-key (kbd "M-X") 'smex-major-mode-commands)
;; This is your old M-x.
;;(global-set-key (kbd "C-c C-c M-x") 'execute-extended-command)

;;; Stefan Monnier <foo at acm.org>. It is the opposite of fill-paragraph    
    (defun unfill-paragraph (&optional region)
      "Takes a multi-line paragraph and makes it into a single line of text."
      (interactive (progn (barf-if-buffer-read-only) '(t)))
      (let ((fill-column (point-max))
            ;; This would override `fill-column' if it's an integer.
            (emacs-lisp-docstring-fill-column t))
        (fill-paragraph nil region)))

(defvar *r-target-buffer* "*r*")

(defun r-file-go-region (s e)
  (interactive "r")
  (comint-send-string *r-target-buffer*
		      (concat (buffer-substring s e)
			      (format "\n")))
  (pop-to-buffer *r-target-buffer*)
  (goto-char (point-max)))

(defun r-file-go ()
  (if mark-active
      (r-file-go-region (region-beginning)
			(region-end))
    (r-file-go-whole-file)))

(defun break-on-and-reflow (s e)
  (interactive "r")
  (let* ((pattern (read-string "String: "))
	 (code (buffer-substring s e))
	 (code* (replace-regexp-in-string (regexp-quote pattern)
					  (concat pattern (format "\n"))
					  code)))
    (delete-region s e)
    (let ((p (point)))
      (insert code*)
      (indent-region p (point)))))

(setq org-image-actual-width nil)

(defun rst-insert-twocol-template ()
  (interactive)
  (insert ".. container:: twocol

   .. container:: leftside
      
      left content

   .. container:: rightside

      right content

"))

(setq-default indent-tabs-mode nil)


(defun ir-eval-line ()
  (interactive)
  (let ((line (thing-at-point 'line)))
    (comint-send-string (get-buffer-process "*r*")
                        (format "%s\n" line))))

(defun write-org-to-md ()
  (interactive)
  (let* ((tmp org-export-show-temporary-export-buffer)
         (fn (buffer-file-name (current-buffer)))
         (ofn (replace-regexp-in-string "\.org$" ".md" fn)))
    (setq org-export-show-temporary-export-buffer nil)
    (org-md-export-as-markdown)
    (with-current-buffer (get-buffer "*Org MD Export*")
      (write-region (point-min)
                    (point-max)
                    ofn))))

(setq temporary-file-directory "~/.emacs-trash")
(setq backup-directory-alist
`((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
`((".*" ,temporary-file-directory t)))

(require 'ob-js)

(org-babel-do-load-languages
 'org-babel-load-languages
 '(
   (shell . t)
   (sqlite . t)
   (python . t)
   (emacs-lisp . t)
   (sqlite . t)
   (R . t)
   (python . t)
   (gnuplot . t)
   (js . t)
   ;; Include other languages here...
   ))

(add-to-list 'org-babel-tangle-lang-exts '("js" . "js"))

;; (org-babel-do-load-languages
;;  'org-babel-load-languages (quote ((emacs-lisp . t)
;;                                     (sqlite . t)
;;                                     (R . t)
;;                                     (python . t))))
;; Syntax highlight in #+BEGIN_SRC blocks
(setq org-src-fontify-natively t)
;; Don't prompt before running code in org
(setq org-confirm-babel-evaluate nil)
;; Fix an incompatibility between the ob-async and ob-ipython packages
(setq ob-async-no-async-languages-alist '("ipython"))

(defun insert-bash-block ()
  (interactive)
  (insert "#+begin_src sh :results code :exports both :dir /tmp/example

#+end_src
")
  (forward-line -2))

(defun insert-local-bash-bloack ()
  (interactive)
  (insert "#+begin_src sh :results code :exports both

#+end_src
")
  (forward-line -2))

(setq org-image-actual-width nil)
(put 'narrow-to-region 'disabled nil)

(defun rmd-mode ()
  "ESS Markdown mode for rmd files"
  (interactive)
  (setq load-path 
    (append (list "path/to/polymode/" "path/to/polymode/modes/")
        load-path))
  (require 'poly-R)
  (require 'poly-markdown)     
  (poly-markdown+r-mode))

(put 'downcase-region 'disabled nil)

(defun insert-file-name ()
  (interactive)
  (insert (ido-completing-read "File:" (split-string
                                        (shell-command-to-string "find . -type f")
                                        (format "\n")))))
(defun +shell-command-on-region ())

(add-hook 'emacs-lisp-mode-hook (lambda ()
                            (eldoc-mode t)
                            (paredit-mode t)
                            (show-paren-mode t)
                            (company-mode t)))

(add-hook 'org-mode-hook (lambda ()
                           (auto-fill-mode t)))



(defun insert-rubric ()
  (interactive)
  (insert "Thus half the grade will depend on the following criteria (10 points
each):

1.  Is the project documented? Is there a README which explains what
    the project contains, how to locate source data (if required), how
    to build the Docker image and how to construct the final result?
2.  The project should be portable to any machine which contains
    Docker. That is, the user who checks out the git repository should
    be able to build the Docker image, connect to it per the
    instructions graded in (1) and build the products without
    installing any libraries or other dependencies (except possibly
    downloading the source data set).
3.  Is the project traceable? Can a use examine (for instance) a Make
    file and understand which pieces of code and data produce each
    figure in the project?
4.  Is the git history comprehensible? Does the repository show small
    commits which focus on individual issues or large commits which are
    hard to understand?

40 points will be awarded based on average reviews from other class
members in the following criteria.

1.  Is there a document describing the data set and a few results of
    analysis? The document should contain about 4-6 figures.
2.  Are the figures understandable? It should be difficult to imagine a
    better way of showing the same data, particularly when the
    interpretation in the text of the report is considered.
3.  Does the paper make any interesting observations about the data
    set? It not, does it make a pretty coherent case that there isn't
    much interesting in the data set after all? A negative result
    should be conveyed effectively.
4.  Does the paper contain interesting suggestions for further
    analysis? These can be other data sets that might be appropriate,
    more sophisticated analysis, or suggestions for new experiments or
    data collection efforts?")
)

(defun raw-pwd ()
  (cl-second (split-string (pwd) (regexp-quote "Directory "))))

(defun comint-send-string* (buffer &rest args)
  (with-current-buffer buffer
    (goto-char (point-max))
    (insert (apply #'format args))
    (insert (format "\n"))
    (comint-send-string (get-buffer-process buffer) (format "\n"))))

(defun here-shell ()
  (interactive)
  (let* ((d (raw-pwd))
         (sb (shell "*here-shell*"))
         (sbp (get-buffer-process sb)))
    (comint-send-string* sb (format "cd %s\n" d))
    (with-current-buffer sb
      (cd d))
    (pop-to-buffer sb)))


(put 'narrow-to-page 'disabled nil)
(put 'upcase-region 'disabled nil)

(setq load-path 
      (append (list "~/emacs-lib/")
              load-path))

(require 's)

;(require 'shadchen)

(cl-defmacro chain (name &body body)
  `(let ((,name ,(car body)))
     ,@(cl-loop for term in (cdr body) collect
                `(setq ,name ,term))
     ,name))

;;ssh -l LOGIN proxy19.rt3.io -p 33346
;; (defun parse-remote-it-config (s)
;;   ())

;; (defun remoteit->sshconfig ()
;;   (interactive)
;;   (let ((s (read-string "Paste remoteit config: ")))
;;     ()))

;; (add-to-list 'load-path "~/work/elisp/clocker/")
;; (require 'clocker)

(defun v-unique-strings (lst-of-strings)
  (let ((tbl (make-hash-table :test 'equal)))
    (cl-loop for s in lst-of-strings
             if (not (gethash s tbl nil))
             collect (prog1 
                         s
                       (puthash s t tbl)))))


(defun org-babel-execute:js (body params)
  "Execute a block of Javascript code with org-babel.
This function is called by `org-babel-execute-src-block'."
  (message "Mine!")
  (let* ((org-babel-js-cmd (or (cdr (assq :cmd params)) org-babel-js-cmd))
	 (session (cdr (assq :session params)))
         (result-type (cdr (assq :result-type params)))
         (full-body (org-babel-expand-body:generic
		     body params (org-babel-variable-assignments:js params)))
         (wd (raw-pwd))
         (___ (message (format "Session is %S, wd is %S" session wd)))
	 (result (cond
		  ;; no session specified, external evaluation
		  ((string= session "none")
		   (let ((script-file (org-babel-temp-file "js-script-")))
		     (with-temp-file script-file
                       (insert (format "require(\"process\").chdir(%S);\n" wd))
                       (insert (format "__dirname = %S;\n" wd))
		       (insert                        
			;; return the value or the output
			(if (string= result-type "value")
			    (format org-babel-js-function-wrapper full-body)
			  full-body)))
		     (org-babel-eval
		      (format "NODE_PATH=%s %s %s" wd org-babel-js-cmd
			      (org-babel-process-file-name script-file)) "")))
		  ;; Indium Node REPL.  Separate case because Indium
		  ;; REPL is not inherited from Comint mode.
		  ((string= session "*JS REPL*")
		   (require 'indium-repl)
		   (unless (get-buffer session)
		     (indium-run-node org-babel-js-cmd))
		   (indium-eval full-body))
		  ;; session evaluation
		  (t
		   (let ((session (org-babel-prep-session:js
				   (cdr (assq :session params)) params)))
		     (nth 1
			  (org-babel-comint-with-output
			      (session (format "%S" org-babel-js-eoe) t body)
			    (dolist (code (list body (format "%S" org-babel-js-eoe)))
			      (insert (org-babel-chomp code))
			      (comint-send-input nil t)))))))))
    (org-babel-result-cond (cdr (assq :result-params params))
      result (org-babel-js-read result))))

(defun org-babel-js-read (results)
  "Convert RESULTS into an appropriate elisp value.
If RESULTS look like a table, then convert them into an
Emacs-lisp table, otherwise return the results as a string."
  (org-babel-read
   (if (and (stringp results)
	    (string-prefix-p "[" results)
	    (string-suffix-p "]" results))
       (org-babel-read
        (concat "'"
                (replace-regexp-in-string
                 "\\[" "(" (replace-regexp-in-string
                            "\\]" ")" (replace-regexp-in-string
                                       ",[[:space:]]" " "
				       (replace-regexp-in-string
					"'" "\"" results))))))
     results) t))

(setq erc-server "irc.libera.chat")
(setq erc-user-full-name "composite_higgs")
(setq erc-nick "composite_higgs")


(setq python-shell-interpreter "python3")

;; (require 'org-latex-impatient)

;; (setq org-latex-impatient-tex2svg-bin
;;         ;; location of tex2svg executable
;;       "/home/toups/.local/bin/tex2svg")

;; (require 'org-drill)

(setq max-lisp-eval-depth 10000)
(setq debug-on-error t)



(defun factorial (n)
    (let ((r 1))
      (cl-loop for i from 1 to n do
               (setq r (* r i)))
      r))


(defun binom ( n k)
  (/ (factorial n)
     (* (factorial k)
        (factorial (- n k)))))


(require 'dash)

(defun .get-last-screenshot-location ()
  (chain _
         (shell-command-to-string "ls -1 -t /home/toups/Pictures/Screenshot*.png")
         (split-string _ (format "\n"))
         (car _)))

(defun .org-insert-last-screenshot ()
  (interactive)
  (let* ((last-screenshot-location (.get-last-screenshot-location))
         (local-name (read-string "local-name prefix: "))
         (caption (read-string "caption: "))
         (start (point))
         (local-file-name (format "%s.png" local-name)))
    (when (file-exists-p local-file-name)
        (delete-file local-file-name))
    (copy-file last-screenshot-location local-file-name)
    (insert (format "#+CAPTION: %s\n#+NAME: %s\n[[./%s]]\n" caption local-name local-file-name))
    (indent-region start (point))))

(with-eval-after-load 'tramp
  (add-to-list 'tramp-methods
   '("snail"
     (tramp-login-program "snail")
     (tramp-login-args (("term") ("-p") ("%h") ("--no-raw")))
     (tramp-remote-shell "/bin/sh")
     (tramp-remote-shell-args ("-c")))))

(setq shell-file-name "/bin/bash")

(defun .pluck-file (fn)
  (chain _ (split-string fn "/")
         (reverse _)
         (car _)))

(defun .save-and-browserify ()
  (interactive)
  (let ((file (buffer-file-name (current-buffer))))
    (save-buffer)
    (shell-command-to-string (format "browserify %s -o bundle.js" (.pluck-file file)))))

(defun .equaltbl (&rest pairs)
  (let ((tbl (make-hash-table :test 'equal)))
    (cl-loop for (k v . rest) on pairs by #'cddr
             do (puthash k v tbl))
    tbl))

(defun .gethash-lazy-default (k tbl f)
  (let* ((sigil (gensym))
         (v (gethash k tbl sigil)))
    (if (eq v sigil) (funcall f) v)))

(cl-defmacro .thunk (&body body)
  `(lambda () ,@body))

(defun .insertf (format-string &rest args)
  (insert (apply #'format (cons format-string args))))

(require 'org)

(cl-defmacro when-not-on-host-machine (&body body)
  `(if (not (file-directory-p "/home/toups"))
       (progn ,@body)))

(cl-defmacro when-on-host-machine (&body body)
  `(if (file-directory-p "/home/toups")
    (progn ,@body)))

(setq org-archive-location (substitute-env-vars "$HOME/archive.org::* From %s"))
(setq org-agenda-files (list (substitute-env-vars "$HOME/main.org")))

;(global-set-key (kbd "<escape>") #'god-local-mode)

;; (when-not-on-host-machine
;;     (load-theme 'misterioso))

(setq org-todo-keywords
      '((sequence "TODO" "WAITING" "DAILY" "|" "DONE" "DELEGATED" "DEFUNCT")))

;; (with-current-buffer (find-file (substitute-env-vars "$HOME/main.org"))
;;   (org-todo-list)
;;   (delete-other-windows))

(server-start)

(setq inhibit-startup-screen t)

(when-on-host-machine
 (add-hook 'after-init-hook #'(lambda ()
                                (org-todo-list)
                                (display-buffer "*Org Agenda*"))))

(setq  org-tag-persistent-alist '((:startgroup . nil)
                                  ("quick" . ?q) ("hard" . ?h) ("underspeced" . ?u)
                                  (:endgroup . nil)))

(setq org-startup-indented t)

(require 'oc-csl)

