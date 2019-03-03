# Usage: scoop dlcache <app> [options]
# Summary: Download cache files for offline update
# Help: 'scoop dlcache <app>' downloads the latest version of an app's cache files, useful for performing offline updates.
#
#
# Options:
#   -i, --independent         Don't download dependencies automatically
#   -k, --no-cache            Don't use the download cache
#   -s, --skip                Skip hash validation (use with caution!)
#   -a, --arch <32bit|64bit>  Use the specified architecture, if the app supports it

## ADAPTED FROM EXISTING scoop-install.ps1 BY XEIJIN ##

. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\decompress.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\shortcuts.ps1"
. "$psscriptroot\..\lib\psmodules.ps1"
. "$psscriptroot\..\lib\versions.ps1"
. "$psscriptroot\..\lib\help.ps1"
. "$psscriptroot\..\lib\getopt.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\config.ps1"

reset_aliases

function xeijin_update_buckets() {

## ADAPTED FROM EXISTING 'scoop_update' FUNCTION ##

    write-host -f Yellow 'Updating buckets...'

    @(buckets) | ForEach-Object {
        write-host "Updating '$_'..."
        Push-Location (bucketdir $_)
        git_pull -q
        if($show_update_log) {
            git_log --no-decorate --date=local --since="`"$last_update`"" --format="`"tformat: * %C(yellow)%h%Creset %<|(72,trunc)%s %C(cyan)%cr%Creset`"" HEAD
        }
        Pop-Location
    }

    set_config lastupdate ([System.DateTime]::Now.ToString('o'))
    success 'Buckets updated successfully!'
}

function xeijin_dl_urls($app, $version, $manifest, $bucket, $architecture, $dir, $use_cache = $true, $check_hash = $true) {

### ADAPTED FROM EXISTING 'dl_urls' FUNCTION ###

    # we only want to show this warning once
    if(!$use_cache) { warn "Cache is being ignored." }

    # can be multiple urls: if there are, then msi or installer should go last,
    # so that $fname is set properly
    $urls = @(url $manifest $architecture)

    # can be multiple cookies: they will be used for all HTTP requests.
    $cookies = $manifest.cookie

    $fname = $null

    # download first
    if(aria2_enabled) {
        dl_with_cache_aria2 $app $version $manifest $architecture $dir $cookies $use_cache $check_hash
    } else {
        foreach($url in $urls) {
            $fname = url_filename $url

            try {
                dl_with_cache $app $version $url $null $cookies $use_cache
                # xeijin: "$dir\$fname" (aka $to) changed to $null to prevent dl_with_cache from creating 'apps' folder and copying cache file there (which in turn was causing dlcache'd apps to show as *failed* installations
            } catch {
                write-host -f darkred $_
                abort "URL $url is not valid"
            }

            if($check_hash) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                $ok, $err = check_hash $(cache_path $app $version $url) $manifest_hash $(show_app $app $bucket)
                # xeijin: "$dir\$fname" changed to '$(cache_path $app $version $url)' to prevent hash check trying to take place against file in apps directory
                if(!$ok) {
                    error $err
                    $cached = cache_path $app $version $url
                    if(test-path $cached) {
                        # rm cached file
                        Remove-Item -force $cached
                    }
                    if($url.Contains('sourceforge.net')) {
                        Write-Host -f yellow 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                    }
                    abort $(new_issue_msg $app $bucket "hash check failed")
                }
            }
        }
    }

    $fname # returns the last downloaded file
}

function xeijin_dl_to_cache($app, $architecture, $global, $suggested, $use_cache = $true, $check_hash = $true) {

## ADAPTED FROM EXISTING 'install_app' FUNCTION ##

    $app, $bucket, $null = parse_app $app
    $app, $manifest, $bucket, $url = locate $app $bucket

    if(!$manifest) {
        abort "Couldn't find manifest for '$app'$(if($url) { " at the URL $url" })."
    }

    $version = $manifest.version
    if(!$version) { abort "Manifest doesn't specify a version." }
    if($version -match '[^\w\.\-\+_]') {
        abort "Manifest version has unsupported character '$($matches[0])'."
    }

    $is_nightly = $version -eq 'nightly'
    if ($is_nightly) {
        $version = nightly_version $(get-date)
        $check_hash = $false
    }

    if(!(supports_architecture $manifest $architecture)) {
        write-host -f DarkRed "'$app' doesn't support $architecture architecture!"
        return
    }

    write-host -f Yellow "Downloading '$app' ($version) [$architecture] to cache"

    # Initiates the download to cache
    $fname = xeijin_dl_urls $app $version $manifest $bucket $architecture $dir $use_cache $check_hash

    success "'$app' ($version) was successfully downloaded to cache!"
}

$opt, $apps, $err = getopt $args 'gfiksa:' 'global', 'force', 'independent', 'no-cache', 'skip', 'arch='
if($err) { "scoop dlcache: $err"; exit 1 }

$global = $opt.g -or $opt.global
$check_hash = !($opt.s -or $opt.skip)
$independent = $opt.i -or $opt.independent
$use_cache = !($opt.k -or $opt.'no-cache')
$architecture = default_architecture
try {
    $architecture = ensure_architecture ($opt.a + $opt.arch)
} catch {
    abort "ERROR: $_"
}

if(!$apps) { error '<app> missing'; my_usage; exit 1 }

xeijin_update_buckets

if(is_scoop_outdated) {
    scoop update
}

if($apps.length -eq 1) {
    $app, $null, $null = parse_app $apps
}

# get any specific versions that we need to handle first
$specific_versions = $apps | Where-Object {
    $null, $null, $version = parse_app $_
    return $null -ne $version
}

# compare object does not like nulls
if ($specific_versions.length -gt 0) {
    $difference = Compare-Object -ReferenceObject $apps -DifferenceObject $specific_versions -PassThru
} else {
    $difference = $apps
}

$specific_versions_paths = $specific_versions | ForEach-Object {
    $app, $bucket, $version = parse_app $_
    if (installed_manifest $app $version) {
        abort "'$app' ($version) is already installed.`nUse 'scoop update $app$global_flag' to install a new version."
    }

    generate_user_manifest $app $bucket $version
}
$apps = @(($specific_versions_paths + $difference) | Where-Object { $_ } | Sort-Object -Unique)

# remember which were explictly requested so that we can
# differentiate after dependencies are added
$explicit_apps = $apps

if(!$independent) {
    $apps = install_order $apps $architecture # adds dependencies
}

$skip | Where-Object { $explicit_apps -contains $_} | ForEach-Object {
    $app, $null, $null = parse_app $_
    $version = @(versions $app $global)[-1]
    warn "'$app' ($version) is already installed. Skipping."
}

if(aria2_enabled) {
    warn "Scoop uses 'aria2c' for multi-connection downloads."
    warn "Should it cause issues, run 'scoop config aria2-enabled false' to disable it."
}
$apps | ForEach-Object { xeijin_dl_to_cache $_ $architecture $global $suggested $use_cache $check_hash }

exit 0
