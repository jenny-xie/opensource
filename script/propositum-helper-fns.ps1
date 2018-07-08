function Get-GHLatestReleaseDl ($compValsArr) {
# Original: https://www.helloitscraig.co.uk/2016/02/download-the-latest-repo.html

# --- Set the uri for the latest release
$URI = "https://api.github.com/repos/"+$compValsArr.user+"/"+$compValsArr.repo+"/releases/latest"

# --- Query the API to get the url of the zip

# Switch to supported version of TLS protocol (1.2) for Github
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Traverse the 
$latestRelease = Invoke-RestMethod -Method Get -Uri $URI
$allReleaseAssets = Invoke-RestMethod -Method Get -URI $latestRelease.assets_url

# RegEx to isolate the filename (and version number if multiple artifacts)
$releaseAsset = $allReleaseAssets -match $compValsArr.regex

# Store a sorted list of download URLs (as if contianing version number we want highest at top)
$downloadUrl = $releaseAsset.browser_download_url | Sort-Object -Descending

# Check if the downloadUrl is an array, if true return first array value (i.e. highest ver number)
If ($downloadUrl -is [array]) {return $downloadUrl[0]}

# If not array, must be single download url, return as string
Else {return $downloadUrl}
}

function Get-LatestApacheDirDl ($directoryUrl, $fileRegex, $componentVarName) {

    $componentRegex = "^" + $componentVarName + ".*$"
    $versionRegex = "^(\d*\.\d+)*\/$|^(\d+)*\/$"

    $regexArr = $componentRegex, $versionRegex

    function Get-SiteAsObject ($uri) {
        # Get the HTML and parse
        return (Invoke-WebRequest $uri)
    }

    function Get-UrlFragWithRegex ($siteData, $regex)
    {
        # Initialise Variable
        #$frag = ""
        # Perform match and assign to variable
        $frag = $siteData.Links.href -match $regex | sort -Descending
        #{$frag = $Matches | sort -Descending} # sort descending to get highest ver number
        # Return first element (highest ver) if multiple matches
        If ($frag -is [array]) {return $frag[0]}
        # Otherwise just return as-is
        Else {return $frag}
    }

    #### Function still needs some work, incorrectly parsing table (i.e. not capturing dates)    
    #    function Get-ApacheDirTable ($directoryUrl) {
    #    $directoryUrl.ParsedHtml.getElementsByTagName("tbody") | ForEach-Object {
    #
    #    $Headers = $null
    #
    #    # Might need to uncomment the following line depending on table being parsed
    #    # And if there is more than one table, need a way to get the right headers for each table
    #    #$Headers = @("IP Address", "Hostname", "HW Address", "Device Type")
    #
    #    # Iterate over each <tr> in this table body
    #    $_.getElementsByTagName("tr") | ForEach-Object {
    #        # Select/get the <td>'s, but just grab the InnerText and make them an array
    #        $OutputRow = $_.getElementsByTagName("td") | Select-Object -ExpandProperty InnerText
    #        # If $Headers not defined, this must be the first row and must contain headers
    #        # Otherwise create an object out of the row by building up a hash and then using it to make an object
    #        # These objects can be piped to a lot of different cmdlets, like Out-GridView, ConvertTo-Csv, Format-Table, etc.
    #        if ($Headers) {
    #            $OutputHash = [ordered]@{}
    #            for($i=0;$i -lt $OutputRow.Count;$i++) {
    #                $OutputHash[$Headers[$i]] = $OutputRow[$i]
    #            }
    #            New-Object psobject -Property $OutputHash
    #        } else {
    #            $Headers = $OutputRow
    #
    #        }
    #    }
    #}
    #}
    ### 

    # Initialise variables for loop
    $site = Get-SiteAsObject $directoryUrl
    $match = ""
    $file = ""

    Do {
        ForEach ($regex in $regexArr) {
            # Check each time if the file can be found in the current dir
            $file = Get-UrlFragWithRegex $site $fileRegex
            if ($file -match $fileRegex) {
                ### COMMENTED OUT OBJ ROUTINE AS NOT PARSING DATES ###
                # File found, but let's be extra cautious and isolate those with the latest date
                #$sitePsObj = Get-ApacheDirTable $site
                # Then find the latest date & filter the table
                #$sitePsObj | Where-Object {$_.Name -match $fileRegex}
                # Break out of the loop and return the full URL
                ### END PS OBJ ROUTINE ###
                $directoryUrl = $directoryUrl+$file
                break
            }
            # Otherwise crawl through the RegEx array attempting to find a directory that matches
            else {
                $match = Get-UrlFragWithRegex $site $regex
                $directoryUrl = $directoryUrl+$match
                # Re-initialize the $site object each time we find a match so that we 'enter' the directory
            $site = Get-SiteAsObject $directoryUrl
                continue
            }
        }
    }
    Until ($file -match $fileRegex)

    # Finally, return the full download Url
    return $directoryUrl
}

function Dl-ToDir {
    # Define Parameters incl. defaults, types & validation
    Param(
    # Define accepted backends, each needs its own hash table entry in switch
    [ValidateSet("curl", "wget", "aria2c")]
    [string]$backend = "aria2c", # default

    # Convenience switches for common behaviours we might need to toggle
    [switch]$allowRedirs,
    [switch]$cdispFilename,
    [switch]$uriFilename,

    # Allow user to specify customFilename, which will disable other options
    [string]$customFilename,

    # Allow user to pass arbitrary options
    [string[]]$opts,

    # Make URI mandatory to avoid hash table init issues later
    [parameter(Mandatory=$true)]
    [string]$uri,

    # Check dir exists before accept
    [ValidateScript({Test-Path $_ -PathType 'Container'})]
    $dir = ($dir+"\") # default to current dir if not provided or add backslash to path
    )

    # Define mapping of common commands for each backend
    switch ($backend)
    {
        "curl"
            {
             $cmdMap = [ordered]@{
                        backend = $backend+".exe"; # append .exe to workaround powershell alias issue...
                        allowRedirs = "-L";
                        cdispFilename = "-J";
                        uriFilename = "-O";
                        customFilename = ("-o '"+$customFilename+"'");
                        progressBar = "-#"; # 'graphical' progress indicator, rather than 'tabular' progress indicator
                        uri = $uri;
                        }
            }

        "wget"
            {
             $cmdMap = [ordered]@{
                        backend = $backend+".exe"; # append .exe to workaround powershell alias issue...
                        allowRedirs = if(-not ($allowRedirs)) {"--max-redirect=0"}; # wget allows redirs by default, so disable if switch is false
                        cdispFilename = "--content-disposition";
                        uriFilename = if(-not ($cdispFilename)) {("-O '"+($uri | Split-Path -Leaf)+"'")}; # Get filename from path only if user doesn't want to try sourcing from Content-Disposition
                        customFilename = ("-O '"+$customFilename+"'");
                        overWrite = "-N"; # Note this will only overwrite if the server file timestamp is newer than the local, for 'true' overwrite use the customFilename option
                        progressBar = "--progress=bar:force:noscroll";
                        uri = $uri;
                        }
            }

        "aria2c"
            {
             $cmdMap = [ordered]@{
                        backend = $backend;
                        allowRedirs = ""; # no effect - aria decides this itself
                        cdispFilename = ""; # no effect - aria decides this itself
                        uriFilename = if(-not ($cdispFilename)) {("--out='"+($uri | Split-Path -Leaf)+"'")}; # Get filename from path only if user doesn't want to try sourcing from Content-Disposition
                        customFilename = ("--out='"+$customFilename+"'");
                        overWrite = "--allow-overwrite=true"; # always overwrite an existing file, since mostly we will be running from build servers which start with a fresh env each time. Also prevents creation of .aria control files.
                        dontResume = "--always-resume=false"; # prevent aria from resuming downloads
                        uri = $uri;
                        }
            }

        default # For an unknown backend
            {
            Throw ("Error: backend '"+$backend+"' not found.")
            }
    }

## De-dupe $opts params passed by the user

    # Initialize a new List object to hold the RegEx for de-dupe
    $optDeDupe = New-Object Collections.Generic.List[object]

    # Loop through the keys defined in backend hash table & add to array
    ForEach ($key in $cmdMap.Keys)
        {   
        # Get the associated value for the given arg
        $val = $cmdMap.$key

        # If the $arg has a val, add the RegEx to the list
        if($val) {  
            # Concat regex start/end string tokens & add to list
            $optDeDupe.Add("^"+[string]$val+"$")            
          }
        # Otherwise skip to the next $key
        else {continue}
        }

    # Concat into single Regex with "|" (or) operator
    $optDeDupe = $optDeDupe -join "|"


## Construct the download command

    # Initialise the hash table used to construct the download command
    $dlCmd = [ordered]@{}

    # Add in backend mapping
    $dlCmd += $cmdMap

    #  Exclude any duplicates from $opts passed by user, then Add to hash table
    $uniqueOpts = $opts | ?{ $_ -notmatch $optDeDupe }
    $dlCmd.Add("opts", $uniqueOpts)

    # Disable (remove) other parameters if customFileName is passed by user
    if ($customFilename) {

        $dlCmd.Remove("cdispFilename")
        $dlCmd.Remove("uriFilename")
    }
    # Else remove the customFilename entry copied from the array
    else {$dlCmd.Remove("customFilename")}

    # Get enumerated hashtable, where an given key has a value, then:
    # expand each property to just its value before concat into dl command
    $dlCmd = ($dlCmd.GetEnumerator() | ? Value | Select -ExpandProperty Value) -join " "

## Download, get filename & return details

    # If dir isn't the current path, store the current directory location then cd to the path
    # this is primarily to workaround limitations with Curl -O
    if($dir -ne (Get-Location)){
    $origLocation = Get-Location
    Set-Location $dir
    }

Try {

    # Execute the download (and pipe the output to the console)
    iex $dlCmd | Out-Host

    # If a customFilename was specified, return that as the filename
    if ($customFilename)
    {$fileName = $customFilename}
    # Otherwise get the name of the file added to the download folder *after* the command was run
    else {
    $funcExecTimestamp = (Get-History | Where { $_.CommandLine -contains $MyInvocation.MyCommand } | Sort StartExecutionTime -Descending | Select StartExecutionTime -First 1).StartExecutionTime
    $fileName = Get-ChildItem -Path $propTest | Sort-Object LastWriteTime -Descending | ?{ $_.LastWriteTime -gt $funcExecTimestamp } | Select -First 1}
    }

Finally {
    # cd back to the original location if it exists
    if($origLocaction) {Set-Location $origLocation}

    # Assemble result array (outside of Try block, to assist with debugging) - includes full path to the file, as well as the command used to initiate the download
    $result = ($dir+"\"+$fileName), ([string]$dlCmd)

    }

  return $result

}

### Potentially useful but not currently required ###
#    # Copy the relevant keys 
#    ForEach ($key in $cmdMap.Keys)
#
#    {        
#        # Set some initial variables to make things more legible
#        $value = $cmdMap.$key
#        $keyIsArg = if($PSBoundParameters.ContainsKey($key)) {$true}
#        $keyAsVarValue = $PSBoundParameters.$key
#
#        # If the key is equal to the name of an argument variable and the argument variable is not empty or false
#        if ( ($keyIsArg) -and ($keyAsVarValue) ) 
#            # Then add the key-value pair 
#            {
#            $dlCmd.Add($key, $value)
#            }
#        }
#    }
#
#    # construct the download command
#    $dlCmd = (([ordered]@{ # [ordered] to preserve command order when we concat later
#               backend = $cmdMap.backend; # append .exe to workaround powershell alias issue...
#               allowRedirs = if($allowRedirs){$cmdMap.allowRedirs};
#               cdispFilename = if($cdispFilename){$cmdMap.cdispFilename};
#               uriFilename = if($uriFilename){$cmdMap.uriFilename};
#               uniqueOpts = $opts | ?{ $_ -notmatch $optExcludeRegex }; # Remove any dupe opts that user passed
#               uri = $uri;
#               }).Values | %{ [string]$_ }) -join " " # Get hashtable values, recursively convert to string (to catch opts with an arg) then concat into command
#
#    # Loop through arguments passed by user and add to array
#    ForEach ($arg in $PSBoundParameters.Keys)
#        {   
    #        # Get the associated value for the given arg
    #        $val = $PSBoundParameters.$arg
    #
    #        # Skip '$opts' vals otherwise it will delete opts during de-dupe
    #        if($arg -eq "opts") {continue}
    #        # If the $arg has a val, add the RegEx to the list
    #        if($val) {  
        #            # Concat regex start/end string tokens & add to list
        #            $optDeDupe.Add("^"+[string]$val+"$")            
        #          }
    #        # Otherwise skip to the next $arg
    #        else {continue}
    #        }

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

function Write-InstallStatus ($component, $arr, $status, $msg) {

    # Set status Write-Host colours & messages
    switch ($status)
    {
        "Disabled"
        {
                $msg = If ($msg) {$msg} else {" Component is disabled -- check the components table. "}
                $fgColour = "White"
                $bgColour = "DarkRed"
            }
        "Failed"
        {
                $msg = If ($msg) {$msg} else {" Component installation failed -- check error message "}
                $fgColour = "White"
                $bgColour = "DarkRed"
            }
        "Succeeded"
        {
                $msg = If ($msg) {$msg} else {" Component installation succeeded. "}
                $fgColour = "Green"
                $bgColour = "DarkGreen"
            }
        default # If no status provided
        {
                $status = "Unknown"
                $msg = If ($msg) {$msg} else {" Unable to verify the installation status. "}
                $fgColour = "Yellow"
                $bgColour = "DarkYellow"
            }
    }

    # Send message to user and include the error message if not 'succeeded'
    if($status -ne "Succeeded")
    {Write-Host ("`n ["+$status+"] "+$component.var+": "+$msg+"`nError:`n"+$Error[0]) -ForegroundColor $fgColour -BackgroundColor $bgColour}
    else
    {Write-Host ("`n ["+$status+"] "+$component.var+": "+$msg) -ForegroundColor $fgColour -BackgroundColor $bgColour}

    # Write details into psobj Results Array
    $result = [PSCustomObject]@{
        Component = $component.var
        Status = $status
        Date = Get-Date -Format "ddd dd MMM yyyy h:mm:ss tt"
        Message = $msg
        LastError = if ($status -eq "Failed") {"L: "+$Error[0].InvocationInfo.ScriptLineNumber+" "+$Error[0].Exception}
    }
    $arr += $result
}

function Refresh-PathVariable {
    foreach($level in "Machine","User") {
    [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
        # For Path variables, append the new values, if they're not already in there
        if($_.Name -match 'Path$') { 
            $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
        }
        $_
    } | Set-Content -Path { "Env:$($_.Name)" }
}
}
