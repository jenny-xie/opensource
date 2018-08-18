$Host.UI.RawUI.BackgroundColor = ($bckgrnd = 'Black')

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

subst $drv $propositumLocation

$createdDirs = Path-CheckOrCreate -Paths $propositum.values -CreateDir

cd $propositum.root

[Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls11, Tls, Ssl3"
