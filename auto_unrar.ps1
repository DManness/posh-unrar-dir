$CACHE_FILE = "$PSScriptRoot\cache.dat"
$7z_cmd = "$PSScriptRoot\bin\7z.exe"

function Get-ProcessFile(){
    $pFileContents = @()
    if ([System.IO.File]::Exists($CACHE_FILE))
    {
        $pFileContents = @(Get-Content $CACHE_FILE)
    } 
    return $pFileContents
}


function Get-ValueByKey($key, $list){
    
    $keyPortion = "$key = "
    $line = $list | ? { $_.StartsWith($keyPortion) }

    if ( -not [string]::IsNullOrWhiteSpace($line) ){
        $raw_val = $line.Substring($keyPortion.Length).Trim()

        # 7z shows booleans as "-" and "+". This check will
        # replace it with powershell bools.
        if ( $raw_val.Length -eq 1 -and @("+", "-") -contains $raw_val )
        {
            return $raw_val -eq "+"
        }

        return $raw_val
    }
    return $null
}


function Get-RarInfo($rarFilePath){
    [array] $cmdOutput = &$7z_cmd t $rarFilePath '__no_files__'
    $finfo = @{
        "atype" = (Get-ValueByKey -list $cmdOutput -key "Path");
        "physicalSize" = (Get-ValueByKey -list $cmdOutput -key "Physical Size");
        "characteristics" = @((Get-ValueByKey -list $cmdOutput -key "Characteristics") -split " ");
        "solid" = (Get-ValueByKey -list $cmdOutput -key "Solid");
        "blocks" = (Get-ValueByKey -list $cmdOutput -key "Blocks");
        "multivolume" = (Get-ValueByKey -list $cmdOutput -key "Multivolume");
        "volumeIndex" = (Get-ValueByKey -list $cmdOutput -key "Volume Index");
        "volumeCount" = (Get-ValueByKey -list $cmdOutput -key "Volumes");
        'path' = (Get-ValueByKey -list $cmdOutput -key "Path");
        "raw_output" = $cmdOutput
    }

    return $finfo

}


function Get-TimestampFile(){
    $tsFilePath = "$PSScriptRoot\lastrun.dat"
    $dateTimeValue = new-object DateTime(1970,1,1,0,0,0,0)
    if (Test-Path $tsFilePath){
        $dateTimeValue.AddMilliseconds( [long]( Get-Content $tsFilePath) )
    } else{
        [datetime]$dateTimeValue
    }
}

function Out-TimestampFile(){
    $tsFilePath = "$PSScriptRoot\lastrun.dat"
    [long]([Double](Get-Date -UFormat "%s") * 1000) | Out-File $tsFilePath
}




# Process command line arguments
$dirToUnrar = $args[0]

if ( [String]::IsNullOrWhiteSpace( $dirToUnrar) ){
 $dirToUnrar = (Read-Host -Prompt "Enter the path you want to scan").Trim("""").Trim('''')
}
$dirToUnrar = $dirToUnrar.TrimEnd("\")

if ((Test-Path $dirToUnrar) -ne $true){
    Write-Error "Could not open the path. check to make sure the path exists and try again."
    exit 1
}

$tempDir = "$dirToUnrar\_unrar_temp"
mkdir -f $tempDir

if ( (Test-Path $tempDir) -ne $true) {
    Write-Error "could not create temp dir"
    exit 1
}



# Grab the timestamp whence the script last ran
$lastRun = Get-TimestampFile

# Overwrite the timestamp (for the next run)
Out-TimestampFile


$already_processed = @(Get-ProcessFile)
$rar_files = $null



#PS5 allows you to set a recursion depth. Earlier versions don't have a limit option. this means means the script will run slower or possible get stuck in a loop if running older versions of PoSh
if ($PSVersionTable.PSVersion.Major -ge 5){
    $rar_files = ls $dirToUnrar -Depth 5 | ? {$_.Extension -ieq '.rar' -and $_.LastWriteTime -ge $lastRun}
} else {
    $rar_files = ls $dirToUnrar -Recurse | ? {$_.Extension -ieq '.rar' -and $_.LastWriteTime -ge $lastRun}
}
    

foreach ($rarfile in $rar_files) {
    if ($already_processed -contains $rarfile.Name){
        Write-Host "Skipping $($rarfile.Name) as it's already marked extracted."
        continue
    }

    # Check if this is a multivolume archive that's incorrectly named *.rar instead of *.r0x
    $archiveInfo = Get-RarInfo $rarfile.FullName
    
    if ( $archiveInfo["multivolume"] -and ($archiveInfo["volumeIndex"] -gt 0 -or $archiveInfo["characteristics"] -notcontains "FirstVolume")  ){
        #We'll call this one "processed" even though it's more like... "Banned".
        Write-Host "Skipping $($rarfile.Name) as it's a piece of a larger volume."
        $already_processed += $rarfile.Name
        $already_processed | Out-File $CACHE_FILE
        continue
    }


    Write-Host "extracting ${$rarfile.FullName}"
    mkdir -f "$tempDir\$($rarfile.Directory.Name)"

    &$7z_cmd x $rarfile.FullName -t* -y -spe -o"$tempDir\$($rarfile.Directory.Name)"

    Move-Item "$tempDir\$($rarfile.Directory.Name)" -Destination "$($rarfile.Directory.FullName)\_unrar_out" -Force

    # Remove remnants of current operation.
    $already_processed += $rarfile.Name
    $already_processed | Out-File $CACHE_FILE
}

# Full cleanup
rm -Recurse -Force $tempDir


