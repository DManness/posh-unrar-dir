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
 $dirToUnrar = Read-Host -Prompt "Enter the path you want to scan"
}



$already_processed = @(Get-ProcessFile)
$rar_files = ls $dirToUnrar  -Depth 3 | ? {$_.Extension -ieq '.rar'}

foreach ($rarfile in $rar_files) {
    if ($already_processed -contains $rarfile.Name){
        Write-Host "Skipping $($rarfile.Name) as it's already marked extracted."
        continue
    }
    Write-Host "extracting ${$rarfile.FullName}"
    mkdir -f "$($rarfile.Directory.FullName)\_unrar_out"
    &$7z_cmd x $rarfile.FullName -t* -y -o"$($rarfile.Directory.FullName)\_unrar_out"

    $already_processed += $rarfile.Name
    $already_processed | Out-File $CACHE_FILE
}

    


