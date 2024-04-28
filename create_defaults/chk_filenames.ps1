function Compare-FolderContents {
    param (
        [string]$folder1,
        [string]$folder2,
        [string[]]$ignoreItems
    )

    $folder1Contents = Get-ChildItem -Path $folder1 -Recurse | Where-Object { $ignoreItems -notcontains $_.FullName } | Select-Object -ExpandProperty FullName
    $folder2Contents = Get-ChildItem -Path $folder2 -Recurse | Where-Object { $ignoreItems -notcontains $_.FullName } | Select-Object -ExpandProperty FullName

    $folder1Names = $folder1Contents | ForEach-Object { $_ -replace [regex]::Escape($folder1), '' }
    $folder2Names = $folder2Contents | ForEach-Object { $_ -replace [regex]::Escape($folder2), '' }

    $uniqueInFolder1 = Compare-Object $folder1Names $folder2Names -CaseSensitive | Where-Object { $_.SideIndicator -eq "<=" } | Select-Object -ExpandProperty InputObject
    $uniqueInFolder2 = Compare-Object $folder1Names $folder2Names -CaseSensitive | Where-Object { $_.SideIndicator -eq "=>" } | Select-Object -ExpandProperty InputObject

    Write-Host "Unique items in ${folder1}:"
    $uniqueInFolder1 | ForEach-Object {
        $fullPath = Join-Path $folder1 $_
        Write-Host $fullPath -ForegroundColor Green
    }

    Write-Host "Unique items in ${folder2}:"
    $uniqueInFolder2 | ForEach-Object {
        $fullPath = Join-Path $folder2 $_
        Write-Host $fullPath -ForegroundColor Cyan
    }
}


# $folder1 = "D:\defaults"
# $folder2 = "D:\bullmoose20\Default-Images"
Compare-FolderContents -folder1 "D:\defaults" -folder2 "D:\bullmoose20\Default-Images"
Compare-FolderContents -folder1 "D:\Kometa" -folder2 "D:\bullmoose20\Kometa"
Compare-FolderContents -folder1 "D:\defaults\studio\logos_overlays" -folder2 "D:\Kometa\defaults\overlays\images\studio"
Compare-FolderContents -folder1 "D:\defaults\streaming\logos_overlays" -folder2 "D:\Kometa\defaults\overlays\images\streaming"
Compare-FolderContents -folder1 "D:\defaults\network\logos_overlays" -folder2 "D:\Kometa\defaults\overlays\images\network"
Compare-FolderContents -folder1 "D:\defaults\resolution\logos_overlays" -folder2 "D:\Kometa\defaults\overlays\images\resolution"
# Compare-FolderContents -folder1 "D:\defaults\content_rating\logos_overlays" -folder2 "D:\Kometa\defaults\overlays\images\cr"

# $ignoreItems = @("D:\temp\TEST\create_defaults\logs\", "D:\temp\TEST\create_defaults\defaults-fr\", "D:\temp\TEST\create_defaults\defaults-en\", "D:\temp\TEST\create_defaults\defaults-de\", "D:\temp\TEST\create_defaults\file1.txt")
# Compare-FolderContents -folder1 "D:\temp\TEST\create_defaults\" -folder2 "C:\Users\nickz\Documents\Plex-Stuff\create_defaults\" -ignoreItems $ignoreItems
