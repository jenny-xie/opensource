  (require 'org)
  ;(require 'json)

(let ((csv-path (quote "")))
  (with-temp-buffer
    (org-table-import csv-path nil) ;; MEMO on `nil' arg is in the footnotes.
    (setq LST (org-table-to-lisp))
    ;; comment out or cut below one line if you don't have column names in CSV file.
    (append (list (car LST)) '(hline) (cdr (org-table-to-lisp))))
)

(let ((csv-path (quote ""))
      (tbl-name (quote "")))
  (save-excursion
    (org-open-link-from-string (concat "[[" tbl-name "]]"))
    (while (not (org-table-p)) (forward-line))
    (org-table-export csv-path "orgtbl-to-csv"))
)
