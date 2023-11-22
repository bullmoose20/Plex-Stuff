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
    $uniqueInFolder1 | ForEach-Object { Join-Path $folder1 $_ }

    Write-Host "Unique items in ${folder2}:"
    $uniqueInFolder2 | ForEach-Object { Join-Path $folder2 $_ }
}


# $folder1 = "D:\defaults"
# $folder2 = "D:\bullmoose20\Plex-Meta-Manager-Images"
Compare-FolderContents -folder1 "D:\defaults" -folder2 "D:\bullmoose20\Plex-Meta-Manager-Images"
Compare-FolderContents -folder1 "D:\Plex-Meta-Manager" -folder2 "C:\Users\nickz\Documents\Plex-Meta-Manager"

# $ignoreItems = @("D:\temp\TEST\create_defaults\logs\", "D:\temp\TEST\create_defaults\defaults-fr\", "D:\temp\TEST\create_defaults\defaults-en\", "D:\temp\TEST\create_defaults\defaults-de\", "D:\temp\TEST\create_defaults\file1.txt")
# Compare-FolderContents -folder1 "D:\temp\TEST\create_defaults\" -folder2 "C:\Users\nickz\Documents\Plex-Stuff\create_defaults\" -ignoreItems $ignoreItems
