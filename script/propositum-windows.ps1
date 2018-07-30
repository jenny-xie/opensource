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

[environment]::setEnvironmentVariable('SCOOP',($propositum.root),'User')

iex (new-object net.webclient).downloadstring('https://get.scoop.sh')

scoop bucket add extras

scoop bucket add propositum 'https://github.com/xeijin/propositum-bucket.git'

scoop install cmder autohotkey knime-p rawgraphs-p regfont-p emacs-p doom-emacs-develop-p texteditoranywhere-p superset-p

if ($buildPlatform -eq "appveyor")
{
    Remove-Item -path $propositumDL -recurse -force # Delete downloads directory
    echo "Compressing files into release artifact..."
    7z a -t7z -m0=lzma2:d1024m -mx=9 -aoa -mfb=64 -md=32m -ms=on C:\propositum\propositum.7z C:\propositum  # Additional options to increase compression ratio
}

if ($buildPlatform -eq "appveyor") {$deploy = $true}
else {$deploy = $false}
