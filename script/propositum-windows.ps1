### --- NOTE: If you are reading from the PS1 script you will find documentation sparse, --- ###
### --- this script is accompanied by an org-mode file used to literately generate it.   --- ###
### --- Please see https://github.com/xeijin/propositum for the accompanying README.org  --- ###

  cd $psScriptRoot

$promptPropositumDrv = if(($result = Read-Host -Prompt "Please provide a letter for the Propositum root drive (default is 'P').") -eq ""){("P").Trim(":")+":"}else{$result.Trim(":")+":"} 
$promptGitHubAPIToken = Read-Host -AsSecureString -Prompt "Please provide your GitHub token." 
$promptSupersetPassword = Read-Host -AsSecureString -Prompt "Please provide a password for the Superset user 'Propositum'."

$testing = $false

  $buildPlatform = if ($env:APPVEYOR) {"appveyor"}
  elseif ($testing) {"testing"} # For debugging locally
  elseif ($env:computername -match "NDS.*") {"local-gs"} # Check for NDS
  else {"local"}

  cd $PSScriptRoot

  $Host.UI.RawUI.BackgroundColor = ($bckgrnd = 'Black')

   . ./propositum-helper-fns.ps1

   Try
   {
       $platformVars = Import-CSV "vars-platform.csv"
   }
   Catch
   {
       Throw "Check the CSV file actually exists and is formatted correctly before proceeding."
       $error[0]|format-list -force
   }

ForEach ($var in $platformVars | Select 'var', $buildPlatform, 'exec') { # Narrow to required columns & $buildPlatform
    if ($var.var -like "env:*") { # If variable name contains 'env:'
        if ($var.exec -eq 'execute') {Set-Item -Verbose -Path $var.var -Value (iex $var.$buildPlatform)}  # If we need to 'execute'
        else {Set-Item -Verbose -Path $var.var -Value $var.$buildPlatform} # Else just assign
    }
    else { # Logic for non-environment variables
        if ($var.exec -eq 'execute') {New-Variable -Verbose $var.var (iex $var.$buildPlatform) -Force}
        else {New-Variable -Verbose $var.var $var.$buildPlatform -Force}
    }
}

   Try
   {
       $otherVars = Import-CSV "vars-other.csv"
   }
   Catch
   {
       Throw "Check the CSV file actually exists and is formatted correctly before proceeding."
       $error[0]|format-list -force
   }

ForEach ($var in $otherVars) {
    if (($var.var -like "env:*") -or ($var.type -eq 'env-var')) { # If variable name contains 'env:', or is type 'env-var'
        if ($var.exec -eq "execute") {Set-Item -Verbose -Path $var.var -Value (iex $var.value)} # If we need to 'execute'
        else {Set-Item -Verbose -Path $var.var -Value $var.value} # Else just assign
    }
    elseif ($var.type -eq 'hsh-itm') { # Logic for hash table items
        $hsh = $var.var -split '\.' # Split the hash table item into a two-member array (note all hash table items must follow a hashtbl.keyname format)
        $hshtbl = iex ('$' + $hsh[0]) # Add '$' & define as hash table
        if ($var.exec -eq 'execute') {$hshtbl.add($hsh[1], (iex $var.value))}  # Add the key-value entry top the hash table: The first array entry is the hash table name, the second the name of the key
        else {$hshtbl.add($hsh[1], $var.value)}  # Same as above, but assign rather than invoke/execute the $var.value
    }
    else { # Logic for everything else (i.e. a regular variable)
        if ($var.exec -eq 'execute') {New-Variable -Verbose $var.var (iex $var.value) -Force} 
        else {New-Variable -Verbose $var.var $var.value -Force}
    }
}

$propositum | Format-Table | Out-String | Write-Host

  if ($testing -and $env:propositumLocation) {Remove-Item ($env:propositumLocation+"\*") -Recurse -Force}

    subst $env:propositumDrv $env:propositumLocation

    $createdDirs = Path-CheckOrCreate -Paths $propositum.values -CreateDir

    cd $propositum.root

  [Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls11, Tls, Ssl3"

  iex (new-object net.webclient).downloadstring('https://get.scoop.sh')

  scoop bucket add extras

  scoop bucket add propositum 'https://github.com/xeijin/propositum-bucket.git'

  # Hash table with necessary details for the clone command
  $propositumRepo = [ordered]@{
      user = "xeijin"
      repo = "propositum"
  }

  # Clone the repo (if not AppVeyor as it is already cloned for us)
  if(-not $buildPlatform -eq "appveyor"){Github-CloneRepo "" $propositumRepo $env:propositumLocation}

$propositumScoop = @(
    'cmder',
    'lunacy',
    'autohotkey',
    'miniconda3',
    'imagemagick',
    'knime-p',
    'rawgraphs-p',
    'regfont-p',
    'emacs-p',
    'texteditoranywhere-p',
    'superset-p',
    'pandoc'
)

$componentsToInstall = $propositumScoop -join "`r`n=> " | Out-String
Write-Host "`r`nThe following components will be installed:`r`n`r`n=> $componentsToInstall" -ForegroundColor Black -BackgroundColor Yellow

Invoke-Expression "scoop install $propositumScoop"

Push-Location $propositum.home

git clone https://github.com/hlissner/doom-emacs .emacs.d; cd .emacs.d; git checkout develop

$doomBin = $propositum.home + "\.emacs.d\bin"
$env:Path = $env:Path + ";" + $doomBin

Refresh-PathVariable

doom quickstart

Pop-Location

if ($buildPlatform -eq "appveyor")
{
    echo "Compressing files into release artifact..."

    # iex "7z a -t7z -m0=lzma2:d=1024m -mx=9 -aoa -mfb=64 -md=32m -ms=on C:\propositum\propositum.7z C:\propositum"  # Additional options to increase compression ratio
    iex "7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on propositum.7z C:\propositum"
}

  if ($buildPlatform -eq "appveyor") {$deploy = $true}
  else {$deploy = $false}
