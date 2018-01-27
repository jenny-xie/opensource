@ECHO off

REM Adapted from: http://scripts.dragon-it.co.uk/scripts.nsf/docs/batch-add-line-to-INI-file!OpenDocument&ExpandSection=2&AutoFramed

set REL_HOME=..\..\home
set HOME=

rem // Save current directory and change to target directory
pushd %REL_HOME%

rem // Save value of CD variable (current directory)
set HOME=%CD%

rem // Restore original directory
popd

Set file=%HOME%\..\app\winpythonzero\settings\winpython.ini
Set section=[environment]
Set newline=HOME=%HOME%

if not exist "%file%" (
echo There is no ini file. Write new one:
(echo %section%
echo %newline%) > "%file%"
goto finished
)

find "%section%" < "%file%" > NUL || (
echo There is no %section% section already in file. Write new one:
(echo %section%) >> "%file%"
(echo %newline%) >> "%file%"
goto finished
)

find "%newline%" < "%file%" > NUL && (
echo The new line already exists in the file. Do nothing:
goto finished
)

echo The %section% section was found so looking for the line to add after

copy /y "%file%" "%file%.old" >NUL
del "%file%"

for /f "tokens=*" %%l in (%file%.old) do (
(echo %%l)>> "%file%"
if /i "%%l"=="%section%" (
echo Found %section% section, adding line
(echo %newline%)>> "%file%"
) 
)

:finished

echo.
echo Done.
