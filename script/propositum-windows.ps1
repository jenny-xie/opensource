### --- NOTE: If you are reading from the PS1 script you will find documentation sparse - this script is accompanied by an org-mode file used to literately generate it --- ####
### --- Please see https://github.com/xeijin/propositum for the accompanying README.org --- ###

cd $psScriptRoot

Try
{
    $components = Import-CSV "components.csv" | ?{ $_.status -ne "disabled" } | %{ $_.var = $_.var.Trim("[]"); $_}
}
Catch
{
    Throw "Check the CSV file actually exists and is formatted correctly before proceeding."
    $error[0]|format-list -force
}

cd $PSScriptRoot

# Testing / development mode  
$testing = $true

$buildPlatform = if ($env:APPVEYOR) {"appveyor"}
elseif ($testing) {"testing"} # For debugging locally
elseif ($env:computername -match "NDS.*") {"local-gs"} # Check for a GS NDS
else {"local"}

. ./propositum-helper-fns.ps1

Try
{
    $environmentVars = Import-CSV "vars-platform.csv"
}
Catch
{
    Throw "Check the CSV file actually exists and is formatted correctly before proceeding."
    $error[0]|format-list -force
}

$environmentVars | Select "exec", "var", $buildPlatform | ForEach-Object { if ($_.exec -eq "execute") {New-Variable $_.var (iex $_.$buildPlatform) -Force} else {New-Variable $_.var $_.$buildPlatform -Force}}

Try
{
    $otherVars = Import-CSV "vars-other.csv"
}
Catch
{
    Throw "Check the CSV file actually exists and is formatted correctly before proceeding."
    $error[0]|format-list -force
}

$otherVars | Select "exec", "var", "value" | ForEach-Object { if ($_.exec -eq "execute") {New-Variable $_.var (iex $_.value) -Force} else {New-Variable $_.var $_.value -Force}}

if ($testing -and $propositumLocation) {Remove-Item ($propositumLocation+"\*") -Recurse -Force}

# If git isn't installed, install it
if (-not (iex "choco list -lo" | ?{$_ -match "git.*"})) {iex "choco install git -y"}
# Refresh path variable to include git
Refresh-PathVariable

# Hash table with necessary details for the clone command
$propositumRepo = [ordered]@{
    user = "xeijin"
    repo = "propositum"
}

# Clone the repo
Github-CloneRepo "" $propositumRepo $propositumLocation

subst $drv $propositumLocation

$createdDirs = Path-CheckOrCreate -Paths $propositum.values -CreateDir

cd $propositum.root

[Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls11, Tls, Ssl3"

[environment]::setEnvironmentVariable('SCOOP',($propositum.app+"\scoop"),'User')

iex (new-object net.webclient).downloadstring('https://get.scoop.sh')

scoop install make

if (-not (Get-Command choco.exe)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

if (-not (Get-Command 7z.exe)) {choco install -y 7zip}
Refresh-PathVariable

if($alias:curl) {remove-item alias:curl}

if (-not (Get-Command curl.exe)) {choco install -y curl}
Refresh-PathVariable

if($alias:wget) {remove-item alias:wget}

if (-not (Get-Command curl.exe)) {choco install -y curl}
Refresh-PathVariable

if (-not (Get-Command aria2c.exe)) {choco install -y aria2c}
Refresh-PathVariable

foreach($component in $components)
{
    if ($component.service -eq "github-release") {
        Write-Host ("`n Finding ... "+$component.var+" :: [ "+$component.usage+" ] `n") -ForegroundColor Yellow -BackgroundColor Black
        $component.dl = Get-GHLatestReleaseDl $component
        continue
    }
    elseif ($component.service -eq "apache-dir-dl") {
        Write-Host ("`n Finding ... "+$component.var+" :: [ "+$component.usage+" ] `n") -ForegroundColor Yellow -BackgroundColor Black
        $component.dl = Get-LatestApacheDirDl $component.source $component.regex $component.var
        continue
    }
    else {continue}
}

$installResults = @()

function Install-Cmder
{
    # Search the components array & retrieve the correct array location
    $component = $components | ?{$_.var -eq "cmder"}
    $componentDir = ($propositum.app+"\"+$component.var)

    # Don't run this block if the component is listed as 'disabled' in the components table
    if ($component.status -eq "enabled") # ieq = case-insensitive equals
    {
          try {
              # Download the archive
              $componentDownload = Dl-ToDir -backend aria2c -allowRedirs -cdispFilename -uriFilename -uri $component.dl -dir $propositum.dl
              $componentArchive = $componentDownload[0]

              # As a portable installation, extract directly to the app folder
              7z x $componentArchive ("-o"+$propositum.app+"\*")

              # cd to the corect directory (necessary for relative symlinks)
              cd $propositum.home

              # Define symlink Paths & Values
              $symLinkPaths = ".\.cmder"
              $symLinkValues = "..\app\cmder\config"


              # Check if the .cmder directory exists in the home folder
              if ( -not (Path-CheckOrCreate -Paths ".\.cmder").Existing) 
              # if not move the existing config directory to create it
              {Move-Item -Path ($componentDir+"\config") -Destination ($propositum.home+"\.cmder") -Force}
              # Otherwise delete the existing config directory in preparation for symlink
              else {Remove-Item ($componentDir+"\config") -Recurse -Force}

              # Create symLinks
              Path-CheckOrCreate -Paths $symLinkPaths -CreateSymLink $symLinkValues

              # Symlink other bin dir
              cd $propositum.root
              Path-CheckOrCreate -Paths ".\util\bin" -CreateSymLink ".\app\cmder\bin\utils-bin"

              # Let user know component was successfully installed
              Write-InstallStatus $component $installResults "Succeeded"
          }
        catch {
            Write-InstallStatus $component $installResults "Failed"
        }
    }
    elseif ($component.status -eq "disabled") {
        # Let user know the component was disabled
        Write-InstallStatus $component $installResults "Disabled"
    }
    else {Write-InstallStatus $component $installResults "" "Empty or incorrect component status. Check the components table."}
}

Install-Cmder

function Install-emacs
{
    # Search the components array & retrieve the correct array locaiton
    $component = $components | ?{$_.var -eq "emacs"}
    $componentDir = ($propositum.app+"\"+$component.var)

    # Don't run this block if the component is listed as 'disabled' in the components table
    if ($component.status -eq "enabled")
    {
        try {
            # Download the archive
            $componentDownload = Dl-ToDir -backend aria2c -allowRedirs -cdispFilename -uriFilename -uri $component.dl -dir $propositum.dl
            $componentArchive = $componentDownload[0]

            # As a portable installation, extract directly to the app folder
            7z x $componentArchive ("-o"+$propositum.app+"\emacs")

            # Move to the component binaries directory
            cd ($componentDir+"\bin")

            # Define symLink data
            $symLinkPaths = ".\runemacs.exe", ".\emacsclientw.exe"
            $symLinkValues = "..\..\cmder\bin\runemacs.exe", "..\..\cmder\bin\emacsclientw.exe"

            # Create symlinks
            Path-CheckOrCreate -Paths $symLinkPaths -CreateSymLink $symLinkValues

            # Let user know component was successfully installed
            Write-InstallStatus $component $installResults "Succeeded"
        }
        catch {
            Write-InstallStatus $component $installResults "Failed"
        }
    }
    elseif ($component.status -eq "disabled") {
      # Let user know the component was disabled
      Write-InstallStatus $component $installResults "Disabled"
  }
    else {Write-InstallStatus $component $installResults "" "Empty or incorrect component status. Check the components table."}
}

Install-emacs

function Install-autohotkey
{
    # Search the components array & retrieve the correct array locaiton
    $component = $components | ?{$_.var -eq "autohotkey"}
    $componentDir = ($propositum.app+"\"+$component.var)

    # Don't run this block if the component is listed as 'disabled' in the components table
    if ($component.status -eq "enabled")
    {
        try {
            # Download the archive
            $componentDownload = Dl-ToDir -backend aria2c -allowRedirs -cdispFilename -uriFilename -uri $component.dl -dir $propositum.dl
            $componentArchive = $componentDownload[0]

            # As a portable installation, extract directly to the app folder
            7z x $componentArchive ("-o"+$propositum.app+"\autohotkey")

            # Let user know component was successfully installed
            Write-InstallStatus $component $installResults "Succeeded"
        }
        catch {
            Write-InstallStatus $component $installResults "Failed"
        }
    }
    elseif ($component.status -eq "disabled") {
      # Let user know the component was disabled
      Write-InstallStatus $component $installResults "Disabled"
  }
    else {Write-InstallStatus $component $installResults "" "Empty or incorrect component status. Check the components table."}
}

Install-autohotkey

function Install-doomemacs
{
    # Search the components array & retrieve the correct array locaiton
    $component = $components | ?{$_.var -eq "doom-emacs"}
    $componentDir = ($propositum.app+"\"+$component.var)
    $emacsd =  ($propositum.home+"\.emacs.d")

    # Change to $propositum.root
    cd $propositum.root

    # Don't run this block if the component is listed as 'disabled' in the components table
    if ($component.status -eq "enabled") # ieq = case-insensitive equals
    {
          try {

              # Clone & switch to 'develop' branch for latest fixes
              GitHub-CloneRepo "" $component $emacsd
              cd $emacsd
              iex "git checkout develop"

              # Symlink doom/bin
              cd ($emacsd) # Need to relative symlink so have to cd to path first
              Path-CheckOrCreate -Paths ".\bin" -CreateSymLink "..\..\app\cmder\bin\doom-bin"

              # Install Doom
              make | Out-Host # Ensure we can see output in console?

              # Complete doom installation |GETTING ERRORS WITH THIS CMD CURRENTRLY|
              #.\bin\doom.cmd -p $emacsd quickstart

              # Let user know component was successfully installed
              Write-InstallStatus $component $installResults "Succeeded"
          }
        catch {
            Write-InstallStatus $component $installResults "Failed"
        }
    }
    elseif ($component.status -eq "disabled") {
        # Let user know the component was disabled
        Write-InstallStatus $component $installResults "Disabled"
    }
    else {Write-InstallStatus $component $installResults "" "Empty or incorrect component status. Check the components table."}
}

Install-doomemacs

function Install-knime
{
    # Search the components array & retrieve the correct array locaiton
    $component = $components | ?{$_.var -eq "knime"}
    $componentDir = ($propositum.app+"\"+$component.var)

    # Don't run this block if the component is listed as 'disabled' in the components table
    if ($component.status -eq "enabled")
    {
        try {
            # Download the archive
            $componentDownload = Dl-ToDir -backend aria2c -allowRedirs -cdispFilename -uriFilename -uri $component.dl -dir $propositum.dl
            $componentArchive = $componentDownload[0]

            # As a portable installation, extract to default folder name
            7z x $componentArchive ("-o"+$propositum.app+"\")

            # Rename the versioned KNIME folder
            cd $propositum.app
            if (Get-ChildItem -Directory knime*) {Get-ChildItem -Directory knime* | Rename-Item -NewName knime}

            # Install KNIME plugins - arguments for repository and installIU are both comma-separated strings
            ./knime/eclipsec.exe -application org.eclipse.equinox.p2.director -noSplash -repository "http://update.knime.com/analytics-platform/3.5,http://update.knime.com/store/3.5,http://update.knime.com/community-contributions/trusted/3.5", -installIU "org.knime.features.ext.chromium.feature.group,org.knime.features.ext.exttool.feature.group,org.knime.features.exttool.feature.group,org.knime.features.base.filehandling.feature.group,org.knime.features.ext.birt.feature.group,org.knime.features.js.views.feature.group,org.knime.features.js.views.labs.feature.group,org.knime.features.ext.jfreechart.feature.group,org.knime.features.network.feature.group,org.pasteur.pf2.ngs.feature.feature.group,org.knime.features.ext.perl.feature.group,com.knime.features.enterprise.client.exampleserver.feature.group,org.knime.features.python2.feature.group,com.knime.features.reporting.designer.feature.group,org.knime.features.rest.feature.group,com.knime.features.explorer.serverspace.feature.group,org.knime.features.ext.svg.feature.group,org.knime.features.ext.tableau.feature.group,org.knime.features.ext.textprocessing.feature.group,org.knime.features.ext.webservice.client.feature.group,ws.palladian.nodes.feature.feature.group"

            # Symlink key emacs binaries to cmder bin folder, for injection into cmder PATH variable
            New-Item -ItemType SymbolicLink -Path ".\emacsclientw.exe" -Value "..\..\cmder\bin\emacsclientw.exe" # So org-protocol and other apps can launch emacsclient sessions

            # Let user know component was successfully installed
            Write-InstallStatus $component $installResults "Succeeded"
        }
        catch {
            Write-InstallStatus $component $installResults "Failed"
        }
    }
    elseif ($component.status -eq "disabled") {
      # Let user know the component was disabled
      Write-InstallStatus $component $installResults "Disabled"
  }
    else {Write-InstallStatus $component $installResults "" "Empty or incorrect component status. Check the components table."}
}

Install-knime

function Install-rawgraphs
{
    # Search the components array & retrieve the correct array locaiton
    $component = $components | ?{$_.var -eq "rawgraphs"}
    $componentDir = ($propositum.app+"\"+$component.var)

    # Change to $propositum.root
    cd $propositum.root

    # Don't run this block if the component is listed as 'disabled' in the components table
    if ($component.status -eq "enabled")
    {
        try {

            # Check if bower is installed, proceed with installation if not
            if (-not (choco list -lo | ?{$_ -match "bower.*"})) {choco install bower -y}

            # Refresh path variable to include Bower
            Refresh-PathVariable

            Github-CloneRepo "" $component $componentDir

            # Bower install & configuration
            cd $componentDir
            iex "bower install"
            Rename-Item -Path ".\js\analytics.sample.js" -NewName "analytics.js"

            # Let user know component was successfully installed
            Write-InstallStatus $component $installResults "Succeeded"
        }
        catch {
            Write-InstallStatus $component $installResults "Failed"
        }
    }
    elseif ($component.status -eq "disabled") {
          # Let user know the component was disabled
          Write-InstallStatus $component $installResults "Disabled"
      }
    else {Write-InstallStatus $component $installResults "" "Empty or incorrect component status. Check the components table."}
}

Install-rawgraphs

function Install-WinPython
{
    # Search the components array & retrieve the correct array locaiton
    $component = $components | ?{$_.var -eq "winpython"}
    $componentDir = ($propositum.app+"\"+$component.var)

    # Don't run this block if the component is listed as 'disabled' in the components table
    if ($component.status -eq "enabled")
    {
        try {
            # Download the archive
            $componentDownload = Dl-ToDir -backend aria2c -allowRedirs -cdispFilename -uriFilename -uri $component.dl -dir $propositum.dl
            $componentArchive = $componentDownload[0]

            # As a portable installation, extract directly to the app folder
            iex ($componentArchive+" /S /D="+$componentDir) | Out-Host # Out-Host to force Powershell to wait until winpython extract finishes

            # WinPython configuration
            set-executionpolicy unrestricted -force # To allow us to run the winpython PS1 script
            iex ($componentDir+"\scripts\WinPython_PS_Prompt.ps1") # Start the winpython shell
            $env:home = $propositum.home # Set the home variable in the winpython shell
            $env:pythonhome = "" # Sets to nothing to stop clash with existing python installation
            pip install --upgrade setuptools pip # Ensure we have the latest version of key tools first
            pip install virtualenv # Get python virtualenv

            # Let user know component was successfully installed
            Write-InstallStatus $component $installResults "Succeeded"
        }
        catch {
            Write-InstallStatus $component $installResults "Failed"
        }
    }
    elseif ($component.status -eq "disabled") {
          # Let user know the component was disabled
          Write-InstallStatus $component $installResults "Disabled"
      }
    else {Write-InstallStatus $component $installResults "" "Empty or incorrect component status. Check the components table."}
}

Install-WinPython

function Install-Superset
{
    # Search the components array & retrieve the correct array locaiton
    $component = $components | ?{$_.var -eq "superset"}
    $componentDir = ($propositum.app+"\"+$component.var)

    # Don't run this block if the component is listed as 'disabled' in the components table
    if ($component.status -eq "enabled")
    {
        try {

            ## superset install & config ##
            cd $propositum.App
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

            # Let user know component was successfully installed
            Write-InstallStatus $component $installResults "Succeeded"
        }
        catch {
            Write-InstallStatus $component $installResults "Failed"
        }
    }
    elseif ($component.status -eq "disabled") {
          # Let user know the component was disabled
          Write-InstallStatus $component $installResults "Disabled"
      }
    else {Write-InstallStatus $component $installResults "" "Empty or incorrect component status. Check the components table."}
}

Install-Superset

if ($buildPlatform -eq "appveyor")
{
    Remove-Item -path $propositumDL -recurse -force # Delete downloads directory
    echo "Compressing files into release artifact..."
    7z a -t7z -m0=lzma2:d1024m -mx=9 -aoa -mfb=64 -md=32m -ms=on C:\propositum\propositum.7z C:\propositum  # Additional options to increase compression ratio
}

if ($buildPlatform -eq "appveyor") {$deploy = $true}
else {$deploy = $false}
