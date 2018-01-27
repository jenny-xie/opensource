@echo off

set REL_HOME=..\..\home
set HOME=

rem // Save current directory and change to target directory
pushd %REL_HOME%

rem // Save value of CD variable (current directory)
set HOME=%CD%

rem // Restore original directory
popd

echo %HOME%> absolute-home-path