@echo off
rem // Get home dir & set as variable & winpython.ini
call set-winpython-home.bat

rem // Get absolute path to propositum root directory
set PROPOSITUM=%HOME%\..
cd %PROPOSITUM%
set PROPOSITUM=%cd%

rem // Initialize environment variables for WinPython CMD (links to the winpython version of Python)
call %PROPOSITUM%\app\winpythonzero\scripts\env.bat

rem// Re-set HOME variable
set HOME=%PROPOSITUM%home

rem // Set PYTHONHOME to empty to prevent clash with existing python installations
set PYTHONHOME=

rem // Navigate to emacs app directory
cd %PROPOSITUM%\app\emacs\bin

rem // Launch emacs
start runemacs.exe