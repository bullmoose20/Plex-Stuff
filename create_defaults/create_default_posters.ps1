################################################################################
# create_default_poster.ps1
# Date: 2023-01-13
# Version: 2.0
# Author: bullmoose20
#
# DESCRIPTION: 
# This script contains ten functions that are used to create various types of posters. The functions are:
# CreateAudioLanguage, CreateAwards, CreateChart, CreateCountry, CreateDecade, CreateGenre, CreatePlaylist, CreateSubtitleLanguage, CreateUniverse and CreateYear.
# The script can be called by providing the name of the functionor aliases you want to run as a command-line argument.
# AudioLanguage, Awards, Based, Charts, ContentRating, Country, Decades, Franchise, Genres, Network, Playlist, Resolution, Streaming,
# Studio, Seasonal, Separators, SubtitleLanguages, Universe, Years, All
#
# REQUIREMENTS:
# Imagemagick must be installed - https://imagemagick.org/script/download.php
# font must be installed on system and visible by Imagemagick. Make sure that you install the ttf font for ALL users as an admin so ImageMagick has access to the font when running (r-click on font Install for ALL Users in Windows)
# Powershell security settings: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2
#
# EXAMPLES:
# You can run the script by providing the name of the function you want to run as a command-line argument:
# create_default_posters.ps1 AudioLanguage 
# This will run only the CreateAudioLanguage function.
# You can also provide multiple function names as command-line arguments:
# create_default_posters.ps1 AudioLanguage Playlist Chart
# This will run CreateAudioLanguage, CreatePlaylist, and CreateChart functions in that order.
# Finally just running the script with All will run all of the functions
# create_default_posters.ps1 All
################################################################################


#################################
# GLOBAL VARS
#################################
$global:font_flag = $null
$global:magick = $null
# $global:WidthCache = @{}

#################################
# collect paths
#################################
$script_path = $PSScriptRoot
$scriptName = $MyInvocation.MyCommand.Name
$scriptLog = Join-Path $script_path -ChildPath "$scriptName.log"
$cacheFilePath = Join-Path $script_path -ChildPath "cache.csv"

################################################################################
# Function: Remove-Folders
# Description: Removes folders to start fresh run
################################################################################
Function Remove-Folders {
    Remove-Item -Path $script_path\audio_language -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\award -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\based -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\chart -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\content_rating -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\country -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\decade -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\defaults -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\franchise -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\genre -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\network -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\playlist -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\resolution -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\seasonal -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\separators -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\streaming -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\studio -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\subtitle_language -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\translations -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\universe -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path $script_path\year -Force -Recurse -ErrorAction SilentlyContinue
}

################################################################################
# Function: Test-ImageMagick
# Description: Determines version of ImageMagick installed
################################################################################
Function Test-ImageMagick {
    $global:magick = $global:magick
    $global:magick = magick -version | select-string "Version:"
}

################################################################################
# Function: WriteToLogFile
# Description: Writes to a log file with timestamp
################################################################################
Function WriteToLogFile ($message) {
    Add-content $scriptLog -value ((Get-Date).ToString() + " ~ " + $message)
    Write-Host ((Get-Date).ToString() + " ~ " + $message)
}

################################################################################
# Function: Find-Path
# Description: Determines if path exists and if not, creates it
################################################################################
Function Find-Path ($sub) {
    if (!(Test-Path $sub -ErrorAction SilentlyContinue)) {
        WriteToLogFile "Creating path                : $sub"
        New-Item $sub -ItemType Directory | Out-Null
    }
}

################################################################################
# Function: Find-Fonts
# Description: Determines if fonts required are installed and visible to ImageMagick
################################################################################
# https://www.alkanesolutions.co.uk/2021/12/06/installing-fonts-with-powershell/
Function Find-Fonts ($theFont, $theFile, $theType) {
    $tmp = $null
    $tmp = "Font: " + $theFont + "$"
    $chkfont1 = magick identify -list font | Select-String $tmp
    $global:font_flag = $global:font_flag 
    if ($chkfont1 -eq "" -or $null -eq $chkfont1) {
        $font_list = magick identify -list font | Select-String "Font: "
        $font_list -replace "  Font: ", ""> magick_fonts.txt
        Write-Host "Fonts missing >"$theFont"< not installed/found. List of installed fonts that Imagemagick can use listed and exported here: magick_fonts.txt." -ForegroundColor Red -BackgroundColor White
        Write-Host $font_list.count "fonts are visible to Imagemagick." -ForegroundColor Red -BackgroundColor White
        WriteToLogFile "Fonts missing                : $theFont"
        WriteToLogFile "Fonts missing                : List of installed fonts that Imagemagick can use listed and exported here: magick_fonts.txt."
        WriteToLogFile "Creating file                : $script_path\fonts\$theFont.$theType"
        Convert-TextToBinary -Text $theFile -OutputPath $script_path\fonts\$theFont.$theType
        $global:font_flag = 1
    }
}

################################################################################
# Function: Find-BinFile
# Description: Determines if binary file exists and then creates it if its missing
################################################################################
Function Find-BinFile($thePath, $theFile) {
    if (-not(Test-Path -Path $thePath -PathType Leaf)) {
        Write-Host "File >$thePath< not found. Creating now. Please standby..." -ForegroundColor Red -BackgroundColor White
        WriteToLogFile "Creating file                : $thePath"
        Convert-TextToBinary $theFile $thePath
    }
}

################################################################################
# Function: Convert-BinaryToText
# Description: Converts binary file to text
################################################################################
Function Convert-BinaryToText {
    param
    (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $Bytes = [System.IO.File]::ReadAllBytes($Path)
    [System.Convert]::ToBase64String($Bytes)
}

################################################################################
# Function: Convert-TextToBinary
# Description: Converts text to binary file
################################################################################
Function Convert-TextToBinary {
    param
    (
        [Parameter(Mandatory)]
        [string]
        $Text,

        [Parameter(Mandatory)]
        [string]
        $OutputPath
    )

    $Bytes = [System.Convert]::FromBase64String($Text)
    [System.IO.File]::WriteAllBytes($OutputPath, $Bytes)
}

################################################################################
# Function: Find-Path-Awards
# Description: Ensures the paths to the awards are all there
################################################################################
Function Find-Path-Awards {
    Find-Path "$script_path\award"
    Find-Path "$script_path\award\bafta"
    Find-Path "$script_path\award\berlinale"
    Find-Path "$script_path\award\cannes"
    Find-Path "$script_path\award\cesar"
    Find-Path "$script_path\award\choice"
    Find-Path "$script_path\award\emmys"
    Find-Path "$script_path\award\golden"
    Find-Path "$script_path\award\oscars"
    Find-Path "$script_path\award\spirit"
    Find-Path "$script_path\award\sundance"
    Find-Path "$script_path\award\venice"

    Find-Path "$script_path\award\bafta\winner"
    Find-Path "$script_path\award\berlinale\winner"
    Find-Path "$script_path\award\cannes\winner"
    Find-Path "$script_path\award\cesar\winner"
    Find-Path "$script_path\award\choice\winner"
    Find-Path "$script_path\award\emmys\winner"
    Find-Path "$script_path\award\golden\winner"
    Find-Path "$script_path\award\oscars\winner"
    Find-Path "$script_path\award\spirit\winner"
    Find-Path "$script_path\award\sundance\winner"
    Find-Path "$script_path\award\venice\winner"

    Find-Path "$script_path\award\bafta\best"
    Find-Path "$script_path\award\berlinale\best"
    Find-Path "$script_path\award\cannes\best"
    Find-Path "$script_path\award\cesar\best"
    Find-Path "$script_path\award\choice\best"
    Find-Path "$script_path\award\emmys\best"
    Find-Path "$script_path\award\golden\best"
    Find-Path "$script_path\award\oscars\best"
    Find-Path "$script_path\award\spirit\best"
    Find-Path "$script_path\award\sundance\best"
    Find-Path "$script_path\award\venice\best"

    Find-Path "$script_path\award\bafta\nomination"
    Find-Path "$script_path\award\berlinale\nomination"
    Find-Path "$script_path\award\cannes\nomination"
    Find-Path "$script_path\award\cesar\nomination"
    Find-Path "$script_path\award\choice\nomination"
    Find-Path "$script_path\award\emmys\nomination"
    Find-Path "$script_path\award\golden\nomination"
    Find-Path "$script_path\award\oscars\nomination"
    Find-Path "$script_path\award\spirit\nomination"
    Find-Path "$script_path\award\sundance\nomination"
    Find-Path "$script_path\award\venice\nomination"
}

################################################################################
# Function: Verify-FileChecksum
# Description: validates checksum of files
################################################################################
function Verify-FileChecksum {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedChecksum,

        [Parameter(Mandatory = $true)]
        [ref]$failFlag
    )

    $actualChecksum = Get-FileHash $Path -Algorithm SHA256 | Select-Object -ExpandProperty Hash

    $status = if ($actualChecksum -eq $ExpectedChecksum) {
        "Success"
    }
    else {
        $failFlag.Value = $true
        "Failed"
    }

    $output = [PSCustomObject]@{
        Path             = $Path
        ExpectedChecksum = $ExpectedChecksum
        ActualChecksum   = $actualChecksum
        Status           = $status
        failFlag         = $failFlag
    }

    # Write-Output "Checksum verification $($output.Status) for file $($output.Path). Expected checksum: $($output.ExpectedChecksum), actual checksum: $($output.ActualChecksum)."
    WriteToLogFile "Checksum verification        : $($output.Status) for file $($output.Path). Expected checksum: $($output.ExpectedChecksum), actual checksum: $($output.ActualChecksum)."

    return $output
}

################################################################################
# Function: Download-TranslationFile
# Description: gets the language yml file from github
################################################################################
function Download-TranslationFile {
    param(
        [string]$LanguageCode
    )
  
    $GitHubRepository = "https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager/master/defaults/translations"
    $TranslationFile = "$LanguageCode.yml"
    $TranslationFileUrl = "$GitHubRepository/$TranslationFile"
    $TranslationFilePath = Join-Path $script_path -ChildPath "@translations"
    Find-Path $TranslationFilePath
    $TranslationFilePath = Join-Path $TranslationFilePath -ChildPath "$LanguageCode.yml"
  
    try {
        $response = Invoke-WebRequest -Uri $TranslationFileUrl -Method Head
        if ($response.StatusCode -eq 404) {
            Write-Error "Error: Translation file not found."
            return
        }
  
        Invoke-WebRequest -Uri $TranslationFileUrl -OutFile $TranslationFilePath
        if ((Get-Content $TranslationFilePath).Length -eq 0) {
            throw "Error: Translation file is empty."
        }
    }
    catch {
        Write-Error $_
        return
    }
  
    Write-Output "Translation file downloaded to $TranslationFilePath"
}

################################################################################
# Function: Replace-TextBetweenDelimiters
# Description: replaces <<something>> with a string
################################################################################
function Replace-TextBetweenDelimiters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputString,

        [Parameter(Mandatory = $true)]
        [string]$ReplacementString
    )

    $outputString = $InputString -replace '<<.*?>>', $ReplacementString

    return $outputString
}

################################################################################
# Function: Print-TranslationDictionary
# Description: Prints out the translation dictionary for debugging purposes
################################################################################
function Print-TranslationDictionary {
    param(
        [hashtable]$TranslationDictionary
    )

    foreach ($Key in $TranslationDictionary.Keys) {
        Write-Output "${Key}: $($TranslationDictionary[$Key])"
    }
}

################################################################################
# Function: Get-TranslatedValue
# Description:  gets the translated value for the poster
################################################################################
function Get-TranslatedValue {
    param(
        [string]$TranslationFilePath,
        [string]$EnglishValue,
        [ValidateSet("Exact", "Upper", "Lower")]
        [string]$CaseSensitivity = "Exact"
    )

    try {
        $TranslationDictionary = @{}

        # Load the YML file into a dictionary
        Get-Content $TranslationFilePath | ForEach-Object {
            $Line = $_.Trim()
            if ($Line -match "^(.+):\s+(.+)$") {
                $TranslationDictionary[$Matches[1]] = $Matches[2]
            }
            elseif ($Line -match "^(.+):$") {
                $TranslationDictionary[$Matches[1]] = $Matches[1]
            }
        }

        # Get the translated value
        $EnglishValue = $EnglishValue.Replace("\n", " ")
        $TranslatedValue = $TranslationDictionary[$EnglishValue]

        if ($null -eq $TranslatedValue) {
            Write-Output "TRANSLATION NOT FOUND"
            WriteToLogFile "EnglishValue                 : $EnglishValue"
            WriteToLogFile "TranslatedValue              : $TranslatedValue"
            return
        }
        
        # Apply the requested case sensitivity
        switch ($CaseSensitivity) {
            "Exact" { break }
            "Upper" { $TranslatedValue = $TranslatedValue.ToUpper() }
            "Lower" { $TranslatedValue = $TranslatedValue.ToLower() }
        }

        # Replace spaces with newline characters if the original English value had a newline character
        if ($EnglishValue -contains "\n") {
            $TranslatedValue = $TranslatedValue.Replace(" ", "\n")
        }

        Write-Output $TranslatedValue
        WriteToLogFile "EnglishValue                 : $EnglishValue"
        WriteToLogFile "TranslatedValue              : $TranslatedValue"
    }
    catch {
        Write-Error "Error: Value not found in dictionary."
        return
    }
}

################################################################################
# Function: Get-Width
# Description: gets the width of a string based on a font and pointsize
################################################################################
Function Get-Width($theName, $theFont, $thePointsize) {
    WriteToLogFile "theName is                   : $theName"
    WriteToLogFile "theFont is                   : $theFont"
    WriteToLogFile "thePointsize is              : $thePointsize"
  
    $string = magick -debug annotate  xc: -font $theFont -pointsize $thePointsize -annotate 0 $theName null: 2>&1 | Select-String -Pattern Metrics: -CaseSensitive -SimpleMatch
    $theArray = $string -Split ";"   
    $arrWidth = $theArray[1].Split(" ")
    $theWidth = [int]$arrWidth[2]
    WriteToLogFile "Name Width is                : $theWidth"
    $theWidth
}

$global:WidthCache = @{}

################################################################################
# Function: Export-WidthCache
# Description: Exports to CSV cache
################################################################################
function Export-WidthCache {
    param (
        [string] $cacheFilePath
    )
    $global:WidthCache.GetEnumerator() | Select-Object Text,Font,PointSize,Width |
        Export-Csv -Path $cacheFilePath -NoTypeInformation
}

################################################################################
# Function: Import-WidthCache
# Description: Imports from CSV cache
################################################################################
function Import-WidthCache {
    param (
        [string] $cacheFilePath
    )
    if (Test-Path $cacheFilePath) {
        $cache = Import-Csv -Path $cacheFilePath | ForEach-Object {
            [pscustomobject] @{
                Text      = $_.Text
                Font      = $_.Font
                PointSize = [int] $_.PointSize
                Width     = [double] $_.Width
            }
        }
        if ($cache.Count -gt 0) {
            $global:WidthCache = @{}
            $cache | ForEach-Object {
                $global:WidthCache["$($_.Text) $($_.Font) $($_.PointSize)"] = [double]$_.Width
            }
            WriteToLogFile "Import-WidthCache            : Import-WidthCache completed"
        }
        else {
            $global:WidthCache = @{}
            WriteToLogFile "Import-WidthCache            : $cacheFilePath is empty"
        }
    }
    else {
        WriteToLogFile "Import-WidthCache            : $cacheFilePath not found"
        $global:WidthCache = @{}
    }
}

################################################################################
# Function: Get-WidthCached
# Description: Gets the width cache
################################################################################
Function Get-WidthCached($text, $font, $pointSize) {
    foreach ($cacheItem in $global:WidthCache.GetEnumerator()) {
        if ($cacheItem.Value.Text -eq $text -and $cacheItem.Value.Font -eq $font -and $cacheItem.Value.PointSize -eq $pointSize) {
            return $cacheItem.Value.Width
        }
    }
    
    $width = Get-Width $text $font $pointSize
    $cacheItem = [pscustomobject] @{
        Text      = $text
        Font      = $font
        PointSize = $pointSize
        Width     = $width
    }
    $global:WidthCache["$text $font $pointSize"] = $cacheItem
    
    return $width
}

################################################################################
# Function: Get-OptimalFontSize
# Description: Gets the optimal size for a phrase
################################################################################
Function Get-OptimalFontSize($theName, $theFont, $theMaxWidth, $initialPointSize) {
    $words = $theName -split '\s'
    $minOptimalPointSize = $initialPointSize

    foreach ($word in $words) {
        $optimalPointSize = $initialPointSize
        $currentWidth = Get-WidthCached $word $theFont $optimalPointSize
        
        if ($currentWidth -gt $theMaxWidth) {
            $minPointSize = 1
            $maxPointSize = $optimalPointSize
            while ($maxPointSize - $minPointSize -gt 1) {
                $pointSize = [int]($minPointSize + ($maxPointSize - $minPointSize) / 2)
                
                $width = Get-WidthCached $word $theFont $pointSize
                
                if ($width -gt $theMaxWidth) {
                    $maxPointSize = $pointSize
                }
                else {
                    $minPointSize = $pointSize
                }
            }
            
            $optimalPointSize = $minPointSize
        }
        
        if ($optimalPointSize -lt $minOptimalPointSize) {
            $minOptimalPointSize = $optimalPointSize
        }
    }
    
    WriteToLogFile "optimalFontSize              : Optimal font size for '$theName' with font '$theFont' and maximum width '$theMaxWidth' is '$minOptimalPointSize'."
    return $minOptimalPointSize
}

  
################################################################################
# Function: EncodeIt
# Description:  base64 string encode
################################################################################
Function EncodeIt ($cmd) {
    $encodedCommand = $null
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($cmd)
    $encodedCommand = [Convert]::ToBase64String($bytes)
    return $encodedCommand
}

################################################################################
# Function: Wait-ForProcesses
# Description:  Tracks processses so you know what was launched
################################################################################
Function Wait-ForProcesses {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [int[]]$ProcessIds
    )

    foreach ($id in $ProcessIds) {
        $process = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($process) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            while ($process.Responding) {
                if ($stopwatch.Elapsed.TotalMinutes -gt 5) {
                    Write-Warning "Process $id has exceeded the maximum wait time of 5 minutes and will be terminated"
                    WriteToLogFile "Process Timeout              : Process $id has exceeded the maximum wait time of 5 minutes and will be terminated"
                    $process.Kill()
                    break
                }
                Start-Sleep -Seconds 1
                $process = Get-Process -Id $id -ErrorAction SilentlyContinue
            }
        }
    }
}

################################################################################
# Function: LaunchScripts
# Description:  Launches the scripts
################################################################################
Function LaunchScripts {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ScriptPaths
    )

    $batchSize = 10
    $scriptCount = $ScriptPaths.Count

    for ($i = 0; $i -lt $scriptCount; $i += $batchSize) {
        $batch = $ScriptPaths[$i..($i + $batchSize - 1)]
        $processes = @()
        foreach ($scriptPath in $batch) {
            $encodedCommand = EncodeIt $scriptPath 
            WriteToLogFile "Unencoded                    : $scriptPath"
            WriteToLogFile "Encoded                      : $encodedCommand"
            # $process = Start-Process -NoNewWindow -FilePath "pwsh.exe" -ArgumentList "-noexit -encodedCommand $encodedCommand" -PassThru
            $process = Start-Process -NoNewWindow -FilePath "pwsh.exe" -ArgumentList "-encodedCommand $encodedCommand" -PassThru
            $processes += $process
        }
        Wait-ForProcesses -ProcessIds ( $processes | Select-Object -ExpandProperty Id)
    }
}

################################################################################
# Function: MoveFiles
# Description: Moves Folder and Files to final location
################################################################################
Function MoveFiles {
    Move-Item -Path $script_path\audio_language -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\award -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\based -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\chart -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\content_rating -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\country -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\decade -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\franchise -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\genre -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\network -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\resolution -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\playlist -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\seasonal -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\separators -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\streaming -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\studio -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\subtitle_language -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\universe -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\year -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
    Move-Item -Path $script_path\collectionless.jpg -Destination $script_path\defaults -Force -ErrorAction SilentlyContinue
}
################################################################################
# Function: ConvertSeparators
# Description: Creates the Separator posters
################################################################################
Function Convert-Separators ($theBackdrop, $theFont, $theFontSize, $theLabel, $theFullPath) {
    WriteToLogFile "theBackdrop                  : $theBackdrop"
    WriteToLogFile "theFont                      : $theFont"
    WriteToLogFile "theFontSize                  : $theFontSize"
    WriteToLogFile "theLabel                     : $theLabel"
    WriteToLogFile "theFullPath                  : $theFullPath"
    # write-host "magick $theBackdrop -gravity center -background None -layers Flatten `( -font $theFont -pointsize $theFontSize -fill white -size 1900x1000 -background none label:"$theLabel" -trim -gravity center -extent 1900x1000 `) -gravity center -geometry +0+0 -composite $theFullPath"
    # magick $theBackdrop -gravity center -background None -layers Flatten `( -font $theFont -pointsize $theFontSize -fill white -size 1900x1000 -background none label:"$theLabel" -trim -gravity center -extent 1900x1000 `) -gravity center -geometry +0+0 -composite $theFullPath
    $cmd = "$theBackdrop -gravity center -background None -layers Flatten `( -font $theFont -pointsize $theFontSize -fill white -size 1900x1000 -background none label:""$theLabel"" -trim -gravity center -extent 1900x1000 `) -gravity center -geometry +0+0 -composite $theFullPath"
    WriteToLogFile "magick command               : magick $cmd"
    Start-Process -NoNewWindow magick $cmd
}

################################################################################
# Function: Convert-AwardsBase
# Description: Creates the base posters for the awards
################################################################################
Function Convert-AwardsBase ($theBackdrop, $theFont, $theFontSize, $theNumber, $thePathOnly) {
    Find-Path-Awards
    WriteToLogFile "theBackdrop                  : $theBackdrop"
    WriteToLogFile "theFont                      : $theFont"
    WriteToLogFile "theFontSize                  : $theFontSize"
    WriteToLogFile "theNumber                    : $theNumber"
    WriteToLogFile "thePathOnly                  : $thePathOnly"
    $tmp = $null
    $tmp = "text 0,900 '" + $theNumber + "'" 
    # write-host "magick @base-NULL.png -font $theFont -fill white -pointsize $theFontSize -gravity center -colorspace RGB -draw "$tmp" @base-$theNumber.png"
    # magick $theBackdrop -font $theFont -fill white -pointsize $theFontSize -gravity center -colorspace RGB -draw "$tmp" $thePathOnly\@base-$theNumber.png
    $cmd = "$theBackdrop -font $theFont -fill white -pointsize $theFontSize -gravity center -colorspace RGB -draw ""$tmp"" $thePathOnly\@base-$theNumber.png"
    WriteToLogFile "magick command               : magick $cmd"
    Start-Process -NoNewWindow magick $cmd
}

################################################################################
# Function: Convert-Awards
# Description: Creates the awards posters
################################################################################
Function Convert-Awards ($theBackdrop, $theBase, $theNumber, $thePathOnly) {
    WriteToLogFile "theBackdrop                  : $theBackdrop"
    WriteToLogFile "theBase                      : $theBase"
    WriteToLogFile "theNumber                    : $theNumber"
    WriteToLogFile "thePathOnly                  : $thePathOnly"
    $cmd = "$theBackdrop $theBase $script_path\@base\@base-$theNumber.png -gravity center -background None -layers Flatten $thePathOnly\$theNumber.jpg"
    WriteToLogFile "magick command               : magick $cmd"
    Start-Process -NoNewWindow magick $cmd
}

################################################################################
# Function: Convert-Decades
# Description: Creates the decade posters
################################################################################
Function Convert-Decades ($theBackdrop, $theBase, $theNumber, $thePathOnly) {
    WriteToLogFile "theBackdrop                  : $theBackdrop"
    WriteToLogFile "theBase                      : $theBase"
    WriteToLogFile "theNumber                    : $theNumber"
    WriteToLogFile "thePathOnly                  : $thePathOnly"
    $tmp = $null
    $tmp = $theNumber, "s" | Join-String
    WriteToLogFile "theDecadeTemplate            : $script_path\@base\@zbase-$tmp.png"
    $cmd = "$theBackdrop $theBase $script_path\@base\@zbase-$tmp.png -gravity center -background None -layers Flatten $thePathOnly\$theNumber.jpg"
    WriteToLogFile "magick command               : magick $cmd"
    Start-Process -NoNewWindow magick $cmd
}

################################################################################
# Function: Convert-Years
# Description: Creates the years posters
################################################################################
Function Convert-Years ($theBackdrop, $theBase, $theFont, $theTextSize, $theNumber, $thePathOnly) {
    WriteToLogFile "theBackdrop                  : $theBackdrop"
    WriteToLogFile "theBase                      : $theBase"
    WriteToLogFile "theFont                      : $theFont"
    WriteToLogFile "theTextSize                  : $theTextSize"
    WriteToLogFile "theNumber                    : $theNumber"
    WriteToLogFile "thePathOnly                  : $thePathOnly"
    $cmd = "$theBackdrop $theBase -gravity center -background None -layers Flatten `( -font $theFont -fill white -size $theTextSize -background none label:""$theNumber"" -trim -gravity center -extent $theTextSize `) -gravity center -geometry +0+0 -composite $thePathOnly\$theNumber.jpg"
    WriteToLogFile "magick command               : magick $cmd"
    Start-Process -NoNewWindow magick $cmd
}

################################################################################
# Function: CreateAudioLanguage
# Description:  Creates audio language
################################################################################
Function CreateAudioLanguage {
    Write-Host "Creating Audio Language"
    Set-Location $script_path
    # Find-Path "$script_path\audio_language"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"other`" -base_color `"#FF2000`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ABKHAZIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ab`" -base_color `"#88F678`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"AFAR\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"aa`" -base_color `"#612A1C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"AFRIKAANS\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"af`" -base_color `"#60EC40`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"AKAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ak`" -base_color `"#021FBC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ALBANIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sq`" -base_color `"#C5F277`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"AMHARIC\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"am`" -base_color `"#746BC8`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ARABIC\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ar`" -base_color `"#37C768`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ARAGONESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"an`" -base_color `"#4619FD`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ARMENIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"hy`" -base_color `"#5F26E3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ASSAMESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"as`" -base_color `"#615C3B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"AVARIC\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"av`" -base_color `"#2BCE4A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"AVESTAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ae`" -base_color `"#CF6EEA`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"AYMARA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ay`" -base_color `"#3D5D3B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"AZERBAIJANI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"az`" -base_color `"#A48C7A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BAMBARA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"bm`" -base_color `"#C12E3D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BASHKIR\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ba`" -base_color `"#ECD14A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BASQUE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"eu`" -base_color `"#89679F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BELARUSIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"be`" -base_color `"#1050B0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BENGALI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"bn`" -base_color `"#EA4C42`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BISLAMA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"bi`" -base_color `"#C39A37`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BOSNIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"bs`" -base_color `"#7DE3FE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BRETON\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"br`" -base_color `"#7E1A72`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BULGARIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"bg`" -base_color `"#D5442A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"BURMESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"my`" -base_color `"#9E5CF0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CATALAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ca`" -base_color `"#99BC95`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CENTRAL KHMER\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"km`" -base_color `"#6ABDD6`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CHAMORRO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ch`" -base_color `"#22302F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CHECHEN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ce`" -base_color `"#83E832`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CHICHEWA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ny`" -base_color `"#03E31C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CHINESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"zh`" -base_color `"#40EA69`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CHURCH SLAVIC\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"cu`" -base_color `"#C76DC2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CHUVASH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"cv`" -base_color `"#920F92`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CORNISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"kw`" -base_color `"#55137D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CORSICAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"co`" -base_color `"#C605DC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CREE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"cr`" -base_color `"#75D7F3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CROATIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"hr`" -base_color `"#AB48D3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"CZECH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"cs`" -base_color `"#7804BB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"DANISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"da`" -base_color `"#87A5BE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"DIVEHI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"dv`" -base_color `"#FA57EC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"DUTCH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"nl`" -base_color `"#74352E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"DZONGKHA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"dz`" -base_color `"#F7C931`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ENGLISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"en`" -base_color `"#DD4A2F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ESPERANTO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"eo`" -base_color `"#B65ADE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ESTONIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"et`" -base_color `"#AF1569`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"EWE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ee`" -base_color `"#2B7E43`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"FAROESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"fo`" -base_color `"#507CCC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"FIJIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"fj`" -base_color `"#7083F9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"FILIPINO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"fil`" -base_color `"#8BEF80`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"FINNISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"fi`" -base_color `"#9229A6`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"FRENCH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"fr`" -base_color `"#4111A0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"FULAH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ff`" -base_color `"#649BA7`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"GAELIC\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"gd`" -base_color `"#FBFEC1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"GALICIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"gl`" -base_color `"#DB6769`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"GANDA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"lg`" -base_color `"#C71A50`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"GEORGIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ka`" -base_color `"#8517C8`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"GERMAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"de`" -base_color `"#4F5FDC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"GREEK\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"el`" -base_color `"#49B49A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"GUARANI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"gn`" -base_color `"#EDB51C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"GUJARATI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"gu`" -base_color `"#BDF7FF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"HAITIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ht`" -base_color `"#466EB6`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"HAUSA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ha`" -base_color `"#A949D2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"HEBREW\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"he`" -base_color `"#E9C58A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"HERERO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"hz`" -base_color `"#E9DF57`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"HINDI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"hi`" -base_color `"#77775B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"HIRI MOTU\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ho`" -base_color `"#3BB41B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"HUNGARIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"hu`" -base_color `"#111457`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ICELANDIC\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"is`" -base_color `"#0ACE8F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"IDO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"io`" -base_color `"#75CA6C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"IGBO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ig`" -base_color `"#757EDE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"INDONESIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"id`" -base_color `"#52E822`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"INTERLINGUA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ia`" -base_color `"#7F9248`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"INTERLINGUE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ie`" -base_color `"#8F802C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"INUKTITUT\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"iu`" -base_color `"#43C3B0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"INUPIAQ\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ik`" -base_color `"#ECF371`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"IRISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ga`" -base_color `"#FB7078`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ITALIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"it`" -base_color `"#95B5DF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"JAPANESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ja`" -base_color `"#5D776B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"JAVANESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"jv`" -base_color `"#5014C5`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KALAALLISUT\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"kl`" -base_color `"#050CF3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KANNADA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"kn`" -base_color `"#440B43`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KANURI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"kr`" -base_color `"#4F2AAC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KASHMIRI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ks`" -base_color `"#842C02`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KAZAKH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"kk`" -base_color `"#665F3D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KIKUYU\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ki`" -base_color `"#315679`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KINYARWANDA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"rw`" -base_color `"#CE1391`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KIRGHIZ\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ky`" -base_color `"#5F0D23`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KOMI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"kv`" -base_color `"#9B06C3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KONGO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"kg`" -base_color `"#74BC47`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KOREAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ko`" -base_color `"#F5C630`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KUANYAMA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"kj`" -base_color `"#D8CB60`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"KURDISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ku`" -base_color `"#467330`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"LAO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"lo`" -base_color `"#DD3B78`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"LATIN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"la`" -base_color `"#A73376`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"LATVIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"lv`" -base_color `"#A65EC1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"LIMBURGAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"li`" -base_color `"#13C252`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"LINGALA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ln`" -base_color `"#BBEE5B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"LITHUANIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"lt`" -base_color `"#E89C3E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"LUBA-KATANGA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"lu`" -base_color `"#4E97F3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"LUXEMBOURGISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"lb`" -base_color `"#4738EE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MACEDONIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mk`" -base_color `"#B69974`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MALAGASY\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mg`" -base_color `"#29D850`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MALAY\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ms`" -base_color `"#A74139`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MALAYALAM\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ml`" -base_color `"#FD4C87`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MALTESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mt`" -base_color `"#D6EE0B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MANX\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"gv`" -base_color `"#3F83E9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MAORI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mi`" -base_color `"#8339FD`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MARATHI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mr`" -base_color `"#93DEF1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MARSHALLESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mh`" -base_color `"#11DB75`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"MONGOLIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mn`" -base_color `"#A107D9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NAURU\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"na`" -base_color `"#7A0925`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NAVAJO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"nv`" -base_color `"#48F865`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NDONGA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ng`" -base_color `"#83538B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NEPALI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ne`" -base_color `"#5A15FC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NORTH NDEBELE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"nd`" -base_color `"#A1533B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NORTHERN SAMI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"se`" -base_color `"#AAD61B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NORWEGIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"no`" -base_color `"#13FF63`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NORWEGIAN BOKMÅL\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"nb`" -base_color `"#0AEB4A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"NORWEGIAN NYNORSK\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"nn`" -base_color `"#278B62`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OCCITAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"oc`" -base_color `"#B5B607`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OJIBWA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"oj`" -base_color `"#100894`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ORIYA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"or`" -base_color `"#0198FF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OROMO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"om`" -base_color `"#351BD8`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OSSETIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"os`" -base_color `"#BF715E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"PALI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"pi`" -base_color `"#BEB3FA`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"PASHTO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ps`" -base_color `"#A4236C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"PERSIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"fa`" -base_color `"#68A38E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"POLISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"pl`" -base_color `"#D4F797`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"PORTUGUESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"pt`" -base_color `"#71D659`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"PUNJABI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"pa`" -base_color `"#14F788`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"QUECHUA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"qu`" -base_color `"#268110`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ROMANIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ro`" -base_color `"#06603F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ROMANSH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"rm`" -base_color `"#3A73F3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"RUNDI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"rn`" -base_color `"#715E84`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"RUSSIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ru`" -base_color `"#DB77DA`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SAMOAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sm`" -base_color `"#A26738`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SANGO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sg`" -base_color `"#CA1C7E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SANSKRIT\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sa`" -base_color `"#CF9C76`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SARDINIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sc`" -base_color `"#28AF67`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SERBIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sr`" -base_color `"#FB3F2C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SHONA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sn`" -base_color `"#40F3EC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SICHUAN YI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ii`" -base_color `"#FA3474`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SINDHI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sd`" -base_color `"#62D1BE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SINHALA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"si`" -base_color `"#24787A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SLOVAK\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sk`" -base_color `"#66104F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SLOVENIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sl`" -base_color `"#6F79E6`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SOMALI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"so`" -base_color `"#A36185`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SOUTH NDEBELE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"nr`" -base_color `"#8090E5`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SOUTHERN SOTHO\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"st`" -base_color `"#4C3417`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SPANISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"es`" -base_color `"#7842AE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SUNDANESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"su`" -base_color `"#B2D05B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SWAHILI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sw`" -base_color `"#D32F20`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SWATI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ss`" -base_color `"#AA196D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"SWEDISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"sv`" -base_color `"#0EC5A2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TAGALOG\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tl`" -base_color `"#C9DDAC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TAHITIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ty`" -base_color `"#32009D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TAJIK\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tg`" -base_color `"#100ECF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TAMIL\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ta`" -base_color `"#E71FAE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TATAR\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tt`" -base_color `"#C17483`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TELUGU\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"te`" -base_color `"#E34ABD`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"THAI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"th`" -base_color `"#3FB501`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TIBETAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"bo`" -base_color `"#FF2496`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TIGRINYA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ti`" -base_color `"#9074F0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TONGA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"to`" -base_color `"#B3259E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TSONGA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ts`" -base_color `"#12687C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TSWANA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tn`" -base_color `"#DA3E89`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TURKISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tr`" -base_color `"#A08D29`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TURKMEN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tk`" -base_color `"#E70267`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"TWI\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tw`" -base_color `"#8A6C0F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"UIGHUR\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ug`" -base_color `"#79BC21`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"UKRAINIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"uk`" -base_color `"#EB60E9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"URDU\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ur`" -base_color `"#57E09D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"UZBEK\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"uz`" -base_color `"#4341F3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"VENDA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ve`" -base_color `"#4780ED`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"VIETNAMESE\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"vi`" -base_color `"#90A301`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"VOLAPÜK\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"vo`" -base_color `"#77D574`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"WALLOON\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"wa`" -base_color `"#BD440A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"WELSH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"cy`" -base_color `"#45E39C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"WESTERN FRISIAN\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"fy`" -base_color `"#01F471`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"WOLOF\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"wo`" -base_color `"#BDD498`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"XHOSA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"xh`" -base_color `"#0C6D9C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"YIDDISH\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"yi`" -base_color `"#111D14`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"YORUBA\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"yo`" -base_color `"#E815FF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ZHUANG\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"za`" -base_color `"#C62A89`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"ZULU\nAUDIO`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"zu`" -base_color `"#0049F8`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination audio_language
    Move-Item -Path output-orig -Destination output
    
}

################################################################################
# Function: CreateAwards
# Description:  Creates Awards
################################################################################
Function CreateAwards {
    Write-Host "Creating Awards"
    Set-Location $script_path
    Find-Path-Awards
    WriteToLogFile "ImageMagick Commands for     : Awards"
    WriteToLogFile "ImageMagick Commands for     : Awards-@base"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\Razzie.png`" -logo_offset -500 -logo_resize 1000 -text `"WINNERS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"winner`" -base_color `"#FF0C0C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\Razzie.png`" -logo_offset -500 -logo_resize 1000 -text `"NOMINATIONS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 240 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"nomination`" -base_color `"#FF0C0C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    
    $arr = @()
    for ($i = 1980; $i -lt 2030; $i++) {
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\Razzie.png`" -logo_offset -500 -logo_resize 1000 -text `"$i`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name $i -base_color `"#FF0C0C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzies
    
    $arr = @()
    for ($i = 1980; $i -lt 2030; $i++) {
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\Razzie.png`" -logo_offset -500 -logo_resize 1000 -text `"WINNERS\n$i`" -text_offset +700 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name $i -base_color `"#FF0C0C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzies\winner
    
    $arr = @()
    for ($i = 1980; $i -lt 2030; $i++) {
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\Razzie.png`" -logo_offset -500 -logo_resize 1000 -text `"NOMINATIONS\n$i`" -text_offset +700 -font `"ComfortAa-Medium`" -font_size 240 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name $i -base_color `"#FF0C0C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzies\nomination
    
    $arr = @()
    for ($i = 1980; $i -lt 2030; $i++) {
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\Razzie.png`" -logo_offset -500 -logo_resize 1000 -text `"BEST PICTURE\nWINNER\n$i`" -text_offset +700 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name $i -base_color `"#FF0C0C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzies\best
    Copy-Item -Path logos_award -Destination award\logos -Recurse
    Move-Item -Path output-orig -Destination output
    
    for ($i = 1900; $i -lt 2030; $i++) {
        Convert-AwardsBase $script_path\@base\@base-NULL.png Comfortaa-medium 250 $i $script_path\@base
    }

    ########################
    # BAFTA
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-BAFTA-Winner"
    for ($i = 1947; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-BAFTA.png $script_path\@base\@base-winners.png $i "$script_path\award\bafta\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-BAFTA-Nomination"
    for ($i = 1947; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-BAFTA.png $script_path\@base\@base-nomination.png $i "$script_path\award\bafta\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-BAFTA-Best"
    for ($i = 1947; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-BAFTA.png $script_path\@base\@base-best.png $i "$script_path\award\bafta\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-BAFTA"
    for ($i = 1947; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-BAFTA.png $script_path\@base\@base-$i.png $i "$script_path\award\bafta"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-BAFTA-Other"
    magick $script_path\@base\@zbase-BAFTA.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\bafta\winner.jpg"
    magick $script_path\@base\@zbase-BAFTA.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\bafta\nomination.jpg"
    magick $script_path\@base\@zbase-BAFTA.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\bafta\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-BAFTA.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\bafta\best_director_winner.jpg"
    magick $script_path\@base\@zbase-BAFTA.png $script_path\@base\@zbase-BAFTA.png -gravity center -background None -layers Flatten "$script_path\award\bafta\BAFTA.jpg"

    ########################
    # Berlinale
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Berlinale-Winner"
    for ($i = 1951; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Berlinale.png $script_path\@base\@base-winners.png $i "$script_path\award\Berlinale\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Berlinale-Nomination"
    for ($i = 1951; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Berlinale.png $script_path\@base\@base-nomination.png $i "$script_path\award\Berlinale\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Berlinale-Best"
    for ($i = 1951; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Berlinale.png $script_path\@base\@base-best.png $i "$script_path\award\Berlinale\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Berlinale"
    for ($i = 1951; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Berlinale.png $script_path\@base\@base-$i.png $i "$script_path\award\Berlinale"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Berlinale-Other"
    magick $script_path\@base\@zbase-Berlinale.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Berlinale\winner.jpg"
    magick $script_path\@base\@zbase-Berlinale.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Berlinale\nomination.jpg"
    magick $script_path\@base\@zbase-Berlinale.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Berlinale\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Berlinale.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Berlinale\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Berlinale.png $script_path\@base\@zbase-Berlinale.png -gravity center -background None -layers Flatten "$script_path\award\Berlinale\Berlinale.jpg"

    ########################
    # Cannes
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Cannes-Winner"
    for ($i = 1938; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Cannes.png $script_path\@base\@base-winners.png $i "$script_path\award\Cannes\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Cannes-Nomination"
    for ($i = 1938; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Cannes.png $script_path\@base\@base-nomination.png $i "$script_path\award\Cannes\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Cannes-Best"
    for ($i = 1938; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Cannes.png $script_path\@base\@base-best.png $i "$script_path\award\Cannes\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Cannes"
    for ($i = 1938; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Cannes.png $script_path\@base\@base-$i.png $i "$script_path\award\Cannes"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Cannes-Other"
    magick $script_path\@base\@zbase-Cannes.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Cannes\winner.jpg"
    magick $script_path\@base\@zbase-Cannes.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Cannes\nomination.jpg"
    magick $script_path\@base\@zbase-Cannes.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Cannes\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Cannes.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Cannes\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Cannes.png $script_path\@base\@zbase-Cannes.png -gravity center -background None -layers Flatten "$script_path\award\Cannes\Cannes.jpg"

    ########################
    # Cesar
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Cesar-Winner"
    for ($i = 1976; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Cesar.png $script_path\@base\@base-winners.png $i "$script_path\award\Cesar\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Cesar-Nomination"
    for ($i = 1976; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Cesar.png $script_path\@base\@base-nomination.png $i "$script_path\award\Cesar\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Cesar-Best"
    for ($i = 1976; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Cesar.png $script_path\@base\@base-best.png $i "$script_path\award\Cesar\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Cesar"
    for ($i = 1976; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Cesar.png $script_path\@base\@base-$i.png $i "$script_path\award\Cesar"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Cesar-Other"
    magick $script_path\@base\@zbase-Cesar.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Cesar\winner.jpg"
    magick $script_path\@base\@zbase-Cesar.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Cesar\nomination.jpg"
    magick $script_path\@base\@zbase-Cesar.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Cesar\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Cesar.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Cesar\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Cesar.png $script_path\@base\@zbase-Cesar.png -gravity center -background None -layers Flatten "$script_path\award\Cesar\Cesar.jpg"

    ########################
    # Emmys
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Emmys-Winner"
    for ($i = 1947; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Emmys.png $script_path\@base\@base-winners.png $i "$script_path\award\Emmys\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Emmys-Nomination"
    for ($i = 1947; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Emmys.png $script_path\@base\@base-nomination.png $i "$script_path\award\Emmys\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Emmys-Best"
    for ($i = 1947; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Emmys.png $script_path\@base\@base-best.png $i "$script_path\award\Emmys\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Emmys"
    for ($i = 1947; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Emmys.png $script_path\@base\@base-$i.png $i "$script_path\award\Emmys"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Emmys-Other"
    magick $script_path\@base\@zbase-Emmys.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Emmys\winner.jpg"
    magick $script_path\@base\@zbase-Emmys.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Emmys\nomination.jpg"
    magick $script_path\@base\@zbase-Emmys.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Emmys\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Emmys.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Emmys\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Emmys.png $script_path\@base\@zbase-Emmys.png -gravity center -background None -layers Flatten "$script_path\award\Emmys\Emmys.jpg"

    ########################
    # Golden
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Golden-Winner"
    for ($i = 1943; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Golden.png $script_path\@base\@base-winners.png $i "$script_path\award\Golden\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Golden-Nomination"
    for ($i = 1943; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Golden.png $script_path\@base\@base-nomination.png $i "$script_path\award\Golden\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Golden-Best"
    for ($i = 1943; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Golden.png $script_path\@base\@base-best.png $i "$script_path\award\Golden\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Golden"
    for ($i = 1943; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Golden.png $script_path\@base\@base-$i.png $i "$script_path\award\Golden"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Golden-Other"
    magick $script_path\@base\@zbase-Golden.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Golden\winner.jpg"
    magick $script_path\@base\@zbase-Golden.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Golden\nomination.jpg"
    magick $script_path\@base\@zbase-Golden.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Golden\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Golden.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Golden\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Golden.png $script_path\@base\@zbase-Golden.png -gravity center -background None -layers Flatten "$script_path\award\Golden\Golden.jpg"

    ########################
    # Oscars
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Oscars-Winner"
    for ($i = 1927; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Oscars.png $script_path\@base\@base-winners.png $i "$script_path\award\Oscars\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Oscars-Nomination"
    for ($i = 1927; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Oscars.png $script_path\@base\@base-nomination.png $i "$script_path\award\Oscars\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Oscars-Best"
    for ($i = 1927; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Oscars.png $script_path\@base\@base-best.png $i "$script_path\award\Oscars\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Oscars"
    for ($i = 1927; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Oscars.png $script_path\@base\@base-$i.png $i "$script_path\award\Oscars"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Oscars-Other"
    magick $script_path\@base\@zbase-Oscars.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Oscars\winner.jpg"
    magick $script_path\@base\@zbase-Oscars.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Oscars\nomination.jpg"
    magick $script_path\@base\@zbase-Oscars.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Oscars\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Oscars.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Oscars\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Oscars.png $script_path\@base\@zbase-Oscars.png -gravity center -background None -layers Flatten "$script_path\award\Oscars\Oscars.jpg"

    ########################
    # Sundance
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Sundance-Winner"
    for ($i = 1978; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Sundance.png $script_path\@base\@base-winners.png $i "$script_path\award\Sundance\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Sundance-Nomination"
    for ($i = 1978; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Sundance.png $script_path\@base\@base-nomination.png $i "$script_path\award\Sundance\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Sundance-Best"
    for ($i = 1978; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Sundance.png $script_path\@base\@base-best.png $i "$script_path\award\Sundance\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Sundance"
    for ($i = 1978; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Sundance.png $script_path\@base\@base-$i.png $i "$script_path\award\Sundance"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Sundance-Other"
    magick $script_path\@base\@zbase-Sundance.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Sundance\winner.jpg"
    magick $script_path\@base\@zbase-Sundance.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Sundance\nomination.jpg"
    magick $script_path\@base\@zbase-Sundance.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Sundance\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Sundance.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Sundance\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Sundance.png $script_path\@base\@zbase-grand_jury_winner.png -gravity center -background None -layers Flatten "$script_path\award\Sundance\grand_jury_winner.jpg"
    magick $script_path\@base\@zbase-Sundance.png $script_path\@base\@zbase-Sundance.png -gravity center -background None -layers Flatten "$script_path\award\Sundance\Sundance.jpg"

    ########################
    # Venice
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Venice-Winner"
    for ($i = 1932; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Venice.png $script_path\@base\@base-winners.png $i "$script_path\award\Venice\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Venice-Nomination"
    for ($i = 1932; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Venice.png $script_path\@base\@base-nomination.png $i "$script_path\award\Venice\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Venice-Best"
    for ($i = 1932; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Venice.png $script_path\@base\@base-best.png $i "$script_path\award\Venice\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Venice"
    for ($i = 1932; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Venice.png $script_path\@base\@base-$i.png $i "$script_path\award\Venice"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Venice-Other"
    magick $script_path\@base\@zbase-Venice.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Venice\winner.jpg"
    magick $script_path\@base\@zbase-Venice.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Venice\nomination.jpg"
    magick $script_path\@base\@zbase-Venice.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Venice\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Venice.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Venice\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Venice.png $script_path\@base\@zbase-Venice.png -gravity center -background None -layers Flatten "$script_path\award\Venice\Venice.jpg"

    ########################
    # Choice
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Choice-Winner"
    for ($i = 1929; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Choice.png $script_path\@base\@base-winners.png $i "$script_path\award\Choice\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Choice-Nomination"
    for ($i = 1929; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Choice.png $script_path\@base\@base-nomination.png $i "$script_path\award\Choice\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Choice-Best"
    for ($i = 1929; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Choice.png $script_path\@base\@base-best.png $i "$script_path\award\Choice\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Choice"
    for ($i = 1929; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Choice.png $script_path\@base\@base-$i.png $i "$script_path\award\Choice"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Choice-Other"
    magick $script_path\@base\@zbase-Choice.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Choice\winner.jpg"
    magick $script_path\@base\@zbase-Choice.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Choice\nomination.jpg"
    magick $script_path\@base\@zbase-Choice.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Choice\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Choice.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Choice\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Choice.png $script_path\@base\@zbase-Choice.png -gravity center -background None -layers Flatten "$script_path\award\Choice\Choice.jpg"

    ########################
    # Spirit
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Spirit-Winner"
    for ($i = 1986; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Spirit.png $script_path\@base\@base-winners.png $i "$script_path\award\Spirit\winner"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Spirit-Nomination"
    for ($i = 1986; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Spirit.png $script_path\@base\@base-nomination.png $i "$script_path\award\Spirit\nomination"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Spirit-Best"
    for ($i = 1986; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Spirit.png $script_path\@base\@base-best.png $i "$script_path\award\Spirit\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Spirit"
    for ($i = 1986; $i -lt 2030; $i++) {
        Convert-Awards $script_path\@base\@zbase-Spirit.png $script_path\@base\@base-$i.png $i "$script_path\award\Spirit"
    }

    WriteToLogFile "ImageMagick Commands for     : Awards-Spirit-Other"
    magick $script_path\@base\@zbase-Spirit.png $script_path\@base\@zbase-winner.png -gravity center -background None -layers Flatten "$script_path\award\Spirit\winner.jpg"
    magick $script_path\@base\@zbase-Spirit.png $script_path\@base\@zbase-nomination.png -gravity center -background None -layers Flatten "$script_path\award\Spirit\nomination.jpg"
    magick $script_path\@base\@zbase-Spirit.png $script_path\@base\@zbase-best_picture_winner.png -gravity center -background None -layers Flatten "$script_path\award\Spirit\best_picture_winner.jpg"
    magick $script_path\@base\@zbase-Spirit.png $script_path\@base\@zbase-best_director_winner.png -gravity center -background None -layers Flatten "$script_path\award\Spirit\best_director_winner.jpg"
    magick $script_path\@base\@zbase-Spirit.png $script_path\@base\@zbase-Spirit.png -gravity center -background None -layers Flatten "$script_path\award\Spirit\Spirit.jpg"

    Set-Location $script_path
}

################################################################################
# Function: CreateBased
# Description:  Creates Based Posters
################################################################################
Function CreateBased {
    Write-Host `"Creating Based Posters`"
    Set-Location $script_path
    # Find-Path `"$script_path\based`"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"`" -logo_offset +0 -logo_resize 1800 -text `"BASED ON A BOOK`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Book`" -base_color `"#131CA1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"`" -logo_offset +0 -logo_resize 1800 -text `"BASED ON A COMIC`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Comic`" -base_color `"#7856EF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"`" -logo_offset +0 -logo_resize 1800 -text `"BASED ON A TRUE STORY`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"True Story`" -base_color `"#BC0638`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"`" -logo_offset +0 -logo_resize 1800 -text `"BASED ON A VIDEO GAME`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Video Game`" -base_color `"#38CC66`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination based
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateChart
# Description:  Creates Chart
################################################################################
Function CreateChart {
    Write-Host "Creating Chart"
    Set-Location $script_path
    # Find-Path "$script_path\chart"
    Move-Item -Path output -Destination output-orig
    $chart = "POPULAR", "SEASON", "TOP RATED", "TRENDING"
    $arr = @()
    foreach ( $item in $chart ) { 
        $TextInfo = (Get-Culture).TextInfo
        $item_lower = $item.ToLower()
        $item_proper = $TextInfo.ToTitleCase("$item_lower")
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\AniList.png`" -logo_offset -500 -logo_resize 1500 -text `"$item`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"AniList $item_proper`" -base_color `"#414A81`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\AniDB.png`" -logo_offset -500 -logo_resize 1800 -text `"POPULAR`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"AniDB Popular`" -base_color `"#FF7E17`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\css.png`" -logo_offset -500 -logo_resize 1500 -text `"FAMILIES`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Common Sense Selection`" -base_color `"#1AA931`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Disney+.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"disney_top`" -base_color `"#002CA1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\google_play.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"google_top`" -base_color `"#B81282`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\HBO Max.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"hbo_top`" -base_color `"#9015C5`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\hulu.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"hulu_top`" -base_color `"#1BB68A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\IMDb.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"imdb_top`" -base_color `"#D7B00B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    
    $chart = "BOTTOM RATED", "BOX OFFICE", "LOWEST RATED", "POPULAR", "TOP 250"
    $arr = @()
    foreach ( $item in $chart ) { 
        $TextInfo = (Get-Culture).TextInfo
        $item_lower = $item.ToLower()
        $item_proper = $TextInfo.ToTitleCase("$item_lower")
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\IMDb.png`" -logo_offset -500 -logo_resize 1500 -text `"$item`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"IMDb $item_proper`" -base_color `"#D7B00B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\itunes.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"itunes_top`" -base_color `"#D500CC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    
    $chart = "FAVORITED", "POPULAR", "SEASON", "TOP AIRING", "TOP RATED"
    $arr = @()
    foreach ( $item in $chart ) { 
        $TextInfo = (Get-Culture).TextInfo
        $item_lower = $item.ToLower()
        $item_proper = $TextInfo.ToTitleCase("$item_lower")
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\MyAnimeList.png`" -logo_offset -500 -logo_resize 1500 -text `"$item`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"MyAnimeList $item_proper`" -base_color `"#304DA6`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Apple TV+.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"apple_top`" -base_color `"#494949`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Netflix.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"netflix_top`" -base_color `"#B4121D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Paramount+.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"paramount_top`" -base_color `"#1641C3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Pirated.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10 PIRATED`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Top 10 Pirated Movies of the Week`" -base_color `"#93561D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    
    $chart = "NEW EPISODES", "NEWLY RELEASED EPISODES", "NEWLY RELEASED", "PILOTS", "PLEX PEOPLE WATCHING", "PLEX PILOTS", "PLEX POPULAR", "PLEX WATCHED", "RECENTLY ADDED", "RECENTLY AIRED", "NEW PREMIERES"
    $arr = @()
    foreach ( $item in $chart ) { 
        $TextInfo = (Get-Culture).TextInfo
        $item_lower = $item.ToLower()
        $item_proper = $TextInfo.ToTitleCase("$item_lower")
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Plex.png`" -logo_offset -500 -logo_resize 1500 -text `"$item`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$item_proper`" -base_color `"#DC9924`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Prime Video.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"prime_top`" -base_color `"#43ABCE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\star_plus.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"star_plus_top`" -base_color `"#4A3159`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\StevenLu.png`" -logo_offset -500 -logo_resize 1500 -text `"STEVENLU'S POPULAR MOVIES`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"StevenLu's Popular Movies`" -base_color `"#1D2D51`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    
    $chart = "POPULAR", "WATCHED"
    $arr = @()
    foreach ( $item in $chart ) { 
        $TextInfo = (Get-Culture).TextInfo
        $item_lower = $item.ToLower()
        $item_proper = $TextInfo.ToTitleCase("$item_lower")
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Tautulli.png`" -logo_offset -500 -logo_resize 1500 -text `"$item`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Tautulli $item_proper`" -base_color `"#B9851F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    
    $chart = "AIRING TODAY", "NOW PLAYING", "ON THE AIR", "POPULAR", "TOP RATED", "TRENDING"
    $arr = @()
    foreach ( $item in $chart ) { 
        $TextInfo = (Get-Culture).TextInfo
        $item_lower = $item.ToLower()
        $item_proper = $TextInfo.ToTitleCase("$item_lower")
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\TMDb.png`" -logo_offset -500 -logo_resize 1500 -text `"$item`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TMDb $item_proper`" -base_color `"#062AC8`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr
    
    $chart = "COLLECTED", "NOW PLAYING", "POPULAR", "TRENDING", "WATCHED", "WATCHLIST"
    $arr = @()
    foreach ( $item in $chart ) { 
        $TextInfo = (Get-Culture).TextInfo
        $item_lower = $item.ToLower()
        $item_proper = $TextInfo.ToTitleCase("$item_lower")
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Trakt.png`" -logo_offset -500 -logo_resize 1500 -text `"$item`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Trakt $item_proper`" -base_color `"#CD1A20`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr

    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\Trakt.png`" -logo_offset -500 -logo_resize 1500 -text `"RECOMMENDED`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 220 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Trakt Recommended`" -base_color `"#CD1A20`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\vudu.png`" -logo_offset -500 -logo_resize 1500 -text `"TOP 10`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"vudu_top`" -base_color `"#3567AC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination chart
    Copy-Item -Path logos_chart -Destination chart\logos -Recurse
    Move-Item -Path output-orig -Destination output

}

################################################################################
# Function: CreateContentRating
# Description:  Creates ContentRating
################################################################################
Function CreateContentRating {
    Write-Host "Creating ContentRating"
    Set-Location $script_path
    # Find-Path "$script_path\content_rating"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nRATINGS`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"other`" -base_color `"#FF2000`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination content_rating
    
    $arr = @()
    for ($i = 1; $i -lt 19; $i++) {
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\cs.png`" -logo_offset -500 -logo_resize 1800 -text `"AGE $i+`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"#1AA931`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\cs.png`" -logo_offset -500 -logo_resize 1800 -text `"NOT RATED`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NR`" -base_color `"#1AA931`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination content_rating\cs
    
    $content_rating = "G", "PG", "PG-13", "R", "R+", "Rx"
    $arr = @()
    foreach ( $cr in $content_rating ) { 
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\mal.png`" -logo_offset -500 -logo_resize 1800 -text `"RATED $cr`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$cr`" -base_color `"#2444D1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\mal.png`" -logo_offset -500 -logo_resize 1800 -text `"NOT RATED`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NR`" -base_color `"#2444D1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination content_rating\mal
    
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\uk12.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"12`" -base_color `"#FF7D13`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\uk12A.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"12A`" -base_color `"#FF7D13`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\uk15.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"15`" -base_color `"#FC4E93`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\uk18.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"18`" -base_color `"#DC0A0B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\uknr.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NR`" -base_color `"#0E84A3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\ukpg.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"PG`" -base_color `"#FBAE00`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\ukr18.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"R18`" -base_color `"#016ED3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\uku.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"U`" -base_color `"#0BC700`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination content_rating\uk

    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\usg.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"G`" -base_color `"#79EF06`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\usnc17.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NC-17`" -base_color `"#EE45A4`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\usnr.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NR`" -base_color `"#0E84A3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\uspg.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"PG`" -base_color `"#918CE2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\uspg13.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"PG-13`" -base_color `"#A124CC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\usr.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"R`" -base_color `"#FB5226`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\ustv14.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV-14`" -base_color `"#C29CC1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\ustvg.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV-G`" -base_color `"#98A5BB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\ustvma.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV-MA`" -base_color `"#DB8689`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\ustvpg.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV-PG`" -base_color `"#5B0EFD`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\ustvy.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV-Y`" -base_color `"#3EB3C1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination content_rating\us
    Copy-Item -Path logos_content_rating -Destination content_rating\logos -Recurse
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateCountry
# Description:  Creates Country
################################################################################
Function CreateCountry {
    Write-Host "Creating Country"
    Set-Location $script_path
    Find-Path "$script_path\country"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nCOUNTRIES`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Other Countries`" -base_color `"#FF2000`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ae.png`" -logo_offset -500 -logo_resize 1500 -text `"UNITED ARAB EMIRATES`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"United Arab Emirates`" -base_color `"#BC9C16`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ar.png`" -logo_offset -500 -logo_resize 750 -text `"ARGENTINA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Argentina`" -base_color `"#F05610`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\at.png`" -logo_offset -500 -logo_resize 1500 -text `"AUSTRIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Austria`" -base_color `"#F5E6AE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\au.png`" -logo_offset -500 -logo_resize 1500 -text `"AUSTRALIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Australia`" -base_color `"#D5237B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\be.png`" -logo_offset -500 -logo_resize 1500 -text `"BELGIUM`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Belgium`" -base_color `"#AC98DB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\bg.png`" -logo_offset -500 -logo_resize 1500 -text `"BULGARIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Bulgaria`" -base_color `"#79AB96`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\br.png`" -logo_offset -500 -logo_resize 1500 -text `"BRAZIL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Brazil`" -base_color `"#EE9DA9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\bs.png`" -logo_offset -500 -logo_resize 1500 -text `"BAHAMAS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Bahamas`" -base_color `"#F6CDF0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ca.png`" -logo_offset -500 -logo_resize 1500 -text `"CANADA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Canada`" -base_color `"#32DE58`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ch.png`" -logo_offset -500 -logo_resize 1500 -text `"SWITZERLAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Switzerland`" -base_color `"#5803F1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\cl.png`" -logo_offset -500 -logo_resize 1500 -text `"CHILE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Chile`" -base_color `"#AAC41F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\cn.png`" -logo_offset -500 -logo_resize 1500 -text `"CHINA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"China`" -base_color `"#902A62`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\cr.png`" -logo_offset -500 -logo_resize 1500 -text `"COST RICA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Costa Rica`" -base_color `"#41F306`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\cz.png`" -logo_offset -500 -logo_resize 1500 -text `"CZECH REPUBLIC`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Czech Republic`" -base_color `"#9ECE8F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\de.png`" -logo_offset -500 -logo_resize 1500 -text `"GERMANY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Germany`" -base_color `"#97FDAE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\dk.png`" -logo_offset -500 -logo_resize 1500 -text `"DENMARK`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Denmark`" -base_color `"#685ECB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\do.png`" -logo_offset -500 -logo_resize 1500 -text `"DOMINICAN REPUBLIC`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Dominican Republic`" -base_color `"#83F0A2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ee.png`" -logo_offset -500 -logo_resize 1500 -text `"ESTONIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Estonia`" -base_color `"#5145DA`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\eg.png`" -logo_offset -500 -logo_resize 1500 -text `"EGYPT`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Egypt`" -base_color `"#86B137`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\es.png`" -logo_offset -500 -logo_resize 1500 -text `"SPAIN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Spain`" -base_color `"#99DA4B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\fi.png`" -logo_offset -500 -logo_resize 750 -text `"FINLAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Finland`" -base_color `"#856518`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\fr.png`" -logo_offset -500 -logo_resize 1500 -text `"FRANCE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"France`" -base_color `"#D0404D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\gb.png`" -logo_offset -500 -logo_resize 1500 -text `"UNITED KINGDOM`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"United Kingdom`" -base_color `"#C7B89D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\gr.png`" -logo_offset -500 -logo_resize 1500 -text `"GREECE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Greece`" -base_color `"#431832`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\hk.png`" -logo_offset -500 -logo_resize 1500 -text `"HONG KONG`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hong Kong`" -base_color `"#F6B541`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\hr.png`" -logo_offset -500 -logo_resize 1500 -text `"CROATIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Croatia`" -base_color `"#62BF53`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\hu.png`" -logo_offset -500 -logo_resize 1500 -text `"HUNGARY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hungary`" -base_color `"#E5983C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\id.png`" -logo_offset -500 -logo_resize 1500 -text `"INDONESIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Indonesia`" -base_color `"#3E33E4`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ie.png`" -logo_offset -500 -logo_resize 1500 -text `"IRELAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ireland`" -base_color `"#C6377E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\il.png`" -logo_offset -500 -logo_resize 650 -text `"ISRAEL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Israel`" -base_color `"#41E0A9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\in.png`" -logo_offset -500 -logo_resize 1500 -text `"INDIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"India`" -base_color `"#A6404A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\is.png`" -logo_offset -500 -logo_resize 1500 -text `"ICELAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Iceland`" -base_color `"#CE31A0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\it.png`" -logo_offset -500 -logo_resize 1500 -text `"ITALY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Italy`" -base_color `"#57B9BF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ir.png`" -logo_offset -500 -logo_resize 1500 -text `"IRAN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Iran`" -base_color `"#2AAC15`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\jp.png`" -logo_offset -500 -logo_resize 1500 -text `"JAPAN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Japan`" -base_color `"#4FCF54`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\kr.png`" -logo_offset -500 -logo_resize 1500 -text `"KOREA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Korea`" -base_color `"#127FFE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\lk.png`" -logo_offset -500 -logo_resize 750 -text `"SRI LANKA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sri Lanka`" -base_color `"#6415FD`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\lu.png`" -logo_offset -500 -logo_resize 750 -text `"LUXEMBOURG`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Luxembourg`" -base_color `"#C90586`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\lv.png`" -logo_offset -500 -logo_resize 1500 -text `"LATVIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Latvia`" -base_color `"#5326A3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ma.png`" -logo_offset -500 -logo_resize 1500 -text `"MOROCCO`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Morocco`" -base_color `"#B28BDC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\mx.png`" -logo_offset -500 -logo_resize 1500 -text `"MEXICO`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mexico`" -base_color `"#964F76`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\my.png`" -logo_offset -500 -logo_resize 1500 -text `"MALAYSIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Malaysia`" -base_color `"#9630B4`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\nl.png`" -logo_offset -500 -logo_resize 1500 -text `"NETHERLANDS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 240 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Netherlands`" -base_color `"#B14FAA`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\no.png`" -logo_offset -500 -logo_resize 1500 -text `"NORWAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Norway`" -base_color `"#AC320E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\np.png`" -logo_offset -500 -logo_resize 1500 -text `"NEPAL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nepal`" -base_color `"#3F847B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\nz.png`" -logo_offset -500 -logo_resize 1500 -text `"NEW ZEALAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"New Zealand`" -base_color `"#E0A486`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pa.png`" -logo_offset -500 -logo_resize 1500 -text `"PANAMA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Panama`" -base_color `"#417818`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pe.png`" -logo_offset -500 -logo_resize 750 -text `"PERU`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Peru`" -base_color `"#803704`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ph.png`" -logo_offset -500 -logo_resize 1500 -text `"PHILIPPINES`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Philippines`" -base_color `"#2DF423`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pk.png`" -logo_offset -500 -logo_resize 1500 -text `"PAKISTAN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pakistan`" -base_color `"#6FF34E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pl.png`" -logo_offset -500 -logo_resize 1500 -text `"POLAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Poland`" -base_color `"#BAF6C2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pt.png`" -logo_offset -500 -logo_resize 1500 -text `"PORTUGAL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Portugal`" -base_color `"#A1DE3F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\qa.png`" -logo_offset -500 -logo_resize 750 -text `"QATAR`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Qatar`" -base_color `"#4C1FCC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ro.png`" -logo_offset -500 -logo_resize 1500 -text `"ROMANIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Romania`" -base_color `"#ABD0CF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\rs.png`" -logo_offset -500 -logo_resize 1500 -text `"SERBIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Serbia`" -base_color `"#7E0D8E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ru.png`" -logo_offset -500 -logo_resize 1500 -text `"RUSSIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Russia`" -base_color `"#97D820`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\sa.png`" -logo_offset -500 -logo_resize 1500 -text `"SAUDI ARABIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Saudi Arabia`" -base_color `"#D34B83`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\se.png`" -logo_offset -500 -logo_resize 1500 -text `"SWEDEN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sweden`" -base_color `"#E3C61A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\sg.png`" -logo_offset -500 -logo_resize 1500 -text `"SINGAPORE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Singapore`" -base_color `"#0328DB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\th.png`" -logo_offset -500 -logo_resize 1500 -text `"THAILAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Thailand`" -base_color `"#32DBD9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\tr.png`" -logo_offset -500 -logo_resize 1500 -text `"TURKEY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Turkey`" -base_color `"#CD90D1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ua.png`" -logo_offset -500 -logo_resize 1500 -text `"UKRAINE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ukraine`" -base_color `"#1640B6`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\us.png`" -logo_offset -500 -logo_resize 1500 -text `"UNITED STATES OF AMERICA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"United States of America`" -base_color `"#D2A345`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\vn.png`" -logo_offset -500 -logo_resize 1500 -text `"VIETNAM`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Vietnam`" -base_color `"#19156E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\za.png`" -logo_offset -500 -logo_resize 1500 -text `"SOUTH AFRICA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"South Africa`" -base_color `"#E7BB4A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    LaunchScripts -ScriptPaths $arr
    
    Move-Item -Path output -Destination country\color
    
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nCOUNTRIES`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Other Countries`" -base_color `"#FF2000`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ae.png`" -logo_offset -500 -logo_resize 1500 -text `"UNITED ARAB EMIRATES`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"United Arab Emirates`" -base_color `"#BC9C16`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ar.png`" -logo_offset -500 -logo_resize 750 -text `"ARGENTINA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Argentina`" -base_color `"#F05610`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\at.png`" -logo_offset -500 -logo_resize 1500 -text `"AUSTRIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Austria`" -base_color `"#F5E6AE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\au.png`" -logo_offset -500 -logo_resize 1500 -text `"AUSTRALIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Australia`" -base_color `"#D5237B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\be.png`" -logo_offset -500 -logo_resize 1500 -text `"BELGIUM`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Belgium`" -base_color `"#AC98DB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\bg.png`" -logo_offset -500 -logo_resize 1500 -text `"BULGARIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Bulgaria`" -base_color `"#79AB96`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\br.png`" -logo_offset -500 -logo_resize 1500 -text `"BRAZIL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Brazil`" -base_color `"#EE9DA9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\bs.png`" -logo_offset -500 -logo_resize 1500 -text `"BAHAMAS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Bahamas`" -base_color `"#F6CDF0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ca.png`" -logo_offset -500 -logo_resize 1500 -text `"CANADA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Canada`" -base_color `"#32DE58`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ch.png`" -logo_offset -500 -logo_resize 1500 -text `"SWITZERLAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Switzerland`" -base_color `"#5803F1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\cl.png`" -logo_offset -500 -logo_resize 1500 -text `"CHILE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Chile`" -base_color `"#AAC41F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\cn.png`" -logo_offset -500 -logo_resize 1500 -text `"CHINA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"China`" -base_color `"#902A62`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\cr.png`" -logo_offset -500 -logo_resize 1500 -text `"COST RICA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Costa Rica`" -base_color `"#41F306`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\cz.png`" -logo_offset -500 -logo_resize 1500 -text `"CZECH REPUBLIC`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Czech Republic`" -base_color `"#9ECE8F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\de.png`" -logo_offset -500 -logo_resize 1500 -text `"GERMANY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Germany`" -base_color `"#97FDAE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\dk.png`" -logo_offset -500 -logo_resize 1500 -text `"DENMARK`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Denmark`" -base_color `"#685ECB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\do.png`" -logo_offset -500 -logo_resize 1500 -text `"DOMINICAN REPUBLIC`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Dominican Republic`" -base_color `"#83F0A2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ee.png`" -logo_offset -500 -logo_resize 1500 -text `"ESTONIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Estonia`" -base_color `"#5145DA`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\eg.png`" -logo_offset -500 -logo_resize 1500 -text `"EGYPT`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Egypt`" -base_color `"#86B137`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\es.png`" -logo_offset -500 -logo_resize 1500 -text `"SPAIN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Spain`" -base_color `"#99DA4B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\fi.png`" -logo_offset -500 -logo_resize 750 -text `"FINLAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Finland`" -base_color `"#856518`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\fr.png`" -logo_offset -500 -logo_resize 1500 -text `"FRANCE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"France`" -base_color `"#D0404D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\gb.png`" -logo_offset -500 -logo_resize 1500 -text `"UNITED KINGDOM`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"United Kingdom`" -base_color `"#C7B89D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\gr.png`" -logo_offset -500 -logo_resize 1500 -text `"GREECE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Greece`" -base_color `"#431832`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\hk.png`" -logo_offset -500 -logo_resize 1500 -text `"HONG KONG`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hong Kong`" -base_color `"#F6B541`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\hr.png`" -logo_offset -500 -logo_resize 1500 -text `"CROATIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Croatia`" -base_color `"#62BF53`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\hu.png`" -logo_offset -500 -logo_resize 1500 -text `"HUNGARY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hungary`" -base_color `"#E5983C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\id.png`" -logo_offset -500 -logo_resize 1500 -text `"INDONESIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Indonesia`" -base_color `"#3E33E4`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ie.png`" -logo_offset -500 -logo_resize 1500 -text `"IRELAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ireland`" -base_color `"#C6377E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\il.png`" -logo_offset -500 -logo_resize 650 -text `"ISRAEL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Israel`" -base_color `"#41E0A9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\in.png`" -logo_offset -500 -logo_resize 1500 -text `"INDIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"India`" -base_color `"#A6404A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\is.png`" -logo_offset -500 -logo_resize 1500 -text `"ICELAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Iceland`" -base_color `"#CE31A0`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\it.png`" -logo_offset -500 -logo_resize 1500 -text `"ITALY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Italy`" -base_color `"#57B9BF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ir.png`" -logo_offset -500 -logo_resize 1500 -text `"IRAN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Iran`" -base_color `"#2AAC15`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\jp.png`" -logo_offset -500 -logo_resize 1500 -text `"JAPAN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Japan`" -base_color `"#4FCF54`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\kr.png`" -logo_offset -500 -logo_resize 1500 -text `"KOREA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Korea`" -base_color `"#127FFE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\lk.png`" -logo_offset -500 -logo_resize 750 -text `"SRI LANKA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sri Lanka`" -base_color `"#6415FD`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\lu.png`" -logo_offset -500 -logo_resize 750 -text `"LUXEMBOURG`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Luxembourg`" -base_color `"#C90586`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\lv.png`" -logo_offset -500 -logo_resize 1500 -text `"LATVIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Latvia`" -base_color `"#5326A3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ma.png`" -logo_offset -500 -logo_resize 1500 -text `"MOROCCO`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Morocco`" -base_color `"#B28BDC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\mx.png`" -logo_offset -500 -logo_resize 1500 -text `"MEXICO`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mexico`" -base_color `"#964F76`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\my.png`" -logo_offset -500 -logo_resize 1500 -text `"MALAYSIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Malaysia`" -base_color `"#9630B4`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\nl.png`" -logo_offset -500 -logo_resize 1500 -text `"NETHERLANDS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 240 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Netherlands`" -base_color `"#B14FAA`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\no.png`" -logo_offset -500 -logo_resize 1500 -text `"NORWAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Norway`" -base_color `"#AC320E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\np.png`" -logo_offset -500 -logo_resize 1500 -text `"NEPAL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nepal`" -base_color `"#3F847B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\nz.png`" -logo_offset -500 -logo_resize 1500 -text `"NEW ZEALAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"New Zealand`" -base_color `"#E0A486`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pa.png`" -logo_offset -500 -logo_resize 1500 -text `"PANAMA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Panama`" -base_color `"#417818`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pe.png`" -logo_offset -500 -logo_resize 750 -text `"PERU`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Peru`" -base_color `"#803704`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ph.png`" -logo_offset -500 -logo_resize 1500 -text `"PHILIPPINES`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Philippines`" -base_color `"#2DF423`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pk.png`" -logo_offset -500 -logo_resize 1500 -text `"PAKISTAN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pakistan`" -base_color `"#6FF34E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pl.png`" -logo_offset -500 -logo_resize 1500 -text `"POLAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Poland`" -base_color `"#BAF6C2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\pt.png`" -logo_offset -500 -logo_resize 1500 -text `"PORTUGAL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Portugal`" -base_color `"#A1DE3F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\qa.png`" -logo_offset -500 -logo_resize 750 -text `"QATAR`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Qatar`" -base_color `"#4C1FCC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ro.png`" -logo_offset -500 -logo_resize 1500 -text `"ROMANIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Romania`" -base_color `"#ABD0CF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\rs.png`" -logo_offset -500 -logo_resize 1500 -text `"SERBIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Serbia`" -base_color `"#7E0D8E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ru.png`" -logo_offset -500 -logo_resize 1500 -text `"RUSSIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Russia`" -base_color `"#97D820`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\sa.png`" -logo_offset -500 -logo_resize 1500 -text `"SAUDI ARABIA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Saudi Arabia`" -base_color `"#D34B83`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\se.png`" -logo_offset -500 -logo_resize 1500 -text `"SWEDEN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sweden`" -base_color `"#E3C61A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\sg.png`" -logo_offset -500 -logo_resize 1500 -text `"SINGAPORE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Singapore`" -base_color `"#0328DB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\th.png`" -logo_offset -500 -logo_resize 1500 -text `"THAILAND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Thailand`" -base_color `"#32DBD9`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\tr.png`" -logo_offset -500 -logo_resize 1500 -text `"TURKEY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Turkey`" -base_color `"#CD90D1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\ua.png`" -logo_offset -500 -logo_resize 1500 -text `"UKRAINE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ukraine`" -base_color `"#1640B6`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\us.png`" -logo_offset -500 -logo_resize 1500 -text `"UNITED STATES OF AMERICA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"United States of America`" -base_color `"#D2A345`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\vn.png`" -logo_offset -500 -logo_resize 1500 -text `"VIETNAM`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Vietnam`" -base_color `"#19156E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\za.png`" -logo_offset -500 -logo_resize 1500 -text `"SOUTH AFRICA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"South Africa`" -base_color `"#E7BB4A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination country\white
    Copy-Item -Path logos_country -Destination country\logos -Recurse
    Move-Item -Path output-orig -Destination output
    
}

################################################################################
# Function: CreateDecade
# Description:  Creates Decade
################################################################################
Function CreateDecade {
    Write-Host "Creating Decade"
    Set-Location $script_path
    Find-Path "$script_path\decade"
    Find-Path "$script_path\decade\best"
    WriteToLogFile "ImageMagick Commands for     : Decades"
    WriteToLogFile "ImageMagick Commands for     : Decades-Best"
    .\create_poster.ps1 -logo "$script_path\transparent.png" -logo_offset +0 -logo_resize 1800 -text "OTHER\nDECADES" -text_offset +0 -font "ComfortAa-Medium" -font_size 250 -font_color "#FFFFFF" -border 0 -border_width 15 -border_color "#FFFFFF" -avg_color_image "" -out_name "other" -base_color "#FF2000" -gradient 1 -avg_color 0 -clean 1 -white_wash 1
    Move-Item output\other.jpg -Destination decade
        
    for ($i = 1880; $i -lt 2030; $i += 10) {
        Convert-Decades $script_path\@base\@zbase-decade.png $script_path\@base\@zbase-best.png $i "$script_path\decade\best"
    }
    
    WriteToLogFile "ImageMagick Commands for     : Decades"
    for ($i = 1880; $i -lt 2030; $i += 10) {
        Convert-Decades $script_path\@base\@zbase-decade.png $script_path\@base\@zbase-decade.png $i "$script_path\decade"
    }
}

################################################################################
# Function: CreateFranchise
# Description:  Creates Franchise
################################################################################
Function CreateFranchise {
    Write-Host "Creating Franchise"
    Set-Location $script_path
    # Find-Path "$script_path\franchise"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\28 Days Weeks Later.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"28 Days Weeks Later`" -base_color `"#B93033`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\9-1-1.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"9-1-1`" -base_color `"#C62B2B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\A Nightmare on Elm Street.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"A Nightmare on Elm Street`" -base_color `"#BE3C3E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Alien Predator.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Alien Predator`" -base_color `"#1EAC1B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Alien.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Alien`" -base_color `"#18BC56`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\American Pie.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"American Pie`" -base_color `"#C24940`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Anaconda.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Anaconda`" -base_color `"#A42E2D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Angels In The.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Angels In The`" -base_color `"#4869BD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Appleseed.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Appleseed`" -base_color `"#986E22`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Archie Comics.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Archie Comics`" -base_color `"#DFB920`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Arrowverse.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Arrowverse`" -base_color `"#2B8F40`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Barbershop.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Barbershop`" -base_color `"#2399AF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Batman.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Batman`" -base_color `"#525252`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Bourne.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Bourne`" -base_color `"#383838`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Charlie Brown.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Charlie Brown`" -base_color `"#C8BF2B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Cloverfield.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cloverfield`" -base_color `"#0E1672`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Cornetto Trilogy.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cornetto Trilogy`" -base_color `"#6C9134`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\CSI.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CSI`" -base_color `"#969322`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\DC Super Hero Girls.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"DC Super Hero Girls`" -base_color `"#299CB1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\DC Universe.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"DC Universe`" -base_color `"#213DB6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Deadpool.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Deadpool`" -base_color `"#BD393C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Despicable Me.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Despicable Me`" -base_color `"#C77344`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Doctor Who.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Doctor Who`" -base_color `"#1C38B4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Escape From.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Escape From`" -base_color `"#B82026`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Fantastic Beasts.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Fantastic Beasts`" -base_color `"#9E972B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Fast & Furious.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Fast & Furious`" -base_color `"#8432C4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\FBI.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"FBI`" -base_color `"#FFD32C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Final Fantasy.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Final Fantasy`" -base_color `"#86969F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Friday the 13th.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Friday the 13th`" -base_color `"#B9242A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Frozen.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Frozen`" -base_color `"#2A5994`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Garfield.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Garfield`" -base_color `"#C28117`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Ghostbusters.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ghostbusters`" -base_color `"#414141`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Godzilla (Heisei).png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Godzilla (Heisei)`" -base_color `"#BFB330`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Godzilla (Showa).png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Godzilla (Showa)`" -base_color `"#BDB12A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Godzilla.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Godzilla`" -base_color `"#B82737`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Halloween.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Halloween`" -base_color `"#BB2D22`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Halo.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Halo`" -base_color `"#556A92`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Hannibal Lecter.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hannibal Lecter`" -base_color `"#383838`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Harry Potter.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Harry Potter`" -base_color `"#9D9628`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Has Fallen.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Has Fallen`" -base_color `"#3B3B3B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Ice Age.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ice Age`" -base_color `"#5EA0BB`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\In Association with Marvel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"In Association with Marvel`" -base_color `"#C42424`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Indiana Jones.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Indiana Jones`" -base_color `"#D97724`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\IP Man.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"IP Man`" -base_color `"#8D7E63`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\James Bond 007.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"James Bond 007`" -base_color `"#414141`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Jurassic Park.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Jurassic Park`" -base_color `"#902E32`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Karate Kid.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Karate Kid`" -base_color `"#AC6822`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Law & Order.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Law & Order`" -base_color `"#5B87AB`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Lord of the Rings.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Lord of the Rings`" -base_color `"#C38B27`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Madagascar.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Madagascar`" -base_color `"#AD8F27`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Marvel Cinematic Universe.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Marvel Cinematic Universe`" -base_color `"#AD2B2B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Marx Brothers.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Marx Brothers`" -base_color `"#347294`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Middle Earth.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Middle Earth`" -base_color `"#C28A25`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Mission Impossible.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mission Impossible`" -base_color `"#BF1616`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Monty Python.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Monty Python`" -base_color `"#B61C22`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Mortal Kombat.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mortal Kombat`" -base_color `"#BA4D29`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Mothra.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mothra`" -base_color `"#9C742A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\NCIS.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NCIS`" -base_color `"#AC605F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\One Chicago.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"One Chicago`" -base_color `"#BE7C30`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Oz.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Oz`" -base_color `"#AD8F27`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Pet Sematary.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pet Sematary`" -base_color `"#B71F25`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Pirates of the Caribbean.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pirates of the Caribbean`" -base_color `"#7F6936`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Planet of the Apes.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Planet of the Apes`" -base_color `"#4E4E4E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Pokémon.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pokémon`" -base_color `"#FECA06`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Power Rangers.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Power Rangers`" -base_color `"#24AA60`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Pretty Little Liars.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pretty Little Liars`" -base_color `"#BD0F0F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Resident Evil Biohazard.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Resident Evil Biohazard`" -base_color `"#930B0B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Resident Evil.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Resident Evil`" -base_color `"#940E0F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Rocky Creed.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Rocky Creed`" -base_color `"#C52A2A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Rocky.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Rocky`" -base_color `"#C22121`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Scooby-Doo!.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Scooby-Doo!`" -base_color `"#5F3879`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Shaft.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Shaft`" -base_color `"#382637`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Shrek.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Shrek`" -base_color `"#3DB233`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Spider-Man.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Spider-Man`" -base_color `"#C11B1B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Star Trek Alternate Reality.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Trek Alternate Reality`" -base_color `"#C78639`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Star Trek The Next Generation.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Trek The Next Generation`" -base_color `"#B7AE4C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Star Trek The Original Series.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Trek The Original Series`" -base_color `"#BB5353`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Star Trek.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Trek`" -base_color `"#C2A533`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Star Wars Legends.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Wars Legends`" -base_color `"#BAA416`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Star Wars Skywalker Saga.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Wars Skywalker Saga`" -base_color `"#5C5C5C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Star Wars.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Wars`" -base_color `"#C2A21B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Stargate.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Stargate`" -base_color `"#6C73A1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Street Fighter.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Street Fighter`" -base_color `"#C5873F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Superman.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Superman`" -base_color `"#C34544`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Teenage Mutant Ninja Turtles.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Teenage Mutant Ninja Turtles`" -base_color `"#78A82E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Hunger Games.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Hunger Games`" -base_color `"#619AB5`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Man With No Name.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Man With No Name`" -base_color `"#9A7B40`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Mummy.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Mummy`" -base_color `"#C28A25`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Rookie.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Rookie`" -base_color `"#DC5A2B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Texas Chainsaw Massacre.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Texas Chainsaw Massacre`" -base_color `"#B15253`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Three Stooges.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Three Stooges`" -base_color `"#B9532A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Twilight Zone.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Twilight Zone`" -base_color `"#16245F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Walking Dead.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Walking Dead`" -base_color `"#797F48`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Tom and Jerry.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Tom and Jerry`" -base_color `"#B9252B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Tomb Raider.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Tomb Raider`" -base_color `"#620D0E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Toy Story.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Toy Story`" -base_color `"#CEB423`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Transformers.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Transformers`" -base_color `"#B02B2B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Tron.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Tron`" -base_color `"#5798B2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Twilight.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Twilight`" -base_color `"#3B3B3B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Unbreakable.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Unbreakable`" -base_color `"#445DBB`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Wallace & Gromit.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Wallace & Gromit`" -base_color `"#BA2A20`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Wizarding World.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Wizarding World`" -base_color `"#7B7A33`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\X-Men.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"X-Men`" -base_color `"#636363`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination franchise
    Copy-Item -Path logos_franchise -Destination franchise\logos -Recurse
    Move-Item -Path output-orig -Destination output
    
}

################################################################################
# Function: CreateGenre
# Description:  Creates Genre
################################################################################
Function CreateGenre {
    Write-Host "Creating Genre"
    Set-Location $script_path
    # Find-Path "$script_path\genre"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nGENRES`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"other`" -base_color `"#FF2000`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Action & adventure.png`" -logo_offset -500 -logo_resize 1800 -text `"ACTION & ADVENTURE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Action & adventure`" -base_color `"#65AEA5`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Action.png`" -logo_offset -500 -logo_resize 1800 -text `"ACTION`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Action`" -base_color `"#387DBF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Adult.png`" -logo_offset -500 -logo_resize 1800 -text `"ADULT`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Adult`" -base_color `"#D02D2D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Adventure.png`" -logo_offset -500 -logo_resize 1800 -text `"ADVENTURE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Adventure`" -base_color `"#40B997`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Animation.png`" -logo_offset -500 -logo_resize 1800 -text `"ANIMATION`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Animation`" -base_color `"#9035BE`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Anime.png`" -logo_offset -500 -logo_resize 1800 -text `"ANIME`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Anime`" -base_color `"#41A4BE`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\APAC month.png`" -logo_offset -500 -logo_resize 1800 -text `"ASIAN AMERICAN & PACIFIC ISLANDER HERITAGE MONTH`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 193 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"APAC month`" -base_color `"#0EC26B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Assassin.png`" -logo_offset -500 -logo_resize 1800 -text `"ASSASSIN`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Assasin`" -base_color `"#C52124`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Biography.png`" -logo_offset -500 -logo_resize 1800 -text `"BIOGRAPHY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Biography`" -base_color `"#C1A13E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Biopic.png`" -logo_offset -500 -logo_resize 1800 -text `"BIOPIC`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Biopic`" -base_color `"#C1A13E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Black History.png`" -logo_offset -500 -logo_resize 1800 -text `"BLACK HISTORY MONTH`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Black History`" -base_color `"#D86820`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Black History2.png`" -logo_offset -500 -logo_resize 1800 -text `"BLACK HISTORY MONTH`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Black History2`" -base_color `"#D86820`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Boys Love.png`" -logo_offset -500 -logo_resize 1800 -text `"BOYS LOVE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Boys Love`" -base_color `"#85ADAC`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Cars.png`" -logo_offset -500 -logo_resize 1800 -text `"CARS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cars`" -base_color `"#7B36D2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Children.png`" -logo_offset -500 -logo_resize 1800 -text `"CHILDREN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Children`" -base_color `"#9C42C2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Comedy.png`" -logo_offset -500 -logo_resize 1800 -text `"COMEDY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Comedy`" -base_color `"#B7363E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Competition.png`" -logo_offset -500 -logo_resize 1800 -text `"COMPETITION`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Competition`" -base_color `"#55BF48`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Con Artist.png`" -logo_offset -500 -logo_resize 1800 -text `"CON ARTIST`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Con Artist`" -base_color `"#C7A5A1`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Creature Horror.png`" -logo_offset -500 -logo_resize 1800 -text `"CREATURE HORROR`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Creature Horror`" -base_color `"#AD8603`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Crime.png`" -logo_offset -500 -logo_resize 1800 -text `"CRIME`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Crime`" -base_color `"#888888`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Demons.png`" -logo_offset -500 -logo_resize 1800 -text `"DEMONS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Demons`" -base_color `"#9A2A2A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Disabilities.png`" -logo_offset -500 -logo_resize 1800 -text `"DAY OF PERSONS WITH DISABILITIES`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 235 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disabilities`" -base_color `"#40B9FE`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Documentary.png`" -logo_offset -500 -logo_resize 1800 -text `"DOCUMENTARY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 230 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Documentary`" -base_color `"#2C4FA8`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Drama.png`" -logo_offset -500 -logo_resize 1800 -text `"DRAMA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Drama`" -base_color `"#A22C2C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Ecchi.png`" -logo_offset -500 -logo_resize 1800 -text `"ECCHI`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ecchi`" -base_color `"#C592C0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Erotica.png`" -logo_offset -500 -logo_resize 1800 -text `"EROTICA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Erotica`" -base_color `"#CA9FC9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Family.png`" -logo_offset -500 -logo_resize 1800 -text `"FAMILY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Family`" -base_color `"#BABA6C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Fantasy.png`" -logo_offset -500 -logo_resize 1800 -text `"FANTASY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Fantasy`" -base_color `"#CC2BC6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Film Noir.png`" -logo_offset -500 -logo_resize 1800 -text `"FILM NOIR`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Film Noir`" -base_color `"#5B5B5B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Food.png`" -logo_offset -500 -logo_resize 1800 -text `"FOOD`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Food`" -base_color `"#A145C1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Found Footage Horror.png`" -logo_offset -500 -logo_resize 1800 -text `"FOUND FOOTAGE HORROR`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Found Footage Horror`" -base_color `"#2C3B08`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Game Show.png`" -logo_offset -500 -logo_resize 1800 -text `"GAME SHOW`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Game Show`" -base_color `"#32D184`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Game.png`" -logo_offset -500 -logo_resize 1800 -text `"GAME`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Game`" -base_color `"#70BD98`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Gangster.png`" -logo_offset -500 -logo_resize 1800 -text `"GANGSTER`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Gangster`" -base_color `"#77ACBD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Girls Love.png`" -logo_offset -500 -logo_resize 1800 -text `"GIRLS LOVE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Girls Love`" -base_color `"#AC86AD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Gourmet.png`" -logo_offset -500 -logo_resize 1800 -text `"GOURMET`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Gourmet`" -base_color `"#83AC8F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Harem.png`" -logo_offset -500 -logo_resize 1800 -text `"HAREM`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Harem`" -base_color `"#7DB0C5`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Heist.png`" -logo_offset -500 -logo_resize 1800 -text `"HEIST`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Heist`" -base_color `"#4281C9`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Hentai.png`" -logo_offset -500 -logo_resize 1800 -text `"HENTAI`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hentai`" -base_color `"#B274BF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\History.png`" -logo_offset -500 -logo_resize 1800 -text `"HISTORY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"History`" -base_color `"#B7A95D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Home and Garden.png`" -logo_offset -500 -logo_resize 1800 -text `"HOME AND GARDEN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Home and Garden`" -base_color `"#8CC685`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Horror.png`" -logo_offset -500 -logo_resize 1800 -text `"HORROR`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Horror`" -base_color `"#B94948`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Indie.png`" -logo_offset -500 -logo_resize 1800 -text `"INDIE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Indie`" -base_color `"#BB7493`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Kids.png`" -logo_offset -500 -logo_resize 1800 -text `"KIDS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Kids`" -base_color `"#9F40C6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\LatinX Month.png`" -logo_offset -500 -logo_resize 1800 -text `"LATINX HERITAGE MONTH`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"LatinX`" -base_color `"#FF5F5F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\LGBTQ+.png`" -logo_offset -500 -logo_resize 1800 -text `"LGBTQ+`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"LGBTQ+`" -base_color `"#BD86C4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\LGBTQ+ Month.png`" -logo_offset -500 -logo_resize 1800 -text `"LGBTQ+ PRIDE MONTH`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"LGBTQ+ Month`" -base_color `"#FF3B3C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Martial Arts.png`" -logo_offset -500 -logo_resize 1800 -text `"MARTIAL ARTS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Martial Arts`" -base_color `"#777777`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Mecha.png`" -logo_offset -500 -logo_resize 1800 -text `"MECHA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mecha`" -base_color `"#8B8B8B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Military.png`" -logo_offset -500 -logo_resize 1800 -text `"MILITARY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Military`" -base_color `"#87552F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Mind-Bend.png`" -logo_offset -500 -logo_resize 1800 -text `"MIND-BEND`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mind-Bend`" -base_color `"#619DA2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Mind-Fuck.png`" -logo_offset -500 -logo_resize 1800 -text `"MIND-FUCK`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mind-Fuck`" -base_color `"#619DA2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Mind-Fuck2.png`" -logo_offset -500 -logo_resize 1800 -text `"MIND-F**K`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mind-Fuck2`" -base_color `"#619DA2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Mini-Series.png`" -logo_offset -500 -logo_resize 1800 -text `"MINI-SERIES`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mini-Series`" -base_color `"#66B7BE`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Music.png`" -logo_offset -500 -logo_resize 1800 -text `"MUSIC`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Music`" -base_color `"#3CC79C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Musical.png`" -logo_offset -500 -logo_resize 1800 -text `"MUSICAL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Musical`" -base_color `"#C38CB7`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Mystery.png`" -logo_offset -500 -logo_resize 1800 -text `"MYSTERY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Mystery`" -base_color `"#867CB5`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\News & Politics.png`" -logo_offset -500 -logo_resize 1800 -text `"NEWS & POLITICS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"News & Politics`" -base_color `"#C83131`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\News.png`" -logo_offset -500 -logo_resize 1800 -text `"NEWS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"News`" -base_color `"#C83131`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Outdoor Adventure.png`" -logo_offset -500 -logo_resize 1800 -text `"OUTDOOR ADVENTURE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Outdoor Adventure`" -base_color `"#56C89C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Parody.png`" -logo_offset -500 -logo_resize 1800 -text `"PARODY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Parody`" -base_color `"#83A9A2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Police.png`" -logo_offset -500 -logo_resize 1800 -text `"POLICE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Police`" -base_color `"#262398`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Politics.png`" -logo_offset -500 -logo_resize 1800 -text `"POLITICS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Politics`" -base_color `"#3F5FC0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Psychedelic.png`" -logo_offset -500 -logo_resize 1800 -text `"PSYCHEDELIC`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Psychedelic`" -base_color `"#E973F6`" -gradient 1 -clean 0 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Psychological Horror.png`" -logo_offset -500 -logo_resize 1800 -text `"PSYCHOLOGICAL\nHORROR`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 210 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Psychological Horror`" -base_color `"#AC5969`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Psychological.png`" -logo_offset -500 -logo_resize 1800 -text `"PSYCHOLOGICAL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 210 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Psychological`" -base_color `"#C79367`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Reality.png`" -logo_offset -500 -logo_resize 1800 -text `"REALITY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Reality`" -base_color `"#7CB6AE`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Romance.png`" -logo_offset -500 -logo_resize 1800 -text `"ROMANCE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Romance`" -base_color `"#B6398E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Romantic Comedy.png`" -logo_offset -500 -logo_resize 1800 -text `"ROMANTIC COMEDY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Romantic Comedy`" -base_color `"#B2445D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Romantic Drama.png`" -logo_offset -500 -logo_resize 1800 -text `"ROMANTIC DRAMA`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Romantic Drama`" -base_color `"#AB89C0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Samurai.png`" -logo_offset -500 -logo_resize 1800 -text `"SAMURAI`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Samurai`" -base_color `"#C0C282`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\School.png`" -logo_offset -500 -logo_resize 1800 -text `"SCHOOL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"School`" -base_color `"#4DC369`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Sci-Fi & Fantasy.png`" -logo_offset -500 -logo_resize 1800 -text `"SCI-FI & FANTASY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sci-Fi & Fantasy`" -base_color `"#9254BA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Science Fiction.png`" -logo_offset -500 -logo_resize 1800 -text `"SCIENCE FICTION`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Science Fiction`" -base_color `"#545FBA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Serial Killer.png`" -logo_offset -500 -logo_resize 1800 -text `"SERIAL KILLER`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Serial Killer`" -base_color `"#163F56`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Short.png`" -logo_offset -500 -logo_resize 1800 -text `"SHORT`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Short`" -base_color `"#BCBB7B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Shoujo.png`" -logo_offset -500 -logo_resize 1800 -text `"SHOUJO`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Shoujo`" -base_color `"#89529D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Shounen.png`" -logo_offset -500 -logo_resize 1800 -text `"SHOUNEN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Shounen`" -base_color `"#505E99`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Slasher.png`" -logo_offset -500 -logo_resize 1800 -text `"SLASHER`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Slasher`" -base_color `"#B75157`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Slice of Life.png`" -logo_offset -500 -logo_resize 1800 -text `"SLICE OF LIFE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Slice of Life`" -base_color `"#C696C4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Soap.png`" -logo_offset -500 -logo_resize 1800 -text `"SOAP`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Soap`" -base_color `"#AF7CC0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Space.png`" -logo_offset -500 -logo_resize 1800 -text `"SPACE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Space`" -base_color `"#A793C1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Sport.png`" -logo_offset -500 -logo_resize 1800 -text `"SPORT`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sport`" -base_color `"#587EB1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Spy.png`" -logo_offset -500 -logo_resize 1800 -text `"SPY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Spy`" -base_color `"#B7D99F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Stand-Up Comedy.png`" -logo_offset -500 -logo_resize 1800 -text `"STAND-UP COMEDY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Stand-Up Comedy`" -base_color `"#CF8A49`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Stoner Comedy.png`" -logo_offset -500 -logo_resize 1800 -text `"STONER COMEDY`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Stoner Comedy`" -base_color `"#79D14D`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Super Power.png`" -logo_offset -500 -logo_resize 1800 -text `"SUPER POWER`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Super Power`" -base_color `"#279552`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Superhero.png`" -logo_offset -500 -logo_resize 1800 -text `"SUPERHERO`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Superhero`" -base_color `"#DA8536`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Supernatural.png`" -logo_offset -500 -logo_resize 1800 -text `"SUPERNATURAL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 230 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Supernatural`" -base_color `"#262693`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Survival.png`" -logo_offset -500 -logo_resize 1800 -text `"SURVIVAL`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Survival`" -base_color `"#434447`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Suspense.png`" -logo_offset -500 -logo_resize 1800 -text `"SUSPENSE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Suspense`" -base_color `"#AE5E37`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Sword & Sorcery.png`" -logo_offset -500 -logo_resize 1800 -text `"SWORD & SORCERY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sword & Sorcery`" -base_color `"#B44FBA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\TV Movie.png`" -logo_offset -500 -logo_resize 1800 -text `"TV MOVIE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV Movie`" -base_color `"#85A5B4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Talk Show.png`" -logo_offset -500 -logo_resize 1800 -text `"TALK SHOW`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Talk Show`" -base_color `"#82A2B5`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Thriller.png`" -logo_offset -500 -logo_resize 1800 -text `"THRILLER`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Thriller`" -base_color `"#C3602B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Travel.png`" -logo_offset -500 -logo_resize 1800 -text `"TRAVEL`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Travel`" -base_color `"#B6BA6D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Vampire.png`" -logo_offset -500 -logo_resize 1800 -text `"VAMPIRE`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Vampire`" -base_color `"#7D2627`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\War & Politics.png`" -logo_offset -500 -logo_resize 1800 -text `"WAR & POLITICS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"War & Politics`" -base_color `"#4ABF6E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\War.png`" -logo_offset -500 -logo_resize 1800 -text `"WAR`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"War`" -base_color `"#63AB62`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Western.png`" -logo_offset -500 -logo_resize 1800 -text `"WESTERN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Western`" -base_color `"#AD9B6D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Womens History.png`" -logo_offset -500 -logo_resize 1800 -text `"WOMEN'S HISTORY MONTH`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Womens Month`" -base_color `"#874E83`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\Zombie Horror.png`" -logo_offset -500 -logo_resize 1800 -text `"ZOMBIE HORROR`" -text_offset +850 -font `"Comfortaa-Regular`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Zombie Horror`" -base_color `"#909513`" -gradient 1 -clean 0 -avg_color 0 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination genre
    Copy-Item -Path logos_genre -Destination genre\logos -Recurse
    Move-Item -Path output-orig -Destination output

}

################################################################################
# Function: CreateNetwork
# Description:  Creates Network
################################################################################
Function CreateNetwork {
    Write-Host "Creating Network"
    Set-Location $script_path
    # Find-Path "$script_path\network"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nNETWORKS`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Other Networks`" -base_color `"#FF2000`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER KIDS\nNETWORKS`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Other Kids Networks`" -base_color `"#FF2000`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\A&E.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"A&E`" -base_color `"#676767`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABC (AU).png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABC (AU)`" -base_color `"#CEC281`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABC Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABC Kids`" -base_color `"#6172B9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABC`" -base_color `"#403993`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\AcornTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"AcornTV`" -base_color `"#182034`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Adult Swim.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Adult Swim`" -base_color `"#C0A015`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Amazon Kids+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Amazon Kids+`" -base_color `"#8E2AAF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Amazon.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Amazon`" -base_color `"#9B8832`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\AMC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"AMC`" -base_color `"#4A9472`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Animal Planet.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Animal Planet`" -base_color `"#4389BA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Antena 3.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Antena 3`" -base_color `"#306A94`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Apple TV+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Apple TV+`" -base_color `"#313131`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC America.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC America`" -base_color `"#C83535`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC One.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC One`" -base_color `"#3A38C6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC Two.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC Two`" -base_color `"#9130B1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC`" -base_color `"#A24649`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BET.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BET`" -base_color `"#942C2C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Boomerang.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Boomerang`" -base_color `"#6190B3`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Bravo.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Bravo`" -base_color `"#6D6D6D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BritBox.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BritBox`" -base_color `"#198CA8`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cartoon Network.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cartoon Network`" -base_color `"#6084A0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cartoonito.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cartoonito`" -base_color `"#2D9EB2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CBC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CBC`" -base_color `"#9D3B3F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cbeebies.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cbeebies`" -base_color `"#AFA619`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CBS.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CBS`" -base_color `"#2926C0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Channel 4.png`" -logo_offset +0 -logo_resize 1000 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Channel 4`" -base_color `"#2B297D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Channel 5.png`" -logo_offset +0 -logo_resize 1000 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Channel 5`" -base_color `"#8C28AD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cinemax.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cinemax`" -base_color `"#B4AB22`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Citytv.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Citytv`" -base_color `"#C23B40`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CNN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CNN`" -base_color `"#AE605C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Comedy Central.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Comedy Central`" -base_color `"#BFB516`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cooking Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cooking Channel`" -base_color `"#C29B16`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Criterion Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Criterion Channel`" -base_color `"#810BA7`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Crunchyroll.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Crunchyroll`" -base_color `"#C9761D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CTV`" -base_color `"#1FAA3C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Curiosity Stream.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Curiosity Stream`" -base_color `"#BF983F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Dave.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Dave`" -base_color `"#32336C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Discovery Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Discovery Kids`" -base_color `"#1C7A1E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Discovery.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Discovery`" -base_color `"#1E1CBD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Disney Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney Channel`" -base_color `"#3679C4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Disney Junior.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney Junior`" -base_color `"#C33B40`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Disney XD.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney XD`" -base_color `"#6BAB6D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Disney+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney+`" -base_color `"#0F2FA4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\E!.png`" -logo_offset +0 -logo_resize 500 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"E!`" -base_color `"#BF3137`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Epix.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Epix`" -base_color `"#8E782B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ESPN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ESPN`" -base_color `"#B82B30`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Family Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Family Channel`" -base_color `"#3841B6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Food Network.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Food Network`" -base_color `"#B97A7C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Fox Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Fox Kids`" -base_color `"#B7282D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\FOX.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"FOX`" -base_color `"#474EAB`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Freeform.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Freeform`" -base_color `"#3C9C3E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Freevee.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Freevee`" -base_color `"#B5CF1B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Fuji TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Fuji TV`" -base_color `"#29319C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\FX.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"FX`" -base_color `"#4A51A9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\FXX.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"FXX`" -base_color `"#5070A7`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Global TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Global TV`" -base_color `"#409E42`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Hallmark.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hallmark`" -base_color `"#601CB4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\HBO Max.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"HBO Max`" -base_color `"#7870B9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\HBO.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"HBO`" -base_color `"#458EAD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\HGTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"HGTV`" -base_color `"#3CA38F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\History.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"History`" -base_color `"#A57E2E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Hulu.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hulu`" -base_color `"#1BC073`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\IFC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"IFC`" -base_color `"#296FB4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\IMDb TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"IMDb TV`" -base_color `"#C1CD2F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Investigation Discovery.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Investigation Discovery`" -base_color `"#BD5054`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ITV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ITV`" -base_color `"#B024B5`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Kids WB.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Kids WB`" -base_color `"#B52429`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Lifetime.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Lifetime`" -base_color `"#B61F64`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\MasterClass.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"MasterClass`" -base_color `"#4D4D4D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\MTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"MTV`" -base_color `"#76A3AF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\National Geographic.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"National Geographic`" -base_color `"#C6B31B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\NBC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NBC`" -base_color `"#703AAC`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Netflix.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Netflix`" -base_color `"#B42A33`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nick Jr.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nick Jr`" -base_color `"#4290A4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nick.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nick`" -base_color `"#B68021`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nickelodeon.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nickelodeon`" -base_color `"#C56A16`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nicktoons.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nicktoons`" -base_color `"#C56B17`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Oxygen.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Oxygen`" -base_color `"#CBB23E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Paramount+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Paramount+`" -base_color `"#2A67CC`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\PBS Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"PBS Kids`" -base_color `"#47A149`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\PBS.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"PBS`" -base_color `"#3A4894`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Peacock.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Peacock`" -base_color `"#DA4428`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Prime Video.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Prime Video`" -base_color `"#11607E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Showcase.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Showcase`" -base_color `"#4D4D4D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Showtime.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Showtime`" -base_color `"#C2201F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Shudder.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Shudder`" -base_color `"#0D0C89`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Sky.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sky`" -base_color `"#BC3272`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Smithsonian.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Smithsonian`" -base_color `"#303F8F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Spike TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Spike TV`" -base_color `"#ADAE74`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Stan.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Stan`" -base_color `"#227CC0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Starz.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Starz`" -base_color `"#464646`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Sundance TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sundance TV`" -base_color `"#424242`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Syfy.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Syfy`" -base_color `"#BEB42D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TBS.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TBS`" -base_color `"#A139BF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\The CW.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The CW`" -base_color `"#397F96`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TLC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TLC`" -base_color `"#BA6C70`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TNT.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TNT`" -base_color `"#C1B83A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TOKYO MX.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TOKYO MX`" -base_color `"#8662EA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\truTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"truTV`" -base_color `"#C79F26`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Turner Classic Movies.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Turner Classic Movies`" -base_color `"#616161`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TV Land.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV Land`" -base_color `"#78AFB4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\UKTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"UKTV`" -base_color `"#2EADB1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Universal Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Universal Kids`" -base_color `"#2985A1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\UPN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"UPN`" -base_color `"#C6864E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\USA.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"USA`" -base_color `"#C0565B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\VH1.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"VH1`" -base_color `"#8E3BB1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Vice.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Vice`" -base_color `"#D3D3D3`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Warner Bros..png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Warner Bros.`" -base_color `"#39538F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\YouTube.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"YouTube`" -base_color `"#C51414`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ZDF.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ZDF`" -base_color `"#C58654`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination network
    Copy-Item -Path logos_network -Destination network\logos -Recurse
    Move-Item -Path output-orig -Destination output
    
}

################################################################################
# Function: CreatePlaylist
# Description:  Creates Playlist
################################################################################
Function CreatePlaylist {
    Write-Host "Creating Playlist"
    Set-Location $script_path
    # Find-Path "$script_path\playlist"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\Arrowverse.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Arrowverse (Timeline Order)`" -base_color `"#2B8F40`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\DragonBall.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Dragon Ball (Timeline Order)`" -base_color `"#E39D30`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\Marvel Cinematic Universe.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Marvel Cinematic Universe (Timeline Order)`" -base_color `"#AD2B2B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\Star Trek.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Trek (Timeline Order)`" -base_color `"#0193DD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\Pokémon.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pokémon (Timeline Order)`" -base_color `"#FECA06`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\dca.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"DC Animated Universe (Timeline Order)`" -base_color `"#2832C4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\X-men.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"X-Men (Timeline Order)`" -base_color `"#636363`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\Star Wars The Clone Wars.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Wars The Clone Wars (Timeline Order)`" -base_color `"#ED1C24`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\Star Wars.png`" -logo_offset -200 -logo_resize 1600 -text `"TIMELINE ORDER`" -text_offset +450 -font `"Bebas-Regular`" -font_size 140 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Star Wars (Timeline Order)`" -base_color `"#F8C60A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 0"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination playlist
    Copy-Item -Path logos_playlist -Destination playlist\logos -Recurse
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateResolution
# Description:  Creates Resolution
################################################################################
Function CreateResolution {
    Write-Host "Creating Resolution"
    Set-Location $script_path
    # Find-Path "$script_path\resolution"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nRESOLUTIONS`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"other`" -base_color `"#FF2000`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\4K.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"4k`" -base_color `"#8A46CF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\8K.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"8k`" -base_color `"#95BCDC`"-gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\144p.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"144`" -base_color `"#F0C5E5`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\240p.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"240`" -base_color `"#DFA172`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\360p.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"360`" -base_color `"#6D3FDC`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\480p.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"480`" -base_color `"#3996D3`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\576p.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"576`" -base_color `"#DED1B2`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\720p.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"720`" -base_color `"#30DC76`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\1080p.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"1080`" -base_color `"#D60C0C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination resolution
    
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nRESOLUTIONS`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"other`" -base_color `"#FF2000`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\ultrahd.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"4k`" -base_color `"#8A46CF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\sd.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"480`" -base_color `"#3996D3`"-gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\hdready.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"720`" -base_color `"#30DC76`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\fullhd.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"1080`" -base_color `"#D60C0C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination resolution\standards
    Copy-Item -Path logos_resolution -Destination resolution\logos -Recurse
    Move-Item -Path output-orig -Destination output
    
}

################################################################################
# Function: CreateSeasonal
# Description:  Creates Seasonal
################################################################################
Function CreateSeasonal {
    Write-Host "Creating Seasonal"
    Set-Location $script_path
    # Find-Path "$script_path\seasonal"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\420.png`" -logo_offset -500 -logo_resize 1800 -text `"4/20`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"420`" -base_color `"#43C32F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\christmas.png`" -logo_offset -500 -logo_resize 1800 -text `"CHRISTMAS`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"christmas`" -base_color `"#D52414`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\easter.png`" -logo_offset -500 -logo_resize 1800 -text `"EASTER`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"easter`" -base_color `"#46D69D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\father.png`" -logo_offset -500 -logo_resize 1800 -text `"FATHER'S DAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"father`" -base_color `"#7CDA83`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\halloween.png`" -logo_offset -500 -logo_resize 1800 -text `"HALLOWEEN`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"halloween`" -base_color `"#DA8B25`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\independence.png`" -logo_offset -500 -logo_resize 1800 -text `"INDEPENDENCE\nDAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 220 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"independence`" -base_color `"#2931CB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\labor.png`" -logo_offset -500 -logo_resize 1800 -text `"LABOR DAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"labor`" -base_color `"#DA5C5E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\memorial.png`" -logo_offset -500 -logo_resize 1800 -text `"MEMORIAL DAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"memorial`" -base_color `"#917C5C`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\mother.png`" -logo_offset -500 -logo_resize 1800 -text `"MOTHER'S DAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mother`" -base_color `"#DB81D6`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\patrick.png`" -logo_offset -500 -logo_resize 1800 -text `"ST. PATRICK'S DAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"patrick`" -base_color `"#26A53E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\thanksgiving.png`" -logo_offset -500 -logo_resize 1800 -text `"THANKSGIVING`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 240 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"thanksgiving`" -base_color `"#A1841E`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\valentine.png`" -logo_offset -500 -logo_resize 1800 -text `"VALENTINE'S DAY`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"valentine`" -base_color `"#D12AAE`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\years.png`" -logo_offset -500 -logo_resize 1800 -text `"NEW YEAR`" -text_offset +850 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"years`" -base_color `"#444444`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination seasonal
    Copy-Item -Path logos_seasonal -Destination seasonal\logos -Recurse
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateSeparators
# Description:  Creates Separators
################################################################################
Function CreateSeparators {
    Write-Host "Creating Separators"
    WriteToLogFile "ImageMagick Commands for     : Separators"
    WriteToLogFile "ImageMagick Commands for     : Separators-blue"
    Set-Location $script_path
    Find-Path "$script_path\separators"
    Find-Path "$script_path\separators\blue"
    Find-Path "$script_path\separators\gray"
    Find-Path "$script_path\separators\green"
    Find-Path "$script_path\separators\orig"
    Find-Path "$script_path\separators\purple"
    Find-Path "$script_path\separators\red"
    Find-Path "$script_path\separators\stb"

    .\create_poster.ps1 -logo "$script_path\logos_chart\Plex.png" -logo_offset -500 -logo_resize 1500 -text "COLLECTIONLESS" -text_offset +850 -font "ComfortAa-Medium" -font_size 195 -font_color "#FFFFFF" -border 0 -border_width 15 -border_color "#FFFFFF" -avg_color_image "" -out_name "collectionless" -base_color "#DC9924" -gradient 1 -avg_color 0 -clean 1 -white_wash 1
    Move-Item -Path $script_path\output\collectionless.jpg -Destination $script_path\collectionless.jpg

    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 195 (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "collectionless_name" -CaseSensitivity Upper) $script_path\separators\blue\collectionless-it.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 195 "COLLECTIONLESS\nCOLLECTIONS" $script_path\separators\blue\collectionless.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "ACTOR\nCOLLECTIONS" $script_path\separators\blue\actor.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "AUDIO\nLANGUAGE\nCOLLECTIONS" $script_path\separators\blue\audio_language.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "AWARD\nCOLLECTIONS" $script_path\separators\blue\award.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "CHART\nCOLLECTIONS" $script_path\separators\blue\chart.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "CONTENT\nRATINGS\nCOLLECTIONS" $script_path\separators\blue\content_rating.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "COUNTRY\nCOLLECTIONS" $script_path\separators\blue\country.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "DECADE\nCOLLECTIONS" $script_path\separators\blue\decade.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "DIRECTOR\nCOLLECTIONS" $script_path\separators\blue\director.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "FRANCHISE\nCOLLECTIONS" $script_path\separators\blue\franchise.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "GENRE\nCOLLECTIONS" $script_path\separators\blue\genre.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "KIDS NETWORK\nCOLLECTIONS" $script_path\separators\blue\network_kids.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "MOVIE CHART\nCOLLECTIONS" $script_path\separators\blue\movie_chart.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "NETWORK\nCOLLECTIONS" $script_path\separators\blue\network.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "PERSONAL\nCOLLECTIONS" $script_path\separators\blue\personal.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "PRODUCER\nCOLLECTIONS" $script_path\separators\blue\producer.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "RESOLUTION\nCOLLECTIONS" $script_path\separators\blue\resolution.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "SEASONAL\nCOLLECTIONS" $script_path\separators\blue\seasonal.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "STREAMING\nCOLLECTIONS" $script_path\separators\blue\streaming.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "STUDIO\nANIMATION\nCOLLECTIONS" $script_path\separators\blue\studio_animation.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "STUDIO\nCOLLECTIONS" $script_path\separators\blue\studio.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "SUBTITLE\nCOLLECTIONS" $script_path\separators\blue\subtitle_language.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "TV CHART\nCOLLECTIONS" $script_path\separators\blue\tv_chart.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "UK NETWORK\nCOLLECTIONS" $script_path\separators\blue\network_uk.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "UK STREAMING\nCOLLECTIONS" $script_path\separators\blue\streaming_uk.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "UNIVERSE\nCOLLECTIONS" $script_path\separators\blue\universe.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "US NETWORK\nCOLLECTIONS" $script_path\separators\blue\network_us.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "US STREAMING\nCOLLECTIONS" $script_path\separators\blue\streaming_us.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "WRITER\nCOLLECTIONS" $script_path\separators\blue\writer.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "YEAR\nCOLLECTIONS" $script_path\separators\blue\year.jpg
    Convert-Separators $script_path\@base\blue.png Comfortaa-medium 203 "BASED ON...\nCOLLECTIONS" $script_path\separators\blue\based.jpg
    WriteToLogFile "ImageMagick Commands for     : Separators-gray"
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 195 "COLLECTIONLESS\nCOLLECTIONS" $script_path\separators\gray\collectionless.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "ACTOR\nCOLLECTIONS" $script_path\separators\gray\actor.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "AUDIO\nLANGUAGE\nCOLLECTIONS" $script_path\separators\gray\audio_language.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "AWARD\nCOLLECTIONS" $script_path\separators\gray\award.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "CHART\nCOLLECTIONS" $script_path\separators\gray\chart.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "CONTENT\nRATINGS\nCOLLECTIONS" $script_path\separators\gray\content_rating.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "COUNTRY\nCOLLECTIONS" $script_path\separators\gray\country.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "DECADE\nCOLLECTIONS" $script_path\separators\gray\decade.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "DIRECTOR\nCOLLECTIONS" $script_path\separators\gray\director.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "FRANCHISE\nCOLLECTIONS" $script_path\separators\gray\franchise.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "GENRE\nCOLLECTIONS" $script_path\separators\gray\genre.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "KIDS NETWORK\nCOLLECTIONS" $script_path\separators\gray\network_kids.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "MOVIE CHART\nCOLLECTIONS" $script_path\separators\gray\movie_chart.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "NETWORK\nCOLLECTIONS" $script_path\separators\gray\network.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "PERSONAL\nCOLLECTIONS" $script_path\separators\gray\personal.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "PRODUCER\nCOLLECTIONS" $script_path\separators\gray\producer.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "RESOLUTION\nCOLLECTIONS" $script_path\separators\gray\resolution.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "SEASONAL\nCOLLECTIONS" $script_path\separators\gray\seasonal.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "STREAMING\nCOLLECTIONS" $script_path\separators\gray\streaming.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "STUDIO\nANIMATION\nCOLLECTIONS" $script_path\separators\gray\studio_animation.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "STUDIO\nCOLLECTIONS" $script_path\separators\gray\studio.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "SUBTITLE\nCOLLECTIONS" $script_path\separators\gray\subtitle_language.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "TV CHART\nCOLLECTIONS" $script_path\separators\gray\tv_chart.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "UK NETWORK\nCOLLECTIONS" $script_path\separators\gray\network_uk.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "UK STREAMING\nCOLLECTIONS" $script_path\separators\gray\streaming_uk.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "UNIVERSE\nCOLLECTIONS" $script_path\separators\gray\universe.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "US NETWORK\nCOLLECTIONS" $script_path\separators\gray\network_us.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "US STREAMING\nCOLLECTIONS" $script_path\separators\gray\streaming_us.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "WRITER\nCOLLECTIONS" $script_path\separators\gray\writer.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "YEAR\nCOLLECTIONS" $script_path\separators\gray\year.jpg
    Convert-Separators $script_path\@base\gray.png Comfortaa-medium 203 "BASED ON...\nCOLLECTIONS" $script_path\separators\gray\based.jpg
    WriteToLogFile "ImageMagick Commands for     : Separators-green"
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 195 "COLLECTIONLESS\nCOLLECTIONS" $script_path\separators\green\collectionless.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "ACTOR\nCOLLECTIONS" $script_path\separators\green\actor.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "AUDIO\nLANGUAGE\nCOLLECTIONS" $script_path\separators\green\audio_language.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "AWARD\nCOLLECTIONS" $script_path\separators\green\award.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "CHART\nCOLLECTIONS" $script_path\separators\green\chart.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "CONTENT\nRATINGS\nCOLLECTIONS" $script_path\separators\green\content_rating.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "COUNTRY\nCOLLECTIONS" $script_path\separators\green\country.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "DECADE\nCOLLECTIONS" $script_path\separators\green\decade.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "DIRECTOR\nCOLLECTIONS" $script_path\separators\green\director.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "FRANCHISE\nCOLLECTIONS" $script_path\separators\green\franchise.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "GENRE\nCOLLECTIONS" $script_path\separators\green\genre.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "KIDS NETWORK\nCOLLECTIONS" $script_path\separators\green\network_kids.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "MOVIE CHART\nCOLLECTIONS" $script_path\separators\green\movie_chart.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "NETWORK\nCOLLECTIONS" $script_path\separators\green\network.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "PERSONAL\nCOLLECTIONS" $script_path\separators\green\personal.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "PRODUCER\nCOLLECTIONS" $script_path\separators\green\producer.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "RESOLUTION\nCOLLECTIONS" $script_path\separators\green\resolution.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "SEASONAL\nCOLLECTIONS" $script_path\separators\green\seasonal.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "STREAMING\nCOLLECTIONS" $script_path\separators\green\streaming.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "STUDIO\nANIMATION\nCOLLECTIONS" $script_path\separators\green\studio_animation.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "STUDIO\nCOLLECTIONS" $script_path\separators\green\studio.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "SUBTITLE\nCOLLECTIONS" $script_path\separators\green\subtitle_language.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "TV CHART\nCOLLECTIONS" $script_path\separators\green\tv_chart.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "UK NETWORK\nCOLLECTIONS" $script_path\separators\green\network_uk.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "UK STREAMING\nCOLLECTIONS" $script_path\separators\green\streaming_uk.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "UNIVERSE\nCOLLECTIONS" $script_path\separators\green\universe.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "US NETWORK\nCOLLECTIONS" $script_path\separators\green\network_us.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "US STREAMING\nCOLLECTIONS" $script_path\separators\green\streaming_us.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "WRITER\nCOLLECTIONS" $script_path\separators\green\writer.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "YEAR\nCOLLECTIONS" $script_path\separators\green\year.jpg
    Convert-Separators $script_path\@base\green.png Comfortaa-medium 203 "BASED ON...\nCOLLECTIONS" $script_path\separators\green\based.jpg
    WriteToLogFile "ImageMagick Commands for     : Separators-orig"
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 195 "COLLECTIONLESS\nCOLLECTIONS" $script_path\separators\orig\collectionless.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "ACTOR\nCOLLECTIONS" $script_path\separators\orig\actor.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "AUDIO\nLANGUAGE\nCOLLECTIONS" $script_path\separators\orig\audio_language.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "AWARD\nCOLLECTIONS" $script_path\separators\orig\award.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "CHART\nCOLLECTIONS" $script_path\separators\orig\chart.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "CONTENT\nRATINGS\nCOLLECTIONS" $script_path\separators\orig\content_rating.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "COUNTRY\nCOLLECTIONS" $script_path\separators\orig\country.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "DECADE\nCOLLECTIONS" $script_path\separators\orig\decade.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "DIRECTOR\nCOLLECTIONS" $script_path\separators\orig\director.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "FRANCHISE\nCOLLECTIONS" $script_path\separators\orig\franchise.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "GENRE\nCOLLECTIONS" $script_path\separators\orig\genre.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "KIDS NETWORK\nCOLLECTIONS" $script_path\separators\orig\network_kids.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "MOVIE CHART\nCOLLECTIONS" $script_path\separators\orig\movie_chart.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "NETWORK\nCOLLECTIONS" $script_path\separators\orig\network.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "PERSONAL\nCOLLECTIONS" $script_path\separators\orig\personal.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "PRODUCER\nCOLLECTIONS" $script_path\separators\orig\producer.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "RESOLUTION\nCOLLECTIONS" $script_path\separators\orig\resolution.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "SEASONAL\nCOLLECTIONS" $script_path\separators\orig\seasonal.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "STREAMING\nCOLLECTIONS" $script_path\separators\orig\streaming.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "STUDIO\nANIMATION\nCOLLECTIONS" $script_path\separators\orig\studio_animation.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "STUDIO\nCOLLECTIONS" $script_path\separators\orig\studio.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "SUBTITLE\nCOLLECTIONS" $script_path\separators\orig\subtitle_language.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "TV CHART\nCOLLECTIONS" $script_path\separators\orig\tv_chart.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "UK NETWORK\nCOLLECTIONS" $script_path\separators\orig\network_uk.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "UK STREAMING\nCOLLECTIONS" $script_path\separators\orig\streaming_uk.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "UNIVERSE\nCOLLECTIONS" $script_path\separators\orig\universe.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "US NETWORK\nCOLLECTIONS" $script_path\separators\orig\network_us.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "US STREAMING\nCOLLECTIONS" $script_path\separators\orig\streaming_us.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "WRITER\nCOLLECTIONS" $script_path\separators\orig\writer.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "YEAR\nCOLLECTIONS" $script_path\separators\orig\year.jpg
    Convert-Separators $script_path\@base\orig.png Comfortaa-medium 203 "BASED ON...\nCOLLECTIONS" $script_path\separators\orig\based.jpg
    WriteToLogFile "ImageMagick Commands for     : Separators-purple"
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 195 "COLLECTIONLESS\nCOLLECTIONS" $script_path\separators\purple\collectionless.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "ACTOR\nCOLLECTIONS" $script_path\separators\purple\actor.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "AUDIO\nLANGUAGE\nCOLLECTIONS" $script_path\separators\purple\audio_language.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "AWARD\nCOLLECTIONS" $script_path\separators\purple\award.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "CHART\nCOLLECTIONS" $script_path\separators\purple\chart.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "CONTENT\nRATINGS\nCOLLECTIONS" $script_path\separators\purple\content_rating.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "COUNTRY\nCOLLECTIONS" $script_path\separators\purple\country.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "DECADE\nCOLLECTIONS" $script_path\separators\purple\decade.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "DIRECTOR\nCOLLECTIONS" $script_path\separators\purple\director.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "FRANCHISE\nCOLLECTIONS" $script_path\separators\purple\franchise.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "GENRE\nCOLLECTIONS" $script_path\separators\purple\genre.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "KIDS NETWORK\nCOLLECTIONS" $script_path\separators\purple\network_kids.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "MOVIE CHART\nCOLLECTIONS" $script_path\separators\purple\movie_chart.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "NETWORK\nCOLLECTIONS" $script_path\separators\purple\network.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "PERSONAL\nCOLLECTIONS" $script_path\separators\purple\personal.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "PRODUCER\nCOLLECTIONS" $script_path\separators\purple\producer.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "RESOLUTION\nCOLLECTIONS" $script_path\separators\purple\resolution.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "SEASONAL\nCOLLECTIONS" $script_path\separators\purple\seasonal.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "STREAMING\nCOLLECTIONS" $script_path\separators\purple\streaming.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "STUDIO\nANIMATION\nCOLLECTIONS" $script_path\separators\purple\studio_animation.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "STUDIO\nCOLLECTIONS" $script_path\separators\purple\studio.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "SUBTITLE\nCOLLECTIONS" $script_path\separators\purple\subtitle_language.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "TV CHART\nCOLLECTIONS" $script_path\separators\purple\tv_chart.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "UK NETWORK\nCOLLECTIONS" $script_path\separators\purple\network_uk.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "UK STREAMING\nCOLLECTIONS" $script_path\separators\purple\streaming_uk.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "UNIVERSE\nCOLLECTIONS" $script_path\separators\purple\universe.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "US NETWORK\nCOLLECTIONS" $script_path\separators\purple\network_us.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "US STREAMING\nCOLLECTIONS" $script_path\separators\purple\streaming_us.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "WRITER\nCOLLECTIONS" $script_path\separators\purple\writer.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "YEAR\nCOLLECTIONS" $script_path\separators\purple\year.jpg
    Convert-Separators $script_path\@base\purple.png Comfortaa-medium 203 "BASED ON...\nCOLLECTIONS" $script_path\separators\purple\based.jpg
    WriteToLogFile "ImageMagick Commands for     : Separators-red"
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 195 "COLLECTIONLESS\nCOLLECTIONS" $script_path\separators\red\collectionless.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "ACTOR\nCOLLECTIONS" $script_path\separators\red\actor.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "AUDIO\nLANGUAGE\nCOLLECTIONS" $script_path\separators\red\audio_language.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "AWARD\nCOLLECTIONS" $script_path\separators\red\award.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "CHART\nCOLLECTIONS" $script_path\separators\red\chart.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "CONTENT\nRATINGS\nCOLLECTIONS" $script_path\separators\red\content_rating.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "COUNTRY\nCOLLECTIONS" $script_path\separators\red\country.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "DECADE\nCOLLECTIONS" $script_path\separators\red\decade.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "DIRECTOR\nCOLLECTIONS" $script_path\separators\red\director.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "FRANCHISE\nCOLLECTIONS" $script_path\separators\red\franchise.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "GENRE\nCOLLECTIONS" $script_path\separators\red\genre.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "KIDS NETWORK\nCOLLECTIONS" $script_path\separators\red\network_kids.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "MOVIE CHART\nCOLLECTIONS" $script_path\separators\red\movie_chart.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "NETWORK\nCOLLECTIONS" $script_path\separators\red\network.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "PERSONAL\nCOLLECTIONS" $script_path\separators\red\personal.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "PRODUCER\nCOLLECTIONS" $script_path\separators\red\producer.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "RESOLUTION\nCOLLECTIONS" $script_path\separators\red\resolution.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "SEASONAL\nCOLLECTIONS" $script_path\separators\red\seasonal.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "STREAMING\nCOLLECTIONS" $script_path\separators\red\streaming.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "STUDIO\nANIMATION\nCOLLECTIONS" $script_path\separators\red\studio_animation.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "STUDIO\nCOLLECTIONS" $script_path\separators\red\studio.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "SUBTITLE\nCOLLECTIONS" $script_path\separators\red\subtitle_language.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "TV CHART\nCOLLECTIONS" $script_path\separators\red\tv_chart.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "UK NETWORK\nCOLLECTIONS" $script_path\separators\red\network_uk.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "UK STREAMING\nCOLLECTIONS" $script_path\separators\red\streaming_uk.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "UNIVERSE\nCOLLECTIONS" $script_path\separators\red\universe.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "US NETWORK\nCOLLECTIONS" $script_path\separators\red\network_us.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "US STREAMING\nCOLLECTIONS" $script_path\separators\red\streaming_us.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "WRITER\nCOLLECTIONS" $script_path\separators\red\writer.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "YEAR\nCOLLECTIONS" $script_path\separators\red\year.jpg
    Convert-Separators $script_path\@base\red.png Comfortaa-medium 203 "BASED ON...\nCOLLECTIONS" $script_path\separators\red\based.jpg
    WriteToLogFile "ImageMagick Commands for     : Separators-stb"
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 195 "COLLECTIONLESS\nCOLLECTIONS" $script_path\separators\stb\collectionless.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "ACTOR\nCOLLECTIONS" $script_path\separators\stb\actor.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "AUDIO\nLANGUAGE\nCOLLECTIONS" $script_path\separators\stb\audio_language.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "AWARD\nCOLLECTIONS" $script_path\separators\stb\award.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "CHART\nCOLLECTIONS" $script_path\separators\stb\chart.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "CONTENT\nRATINGS\nCOLLECTIONS" $script_path\separators\stb\content_rating.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "COUNTRY\nCOLLECTIONS" $script_path\separators\stb\country.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "DECADE\nCOLLECTIONS" $script_path\separators\stb\decade.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "DIRECTOR\nCOLLECTIONS" $script_path\separators\stb\director.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "FRANCHISE\nCOLLECTIONS" $script_path\separators\stb\franchise.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "GENRE\nCOLLECTIONS" $script_path\separators\stb\genre.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "KIDS NETWORK\nCOLLECTIONS" $script_path\separators\stb\network_kids.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "MOVIE CHART\nCOLLECTIONS" $script_path\separators\stb\movie_chart.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "NETWORK\nCOLLECTIONS" $script_path\separators\stb\network.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "PERSONAL\nCOLLECTIONS" $script_path\separators\stb\personal.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "PRODUCER\nCOLLECTIONS" $script_path\separators\stb\producer.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "RESOLUTION\nCOLLECTIONS" $script_path\separators\stb\resolution.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "SEASONAL\nCOLLECTIONS" $script_path\separators\stb\seasonal.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "STREAMING\nCOLLECTIONS" $script_path\separators\stb\streaming.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "STUDIO\nANIMATION\nCOLLECTIONS" $script_path\separators\stb\studio_animation.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "STUDIO\nCOLLECTIONS" $script_path\separators\stb\studio.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "SUBTITLE\nCOLLECTIONS" $script_path\separators\stb\subtitle_language.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "TV CHART\nCOLLECTIONS" $script_path\separators\stb\tv_chart.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "UK NETWORK\nCOLLECTIONS" $script_path\separators\stb\network_uk.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "UK STREAMING\nCOLLECTIONS" $script_path\separators\stb\streaming_uk.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "UNIVERSE\nCOLLECTIONS" $script_path\separators\stb\universe.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "US NETWORK\nCOLLECTIONS" $script_path\separators\stb\network_us.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "US STREAMING\nCOLLECTIONS" $script_path\separators\stb\streaming_us.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "WRITER\nCOLLECTIONS" $script_path\separators\stb\writer.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "YEAR\nCOLLECTIONS" $script_path\separators\stb\year.jpg
    Convert-Separators $script_path\@base\stb.png Comfortaa-medium 203 "BASED ON...\nCOLLECTIONS" $script_path\separators\stb\based.jpg
    Set-Location $script_path

}

################################################################################
# Function: CreateStreaming
# Description:  Creates Streaming
################################################################################
Function CreateStreaming {
    Write-Host "Creating Streaming"
    Set-Location $script_path
    # Find-Path "$script_path\streaming"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\All 4.png`" -logo_offset +0 -logo_resize 1000 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"All 4`" -base_color `"#14AE9A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Apple TV+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Apple TV+`" -base_color `"#494949`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\BET+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BET+`" -base_color `"#B3359C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\BritBox.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BritBox`" -base_color `"#198CA8`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\crave.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"crave`" -base_color `"#29C2F1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Crunchyroll.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Crunchyroll`" -base_color `"#C9761D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\discovery+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"discovery+`" -base_color `"#2175D9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Disney+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney+`" -base_color `"#0F2FA4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Funimation.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Funimation`" -base_color `"#513790`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\hayu.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"hayu`" -base_color `"#C9516D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\HBO Max.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"HBO Max`" -base_color `"#7870B9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Hulu.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hulu`" -base_color `"#1BC073`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\My 5.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"My 5`" -base_color `"#426282`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Netflix.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Netflix`" -base_color `"#B42A33`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\NOW.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NOW`" -base_color `"#215659`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Paramount+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Paramount+`" -base_color `"#2A67CC`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Peacock.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Peacock`" -base_color `"#DA4428`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Prime Video.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Prime Video`" -base_color `"#11607E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Quibi.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Quibi`" -base_color `"#AB5E73`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Showtime.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Showtime`" -base_color `"#BC1818`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\Stan.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Stan`" -base_color `"#227CC0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination streaming
    Copy-Item -Path logos_streaming -Destination streaming\logos -Recurse
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateStudio
# Description:  Creates Studio
################################################################################
Function CreateStudio {
    Write-Host "Creating Studio"
    Set-Location $script_path
    # Find-Path "$script_path\studio"
    Move-Item -Path output -Destination output-orig
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER ANIMATION STUDIOS`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"other_animation`" -base_color `"#FF2000`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize 1800 -text `"OTHER\nSTUDIOS`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"other`" -base_color `"#FF2000`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\20th Century Animation.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"20th Century Animation`" -base_color `"#9F3137`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\20th Century Studios.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"20th Century Studios`" -base_color `"#3387C6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\8bit.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"8bit`" -base_color `"#C81246`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\A-1 Pictures.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"A-1 Pictures`" -base_color `"#5776A8`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Amazon Studios.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Amazon Studios`" -base_color `"#D28109`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Amblin Entertainment.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Amblin Entertainment`" -base_color `"#394E76`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Blue Sky Studios.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Blue Sky Studios`" -base_color `"#1E4678`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Blumhouse Productions.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Blumhouse Productions`" -base_color `"#353535`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Bones.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Bones`" -base_color `"#C4AE14`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Brain's Base.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Brain's Base`" -base_color `"#8A530E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Chernin Entertainment.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Chernin Entertainment`" -base_color `"#3D4A64`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Clover Works.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Clover Works`" -base_color `"#B9556C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Columbia Pictures.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Columbia Pictures`" -base_color `"#329763`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Constantin Film.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Constantin Film`" -base_color `"#343B44`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\David Production.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"David Production`" -base_color `"#AB104E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Doga Kobo.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Doga Kobo`" -base_color `"#BD0F0F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\DreamWorks Animation.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"DreamWorks Animation`" -base_color `"#3D6FBA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\DreamWorks Studios.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"DreamWorks Studios`" -base_color `"#2F508F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Gainax.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Gainax`" -base_color `"#A73034`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\GrindStone Entertainment Group.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"GrindStone Entertainment Group`" -base_color `"#B66736`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Happy Madison Productions.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Happy Madison Productions`" -base_color `"#278761`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Illumination Entertainment.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Illumination Entertainment`" -base_color `"#C7C849`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Ingenious Media.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ingenious Media`" -base_color `"#729A3B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\J.C.Staff.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"J.C.Staff`" -base_color `"#A52634`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Kinema Citrus.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Kinema Citrus`" -base_color `"#87A92B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Kyoto Animation.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Kyoto Animation`" -base_color `"#AE4520`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Legendary Pictures.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Legendary Pictures`" -base_color `"#303841`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Lionsgate.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Lionsgate`" -base_color `"#7D22A3`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Lucasfilm Ltd.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Lucasfilm Ltd`" -base_color `"#22669B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Madhouse.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Madhouse`" -base_color `"#C58E2C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Malevolent Films.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Malevolent Films`" -base_color `"#5A6B7B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\MAPPA.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"MAPPA`" -base_color `"#376430`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Marvel Animation.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Marvel Animation`" -base_color `"#BE2B2F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Marvel Studios.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Marvel Studios`" -base_color `"#A61B1F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Metro-Goldwyn-Mayer.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Metro-Goldwyn-Mayer`" -base_color `"#A48221`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Millennium Films.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Millennium Films`" -base_color `"#911213`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Miramax.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Miramax`" -base_color `"#344B75`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\New Line Cinema.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"New Line Cinema`" -base_color `"#67857E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Original Film.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Original Film`" -base_color `"#364B61`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Orion Pictures.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Orion Pictures`" -base_color `"#6E6E6E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\P.A. Works.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"P.A. Works`" -base_color `"#C15D16`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Paramount Animation.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Paramount Animation`" -base_color `"#3254B1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Paramount Pictures.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Paramount Pictures`" -base_color `"#5D94B4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Pixar Animation Studios.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pixar Animation Studios`" -base_color `"#1668B0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Pixar.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Pixar`" -base_color `"#2A58C6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\PlanB Entertainment.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"PlanB Entertainment`" -base_color `"#9084B5`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Production I.G.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Production I.G`" -base_color `"#8843C2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Shaft.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Shaft`" -base_color `"#2BA8A4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Silver Link.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Silver Link`" -base_color `"#747474`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Sony Pictures Animation.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sony Pictures Animation`" -base_color `"#498BA9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Sony Pictures.png`" -logo_offset +0 -logo_resize 1200 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sony Pictures`" -base_color `"#943EBD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Studio DEEN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Studio DEEN`" -base_color `"#3A6EA8`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Studio Ghibli.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Studio Ghibli`" -base_color `"#AB2F46`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Studio Pierrot.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Studio Pierrot`" -base_color `"#459A73`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Summit Entertainment.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Summit Entertainment`" -base_color `"#3898B6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Sunrise.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sunrise`" -base_color `"#C11D1D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Toei Animation.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Toei Animation`" -base_color `"#BB5048`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Trigger.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Trigger`" -base_color `"#5C5C5C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Ufotable.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Ufotable`" -base_color `"#BF1717`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Universal Animation Studios.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Universal Animation Studios`" -base_color `"#B6322D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Universal Pictures.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Universal Pictures`" -base_color `"#207AAB`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Village Roadshow Pictures.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Village Roadshow Pictures`" -base_color `"#A76B29`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Walt Disney Animation Studios.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Walt Disney Animation Studios`" -base_color `"#1290C0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Walt Disney Pictures.png`" -logo_offset +0 -logo_resize 1300 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Walt Disney Pictures`" -base_color `"#2944AA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Warner Animation Group.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Warner Animation Group`" -base_color `"#92171E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Warner Bros. Pictures.png`" -logo_offset +0 -logo_resize 1200 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Warner Bros. Pictures`" -base_color `"#39538F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\White Fox.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"White Fox`" -base_color `"#A86633`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\Wit Studio.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Wit Studio`" -base_color `"#1F3BB6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination studio
    Copy-Item -Path logos_studio -Destination studio\logos -Recurse
    Move-Item -Path output-orig -Destination output
}

# function MyFunction($name, $age, $gender, $occupation) {
#     # Do something with the parameters
#     Write-Host "Name: $name, Age: $age, Gender: $gender, Occupation: $occupation"
# }

# $myArray = @(
#     'Name| Age| Gender| Occupation',
#     'John, Doe| 30| Male| Engineer',
#     'Jane| Smith, Jr.| 25| Female| Teacher',
#     'Bob| Johnson| 40| Male| Manager',
#     'Sara, Lee| 35| Female| Doctor',
#     'Mike| O''Brien| 28| Male| Programmer',
#     'Lisa| Wong| 42| Female| Lawyer',
#     'Dan| Thompson| 45| Male| Accountant',
#     'Jen| Kim| 33| Female| Designer',
#     'Tom| Davis| 29| Male| Salesperson'
# ) | ConvertFrom-Csv -Delimiter '|'

# foreach ($item in $myArray) {
#     MyFunction -name $item.Name -age $item.Age -gender $item.Gender -occupation $item.Occupation
# }


################################################################################
# Function: CreateSubtitleLanguage
# Description:  Creates Subtitle Language
################################################################################
Function CreateSubtitleLanguage {
    Write-Host `"Creating Subtitle Language`"
    Set-Location $script_path
    # Find-Path `"$script_path\subtitle_language`"
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $initialPointSize = 250
    $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "subtitle_language_name" -CaseSensitivity Upper) 

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Name| out_name| base_color| other_setting',
        'A| short| #88F678| NA',
        'THISISALONGONE| long| #88F678| NA',
        'ABKHAZIAN| ab| #88F678| NA',
        'AFAR| aa| #612A1C| NA',
        'AFRIKAANS| af| #60EC40| NA',
        'AKAN| ak| #021FBC| NA',
        'ALBANIAN| sq| #C5F277| NA',
        'AMHARIC| am| #746BC8| NA',
        'ARABIC| ar| #37C768| NA',
        'ARAGONESE| an| #4619FD| NA',
        'ARMENIAN| hy| #5F26E3| NA',
        'ASSAMESE| as| #615C3B| NA',
        'AVARIC| av| #2BCE4A| NA',
        'AVESTAN| ae| #CF6EEA| NA',
        'AYMARA| ay| #3D5D3B| NA',
        'AZERBAIJANI| az| #A48C7A| NA',
        'BAMBARA| bm| #C12E3D| NA',
        'BASHKIR| ba| #ECD14A| NA',
        'BASQUE| eu| #89679F| NA',
        'BELARUSIAN| be| #1050B0| NA',
        'BENGALI| bn| #EA4C42| NA',
        'BISLAMA| bi| #C39A37| NA',
        'BOSNIAN| bs| #7DE3FE| NA',
        'BRETON| br| #7E1A72| NA',
        'BULGARIAN| bg| #D5442A| NA',
        'BURMESE| my| #9E5CF0| NA',
        'CATALAN| ca| #99BC95| NA',
        'CENTRAL KHMER| km| #6ABDD6| NA',
        'CHAMORRO| ch| #22302F| NA',
        'CHECHEN| ce| #83E832| NA',
        'CHICHEWA| ny| #03E31C| NA',
        'CHINESE| zh| #40EA69| NA',
        'CHURCH SLAVIC| cu| #C76DC2| NA',
        'CHUVASH| cv| #920F92| NA',
        'CORNISH| kw| #55137D| NA',
        'CORSICAN| co| #C605DC| NA',
        'CREE| cr| #75D7F3| NA',
        'CROATIAN| hr| #AB48D3| NA',
        'CZECH| cs| #7804BB| NA',
        'DANISH| da| #87A5BE| NA',
        'DIVEHI| dv| #FA57EC| NA',
        'DUTCH| nl| #74352E| NA',
        'DZONGKHA| dz| #F7C931| NA',
        'ENGLISH| en| #DD4A2F| NA',
        'ESPERANTO| eo| #B65ADE| NA',
        'ESTONIAN| et| #AF1569| NA',
        'EWE| ee| #2B7E43| NA',
        'FAROESE| fo| #507CCC| NA',
        'FIJIAN| fj| #7083F9| NA',
        'FILIPINO| fil| #8BEF80| NA',
        'FINNISH| fi| #9229A6| NA',
        'FRENCH| fr| #4111A0| NA',
        'FULAH| ff| #649BA7| NA',
        'GAELIC| gd| #FBFEC1| NA',
        'GALICIAN| gl| #DB6769| NA',
        'GANDA| lg| #C71A50| NA',
        'GEORGIAN| ka| #8517C8| NA',
        'GERMAN| de| #4F5FDC| NA',
        'GREEK| el| #49B49A| NA',
        'GUARANI| gn| #EDB51C| NA',
        'GUJARATI| gu| #BDF7FF| NA',
        'HAITIAN| ht| #466EB6| NA',
        'HAUSA| ha| #A949D2| NA',
        'HEBREW| he| #E9C58A| NA',
        'HERERO| hz| #E9DF57| NA',
        'HINDI| hi| #77775B| NA',
        'HIRI MOTU| ho| #3BB41B| NA',
        'HUNGARIAN| hu| #111457| NA',
        'ICELANDIC| is| #0ACE8F| NA',
        'IDO| io| #75CA6C| NA',
        'IGBO| ig| #757EDE| NA',
        'INDONESIAN| id| #52E822| NA',
        'INTERLINGUA| ia| #7F9248| NA',
        'INTERLINGUE| ie| #8F802C| NA',
        'INUKTITUT| iu| #43C3B0| NA',
        'INUPIAQ| ik| #ECF371| NA',
        'IRISH| ga| #FB7078| NA',
        'ITALIAN| it| #95B5DF| NA',
        'JAPANESE| ja| #5D776B| NA',
        'JAVANESE| jv| #5014C5| NA',
        'KALAALLISUT| kl| #050CF3| NA',
        'KANNADA| kn| #440B43| NA',
        'KANURI| kr| #4F2AAC| NA',
        'KASHMIRI| ks| #842C02| NA',
        'KAZAKH| kk| #665F3D| NA',
        'KIKUYU| ki| #315679| NA',
        'KINYARWANDA| rw| #CE1391| NA',
        'KIRGHIZ| ky| #5F0D23| NA',
        'KOMI| kv| #9B06C3| NA',
        'KONGO| kg| #74BC47| NA',
        'KOREAN| ko| #F5C630| NA',
        'KUANYAMA| kj| #D8CB60| NA',
        'KURDISH| ku| #467330| NA',
        'LAO| lo| #DD3B78| NA',
        'LATIN| la| #A73376| NA',
        'LATVIAN| lv| #A65EC1| NA',
        'LIMBURGAN| li| #13C252| NA',
        'LINGALA| ln| #BBEE5B| NA',
        'LITHUANIAN| lt| #E89C3E| NA',
        'LUBA-KATANGA| lu| #4E97F3| NA',
        'LUXEMBOURGISH| lb| #4738EE| NA',
        'MACEDONIAN| mk| #B69974| NA',
        'MALAGASY| mg| #29D850| NA',
        'MALAY| ms| #A74139| NA',
        'MALAYALAM| ml| #FD4C87| NA',
        'MALTESE| mt| #D6EE0B| NA',
        'MANX| gv| #3F83E9| NA',
        'MAORI| mi| #8339FD| NA',
        'MARATHI| mr| #93DEF1| NA',
        'MARSHALLESE| mh| #11DB75| NA',
        'MONGOLIAN| mn| #A107D9| NA',
        'NAURU| na| #7A0925| NA',
        'NAVAJO| nv| #48F865| NA',
        'NDONGA| ng| #83538B| NA',
        'NEPALI| ne| #5A15FC| NA',
        'NORTH NDEBELE| nd| #A1533B| NA',
        'NORTHERN SAMI| se| #AAD61B| NA',
        'NORWEGIAN BOKMÅL| nb| #0AEB4A| NA',
        'NORWEGIAN NYNORSK| nn| #278B62| NA',
        'NORWEGIAN| no| #13FF63| NA',
        'OCCITAN| oc| #B5B607| NA',
        'OJIBWA| oj| #100894| NA',
        'ORIYA| or| #0198FF| NA',
        'OROMO| om| #351BD8| NA',
        'OSSETIAN| os| #BF715E| NA',
        'OTHER| other| #FF2000| NA',
        'PALI| pi| #BEB3FA| NA',
        'PASHTO| ps| #A4236C| NA',
        'PERSIAN| fa| #68A38E| NA',
        'POLISH| pl| #D4F797| NA',
        'PORTUGUESE| pt| #71D659| NA',
        'PUNJABI| pa| #14F788| NA',
        'QUECHUA| qu| #268110| NA',
        'ROMANIAN| ro| #06603F| NA',
        'ROMANSH| rm| #3A73F3| NA',
        'RUNDI| rn| #715E84| NA',
        'RUSSIAN| ru| #DB77DA| NA',
        'SAMOAN| sm| #A26738| NA',
        'SANGO| sg| #CA1C7E| NA',
        'SANSKRIT| sa| #CF9C76| NA',
        'SARDINIAN| sc| #28AF67| NA',
        'SERBIAN| sr| #FB3F2C| NA',
        'SHONA| sn| #40F3EC| NA',
        'SICHUAN YI| ii| #FA3474| NA',
        'SINDHI| sd| #62D1BE| NA',
        'SINHALA| si| #24787A| NA',
        'SLOVAK| sk| #66104F| NA',
        'SLOVENIAN| sl| #6F79E6| NA',
        'SOMALI| so| #A36185| NA',
        'SOUTH NDEBELE| nr| #8090E5| NA',
        'SOUTHERN SOTHO| st| #4C3417| NA',
        'SPANISH| es| #7842AE| NA',
        'SUNDANESE| su| #B2D05B| NA',
        'SWAHILI| sw| #D32F20| NA',
        'SWATI| ss| #AA196D| NA',
        'SWEDISH| sv| #0EC5A2| NA',
        'TAGALOG| tl| #C9DDAC| NA',
        'TAHITIAN| ty| #32009D| NA',
        'TAJIK| tg| #100ECF| NA',
        'TAMIL| ta| #E71FAE| NA',
        'TATAR| tt| #C17483| NA',
        'TELUGU| te| #E34ABD| NA',
        'THAI| th| #3FB501| NA',
        'TIBETAN| bo| #FF2496| NA',
        'TIGRINYA| ti| #9074F0| NA',
        'TONGA| to| #B3259E| NA',
        'TSONGA| ts| #12687C| NA',
        'TSWANA| tn| #DA3E89| NA',
        'TURKISH| tr| #A08D29| NA',
        'TURKMEN| tk| #E70267| NA',
        'TWI| tw| #8A6C0F| NA',
        'UIGHUR| ug| #79BC21| NA',
        'UKRAINIAN| uk| #EB60E9| NA',
        'URDU| ur| #57E09D| NA',
        'UZBEK| uz| #4341F3| NA',
        'VENDA| ve| #4780ED| NA',
        'VIETNAMESE| vi| #90A301| NA',
        'VOLAPÜK| vo| #77D574| NA',
        'WALLOON| wa| #BD440A| NA',
        'WELSH| cy| #45E39C| NA',
        'WESTERN FRISIAN| fy| #01F471| NA',
        'WOLOF| wo| #BDD498| NA',
        'XHOSA| xh| #0C6D9C| NA',
        'YIDDISH| yi| #111D14| NA',
        'YORUBA| yo| #E815FF| NA',
        'ZHUANG| za| #C62A89| NA',
        'ZULU| zu| #0049F8| NA'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        # write-host $($item.Name)
        # write-host $($item.out_name)
        # write-host $($item.base_color)
        $myvar = Replace-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalFontSize $myvar $theFont $theMaxWidth $initialPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
        }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination subtitle_language
    Move-Item -Path output-orig -Destination output
}


################################################################################
# Function: CreateUniverse
# Description:  Creates Universe
################################################################################
Function CreateUniverse {
    Write-Host "Creating Universe"
    Set-Location $script_path
    # Find-Path "$script_path\universe"
    Move-Item -Path output -Destination output-orig    
    $arr = @()
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\askew.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"askew`" -base_color `"#0F66AD`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\avp.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"avp`" -base_color `"#2FC926`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\arrow.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"arrow`" -base_color `"#03451A`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\dca.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"dca`" -base_color `"#2832C5`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\dcu.png`" -logo_offset +0 -logo_resize 1500 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"dcu`" -base_color `"#2832C4`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\fast.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"fast`" -base_color `"#7F1FC8`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\marvel.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"marvel`" -base_color `"#ED171F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\mcu.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mcu`" -base_color `"#C62D21`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\middle.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"middle`" -base_color `"#D79C2B`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\mummy.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"mummy`" -base_color `"#DBA02F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\rocky.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"rocky`" -base_color `"#CC1F10`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\star.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"star`" -base_color `"#FFD64F`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\star (1).png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"star (1)`" -base_color `"#F2DC1D`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\starsky.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"starsky`" -base_color `"#0595FB`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\trek.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"trek`" -base_color `"#ffe15f`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\wizard.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"wizard`" -base_color `"#878536`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\xmen.png`" -logo_offset +0 -logo_resize 1800 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"xmen`" -base_color `"#636363`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination universe
    Copy-Item -Path logos_universe -Destination universe\logos -Recurse
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateYear
# Description:  Creates Year
################################################################################
Function CreateYear {
    Write-Host "Creating Year"
    Set-Location $script_path
    Find-Path "$script_path\year"
    Find-Path "$script_path\year\best"
    WriteToLogFile "ImageMagick Commands for     : Years"
    WriteToLogFile "ImageMagick Commands for     : Years-Best"

    .\create_poster.ps1 -logo "$script_path\transparent.png" -logo_offset +0 -logo_resize 1800 -text "OTHER\nYEARS" -text_offset +0 -font "ComfortAa-Medium" -font_size 250 -font_color "#FFFFFF" -border 0 -border_width 15 -border_color "#FFFFFF" -avg_color_image "" -out_name "other" -base_color "#FF2000" -gradient 1 -avg_color 0 -clean 1 -white_wash 1
    Move-Item output\other.jpg -Destination year

    for ($i = 1880; $i -lt 1890; $i++) {
        $j = $i - 1880
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Rye-Regular 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1890; $i -lt 1900; $i++) {
        $j = $i - 1890
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Limelight-Regular 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1900; $i -lt 1910; $i++) {
        $j = $i - 1900
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png BoecklinsUniverse 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1910; $i -lt 1920; $i++) {
        $j = $i - 1910
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Glass-Antiqua 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1920; $i -lt 1930; $i++) {
        $j = $i - 1920
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Young-20s-Regular 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1930; $i -lt 1940; $i++) {
        $j = $i - 1930
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png AirstreamNF 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1940; $i -lt 1950; $i++) {
        $j = $i - 1940
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png RicksAmericanNF 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1950; $i -lt 1960; $i++) {
        $j = $i - 1950
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Sacramento 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1960; $i -lt 1970; $i++) {
        $j = $i - 1960
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png ActionIs 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1970; $i -lt 1980; $i++) {
        $j = $i - 1970
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Mexcellent-Regular 1900x500 $i "$script_path\year\best"
    }

    for ($i = 1980; $i -lt 1990; $i++) {
        $j = $i - 1980
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Press-Start-2P 1900x300 $i "$script_path\year\best"
    }

    for ($i = 1990; $i -lt 2000; $i++) {
        $j = $i - 1990
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Milenia 1900x500 $i "$script_path\year\best"
    }

    for ($i = 2000; $i -lt 2010; $i++) {
        $j = $i - 2000
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png XBAND-Rough 1900x500 $i "$script_path\year\best"
    }

    for ($i = 2010; $i -lt 2020; $i++) {
        $j = $i - 2010
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png VAL-UltraBlack 1900x500 $i "$script_path\year\best"
    }

    for ($i = 2020; $i -lt 2030; $i++) {
        $j = $i - 2020
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-best.png Helvetica-Bold 1900x500 $i "$script_path\year\best"
    }

    WriteToLogFile "ImageMagick Commands for     : Years"
    for ($i = 1880; $i -lt 1890; $i++) {
        $j = $i - 1880
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Rye-Regular 1900x500 $i "$script_path\year"
    }

    for ($i = 1890; $i -lt 1900; $i++) {
        $j = $i - 1890
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Limelight-Regular 1900x500 $i "$script_path\year"
    }

    for ($i = 1900; $i -lt 1910; $i++) {
        $j = $i - 1900
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png BoecklinsUniverse 1900x500 $i "$script_path\year"
    }

    for ($i = 1910; $i -lt 1920; $i++) {
        $j = $i - 1910
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Glass-Antiqua 1900x500 $i "$script_path\year"
    }

    for ($i = 1920; $i -lt 1930; $i++) {
        $j = $i - 1920
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Young-20s-Regular 1900x500 $i "$script_path\year"
    }

    for ($i = 1930; $i -lt 1940; $i++) {
        $j = $i - 1930
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png AirstreamNF 1900x500 $i "$script_path\year"
    }

    for ($i = 1940; $i -lt 1950; $i++) {
        $j = $i - 1940
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png RicksAmericanNF 1900x500 $i "$script_path\year"
    }

    for ($i = 1950; $i -lt 1960; $i++) {
        $j = $i - 1950
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Sacramento 1900x500 $i "$script_path\year"
    }

    for ($i = 1960; $i -lt 1970; $i++) {
        $j = $i - 1960
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png ActionIs 1900x500 $i "$script_path\year"
    }

    for ($i = 1970; $i -lt 1980; $i++) {
        $j = $i - 1970
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Mexcellent-Regular 1900x500 $i "$script_path\year"
    }

    for ($i = 1980; $i -lt 1990; $i++) {
        $j = $i - 1980
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Press-Start-2P 1900x300 $i "$script_path\year"
    }

    for ($i = 1990; $i -lt 2000; $i++) {
        $j = $i - 1990
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Milenia 1900x500 $i "$script_path\year"
    }

    for ($i = 2000; $i -lt 2010; $i++) {
        $j = $i - 2000
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png XBAND-Rough 1900x500 $i "$script_path\year"
    }

    for ($i = 2010; $i -lt 2020; $i++) {
        $j = $i - 2010
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png VAL-UltraBlack 1900x500 $i "$script_path\year"
    }

    for ($i = 2020; $i -lt 2030; $i++) {
        $j = $i - 2020
        Convert-Years $script_path\@base\@zbase-0$j.png $script_path\@base\@zbase-0$j.png Helvetica-Bold 1900x500 $i "$script_path\year"
    }
}

################################################################################
# Function: MonitorProcess
# Description: Checks to see if process is running in memory and only exits
################################################################################
Function MonitorProcess {
    param(
        [string]$ProcessName
    )
    # Start-Sleep -Seconds 10
    $startTime = Get-Date
    while ((Get-Process $ProcessName -ErrorAction SilentlyContinue) -and ((New-TimeSpan -Start $startTime).TotalMinutes -lt 10)) {
        Start-Sleep -Seconds 10
    }
    if ((Get-Process $ProcessName -ErrorAction SilentlyContinue)) {
        WriteToLogFile "MonitorProcess               : Process $ProcessName is still running after 10 minutes, exiting the function"
    }
    else {
        WriteToLogFile "MonitorProcess               : Process $ProcessName is no longer running"

    }
}

################################################################################
# Function: ShowFunctions
# Description: Prints the list of possible parameters
################################################################################
Function ShowFunctions {
    Write-Host "EXAMPLES:"
    Write-Host "You can run the script by providing the name of the function you want to run as a command-line argument:"
    Write-Host "create_default_posters.ps1 AudioLanguage "
    Write-Host "This will run only the CreateAudioLanguage function."
    Write-Host ""
    Write-Host "You can also provide multiple function names as command-line arguments:"
    Write-Host "create_default_posters.ps1 AudioLanguage Playlist Chart"
    Write-Host "This will run CreateAudioLanguage, CreatePlaylist, and CreateChart functions in that order."
    Write-Host ""
    Write-Host "Finally just running the script with All will run all of the functions"
    Write-Host "create_default_posters.ps1 All"
    Write-Host ""
    Write-Host "Possible parameters are:"
    Write-Host "AudioLanguage, Awards, Based, Charts, ContentRating, Country, Decades, Franchise, Genres, Network, Playlist, Resolution, Streaming, Studio, Seasonal, Separators, SubtitleLanguages, Universe, Years, All"
    exit
}

#################################
# MAIN
#################################
Set-Location $script_path
$font_flag = $null
if (Test-Path $scriptLog) {
    Remove-Item $scriptLog
}
#################################
# Language Code
#################################
$LanguageCodes = @("default", "da", "de", "es", "fr", "it", "pt-br")
$DefaultLanguageCode = "default"
$LanguageCode = Read-Host "Enter language code ($($LanguageCodes -join ', ')). Press Enter to use the default language code: $DefaultLanguageCode"

if (-not [string]::IsNullOrWhiteSpace($LanguageCode) -and $LanguageCodes -notcontains $LanguageCode) {
    Write-Error "Error: Invalid language code."
    return
}

if ([string]::IsNullOrWhiteSpace($LanguageCode)) {
    $LanguageCode = $DefaultLanguageCode
}

Download-TranslationFile -LanguageCode $LanguageCode
# Read-Host -Prompt "Press any key to continue..."

$TranslationFilePath = Join-Path $script_path -ChildPath "@translations"
$TranslationFilePath = Join-Path $TranslationFilePath -ChildPath "$LanguageCode.yml"

WriteToLogFile "#### START ####"
WriteToLogFile "Script Path                  : $script_path"

$Stopwatch = [System.Diagnostics.Stopwatch]::new()
$Stopwatch.Start()

Test-ImageMagick
$test = $global:magick
if ($null -eq $test) {
    WriteToLogFile "Imagemagick                  : Imagemagick is NOT installed. Aborting.... Imagemagick must be installed - https://imagemagick.org/script/download.php"
    exit
}
else {
    WriteToLogFile "Imagemagick                  : Imagemagick is installed. $global:magick"
}
$tmp = $null
$tmp = $PSVersionTable.PSVersion.ToString()
WriteToLogFile "Powershell Version           : $tmp"

#################################
# Cleanup Folders
#################################
Set-Location $script_path
Remove-Folders

#################################
# Create Paths if needed
#################################
Find-Path "$script_path\@base"
Find-Path "$script_path\defaults"
Find-Path "$script_path\fonts"
Find-Path "$script_path\output"

#################################
# Checksum Files
#################################
Set-Location $script_path
WriteToLogFile "CheckSum Files               : Checking dependency files."

$sep1 = "blue.png"
$sep2 = "gray.png"
$sep3 = "green.png"
$sep4 = "orig.png"
$sep5 = "purple.png"
$sep6 = "red.png"
$sep7 = "stb.png"
$ttf1 = "ActionIs.ttf"
$ttf2 = "AirstreamNF.ttf"
$ttf3 = "Bebas-Regular.ttf"
$ttf4 = "BoecklinsUniverse.ttf"
$ttf5 = "Comfortaa-Medium.ttf"
$ttf6 = "Glass-Antiqua.ttf"
$ttf7 = "Helvetica-Bold.ttf"
$ttf8 = "Limelight-Regular.ttf"
$ttf9 = "Mexcellent-Regular.ttf"
$ttf10 = "Milenia.ttf"
$ttf11 = "Press-Start-2P.ttf"
$ttf12 = "RicksAmericanNF.ttf"
$ttf13 = "Rye-Regular.ttf"
$ttf14 = "Sacramento.ttf"
$ttf15 = "VAL-UltraBlack.ttf"
$ttf16 = "XBAND-Rough.ttf"
$ttf17 = "Young-20s-Regular.ttf"
$base1 = "@base-best.png"
$base2 = "@base-nomination.png"
$base3 = "@base-NULL.png"
$base4 = "@base-winners.png"
$base5 = "@zbase-00.png"
$base6 = "@zbase-01.png"
$base7 = "@zbase-02.png"
$base8 = "@zbase-03.png"
$base9 = "@zbase-04.png"
$base10 = "@zbase-05.png"
$base11 = "@zbase-06.png"
$base12 = "@zbase-07.png"
$base13 = "@zbase-08.png"
$base14 = "@zbase-09.png"
$base15 = "@zbase-1880s.png"
$base16 = "@zbase-1890s.png"
$base17 = "@zbase-1900s.png"
$base18 = "@zbase-1910s.png"
$base19 = "@zbase-1920s.png"
$base20 = "@zbase-1930s.png"
$base21 = "@zbase-1940s.png"
$base22 = "@zbase-1950s.png"
$base23 = "@zbase-1960s.png"
$base24 = "@zbase-1970s.png"
$base25 = "@zbase-1980s.png"
$base26 = "@zbase-1990s.png"
$base27 = "@zbase-2000s.png"
$base28 = "@zbase-2010s.png"
$base29 = "@zbase-2020s.png"
$base30 = "@zbase-BAFTA.png"
$base31 = "@zbase-Berlinale.png"
$base32 = "@zbase-best_director_winner.png"
$base33 = "@zbase-best_picture_winner.png"
$base34 = "@zbase-best.png"
$base35 = "@zbase-Cannes.png"
$base36 = "@zbase-Cesar.png"
$base37 = "@zbase-Choice.png"
$base38 = "@zbase-decade.png"
$base39 = "@zbase-Emmys.png"
$base40 = "@zbase-Golden.png"
$base41 = "@zbase-grand_jury_winner.png"
$base42 = "@zbase-nomination.png"
$base43 = "@zbase-Oscars.png"
$base44 = "@zbase-Spirit.png"
$base45 = "@zbase-Sundance.png"
$base46 = "@zbase-Venice.png"
$base47 = "@zbase-winner.png"

$fade1 = "@bottom-top-fade.png"
$fade2 = "@bottom-up-fade.png"
$fade3 = "@center-out-fade.png"
$fade4 = "@none.png"
$fade5 = "@top-down-fade.png"

$trans1 = "transparent.png"

$expectedChecksum_sep1 = "AB8DBC5FCE661BDFC643F9697EEC1463CD2CDE90E4594B232A6B92C272DE0561"
$expectedChecksum_sep2 = "9570B1E86BEC71CAED6DDFD6D2F18023A7C5D408B6A6D5B50C045672D4310772"
$expectedChecksum_sep3 = "89951DFC6338ABC64444635F6F2835472418BF779A1EB5C342078AF0B8365F80"
$expectedChecksum_sep4 = "98E161CD70C3300D30340257D674FCC18B11FDADEE3FFF9B80D09C4AB09C1483"
$expectedChecksum_sep5 = "3768CA736B6BD1CAD0CD02827A6BA7BDBCA2077B1A109802C57144C31B379477"
$expectedChecksum_sep6 = "03E9026430C8F0ABD031B608225BF40CB87FD1983899C113E410A511CC5622A7"
$expectedChecksum_sep7 = "A01695FAB8646079331811F381A38A529E76AFC31538285E7EE60600CA07ADC1"

$expectedChecksum_ttf1 = "86862A55996EE1DC2AACE43C4B82737D1A07F067588FF08BB27F08E12C93B9CB"
$expectedChecksum_ttf2 = "128F10A9D74C18CC42A923D66D38B3FEBE9C4E1C859F24C8A879A1C9077F4E23"
$expectedChecksum_ttf3 = "39D2EB178FDD52B4C350AC6DEE3D2090AE5A7C187225B0D161A1473CCBB6320D"
$expectedChecksum_ttf4 = "5F6F6396EDEE3FA1FE9443258D7463F82E6B2512A03C5102A90295A095339FB5"
$expectedChecksum_ttf5 = "992F89F3C26BE37CCEBF784B294D36F40B96ED96AD9A3CC1396F4D389FC69D0C"
$expectedChecksum_ttf6 = "AF93FAEDD95BD2EA55FD6F6CA62136933B641497693F15B19FC3642D54B5B44E"
$expectedChecksum_ttf7 = "D19CCD4211E3CAAAC2C7F1AE544456F5C67CD912E2BDFB1EFB6602C090C724EE"
$expectedChecksum_ttf8 = "5D2C9F43D8CB4D49481A39A33CDC2A9157B1FCBFB381063A11617EDE209A105C"
$expectedChecksum_ttf9 = "4170A34DD5956F96B2D2F2725363B566FFD72BC0DFC75C5A0F514D99E7F69830"
$expectedChecksum_ttf10 = "34C62B45859DE99BD80EA57817E558524117EB074DA0DF63512B55A7F0062DD0"
$expectedChecksum_ttf11 = "17EC7D250FF590971A6D966B4FDC5AA04D5E39A7694F4A0BECB515B6A70A7228"
$expectedChecksum_ttf12 = "96E18BC0DE6A9E1B67070D9DD2B358C01E0DD44BB135A1917DABCCF0CEDDCB0C"
$expectedChecksum_ttf13 = "722825F800CF7CEAE4791B274D45DA9DF517DB7CF7A07BFAFD34452B787C5354"
$expectedChecksum_ttf14 = "9341FDA10ADBFEB7EFC94302B34507A3E227D7E7F5C432DF3F5AC8753FF73D24"
$expectedChecksum_ttf15 = "44CCF182F86E3A538ACF06EF0297507ABB1C73E2B21577BF6F62B7959DF9FB79"
$expectedChecksum_ttf16 = "06DB27021D3651175CB4FFCD9CE581CFD69ED2AD681FD336631E45B31A6B1263"
$expectedChecksum_ttf17 = "6089FD0829F574CCCEC9E3A790FEE04A7AB65F132CD2BA35CD8B6D9E92CDDB94"

$expectedChecksum_base1 = "2F5EC311CDE0EB4F198A0CC2CA75F20FF67154D81D6828484090CEC094020005"
$expectedChecksum_base2 = "F8BB53CB9503BD6AFACD7C9D195CACFFFF7FC4F6D972D1C85AFA0CB10E81D027"
$expectedChecksum_base3 = "4C166FDC756B04E3AA6F87BCF6896CB4DD23C2374129A589F570FEC284818896"
$expectedChecksum_base4 = "FA91DEABE72BB51D94CE6EB76E617AFE9CC16E5C7ECD8FCE90B7B00B559574FA"
$expectedChecksum_base5 = "CB998DA647D537852CE06403EF22EE64588E49CA690C96C3B2BA04F8E07CF36B"
$expectedChecksum_base6 = "169CA870948C69EDFBBD12C20F8900EA9AFD7EC592F31ECCF3B2993EF1278980"
$expectedChecksum_base7 = "29E82A0F99FA7EDAF0E804DAB344447F82AD7C2CBAB400B133AF2230EE466F00"
$expectedChecksum_base8 = "FD7228CC318E901ABAD8A648A5D6A09DCF07C2F8DF7740131CDC8CE257722D12"
$expectedChecksum_base9 = "BA04F2148EB8D387AE4AD7F94573DE28EC4C207D71470F3CC0A602D74443ED69"
$expectedChecksum_base10 = "B9DB691FC235E129DB3CD40647578110633E9FB70CAEA416CD77BEF2A23D3760"
$expectedChecksum_base11 = "42B555C2F944A4A1B2078702861187D28939ED6635BB921E6EF2BA446C49188A"
$expectedChecksum_base12 = "9D21D44B0A4C3AD180DE496851C23E866ECBC18BBA8A57AC4E658DB153483A5E"
$expectedChecksum_base13 = "7103464487DB234575EAE8B544F9334937DE8B1A1D19D0CEA9E78F7367F59396"
$expectedChecksum_base14 = "FE21543996792C2C2D4FF9A7417D2756D8D8216F1726C582819E852BCC82490A"
$expectedChecksum_base15 = "8839109ACEBE09A49F2D136434ADC2747E32B361D96562EE1FBE0CD039D912F8"
$expectedChecksum_base16 = "4DBE7AC1B165BF6EABCBCE9870F597A50AA55E3EEE8464E308EBF80999308823"
$expectedChecksum_base17 = "F22A0B5F9C6290F28D06A6978D5D44CF398862CF655F72A4D6E17167478D6F6F"
$expectedChecksum_base18 = "C3B89A46827231B56A4818530DE30E529114F6CF4B0A2633C1EB84C0BF51EB01"
$expectedChecksum_base19 = "90D315EF0656BA39B1BD3F261D69A96A69FA3332A9714991CA990656CE864D27"
$expectedChecksum_base20 = "11B6002460BCC798B3DF811A1B1DA9C66E70A2970EF83BB7CA2B2FCBF210920B"
$expectedChecksum_base21 = "AF02FC1F817F0773CD5A4AA591B28D4932054BC7229E2331622D2103DB82A147"
$expectedChecksum_base22 = "269AD0F54C294345B5EEF485E12E8463FE79F8CEBB2A80D9E11F1B0D961E52B0"
$expectedChecksum_base23 = "B0012A960453E75A41527CE73CC7422980604ABD548DFB803CD7E8AAB81720EB"
$expectedChecksum_base24 = "A9A736CE0E63AFA36E6B4262F22D78948780248ADDDA8E035D44D5AE08D5FAF7"
$expectedChecksum_base25 = "9161CE1200062CAD400AA7A0D382CFB284443C549BE8FE17838B65168F2970BB"
$expectedChecksum_base26 = "1F577EBEC9B53607E177D6CB083D9373C1A2577F2EFD781BFEFF24D3C8081537"
$expectedChecksum_base27 = "6C26ADEC9DA35A6417B38B6AF083A9F8240F674882247B398F0ED2F162C10DC4"
$expectedChecksum_base28 = "EE442FF1CD82D809E4AE2A5FFA43F3B177C0952B683704C6C9936D7A2A76E1FD"
$expectedChecksum_base29 = "8DF15F8FA52C076BE85B1031B005D452C802D61A1872A502462A096375804472"
$expectedChecksum_base30 = "F9DC96A0BE900951EFE99A0E39F6B067C335B01713175C732E541A916AF635DD"
$expectedChecksum_base31 = "5A59FA31B05CDD27088DF17EB05A3AA7C04BC57C7210244136156895C64EF68C"
$expectedChecksum_base32 = "81749AE86D6DA76A781391BF46AB14D1CA724897117D5715D2020BF91558C29D"
$expectedChecksum_base33 = "21D790B049BA73364B8FB8AA109CBD373CCB2C1D94CA10AF554C823E4EC9E867"
$expectedChecksum_base34 = "597CA9E13D39B943ED22A0A6029EC02EE0693EBCCE8A8C4501CF091EA194EC88"
$expectedChecksum_base35 = "B19157A68186AE02881EAAA3C95E2CEC7920DFD066819784A0637B0D2526C83A"
$expectedChecksum_base36 = "26AB5358249755D5C2A249155DB752842C18B2E0A5597E092A4F9EE1D930C9A3"
$expectedChecksum_base37 = "4742A22B862331B40DEAE73371A0CDAC303401796147646C1D039F2B016E1658"
$expectedChecksum_base38 = "D693075F0AF4CDB3F7503E5C3135197079465C07596D394D5D2591E6E1EF5196"
$expectedChecksum_base39 = "416BAFFA38C5BA859F5DDF5B6611603F52172E4A37FDD3BD970354D8EF633617"
$expectedChecksum_base40 = "1B37A0AF6A3ED5B0BC23FDEAD62C9AD4C0A140CB98A89EDB62E9AB4D3CBC216F"
$expectedChecksum_base41 = "AF82581F1D9F0CF64023F7A63A1C419475E1E01EB6FB11CA6E7C4634A257376F"
$expectedChecksum_base42 = "5759BB9FA8C9F9CE68CE26C42B7E9441C53397F3F8F88678FCCBCA7CD77FBDF0"
$expectedChecksum_base43 = "F326B2D94D42189516C9CCAF02C10064AA2028FE9480B1C78D4A20AEE1BAE9CA"
$expectedChecksum_base44 = "6097877450E63890250F03A47B8EB935DEE5BB2205B541F1AB4F83A4F817D729"
$expectedChecksum_base45 = "0925F59D38BA4213B917BCA0FDD70C9E9EE13115471713ED1F67D5856E44C662"
$expectedChecksum_base46 = "1DD63AD69190BD7DA0E858BBB8DF9B1D6C5BAC4D566185487CF8623DE1BFDE21"
$expectedChecksum_base47 = "19893DD5E4D8F5F50CD8639C2B87A35B54962B7383A415091237289448EBC3CF"

$expectedChecksum_fade1 = "79D93B7455A694820A4DF4B27B4418EA0063AF59400ED778FC66F83648DAA110"
$expectedChecksum_fade2 = "7ED182E395A08B4035B687E6F0661029EF938F8027923EC9434EBCBC5D144CFD"
$expectedChecksum_fade3 = "6D36359197363DDC092FDAA8AA4590838B01B8A22C3BF4B6DED76D65BC85A87C"
$expectedChecksum_fade4 = "5E89879184510E91E477D41C61BD86A0E9209E9ECC17909A7B0EE20427950CBC"
$expectedChecksum_fade5 = "CBBF0B235A893410E02977419C89EE6AD97DF253CBAEE382E01D088D2CCE6B39"

$expectedChecksum_trans1 = "64A0A1D637FF0687CCBCAECA31B8E6B7235002B1EE8528E7A60BE6A7D636F1FC"

$failFlag = [ref] $false
Write-Output "Begin: " $failFlag.Value

Verify-FileChecksum -Path $script_path\@base\$sep1 -ExpectedChecksum $expectedChecksum_sep1 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$sep2 -ExpectedChecksum $expectedChecksum_sep2 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$sep3 -ExpectedChecksum $expectedChecksum_sep3 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$sep4 -ExpectedChecksum $expectedChecksum_sep4 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$sep5 -ExpectedChecksum $expectedChecksum_sep5 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$sep6 -ExpectedChecksum $expectedChecksum_sep6 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$sep7 -ExpectedChecksum $expectedChecksum_sep7 -failFlag $failFlag

Verify-FileChecksum -Path $script_path\fonts\$ttf1 -ExpectedChecksum $expectedChecksum_ttf1 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf2 -ExpectedChecksum $expectedChecksum_ttf2 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf3 -ExpectedChecksum $expectedChecksum_ttf3 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf4 -ExpectedChecksum $expectedChecksum_ttf4 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf5 -ExpectedChecksum $expectedChecksum_ttf5 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf6 -ExpectedChecksum $expectedChecksum_ttf6 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf7 -ExpectedChecksum $expectedChecksum_ttf7 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf8 -ExpectedChecksum $expectedChecksum_ttf8 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf9 -ExpectedChecksum $expectedChecksum_ttf9 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf10 -ExpectedChecksum $expectedChecksum_ttf10 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf11 -ExpectedChecksum $expectedChecksum_ttf11 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf12 -ExpectedChecksum $expectedChecksum_ttf12 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf13 -ExpectedChecksum $expectedChecksum_ttf13 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf14 -ExpectedChecksum $expectedChecksum_ttf14 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf15 -ExpectedChecksum $expectedChecksum_ttf15 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf16 -ExpectedChecksum $expectedChecksum_ttf16 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fonts\$ttf17 -ExpectedChecksum $expectedChecksum_ttf17 -failFlag $failFlag

Verify-FileChecksum -Path $script_path\@base\$base1 -ExpectedChecksum $expectedChecksum_base1 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base2 -ExpectedChecksum $expectedChecksum_base2 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base3 -ExpectedChecksum $expectedChecksum_base3 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base4 -ExpectedChecksum $expectedChecksum_base4 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base5 -ExpectedChecksum $expectedChecksum_base5 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base6 -ExpectedChecksum $expectedChecksum_base6 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base7 -ExpectedChecksum $expectedChecksum_base7 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base8 -ExpectedChecksum $expectedChecksum_base8 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base9 -ExpectedChecksum $expectedChecksum_base9 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base10 -ExpectedChecksum $expectedChecksum_base10 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base11 -ExpectedChecksum $expectedChecksum_base11 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base12 -ExpectedChecksum $expectedChecksum_base12 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base13 -ExpectedChecksum $expectedChecksum_base13 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base14 -ExpectedChecksum $expectedChecksum_base14 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base15 -ExpectedChecksum $expectedChecksum_base15 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base16 -ExpectedChecksum $expectedChecksum_base16 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base17 -ExpectedChecksum $expectedChecksum_base17 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base18 -ExpectedChecksum $expectedChecksum_base18 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base19 -ExpectedChecksum $expectedChecksum_base19 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base20 -ExpectedChecksum $expectedChecksum_base20 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base21 -ExpectedChecksum $expectedChecksum_base21 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base22 -ExpectedChecksum $expectedChecksum_base22 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base23 -ExpectedChecksum $expectedChecksum_base23 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base24 -ExpectedChecksum $expectedChecksum_base24 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base25 -ExpectedChecksum $expectedChecksum_base25 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base26 -ExpectedChecksum $expectedChecksum_base26 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base27 -ExpectedChecksum $expectedChecksum_base27 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base28 -ExpectedChecksum $expectedChecksum_base28 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base29 -ExpectedChecksum $expectedChecksum_base29 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base30 -ExpectedChecksum $expectedChecksum_base30 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base31 -ExpectedChecksum $expectedChecksum_base31 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base32 -ExpectedChecksum $expectedChecksum_base32 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base33 -ExpectedChecksum $expectedChecksum_base33 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base34 -ExpectedChecksum $expectedChecksum_base34 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base35 -ExpectedChecksum $expectedChecksum_base35 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base36 -ExpectedChecksum $expectedChecksum_base36 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base37 -ExpectedChecksum $expectedChecksum_base37 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base38 -ExpectedChecksum $expectedChecksum_base38 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base39 -ExpectedChecksum $expectedChecksum_base39 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base40 -ExpectedChecksum $expectedChecksum_base40 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base41 -ExpectedChecksum $expectedChecksum_base41 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base42 -ExpectedChecksum $expectedChecksum_base42 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base43 -ExpectedChecksum $expectedChecksum_base43 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base44 -ExpectedChecksum $expectedChecksum_base44 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base45 -ExpectedChecksum $expectedChecksum_base45 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base46 -ExpectedChecksum $expectedChecksum_base46 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\@base\$base47 -ExpectedChecksum $expectedChecksum_base47 -failFlag $failFlag

Verify-FileChecksum -Path $script_path\fades\$fade1 -ExpectedChecksum $expectedChecksum_fade1 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fades\$fade2 -ExpectedChecksum $expectedChecksum_fade2 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fades\$fade3 -ExpectedChecksum $expectedChecksum_fade3 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fades\$fade4 -ExpectedChecksum $expectedChecksum_fade4 -failFlag $failFlag
Verify-FileChecksum -Path $script_path\fades\$fade5 -ExpectedChecksum $expectedChecksum_fade5 -failFlag $failFlag

Verify-FileChecksum -Path $script_path\$trans1 -ExpectedChecksum $expectedChecksum_trans1 -failFlag $failFlag

Write-Output "End:" $failFlag.Value

if ($failFlag.Value) {
    WriteToLogFile "Checksums                    : At least one checksum verification failed. Aborting..."
    exit
}
else {
    WriteToLogFile "Checksums                    : All checksum verifications succeeded."
}
Import-WidthCache -cacheFilePath $cacheFilePath

#################################
# Determine parameters passed from command line
#################################
Set-Location $script_path

foreach ($param in $args) {
    Switch ($param) {
        "AudioLanguage" { CreateAudioLanguage }
        "AudioLanguages" { CreateAudioLanguage }
        "Award" { CreateAwards }
        "Awards" { CreateAwards }
        "Based" { CreateBased }
        "Chart" { CreateChart }
        "Charts" { CreateChart }
        "ContentRating" { CreateContentRating }
        "ContentRatings" { CreateContentRating }
        "Country" { CreateCountry }
        "Countries" { CreateCountry }
        "Decade" { CreateDecade }
        "Decades" { CreateDecade }
        "Franchise" { CreateFranchise }
        "Franchises" { CreateFranchise }
        "Genre" { CreateGenre }
        "Genres" { CreateGenre }
        "Network" { CreateNetwork }
        "Networks" { CreateNetwork }
        "Playlist" { CreatePlaylist }
        "Playlists" { CreatePlaylist }
        "Resolution" { CreateResolution }
        "Resolutions" { CreateResolution }
        "Streaming" { CreateStreaming }
        "Studio" { CreateStudio }
        "Studios" { CreateStudio }
        "Seasonal" { CreateSeasonal }
        "Seasonals" { CreateSeasonal }
        "Separator" { CreateSeparators }
        "Separators" { CreateSeparators }
        "SubtitleLanguage" { CreateSubtitleLanguage }
        "SubtitleLanguages" { CreateSubtitleLanguage }
        "Universe" { CreateUniverse }
        "Universes" { CreateUniverse }
        "Year" { CreateYear }
        "Years" { CreateYear }
        "All" {
            CreateAudioLanguage
            CreateAwards
            CreateBased
            CreateChart
            CreateContentRating
            CreateCountry
            CreateDecade
            CreateFranchise
            CreateGenre
            CreateNetwork
            CreatePlaylist
            CreateResolution
            CreateSeasonal
            CreateSeparators
            CreateStreaming
            CreateStudio
            CreateSubtitleLanguage
            CreateUniverse
            CreateYear
        }
        default {
            ShowFunctions
        }
    }
}

if (!$args) {
    ShowFunctions
}

#######################
# Export cache
#######################
Set-Location $script_path

write-host $global:WidthCache
write-host $cacheFilePath 
WriteToLogFile "cacheFilePath                : $cacheFilePath"
WriteToLogFile "global:WidthCache            : $global:WidthCache"

Export-WidthCache -cacheFilePath $cacheFilePath

#######################
# Move folders to $script_path\defaults
#######################
Set-Location $script_path
WriteToLogFile "MonitorProcess               : Waiting for all processes to end..."
Start-Sleep -Seconds 3
MonitorProcess -ProcessName "magick.exe"
MoveFiles

#######################
# Count files created
#######################
Set-Location $script_path
$tmp = (Get-ChildItem $script_path\defaults -Recurse -File | Measure-Object).Count
$files_to_process = $tmp

#######################
# Output files created to a file
#######################
Set-Location $script_path
Get-ChildItem -Recurse ".\defaults\" -Name -File | ForEach-Object { '"{0}"' -f $_ } | Out-File defaults_list.txt

#######################
# SUMMARY
#######################
Set-Location $script_path
WriteToLogFile "#######################"
WriteToLogFile "# SUMMARY"
WriteToLogFile "#######################"

$x = [math]::Round($Stopwatch.Elapsed.TotalMinutes, 2)
$speed = [math]::Round($files_to_process / $Stopwatch.Elapsed.TotalMinutes, 2)
$y = [math]::Round($Stopwatch.Elapsed.TotalMinutes, 2)

$string = "Elapsed time is              : $x minutes"
WriteToLogFile $string

$string = "Files Processed              : $files_to_process in $y minutes"
WriteToLogFile $string

$string = "Posters per minute           : " + $speed.ToString()
WriteToLogFile $string
WriteToLogFile "#### END ####"