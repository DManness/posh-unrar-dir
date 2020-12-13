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

$already_processed = @(Get-ProcessFile)
$rar_files = $null

#PS5 allows you to set a recursion depth. Earlier versions don't have a limit option. this means means the script will run slower or possible get stuck in a loop if running older versions of PoSh
if ($PSVersionTable.PSVersion.Major -ge 5){
    $rar_files = ls $dirToUnrar -Depth 5 | ? {$_.Extension -ieq '.rar'}
} else {
    $rar_files = ls $dirToUnrar -Recurse | ? {$_.Extension -ieq '.rar'}
}
    

foreach ($rarfile in $rar_files) {
    if ($already_processed -contains $rarfile.Name){
        Write-Host "Skipping $($rarfile.Name) as it's already marked extracted."
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


