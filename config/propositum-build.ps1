echo "Setting variables."
# Drive that the propositum root will be mapped to (only needs to be changed if 'P:' is already taken on the deployment target)
$drv = "P:"
$propositumRoot = $drv + "\"
$propositumApp = $drv + "\app"
$propositumDL = $drv + "\propositum-dl"
$propositumHome = $drv + "\home"
$propositumConfig = $drv + "\config"
$propositumFont = $drv + "\font"

# Set HOME variable to propositum home directory
$env:HOME = $propositumHome

# URLs for either binary downloads of applications, latest github release page or the github repository itself to be cloned
$cmder = "https://github.com/cmderdev/cmder/releases/latest"
$knime = "https://download.knime.org/analytics-platform/win/knime-latest-win32.win32.x86_64.zip"
$emacs = "https://github.com/zklhp/emacs-w64/releases/latest"
$winpython = "https://github.com/winpython/winpython/releases/latest"
$spacemacs = "https://github.com/syl20bnr/spacemacs"
$rawgrpahs = "https://github.com/densitydesign/raw"
$autohotkey = "https://autohotkey.com/download/1.1/AutoHotKey_1.1.27.07.zip"

# Temporary direct binary DL links for pre-built binaries
$cmderDL = "https://github.com/cmderdev/cmder/releases/download/v1.3.4/cmder.7z"
$knimeDL = $knime
$emacsDL = "https://github.com/zklhp/emacs-w64/releases/download/e0284ab/emacs-w64-25.3-O2-with-modules.7z"
$winpythonDL = "https://github.com/winpython/winpython/releases/download/1.9.20171031/WinPython-64bit-3.6.3.0Zero.exe"
$autohotkeyDL = $autohotkey

Echo "Mapping propositum root to drive letter 'P:'."
# map the root folder to the supplied drive letter (default is P:)
subst $drv $env:APPVEYOR_BUILD_FOLDER # Set to current working directory (which should be C:\propositum, or wherever the files were cloned to)

Echo "Creating download folder for pre-built binaries."
# Download pre-built binaries (paths hardcoded for now...)
mkdir $propositumDL
cd $propositumDL
$WebClient = New-Object System.Net.WebClient

echo "Downloading & extracting Cmder..."
$WebClient.DownloadFile($cmderDL, "$propositumDL\cmder.7z")
7z x cmder.7z -o"$propositumApp\*" # '*' denotes fiename (sans-extension) is used as name of folder to extract to
rm cmder.7z

echo "Downloading & extracting KNIME..."
$WebClient.DownloadFile($knimeDL, "$propositumDL\knime.zip")
7z x knime.zip -o"$propositumApp\" # Removed '*' as we will rename the directory knime is already contained within, instead
rm knime.zip

echo "Downloading & extracting emacs..."
$WebClient.DownloadFile($emacsDL, "$propositumDL\emacs.7z")
7z x emacs.7z -o"$propositumApp\" # Removed '*' as emacs already contained within its own directory called 'emacs'
rm emacs.7z

echo "Downloading & extracting AutoHotKey..."
$WebClient.DownloadFile($autohotkeyDL, "$propositumDL\autohotkey.zip")
7z x autohotkey.zip -o"$propositumApp\*"
rm autohotkey.zip

echo "Downloading & extracting WinPython Zero..."
$WebClient.DownloadFile($winpythonDL, "$propositumDL\winpythonzero.exe")
./winpythonzero.exe /S /D="$propositumapp\winpythonzero" | Out-Null # Out-Null to force Powershell to wait until winpython extract finishes
rm winpythonzero.exe

echo "Renaming application directories.."
cd $propositumApp
Get-ChildItem -Directory knime* | Rename-Item -NewName knime

echo "Installing KNIME plugins..."
## TODO automate rather than hardcode this ##
cd $propositumApp
cd ./knime
# arguments for repository and installIU are both comma-separated strings
./eclipsec.exe -application org.eclipse.equinox.p2.director -noSplash -repository "http://update.knime.com/analytics-platform/3.5,http://update.knime.com/store/3.5,http://update.knime.com/community-contributions/trusted/3.5", -installIU "org.knime.features.ext.chromium.feature.group,org.knime.features.ext.exttool.feature.group,org.knime.features.exttool.feature.group,org.knime.features.base.filehandling.feature.group,org.knime.features.ext.birt.feature.group,org.knime.features.js.views.feature.group,org.knime.features.js.views.labs.feature.group,org.knime.features.ext.jfreechart.feature.group,org.knime.features.network.feature.group,org.pasteur.pf2.ngs.feature.feature.group,org.knime.features.ext.perl.feature.group,com.knime.features.enterprise.client.exampleserver.feature.group,org.knime.features.python2.feature.group,com.knime.features.reporting.designer.feature.group,org.knime.features.rest.feature.group,com.knime.features.explorer.serverspace.feature.group,org.knime.features.ext.svg.feature.group,org.knime.features.ext.tableau.feature.group,org.knime.features.ext.textprocessing.feature.group,org.knime.features.ext.webservice.client.feature.group,ws.palladian.nodes.feature.feature.group"

echo "Cloning & installing spacemacs..."
## spacemacs installation ##
cd $propositumHome
git clone https://github.com/syl20bnr/spacemacs .emacs.d 2> $null
echo "Installing spacemacs layers..."
cd $propositumApp
.\emacs\bin\emacs.exe --daemon --eval "(progn (configuration-layer/update-packages) (save-buffers-kill-emacs))" | Out-Null # Temporarily make a bit less verbose whilst troubleshooting AppVeyor build # Force spacemacs to load (as daemon), install required packages, then quit
cd $propositumHome
Remove-Item -path .\.emacs.d\.cache -recurse -force # Remove the cache folder to decrease overall artifact size

echo "Cloning & installing RAWgraphs..."
## rawgraphs installation ##
cd $propositumApp
choco install bower -y
# refresh path variable to include bower
foreach($level in "Machine","User") {
   [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
      # For Path variables, append the new values, if they're not already in there
      if($_.Name -match 'Path$') { 
         $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
      }
      $_
   } | Set-Content -Path { "Env:$($_.Name)" }
}
git clone https://github.com/densitydesign/raw.git rawgraphs 2> $null
cd rawgraphs
bower install
Rename-Item -Path ".\js\analytics.sample.js" -NewName "analytics.js"

### SHOULD ALWAYS BE LAST AS WINPYTHON PROMPT MESSES UP ENVIRONMENT VARIABLES ###
echo "Configuring WinPython Zero..."
## python configuration ##
cd $propositumRoot
set-executionpolicy unrestricted -force # To allow us to run the winpython PS1 script
./app/winpythonzero/scripts/WinPython_PS_Prompt.ps1 # Start the winpython shell
$env:home = "$propositumHome" # Set the home variable in the winpython shell
$env:pythonhome = "" # Sets to nothing to stop clash with existing python installation
pip install --upgrade setuptools pip # Ensure we have the latest version of key tools first
pip install virtualenv # Get python virtualenv

echo "Installing Superset via Python pip..."
## superset install & config ##
cd ./app
virtualenv superset
virtualenv superset --relocatable
cd ./superset/Scripts
./activate # Activate virtualenv -- important not to include '.bat' on the end otherwise powershell doesnt actually activate...
pip install superset
echo "Configuring Superset..."
fabmanager create-admin --app superset --username 'propositum' --firstname 'Propositum' --lastname 'Admin' --email 'propositum@propositum' --password "'"+$env:supersetpassword+"'" # Pre-populate admin info, $env:supersetpassword is an AppVeyor secure variable, encrypted using the Accounts > Encrypt Data tool on the AppVeyor site
python superset db upgrade
python superset load_examples
python superset init
deactivate # Exit the superset virtualenv, note: needs to NOT be proceeded by a './' otherwise doesnt work in Powershell!

### CREATE BUILD ARTIFACT ###
Remove-Item -path $propositumDL -recurse -force # Delete downloads directory
echo "Compressing files into release artifact..."
7z a -t7z -m0=lzma2:d1024m -mx=9 -aoa -mfb=64 -md=32m -ms=on C:\propositum\propositum.7z C:\propositum  # Additional options to increase compression ratio
