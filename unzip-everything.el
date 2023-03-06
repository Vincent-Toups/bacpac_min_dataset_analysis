; -*- lexical-binding: t -*-
(require 'cl)

(cl-defmacro --> (name init &body body)
  `(let* ((,name ,init)
          ,@(cl-loop for form in body collect `(,name ,form)))
     ,name))

(defun has-extension? (filename ext)
  (--> %  (split-string filename (regexp-quote "."))
       (reverse %)
       (string-equal (car %) ext)))

(defun all-files-of-interest ()
  (--> % (shell-command-to-string "find canonical -type f")
       (split-string % (format "\n") t)
       (cl-loop for filename in % when
                (or (has-extension? filename "zip")
                    (has-extension? filename "csv")
                    (has-extension? filename "xpt"))
                collect filename)))

(defun all-zip-files ()
  (with-temp-buffer
    (insert-file "derived_data/zip-files.txt")
    (split-string (buffer-substring-no-properties (point-min) (point-max))
                  (format "\n") t)))

(defun join-strings (strings delim)
  (apply #'concat (cl-loop for (hd . tail) on strings by #'cdr
                           collect hd
                           when tail
                           collect delim)))

(defun file-stem (filename)
  (--> % (split-string filename (regexp-quote "."))
       (if (= (length %) 1) %
         (--> % (reverse %)
              (cdr %)
              (reverse %)
              (join-strings % "/")))))

(defun unzip-all ()
  (cl-loop for z in (all-zip-files) collect
           (progn
             (print (format "Unzipping %s" z));
             (print (list (shell-command-to-string (format "mkdir -p \"./%s\"" (file-stem z)))
                          (shell-command-to-string (format "unzip \"%s\" -d \"./%s\"" z (file-stem z))))))))

(unzip-all)

(shell-command-to-string "touch derived_data/unzipped-everything")
