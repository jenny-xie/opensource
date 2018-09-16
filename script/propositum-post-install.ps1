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
ForEach ($var in $platformVars | Select 'var', $buildPlatform, 'exec') { # Narrow to required columns & $buildPlatform
    if ($var.var -like "env:*") { # If variable name contains 'env:'
        if ($var.exec -eq 'execute') {Set-Item -Path $var.var -Value (iex $var.$buildPlatform)}  # If we need to 'execute'
        else {Set-Item -Path $var.var -Value $var.$buildPlatform} # Else just assign
    }
    else { # Logic for non-environment variables
        if ($var.exec -eq 'execute') {New-Variable $var.var (iex $var.$buildPlatform) -Force}
        else {New-Variable $var.var $var.$buildPlatform -Force}
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
        if ($var.exec -eq "execute") {Set-Item -Path $var.var -Value (iex $var.value)} # If we need to 'execute'
        else {Set-Item -Path $var.var -Value $var.value} # Else just assign
    }
    elseif ($var.type -eq 'hsh-itm') { # Logic for hash table items
        $hsh = $var.var -split '\.' # Split the hash table item into a two-member array (note all hash table items must follow a hashtbl.keyname format)
        $hshtbl = iex ('$' + $hsh[0]) # Add '$' & define as hash table
        if ($var.exec -eq 'execute') {$hshtbl.add($hsh[1], (iex $var.value))}  # Add the key-value entry top the hash table: The first array entry is the hash table name, the second the name of the key
        else {$hshtbl.add($hsh[1], $var.value)}  # Same as above, but assign rather than invoke/execute the $var.value
    }
    else { # Logic for everything else (i.e. a regular variable)
        if ($var.exec -eq 'execute') {New-Variable $var.var (iex $var.value) -Force} 
        else {New-Variable $var.var $var.value -Force}
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
    'pandoc',
    'latex'
) 
$doomBin = $propositum.home + "\.emacs.d\bin"
$env:Path = $env:Path + ";" + $doomBin
iex "scoop cleanup **"; iex "scoop reset **"
