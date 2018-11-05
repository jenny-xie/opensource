;; -*- no-byte-compile: t; -*-
;;; lang/powershell/packages.el

(package! powershell)

(when (featurep! +babel)
 (package! ob-powershell :recipe (:fetcher github :repo "rkiggen/ob-powershell")))
