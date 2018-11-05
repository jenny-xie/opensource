;;; lang/powershell/config.el -*- lexical-binding: t; -*-


(def-package! ob-powershell
  :when (featurep! :feature org +babel)
  :after powershell org)
