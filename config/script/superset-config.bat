rem // Get home dir & set as variable & winpython.ini
call set-winpython-home.bat

rem // Get absolute path to propositum root directory
set PROPOSITUM=%HOME%\..
cd %PROPOSITUM%
set PROPOSITUM=%cd%

rem // Initialize environment variables for WinPython CMD (links to the winpython version of Python)
call %PROPOSITUM%\app\winpythonzero\scripts\env.bat

rem // Set PYTHONHOME to empty to prevent clash with existing python installations
set PYTHONHOME=

rem // Change to superset Scripts directory
cd %PROPOSITUM%\app\superset\Scripts

rem // Activate superset virtualenv
call activate.bat

rem// Re-set HOME variable
set HOME=%PROPOSITUM%\home

rem // Prompt user to create admin account
echo Please provide superset admin user details (hit RETURN to accept [defaults])
fabmanager create-admin --app superset

rem // DB Upgrade
python superset db upgrade

rem // Prompt user on loading sample data
echo Would you like to load the superset sample database?
set INPUT=
set /P INPUT=Enter y or n: %=%
If "%INPUT%"=="y" goto loadsample
If "%INPUT%"=="Y" goto loadsample
If "%INPUT%"=="n" goto appinit
If "%INPUT%"=="N" goto appinit

rem // Load sample data
:loadsample
python superset load_examples
goto appinit

rem // Initialize application
:appinit
python superset init

echo "superset configuration complete."