  $buildPlatform = if ($env:APPVEYOR) {"appveyor"}
  elseif ($testing) {"testing"} # For debugging locally
  elseif ($env:computername -match "NDS.*") {"local-gs"} # Check for NDS
  else {"local"}
   Try
   {
       $platformVars = Import-CSV "vars-platform.csv"
   }
   Catch
   {
       Throw "Check the CSV file actually exists and is formatted correctly before proceeding."
       $error[0]|format-list -force
   }
ForEach ($var in $platformVars | Select "var", $buildPlatform, "exec") { # Narrow to required columns & $buildPlatform
    if ($var.var -like "env:*") { # If variable name contains 'env:'
        if ($var.exec -eq "execute") {Set-Item -Verbose -Path $var.var -Value (iex $var.$buildPlatform)}  # If we need to 'execute'
        else {Set-Item -Verbose -Path $var.var -Value $var.$buildPlatform} # Else just assign
    }
    else # Logic for non-environment variables
        if ($var.exec -eq "execute") {New-Variable -Verbose $var.var (iex $var.$buildPlatform) -Force}
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
    if ($var.var -like "env:*") { # If variable name contains 'env:'
        if ($var.exec -eq "execute") {Set-Item -Verbose -Path $var.var -Value (iex $var.value)} # If we need to 'execute'
        else {Set-Item -Verbose -Path $var.var -Value $var.value} # Else just assign
    }
    else { # Logic for non-environment variables
        if ($var.exec -eq "execute") {New-Variable -Verbose $var.var (iex $var.value) -Force} 
        else {New-Variable -Verbose $var.var $var.value -Force}
    }
}

    subst $env:propositumDrv $env:propositumLocation
reg add HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /f /v "Propositum" /d "subst $propositumDrv $propositumLocation" # Add registry entry to map on startup
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
$doomBin = $propositum.home + "\.emacs.d\bin"
$env:Path = $env:Path + ";" + $doomBin
iex "scoop cleanup **"; iex "scoop reset **"
