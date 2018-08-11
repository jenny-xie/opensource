  function Path-CheckOrCreate {

  # Don't make parameters positionally-bound (unless explicitly stated) and make the Default set required with all
  [CmdletBinding(PositionalBinding=$False,DefaultParameterSetName="Default")]

      # Define Parameters incl. defaults, types & validation
      Param(
          # Allow an array of strings (paths)
          [Parameter(Mandatory,ParameterSetName="Default")]
          [Parameter(Mandatory,ParameterSetName="CreateDir")]
          [Parameter(Mandatory,ParameterSetName="CreateSymLink")]
          [string[]]$paths,

          # Parameter sets to allow either/or but not both, of createDir and createSymLink. createSymLink is an array of strings to provide the option of matching with multiple paths.
          [Parameter(ParameterSetName="CreateDir",Mandatory=$false)][switch]$createDir,
          [Parameter(ParameterSetName="CreateSymLink",Mandatory=$false)][string[]]$createSymLink = @() # Default value is an empty array to prevent 'Cannot index into null array'
     )

      # Create Arrs to collect the directories that exist/don't exist
      $existing = @()
      $notExisting = @()
      $existingSymLink = @()
      $notExistingSymLink = @()
      $createdDir = @()
      $createdSymLink = @()

      # Loop through directories in $directory
      for ($i = 0; $i -ne $paths.Length; $i++)
      {

          # If exists, add to existing, else add to not existing
          if (Test-Path $paths[$i]) {$existing += , $paths[$i]}
          else {$notExisting += , $paths[$i]}

          # If any symlinks have been provided, also do a check to see if these exist
          if ( ($createSymLink[$i]) -and (Test-Path $createSymLink[$i]) )
          {$existingSymLink += , $createSymLink[$i]}
          else {$notExistingSymLink += , $createSymLink[$i]}

          # Next, check if valid path
          if (Test-Path -Path $paths[$i] -IsValid)
          {
              # If user wants to create the directory, do so
              if ($createDir)
              {
                  if (mkdir $paths[$i]) {$createdDir += , $paths[$i]}
              }
              # If user wants to create a symbolic link, do so
              elseif ($createSymlink)
              {
              if(New-Item -ItemType SymbolicLink -Value $paths[$i] -Path $createSymLink[$i]) # Use the counter to select the right Symlink value
                  {$createdSymLink += , $createSymLink[$i]}
              }
          }
          else {Throw "An error occurred. Check the path is valid."}

      }

      # Write summary of directory operations to console [Turned off as annoying to see each time the command is run]
      #Write-Host "`n==========`n"
      #Write-Host "`n[Summary of Directory Operations]`n"
      #Write-Host "`nDirectories already exist:`n$existing`n"
      #Write-Host "`nDirectories that do not exist:`n$notExisting`n"
      #Write-Host "`nDirectories created:`n$createdDir`n"
      #Write-Host "`nSymbolic Links created:`n$createdSymLink`n"
      #Write-Host "`n==========`n"
    
      # Create a hash table of arrs, to access a given entry: place e.g. ["existing"] at the end of the expression
      # to get the arr value within add an index ref. e.g. ["existing"][0] for the first value within existing dirs
      $result = [ordered]@{
          existing = $existing
          existingSymLinks = $existingSymLink
          notExisting = $notexisting
          notExistingSymLinks = $notExistingSymLink
          createdDirs = $createdDir
          createdSymLinks = $createdSymLink
      }
    
      # Write results to the console
      Write-Host "`n================================="
      Write-Host "[Summary of Directory Operations]"
      Write-Host "=================================`n"
      Write-Host ($result | Format-Table | Out-String)
    
      return $result

  }

  function Github-CloneRepo ($opts, $compValsArr, $cloneDir) {
  Write-Host ("Cloning ... [ "+"~"+$compValsArr.user+"/"+$compValsArr.repo+" ]") -ForegroundColor Yellow -BackgroundColor Black
  $cloneUrl = ("https://github.com/"+$compValsArr.user+"/"+$compValsArr.repo)
  iex "git clone $opts $cloneUrl $cloneDir"
  }
