################################################################################
# create_default_poster.ps1
# Date: 2023-05-12
# Version: 3.1
# Author: bullmoose20
#
# DESCRIPTION: 
# This script contains ten functions that are used to create various types of posters. The functions are:
# CreateAudioLanguage, CreateAwards, CreateChart, CreateCountry, CreateDecade, CreateGenre, CreatePlaylist, CreateSubtitleLanguage, CreateUniverse, CreateVideoFormat, CreateYear, and CreateOverlays.
# The script can be called by providing the name of the function or aliases you want to run as a command-line argument.
# Aspect, AudioLanguage, Awards, Based, Charts, ContentRating, Country, Decades, Franchise, Genres, Network, Playlist, Resolution, Streaming,
# Studio, Seasonal, Separators, SubtitleLanguages, Universe, VideoFormat, Years, All
#
# REQUIREMENTS:
# Imagemagick must be installed - https://imagemagick.org/script/download.php
# font must be installed on system and visible by Imagemagick. Make sure that you install the ttf font for ALL users as an admin so ImageMagick has access to the font when running (r-click on font Install for ALL Users in Windows)
# Powershell security settings: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2
#
# multi-lingual font that supports arabic - Cairo-Regular
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
$global:ConfigObj = $null
$global:Config = $null

#################################
# collect paths
#################################
$script_path = $PSScriptRoot
Set-Location $script_path
$scriptName = $MyInvocation.MyCommand.Name
$scriptLogPath = Join-Path $script_path -ChildPath "logs"
$scriptLog = Join-Path $scriptLogPath -ChildPath "$scriptName.log"
$databasePath = Join-Path $script_path -ChildPath "OptimalPointSizeCache.db"
$scriptLog2 = Join-Path $scriptLogPath "create_poster.ps1.log"
$playback = Join-Path $script_path "playback.txt"

################################################################################
# Function: Clear-Log
# Description: clear create_poster.ps1.log to ensure we don't get errors reported from previous runs
################################################################################
Function Clear-Log {
    if (Test-Path -Path $scriptLog2) {
        Remove-Item -Path $scriptLog2 -Force
        WriteToLogFile "Reset Log                    : File deleted: $scriptLog2"
    }
    else {
        WriteToLogFile "Reset Log                    : File not found: $scriptLog2"
    }
}
################################################################################
# Function: New-SQLCache
# Description: creates a sqlcache file
################################################################################
Function New-SQLCache {
    # Import the required .NET assemblies
    Add-Type -Path "System.Data.SQLite.dll"

    # Define the SQLite table name
    $tableName = "Cache"

    # Create a SQLite connection and command objects
    $connection = New-Object System.Data.SQLite.SQLiteConnection "Data Source=$databasePath"
    $command = New-Object System.Data.SQLite.SQLiteCommand($connection)

    # Create the Cache table if it does not already exist
    $command.CommandText = @"
    CREATE TABLE IF NOT EXISTS $tableName (
        CacheKey TEXT PRIMARY KEY,
        PointSize INTEGER NOT NULL
    );
"@
    $connection.Open()
    $command.ExecuteNonQuery()
    $connection.Close()
}

################################################################################
# Function: Import-YamlModule
# Description: installs module if its not there
################################################################################
Function Import-YamlModule {
    # Check if PowerShell-YAML module is installed
    if (!(Get-Module -Name PowerShell-YAML -ListAvailable)) {
        # If not installed, install the module
        Install-Module -Name PowerShell-YAML -Scope CurrentUser -Force
    }

    # Import the module
    Import-Module -Name PowerShell-YAML
}

################################################################################
# Function: Update-LogFile
# Description: Rotates logs up to 10
################################################################################
Function Update-LogFile {
    param (
        [string]$LogPath
    )

    if (Test-Path $LogPath) {
        # Check if the last log file exists and delete it if it does
        $lastLog = Join-Path $scriptLogPath -ChildPath "$scriptName.10.log"
        if (Test-Path $lastLog) {
            Remove-Item $lastLog -Force
        }

        # Rename existing log files
        for ($i = 9; $i -ge 1; $i--) {
            $prevLog = Join-Path $scriptLogPath -ChildPath "$scriptName.$('{0:d2}' -f $i).log"
            $newLog = Join-Path $scriptLogPath -ChildPath "$scriptName.$('{0:d2}' -f ($i+1)).log"
            if (Test-Path $prevLog) {
                Rename-Item $prevLog -NewName $newLog -Force
            }
        }

        # Rename current log file
        $newLog = Join-Path $scriptLogPath -ChildPath "$scriptName.01.log"
        Rename-Item $LogPath -NewName $newLog -Force
    }
}

################################################################################
# Function: InstallFontsIfNeeded
# Description: Determines if font is installed and if not, exits script
################################################################################
Function InstallFontsIfNeeded {
    $fontNames = @(
        "Comfortaa-Medium", 
        "Bebas-Regular",
        "Rye-Regular", 
        "Limelight-Regular", 
        "BoecklinsUniverse", 
        "UnifrakturCook", 
        "Trochut", 
        "Righteous", 
        "Yesteryear", 
        "Cherry-Cream-Soda-Regular", 
        "Boogaloo-Regular", 
        "Monoton", 
        "Press-Start-2P", 
        "Jura-Bold", 
        "Special-Elite-Regular", 
        "Barlow-Regular", 
        "Helvetica-Bold"
    )
    $missingFonts = $fontNames | Where-Object { !(magick identify -list font | Select-String "Font: $_$") }
    
    if ($missingFonts) {
        $fontList = magick identify -list font | Select-String "Font: " | ForEach-Object { $_.ToString().Trim().Substring(6) }
        $fontList | Out-File -Encoding utf8 -FilePath "magick_fonts.txt"
        WriteToLogFile "Fonts Check [ERROR]          : Fonts missing $($missingFonts -join ', ') are not installed/found. List of installed fonts that Imagemagick can use listed and exported here: magick_fonts.txt."
        WriteToLogFile "Fonts Check [ERROR]          : $($fontList.Count) fonts are visible to Imagemagick."
        WriteToLogFile "Fonts Check [ERROR]          : Please right-click 'Install for all users' on each font file in the $script_path\fonts folder before retrying."
        return $false
    }
    return $true
}

################################################################################
# Function: Remove-Folders
# Description: Removes folders to start fresh run
################################################################################
Function Remove-Folders {
    $folders = "aspect", "audio_language", "award", "based", "chart", "content_rating", "country",
    "decade", "defaults-$LanguageCode", "franchise", "genre", "network", "playlist", "resolution",
    "seasonal", "separators", "streaming", "studio", "subtitle_language",
    "translations", "universe", "video_format", "year"
    
    foreach ($folder in $folders) {
        $path = Join-Path $script_path $folder
        Remove-Item $path -Force -Recurse -ErrorAction SilentlyContinue
    }
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
# Function: Compare-FileChecksum
# Description: validates checksum of files
################################################################################
Function Compare-FileChecksum {
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

    $output = [PSCustomObject]@{
        Path             = $Path
        ExpectedChecksum = $ExpectedChecksum
        ActualChecksum   = $actualChecksum
        Status           = $status
        failFlag         = $failFlag
    }

    $status = if ($actualChecksum -eq $ExpectedChecksum) {
        "Success"
        WriteToLogFile "Checksum verification        : Success for file $($output.Path). Expected checksum: $($output.ExpectedChecksum), actual checksum: $($output.ActualChecksum)."
    }
    else {
        $failFlag.Value = $true
        "Failed"
        WriteToLogFile "Checksum verification [ERROR]: Failed for file $($output.Path). Expected checksum: $($output.ExpectedChecksum), actual checksum: $($output.ActualChecksum)."
    }

    return $output
}

################################################################################
# Function: Get-TranslationFile
# Description: gets the language yml file from github
################################################################################
Function Get-TranslationFile {
    param(
        [string]$LanguageCode,
        [string]$BranchOption = "nightly"
    )

    $BranchOptions = @("master", "develop", "nightly")
    if ($BranchOptions -notcontains $BranchOption) {
        Write-Error "Error: Invalid branch option."
        return
    }

    # $GitHubRepository = "https://raw.githubusercontent.com/Kometa-Team/Kometa/$BranchOption/defaults/translations"
    $GitHubRepository = "https://raw.githubusercontent.com/Kometa-Team/Translations/master/defaults"
	$TranslationFile = "$LanguageCode.yml"
    $TranslationFileUrl = "$GitHubRepository/$TranslationFile"
    $TranslationsPath = Join-Path $script_path "@translations"
    $TranslationFilePath = Join-Path $TranslationsPath $TranslationFile

    Find-Path $TranslationsPath

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
# Function: Read-Yaml
# Description: read in yaml file for use
################################################################################
Function Read-Yaml {
    $global:Config = Get-Content $TranslationFilePath -Raw
    $global:ConfigObj = $global:Config | ConvertFrom-Yaml
}

################################################################################
# Function: Get-YamlPropertyValue
# Description: searches the yaml
################################################################################
Function Get-YamlPropertyValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$PropertyPath,
        
        [Parameter(Mandatory = $true)]
        [object]$ConfigObject,
        
        [Parameter()]
        [ValidateSet("Exact", "Upper", "Lower")]
        [string]$CaseSensitivity = "Exact"
    )
    
    $value = $ConfigObject
    foreach ($path in $PropertyPath.Split(".")) {
        if ($value.ContainsKey($path)) {
            $value = $value.$path
        }
        else {
            Write-Output "TRANSLATION NOT FOUND"
            WriteToLogFile "TranslatedValue [ERROR]      : ${path}: TRANSLATION NOT FOUND in $TranslationFilePath"
            return
        }
    }
    
    switch ($CaseSensitivity) {
        "Exact" { break }
        "Upper" { $value = $value.ToUpper() }
        "Lower" { $value = $value.ToLower() }
    }
    WriteToLogFile "TranslatedValue              : ${path}: $value in $TranslationFilePath"
    return $value
}

################################################################################
# Function: Set-TextBetweenDelimiters
# Description: replaces <<something>> with a string
################################################################################
Function Set-TextBetweenDelimiters {
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
# Function: New-SqliteTable
# Description: Function to create a new SQLite table
################################################################################
Function New-SqliteTable {
    param(
        [string]$Database,
        [string]$Table,
        [string[]]$Columns,
        [string]$PrimaryKey
    )

    # Construct CREATE TABLE statement
    $sql = "CREATE TABLE IF NOT EXISTS $Table ("

    # Add column definitions
    foreach ($column in $Columns) {
        $sql += "$column, "
    }

    # Add primary key definition
    if ($PrimaryKey) {
        $sql += "PRIMARY KEY ($PrimaryKey)"
    }
    else {
        $sql = $sql.TrimEnd(", ")
    }

    $sql += ")"

    # Create table in database
    $connection = New-Object System.Data.SQLite.SQLiteConnection "Data Source=$Database"
    $connection.Open()

    $command = $connection.CreateCommand()
    $command.CommandText = $sql
    $command.ExecuteNonQuery()

    $connection.Close()
}

################################################################################
# Function: Get-SqliteData
# Description: Function to get data from a SQLite database
################################################################################
Function Get-SqliteData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    $connection = New-Object System.Data.SQLite.SQLiteConnection
    $connection.ConnectionString = "Data Source=$Path"

    try {
        $connection.Open()
        $command = New-Object System.Data.SQLite.SQLiteCommand($Query, $connection)
        $result = $command.ExecuteScalar()
        return $result
    }
    catch {
        throw $_
    }
    finally {
        $connection.Close()
    }
}

################################################################################
# Function: Set-SqliteData
# Description: Function to set data in a SQLite database
################################################################################
Function Set-SqliteData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    $connection = New-Object System.Data.SQLite.SQLiteConnection
    $connection.ConnectionString = "Data Source=$Path"

    try {
        $connection.Open()
        $command = New-Object System.Data.SQLite.SQLiteCommand($Query, $connection)
        $command.ExecuteNonQuery()
    }
    catch {
        throw $_
    }
    finally {
        $connection.Close()
    }
}

################################################################################
# Function: Get-OptimalPointSize
# Description: Gets the optimal pointsize for a phrase
################################################################################
Function Get-OptimalPointSize {
    param(
        [string]$text,
        [string]$font,
        [int]$box_width,
        [int]$box_height,
        [int]$min_pointsize,
        [int]$max_pointsize
    )

    # Create SQLite cache table if it doesn't exist
    if (-not (Test-Path $databasePath)) {
        $null = New-SqliteTable -Path $databasePath -Table 'Cache' -Columns 'CacheKey', 'PointSize'
    }

    # Generate cache key
    $cache_key = "{0}-{1}-{2}-{3}-{4}-{5}" -f $text, $font, $box_width, $box_height, $min_pointsize, $max_pointsize

    if ($IsWindows) {
        # Windows-specific escape characters
        $escaped_cache_key = [System.Management.Automation.WildcardPattern]::Escape($cache_key)

        # Escape single quotes (')
        $escaped_cache_key = $escaped_cache_key -replace "'", "''"
    }
    else {
        # Unix-specific escape characters (No clue what to put here)
        $escaped_cache_key = $escaped_cache_key -replace "'", "''"
    }

    # Check if cache contains the key and return cached result if available
    $cached_pointsize = (Get-SqliteData -Path $databasePath -Query "SELECT PointSize FROM Cache WHERE CacheKey = '$escaped_cache_key'")
    if ($null -ne $cached_pointsize) {
        WriteToLogFile "Cache                        : Cache hit for key '$cache_key'"
        return $cached_pointsize
    }

    # Prepare command to get optimal point size
    # Escape special characters
    if ($IsWindows) {
        # Windows-specific escape characters
        $escaped_text = [System.Management.Automation.WildcardPattern]::Escape($text)
        $escaped_font = [System.Management.Automation.WildcardPattern]::Escape($font)

        # Escape single quotes (')
        $escaped_text = $escaped_text -replace "'", "''"
        $escaped_font = $escaped_font -replace "'", "''"
    }
    else {
        # Unix-specific escape characters (No clue what to put here)
        $escaped_text = $escaped_text -replace "'", "''"
        $escaped_font = $escaped_font -replace "'", "''"
    }

    $cmd = "magick -size ${box_width}x${box_height} -font `"$escaped_font`" -gravity center -fill black caption:`'$escaped_text`' -format `"%[caption:pointsize]`" info:"
    WriteToLogFile "cmd for optimal size         : $cmd"

    # Execute command and get point size
    $current_pointsize = [int](Invoke-Expression $cmd | Out-String).Trim()
    WriteToLogFile "Caption point size           : $current_pointsize"

    # Apply point size limits
    if ($current_pointsize -gt $max_pointsize) {
        WriteToLogFile "Optimal Point Size           : Font size limit reached"
        $current_pointsize = $max_pointsize
    }
    elseif ($current_pointsize -lt $min_pointsize) {
        WriteToLogFile "Optimal Point Size [ERROR]   : Text is too small and will be truncated"
        $current_pointsize = $min_pointsize
    }

    # Update cache with new result
    $null = Set-SqliteData -Path $databasePath -Query "INSERT OR REPLACE INTO Cache (CacheKey, PointSize) VALUES ('$escaped_cache_key', $current_pointsize)"
    WriteToLogFile "Optimal Point Size           : $current_pointsize"

    # Return optimal point size
    return $current_pointsize
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
            # Check exit code
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
    # $defaultsPath = Join-Path $script_path -ChildPath "defaults"

    $foldersToMove = @(
        "aspect"
        "audio_language"
        "award"
        "based"
        "chart"
        "content_rating"
        "country"
        "decade"
        "franchise"
        "genre"
        "network"
        "resolution"
        "playlist"
        "seasonal"
        "separators"
        "streaming"
        "studio"
        "subtitle_language"
        "universe"
        "video_format"
        "year"
    )

    $filesToMove = @(
        "collectionless.jpg"
    )

    foreach ($folder in $foldersToMove) {
        Move-Item -Path (Join-Path $script_path -ChildPath $folder) -Destination $DefaultsPath -Force -ErrorAction SilentlyContinue
    }

    foreach ($file in $filesToMove) {
        Move-Item -Path (Join-Path $script_path -ChildPath $file) -Destination $DefaultsPath -Force -ErrorAction SilentlyContinue
    }
}

################################################################################
# Function: CreateAspect
# Description:  Creates aspect ratio posters
################################################################################
Function CreateAspect {
    Write-Host "Creating Aspect"
    Set-Location $script_path
    # Find-Path "$script_path\aspect"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'aspect_ratio_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| 1.33.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1.33| #93B69F| 1| 1| 0| 1',
        '| 1.65.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1.65| #FB0AA1| 1| 1| 0| 1',
        '| 1.66.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1.66| #FFA500| 1| 1| 0| 1',
        '| 1.78.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1.78| #B96EE9| 1| 1| 0| 1',
        '| 1.85.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1.85| #43F6EF| 1| 1| 0| 1',
        '| 2.2.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 2.2| #133CD8| 1| 1| 0| 1',
        '| 2.35.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 2.35| #0B8D4E| 1| 1| 0| 1',
        '| 2.77.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 2.77| #8890C8| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_aspect\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination aspect
    Copy-Item -Path logos_aspect -Destination aspect\logos -Recurse
    Move-Item -Path output-orig -Destination output
    
}


################################################################################
# Function: CreateAudioLanguage
# Description:  Creates audio language
################################################################################
Function CreateAudioLanguage {
    Write-Host "Creating Audio Language"
    Set-Location $script_path
    # Find-Path "$script_path\audio_language"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'audio_language_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $pre_value = Get-YamlPropertyValue -PropertyPath "collections.audio_language.name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'ABKHAZIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ab| #88F678| 1| 1| 0| 1',
        'AFAR| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | aa| #612A1C| 1| 1| 0| 1',
        'AFRIKAANS| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | af| #60EC40| 1| 1| 0| 1',
        'AKAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ak| #021FBC| 1| 1| 0| 1',
        'ALBANIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sq| #C5F277| 1| 1| 0| 1',
        'AMHARIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | am| #746BC8| 1| 1| 0| 1',
        'ARABIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ar| #37C768| 1| 1| 0| 1',
        'ARAGONESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | an| #4619FD| 1| 1| 0| 1',
        'ARMENIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hy| #5F26E3| 1| 1| 0| 1',
        'ASSAMESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | as| #615C3B| 1| 1| 0| 1',
        'AVARIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | av| #2BCE4A| 1| 1| 0| 1',
        'AVESTAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ae| #CF6EEA| 1| 1| 0| 1',
        'AYMARA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ay| #3D5D3B| 1| 1| 0| 1',
        'AZERBAIJANI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | az| #A48C7A| 1| 1| 0| 1',
        'BAMBARA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bm| #C12E3D| 1| 1| 0| 1',
        'BASHKIR| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ba| #ECD14A| 1| 1| 0| 1',
        'BASQUE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | eu| #89679F| 1| 1| 0| 1',
        'BELARUSIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | be| #1050B0| 1| 1| 0| 1',
        'BENGALI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bn| #EA4C42| 1| 1| 0| 1',
        'BISLAMA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bi| #C39A37| 1| 1| 0| 1',
        'BOSNIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bs| #7DE3FE| 1| 1| 0| 1',
        'BRETON| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | br| #7E1A72| 1| 1| 0| 1',
        'BULGARIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bg| #D5442A| 1| 1| 0| 1',
        'BURMESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | my| #9E5CF0| 1| 1| 0| 1',
        'CATALAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ca| #99BC95| 1| 1| 0| 1',
        'CENTRAL_KHMER| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | km| #6ABDD6| 1| 1| 0| 1',
        'CHAMORRO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ch| #22302F| 1| 1| 0| 1',
        'CHECHEN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ce| #83E832| 1| 1| 0| 1',
        'CHICHEWA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ny| #03E31C| 1| 1| 0| 1',
        'CHINESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | zh| #40EA69| 1| 1| 0| 1',
        'CHURCH_SLAVIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cu| #C76DC2| 1| 1| 0| 1',
        'CHUVASH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cv| #920F92| 1| 1| 0| 1',
        'CORNISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kw| #55137D| 1| 1| 0| 1',
        'CORSICAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | co| #C605DC| 1| 1| 0| 1',
        'CREE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cr| #75D7F3| 1| 1| 0| 1',
        'CROATIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hr| #AB48D3| 1| 1| 0| 1',
        'CZECH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cs| #7804BB| 1| 1| 0| 1',
        'DANISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | da| #87A5BE| 1| 1| 0| 1',
        'DIVEHI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | dv| #FA57EC| 1| 1| 0| 1',
        'DUTCH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nl| #74352E| 1| 1| 0| 1',
        'DZONGKHA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | dz| #F7C931| 1| 1| 0| 1',
        'ENGLISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | en| #DD4A2F| 1| 1| 0| 1',
        'ESPERANTO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | eo| #B65ADE| 1| 1| 0| 1',
        'ESTONIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | et| #AF1569| 1| 1| 0| 1',
        'EWE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ee| #2B7E43| 1| 1| 0| 1',
        'FAROESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fo| #507CCC| 1| 1| 0| 1',
        'FIJIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fj| #7083F9| 1| 1| 0| 1',
        'FILIPINO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fil| #8BEF80| 1| 1| 0| 1',
        'FINNISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fi| #9229A6| 1| 1| 0| 1',
        'FRENCH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fr| #4111A0| 1| 1| 0| 1',
        'FULAH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ff| #649BA7| 1| 1| 0| 1',
        'GAELIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gd| #FBFEC1| 1| 1| 0| 1',
        'GALICIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gl| #DB6769| 1| 1| 0| 1',
        'GANDA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lg| #C71A50| 1| 1| 0| 1',
        'GEORGIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ka| #8517C8| 1| 1| 0| 1',
        'GERMAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | de| #4F5FDC| 1| 1| 0| 1',
        'GREEK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | el| #49B49A| 1| 1| 0| 1',
        'GUARANI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gn| #EDB51C| 1| 1| 0| 1',
        'GUJARATI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gu| #BDF7FF| 1| 1| 0| 1',
        'HAITIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ht| #466EB6| 1| 1| 0| 1',
        'HAUSA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ha| #A949D2| 1| 1| 0| 1',
        'HEBREW| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | he| #E9C58A| 1| 1| 0| 1',
        'HERERO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hz| #E9DF57| 1| 1| 0| 1',
        'HINDI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hi| #77775B| 1| 1| 0| 1',
        'HIRI_MOTU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ho| #3BB41B| 1| 1| 0| 1',
        'HUNGARIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hu| #111457| 1| 1| 0| 1',
        'ICELANDIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | is| #0ACE8F| 1| 1| 0| 1',
        'IDO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | io| #75CA6C| 1| 1| 0| 1',
        'IGBO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ig| #757EDE| 1| 1| 0| 1',
        'INDONESIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | id| #52E822| 1| 1| 0| 1',
        'INTERLINGUA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ia| #7F9248| 1| 1| 0| 1',
        'INTERLINGUE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ie| #8F802C| 1| 1| 0| 1',
        'INUKTITUT| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | iu| #43C3B0| 1| 1| 0| 1',
        'INUPIAQ| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ik| #ECF371| 1| 1| 0| 1',
        'IRISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ga| #FB7078| 1| 1| 0| 1',
        'ITALIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | it| #95B5DF| 1| 1| 0| 1',
        'JAPANESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ja| #5D776B| 1| 1| 0| 1',
        'JAVANESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | jv| #5014C5| 1| 1| 0| 1',
        'KALAALLISUT| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kl| #050CF3| 1| 1| 0| 1',
        'KANNADA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kn| #440B43| 1| 1| 0| 1',
        'KANURI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kr| #4F2AAC| 1| 1| 0| 1',
        'KASHMIRI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ks| #842C02| 1| 1| 0| 1',
        'KAZAKH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kk| #665F3D| 1| 1| 0| 1',
        'KIKUYU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ki| #315679| 1| 1| 0| 1',
        'KINYARWANDA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rw| #CE1391| 1| 1| 0| 1',
        'KIRGHIZ| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ky| #5F0D23| 1| 1| 0| 1',
        'KOMI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kv| #9B06C3| 1| 1| 0| 1',
        'KONGO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kg| #74BC47| 1| 1| 0| 1',
        'KOREAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ko| #F5C630| 1| 1| 0| 1',
        'KUANYAMA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kj| #D8CB60| 1| 1| 0| 1',
        'KURDISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ku| #467330| 1| 1| 0| 1',
        'LAOS| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lo| #DD3B78| 1| 1| 0| 1',
        'LATIN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | la| #A73376| 1| 1| 0| 1',
        'LATVIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lv| #A65EC1| 1| 1| 0| 1',
        'LIMBURGAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | li| #13C252| 1| 1| 0| 1',
        'LINGALA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ln| #BBEE5B| 1| 1| 0| 1',
        'LITHUANIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lt| #E89C3E| 1| 1| 0| 1',
        'LUBA-KATANGA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lu| #4E97F3| 1| 1| 0| 1',
        'LUXEMBOURGISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lb| #4738EE| 1| 1| 0| 1',
        'MACEDONIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mk| #B69974| 1| 1| 0| 1',
        'MALAGASY| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mg| #29D850| 1| 1| 0| 1',
        'MALAY| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ms| #A74139| 1| 1| 0| 1',
        'MALAYALAM| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ml| #FD4C87| 1| 1| 0| 1',
        'MALTESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mt| #D6EE0B| 1| 1| 0| 1',
        'MANX| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gv| #3F83E9| 1| 1| 0| 1',
        'MAORI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mi| #8339FD| 1| 1| 0| 1',
        'MARATHI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mr| #93DEF1| 1| 1| 0| 1',
        'MARSHALLESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mh| #11DB75| 1| 1| 0| 1',
        'MAYAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | myn| #7F41FB| 1| 1| 0| 1',
        'MONGOLIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mn| #A107D9| 1| 1| 0| 1',
        'NAURU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | na| #7A0925| 1| 1| 0| 1',
        'NAVAJO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nv| #48F865| 1| 1| 0| 1',
        'NDONGA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ng| #83538B| 1| 1| 0| 1',
        'NEPALI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ne| #5A15FC| 1| 1| 0| 1',
        'NORTH_NDEBELE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nd| #A1533B| 1| 1| 0| 1',
        'NORTHERN_SAMI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | se| #AAD61B| 1| 1| 0| 1',
        'NORWEGIAN_BOKMÅL| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nb| #0AEB4A| 1| 1| 0| 1',
        'NORWEGIAN_NYNORSK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nn| #278B62| 1| 1| 0| 1',
        'NORWEGIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | no| #13FF63| 1| 1| 0| 1',
        'OCCITAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | oc| #B5B607| 1| 1| 0| 1',
        'OJIBWA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | oj| #100894| 1| 1| 0| 1',
        'ORIYA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | or| #0198FF| 1| 1| 0| 1',
        'OROMO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | om| #351BD8| 1| 1| 0| 1',
        'OSSETIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | os| #BF715E| 1| 1| 0| 1',
        'PALI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | pi| #BEB3FA| 1| 1| 0| 1',
        'PASHTO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ps| #A4236C| 1| 1| 0| 1',
        'PERSIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fa| #68A38E| 1| 1| 0| 1',
        'POLISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | pl| #D4F797| 1| 1| 0| 1',
        'PORTUGUESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | pt| #71D659| 1| 1| 0| 1',
        'PUNJABI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | pa| #14F788| 1| 1| 0| 1',
        'QUECHUA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | qu| #268110| 1| 1| 0| 1',
        'ROMANIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ro| #06603F| 1| 1| 0| 1',
        'ROMANSH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rm| #3A73F3| 1| 1| 0| 1',
        'ROMANY| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rom| #790322| 1| 1| 0| 1',
        'RUNDI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rn| #715E84| 1| 1| 0| 1',
        'RUSSIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ru| #DB77DA| 1| 1| 0| 1',
        'SAMOAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sm| #A26738| 1| 1| 0| 1',
        'SANGO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sg| #CA1C7E| 1| 1| 0| 1',
        'SANSKRIT| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sa| #CF9C76| 1| 1| 0| 1',
        'SARDINIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sc| #28AF67| 1| 1| 0| 1',
        'SERBIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sr| #FB3F2C| 1| 1| 0| 1',
        'SHONA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sn| #40F3EC| 1| 1| 0| 1',
        'SICHUAN_YI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ii| #FA3474| 1| 1| 0| 1',
        'SINDHI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sd| #62D1BE| 1| 1| 0| 1',
        'SINHALA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | si| #24787A| 1| 1| 0| 1',
        'SLOVAK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sk| #66104F| 1| 1| 0| 1',
        'SLOVENIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sl| #6F79E6| 1| 1| 0| 1',
        'SOMALI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | so| #A36185| 1| 1| 0| 1',
        'SOUTH_NDEBELE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nr| #8090E5| 1| 1| 0| 1',
        'SOUTHERN_SOTHO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | st| #4C3417| 1| 1| 0| 1',
        'SPANISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | es| #7842AE| 1| 1| 0| 1',
        'SUNDANESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | su| #B2D05B| 1| 1| 0| 1',
        'SWAHILI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sw| #D32F20| 1| 1| 0| 1',
        'SWATI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ss| #AA196D| 1| 1| 0| 1',
        'SWEDISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sv| #0EC5A2| 1| 1| 0| 1',
        'TAGALOG| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tl| #C9DDAC| 1| 1| 0| 1',
        'TAHITIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ty| #32009D| 1| 1| 0| 1',
        'TAI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tai| #2AB44C| 1| 1| 0| 1',
        'TAJIK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tg| #100ECF| 1| 1| 0| 1',
        'TAMIL| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ta| #E71FAE| 1| 1| 0| 1',
        'TATAR| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tt| #C17483| 1| 1| 0| 1',
        'TELUGU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | te| #E34ABD| 1| 1| 0| 1',
        'THAI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | th| #3FB501| 1| 1| 0| 1',
        'TIBETAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bo| #FF2496| 1| 1| 0| 1',
        'TIGRINYA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ti| #9074F0| 1| 1| 0| 1',
        'TONGA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | to| #B3259E| 1| 1| 0| 1',
        'TSONGA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ts| #12687C| 1| 1| 0| 1',
        'TSWANA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tn| #DA3E89| 1| 1| 0| 1',
        'TURKISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tr| #A08D29| 1| 1| 0| 1',
        'TURKMEN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tk| #E70267| 1| 1| 0| 1',
        'TWI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tw| #8A6C0F| 1| 1| 0| 1',
        'UIGHUR| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ug| #79BC21| 1| 1| 0| 1',
        'UKRAINIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | uk| #EB60E9| 1| 1| 0| 1',
        'URDU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ur| #57E09D| 1| 1| 0| 1',
        'UZBEK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | uz| #4341F3| 1| 1| 0| 1',
        'VENDA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ve| #4780ED| 1| 1| 0| 1',
        'VIETNAMESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vi| #90A301| 1| 1| 0| 1',
        'VOLAPÜK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vo| #77D574| 1| 1| 0| 1',
        'WALLOON| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | wa| #BD440A| 1| 1| 0| 1',
        'WELSH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cy| #45E39C| 1| 1| 0| 1',
        'WESTERN_FRISIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fy| #01F471| 1| 1| 0| 1',
        'WOLOF| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | wo| #BDD498| 1| 1| 0| 1',
        'XHOSA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | xh| #0C6D9C| 1| 1| 0| 1',
        'YIDDISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | yi| #111D14| 1| 1| 0| 1',
        'YORUBA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | yo| #E815FF| 1| 1| 0| 1',
        'ZHUANG| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | za| #C62A89| 1| 1| 0| 1',
        'ZULU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | zu| #0049F8| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = Set-TextBetweenDelimiters -InputString $pre_value -ReplacementString (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
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
    Find-Path "$script_path\award"
    WriteToLogFile "ImageMagick Commands for     : Awards"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    ########################
    # PCA #B26AAA
    ########################
    WriteToLogFile "ImageMagick Commands for     : PCA"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #B26AAA| 1| 1| 0| 1',
        'NOMINATIONS| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #B26AAA| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #B26AAA| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #B26AAA| 1| 1| 0| 1',
        '| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PCA| #B26AAA| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #B26AAA| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1975; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\pca

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #B26AAA| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1975; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\pca\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #B26AAA| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1975; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\pca\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| PCA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #B26AAA| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1975; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\pca\best

    ########################
    # NFR #D32864
    ########################
    WriteToLogFile "ImageMagick Commands for     : NFR"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        # 'WINNERS| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D32864| 1| 1| 0| 1',
        # 'NOMINATIONS| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #D32864| 1| 1| 0| 1',
        # 'BEST_DIRECTOR_WINNERS| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #D32864| 1| 1| 0| 1',
        # 'BEST_PICTURE_WINNERS| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #D32864| 1| 1| 0| 1',
        'ALL_TIME| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | all_time| #D32864| 1| 1| 0| 1',
        '| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NFR| #D32864| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D32864| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1989; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\nfr

    # $myArray = @(
    #     'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
    #     'WINNERS| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D32864| 1| 1| 0| 1'
    # ) | ConvertFrom-Csv -Delimiter '|'

    # $arr = @()
    # foreach ($item in $myArray) {
    #     for ($i = 1989; $i -lt 2030; $i++) {
    #         $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    #         $value = "$value $i"
    #         $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    #         $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    #     }
    # }
    # LaunchScripts -ScriptPaths $arr
    # Move-Item -Path output -Destination award\nfr\winner

    # $myArray = @(
    #     'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
    #     'NOMINATIONS| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #D32864| 1| 1| 0| 1'
    # ) | ConvertFrom-Csv -Delimiter '|'

    # $arr = @()
    # foreach ($item in $myArray) {
    #     for ($i = 1989; $i -lt 2030; $i++) {
    #         $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    #         $value = "$value $i"
    #         $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    #         $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    #     }
    # }
    # LaunchScripts -ScriptPaths $arr
    # Move-Item -Path output -Destination award\nfr\nomination

    # $myArray = @(
    #     'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
    #     'BEST_PICTURE_WINNER| NFR.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D32864| 1| 1| 0| 1'
    # ) | ConvertFrom-Csv -Delimiter '|'

    # $arr = @()
    # foreach ($item in $myArray) {
    #     for ($i = 1989; $i -lt 2030; $i++) {
    #         $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    #         $value = "$value $i"
    #         $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    #         $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    #     }
    # }
    # LaunchScripts -ScriptPaths $arr
    # Move-Item -Path output -Destination award\nfr\best

    ########################
    # SAG #6E889A
    ########################
    WriteToLogFile "ImageMagick Commands for     : SAG"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #6E889A| 1| 1| 0| 1',
        'NOMINATIONS| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #6E889A| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #6E889A| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #6E889A| 1| 1| 0| 1',
        '| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SAG| #6E889A| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #6E889A| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1963; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sag

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #6E889A| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1963; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sag\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #6E889A| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1963; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sag\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| SAG.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #6E889A| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1963; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sag\best

    ########################
    # TIFF #F36F21
    ########################
    WriteToLogFile "ImageMagick Commands for     : TIFF"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #F36F21| 1| 1| 0| 1',
        'NOMINATIONS| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #F36F21| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #F36F21| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #F36F21| 1| 1| 0| 1',
        '| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tiff| #F36F21| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #F36F21| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\tiff

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #F36F21| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\tiff\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #F36F21| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\tiff\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| tiff.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #F36F21| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\tiff\best

    ########################
    # BAFTA #9C7C26
    ########################
    WriteToLogFile "ImageMagick Commands for     : BAFTA"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #9C7C26| 1| 1| 0| 1',
        'NOMINATIONS| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #9C7C26| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #9C7C26| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #9C7C26| 1| 1| 0| 1',
        '| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BAFTA| #9C7C26| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #9C7C26| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\bafta

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #9C7C26| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\bafta\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #9C7C26| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\bafta\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| BAFTA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #9C7C26| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\bafta\best

    # ########################
    # # Berlinale #BB0B34
    # ########################
    WriteToLogFile "ImageMagick Commands for     : Berlinale"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #BB0B34| 1| 1| 0| 1',
        'NOMINATIONS| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #BB0B34| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #BB0B34| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #BB0B34| 1| 1| 0| 1',
        '| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Berlinale| #BB0B34| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #BB0B34| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1951; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\berlinale

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #BB0B34| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1951; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\berlinale\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #BB0B34| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1951; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\berlinale\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Berlinale.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #BB0B34| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1951; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\berlinale\best

    ########################
    # Cannes #AF8F51
    ########################
    WriteToLogFile "ImageMagick Commands for     : Cannes"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #AF8F51| 1| 1| 0| 1',
        'NOMINATIONS| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #AF8F51| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #AF8F51| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #AF8F51| 1| 1| 0| 1',
        '| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cannes| #AF8F51| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #AF8F51| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1938; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cannes

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #AF8F51| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1938; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cannes\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #AF8F51| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1938; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cannes\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Cannes.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #AF8F51| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1938; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cannes\best

    ########################
    # Cesar #E2A845
    ########################
    WriteToLogFile "ImageMagick Commands for     : Cesar"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #E2A845| 1| 1| 0| 1',
        'NOMINATIONS| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #E2A845| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #E2A845| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #E2A845| 1| 1| 0| 1',
        '| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cesar| #E2A845| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #E2A845| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1976; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cesar

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #E2A845| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1976; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cesar\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #E2A845| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1976; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cesar\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Cesar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #E2A845| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1976; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cesar\best

    ########################
    # Choice #AC7427
    ########################
    WriteToLogFile "ImageMagick Commands for     : Choice"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #AC7427| 1| 1| 0| 1',
        'NOMINATIONS| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #AC7427| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #AC7427| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #AC7427| 1| 1| 0| 1',
        '| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Choice| #AC7427| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    $i = "2016-2"
    $value = $i
    $item.out_name = $i
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #AC7427| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1929; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "2016-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = $i
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\choice

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #AC7427| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1929; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "2016-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\choice\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #AC7427| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1929; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "2016-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\choice\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Choice.png| -500| 600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #AC7427| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1929; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "2016-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\choice\best

    ########################
    # Emmys #D89C27
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Emmys-Winner"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D89C27| 1| 1| 0| 1',
        'NOMINATIONS| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #D89C27| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #D89C27| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #D89C27| 1| 1| 0| 1',
        '| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Emmys| #D89C27| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D89C27| 1| 1| 0| 1'
        # 'Logo| logo_resize| Name| out_name| base_color| ww',
        # 'Emmys.png| 1500| WINNERS| winner| #D89C27| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\emmys

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D89C27| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\emmys\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #D89C27| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\emmys\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Emmys.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D89C27| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\emmys\best

    ########################
    # Golden #D0A047
    ########################
    WriteToLogFile "ImageMagick Commands for     : Golden"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D0A047| 1| 1| 0| 1',
        'NOMINATIONS| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #D0A047| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #D0A047| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #D0A047| 1| 1| 0| 1',
        '| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Golden| #D0A047| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D0A047| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1943; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\golden

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D0A047| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1943; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\golden\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #D0A047| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1943; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\golden\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Golden.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D0A047| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1943; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
            # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$value`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\golden\best

    ########################
    # Oscars #A9842E
    ########################
    WriteToLogFile "ImageMagick Commands for     : Oscars"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #A9842E| 1| 1| 0| 1',
        'NOMINATIONS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #A9842E| 1| 1| 0| 1',
        'BEST_ANIMATED_FEATURE_FILM_NOMINATION| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_animated_feature_film_nomination| #A9842E| 1| 1| 0| 1',
        'BEST_ANIMATED_FEATURE_FILM_WINNERS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_animated_feature_film_winner| #A9842E| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #A9842E| 1| 1| 0| 1',
        'BEST_LIVE_ACTION_SHORT_FILM_NOMINATION| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_live_action_short_film_nomination| #A9842E| 1| 1| 0| 1',
        'BEST_LIVE_ACTION_SHORT_FILM_WINNERS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_live_action_short_film_winner| #A9842E| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #A9842E| 1| 1| 0| 1',
        'BEST_DIRECTOR_NOMINATION| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_nomination| #A9842E| 1| 1| 0| 1',
        'BEST_PICTURE_NOMINATION| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_nomination| #A9842E| 1| 1| 0| 1',
        '| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Oscars| #A9842E| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    $i = "1930-2"
    $value = $i
    $item.out_name = $i
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #A9842E| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "1930-2"
    $value = $i
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_DIRECTOR_NOMINATION| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_nomination| #A9842E| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
            # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$value`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    $i = "1930-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\director_nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_NOMINATION| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_nomination| #A9842E| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
            # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$value`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    $i = "1930-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\picture_nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #A9842E| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "1930-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #A9842E| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "1930-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\best

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #A9842E| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "1930-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_DIRECTOR_WINNERS| Oscars.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #A9842E| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    $i = "1930-2"
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $value = "$value $i"
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\best_director

    ########################
    # Razzie #FF0C0C
    ########################
    WriteToLogFile "ImageMagick Commands for     : Razzie"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #FF0C0C| 1| 1| 0| 1',
        'NOMINATIONS| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #FF0C0C| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #FF0C0C| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #FF0C0C| 1| 1| 0| 1',
        '| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Razzie| #FF0C0C| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #FF0C0C| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1980; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzie

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #FF0C0C| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1980; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzie\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #FF0C0C| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1980; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzie\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Razzie.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #FF0C0C| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1980; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzie\best

    ########################
    # Spirit #4662E7
    ########################
    WriteToLogFile "ImageMagick Commands for     : Spirit"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #4662E7| 1| 1| 0| 1',
        'NOMINATIONS| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #4662E7| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #4662E7| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #4662E7| 1| 1| 0| 1',
        '| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spirit| #4662E7| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #4662E7| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1986; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\spirit

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #4662E7| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1986; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\spirit\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #4662E7| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1986; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\spirit\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Spirit.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #4662E7| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1986; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\spirit\best

    ########################
    # Sundance #7EB2CF
    ########################
    WriteToLogFile "ImageMagick Commands for     : Sundance"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #7EB2CF| 1| 1| 0| 1',
        'NOMINATIONS| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #7EB2CF| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #7EB2CF| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #7EB2CF| 1| 1| 0| 1',
        'GRAND_JURY_WINNERS| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | grand_jury_winner| #7EB2CF| 1| 1| 0| 1',
        '| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sundance| #7EB2CF| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #7EB2CF| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sundance

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #7EB2CF| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
            # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$value`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sundance\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #7EB2CF| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sundance\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Sundance.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #7EB2CF| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sundance\best

    ########################
    # Venice #D21635
    ########################
    WriteToLogFile "ImageMagick Commands for     : Venice"
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D21635| 1| 1| 0| 1',
        'NOMINATIONS| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #D21635| 1| 1| 0| 1',
        'BEST_DIRECTOR_WINNERS| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_director_winner| #D21635| 1| 1| 0| 1',
        'BEST_PICTURE_WINNERS| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | best_picture_winner| #D21635| 1| 1| 0| 1',
        '| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Venice| #D21635| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D21635| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1932; $i -lt 2030; $i++) {
            $value = $i
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\venice

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'WINNERS| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D21635| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1932; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\venice\winner

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'NOMINATIONS| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nomination| #D21635| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1932; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
            # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$value`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\venice\nomination

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'BEST_PICTURE_WINNER| Venice.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | winner| #D21635| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1932; $i -lt 2030; $i++) {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
            $value = "$value $i"
            $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\venice\best

    Copy-Item -Path logos_award -Destination award\logos -Recurse
    Move-Item -Path output-orig -Destination output

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
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        # 'best_of_britain| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Best of Britain| #7335B5| 1| 1| 0| 1',
        # 'based_on_books_and_games| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Based on Books and Games| #7335B5| 1| 1| 0| 1',
        # 'heroes_and_wizards| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Heroes and Wizards| #7335B5| 1| 1| 0| 1',
        # 'throwback_thursday| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Throwback Thursday| #7335B5| 1| 1| 0| 1',
        # 'the_justice_system| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Nustice System| #7335B5| 1| 1| 0| 1',
        # 'family_favourites| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Family Favourites| #7335B5| 1| 1| 0| 1',
        # 'mystery_and_drama| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mystery and Drama| #7335B5| 1| 1| 0| 1',
        'BASED_ON_A_BOOK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Book| #131CA1| 1| 1| 0| 1',
        'BASED_ON_A_COMIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Comic| #7856EF| 1| 1| 0| 1',
        'BASED_ON_A_TRUE_STORY| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | True Story| #BC0638| 1| 1| 0| 1',
        'BASED_ON_A_VIDEO_GAME| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Video Game| #38CC66| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
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
    Find-Path "$script_path\chart"
    $theMaxWidth = 1500
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'MUST_SEE| Metacritic.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Metacritic Must See| #80B17A| 1| 1| 0| 0',
        'CERTIFIED_FRESH| Rotten Tomatoes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RT Certified Fresh| #4726DC| 1| 1| 0| 0',
        'RATED_100| Rotten Tomatoes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RT Rated 100| #4726DC| 1| 1| 0| 0',
        'AIRING_TODAY| TMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TMDb Airing Today| #062AC8| 1| 1| 0| 0',
        'BOTTOM_RATED| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IMDb Bottom Rated| #D7B00B| 1| 1| 0| 0',
        'BOX_OFFICE| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IMDb Box Office| #D7B00B| 1| 1| 0| 0',
        'COLLECTED| Trakt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trakt Collected| #CD1A20| 1| 1| 0| 0',
        'FAMILIES| css.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Common Sense Selection| #1AA931| 1| 1| 0| 0',
        'FAVORITED| MyAnimeList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MyAnimeList Favorited| #304DA6| 1| 1| 0| 0',
        'TOP_250| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Letterboxd Top 250| #405162| 1| 1| 0| 0',
        'BOX_OFFICE_MOJO_ALL_TIME_100| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Box Office Mojo All Time 100| #405162| 1| 1| 0| 0',
        'AFI_100_YEARS_100_MOVIES| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AFI 100 Years 100 Movies| #405162| 1| 1| 0| 0',
        'SIGHT_AND_SOUND_GREATEST_FILMS| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sight & Sound Greatest Films| #405162| 1| 1| 0| 0',
        '1001_MOVIES_TO_SEE_BEFORE_YOU_DIE| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1,001 To See Before You Die| #405162| 1| 1| 0| 0',
        'EDGAR_WRIGHTS_1000_FAVORITES| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Edgar Wright''s 1,000 Favorites| #405162| 1| 1| 0| 0',
        'ROGER_EBERTS_GREAT_MOVIES| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Roger Ebert''s Great Movies| #405162| 1| 1| 0| 0',
        'TOP_250_WOMEN_DIRECTED| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top 250 Women-Directed| #405162| 1| 1| 0| 0',
        'TOP_100_BLACK_DIRECTED| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top 100 Black-Directed| #405162| 1| 1| 0| 0',
        'TOP_250_MOST_FANS| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top 250 Most Fans| #405162| 1| 1| 0| 0',
        'TOP_250_DOCUMENTARIES| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top 250 Documentaries| #405162| 1| 1| 0| 0',
        'TOP_100_ANIMATION| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top 100 Animation| #405162| 1| 1| 0| 0',
        'TOP_250_HORROR| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top 250 Horror| #405162| 1| 1| 0| 0',
        'MOJO_TOP_100| Mojo.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mojo Top 100| #B452FD| 1| 1| 0| 0',
        'IMDB_TOP_250| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IMDb Top 250 (Letterboxd)| #405162| 1| 1| 0| 0',
        'OSCARS_BEST_PICTURE_WINNERS| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Oscar Best Picture Winners| #405162| 1| 1| 0| 0',
        'CANNES_PALMES_DOR_WINNERS| Letterboxd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cannes Palme d''Or Winners| #405162| 1| 1| 0| 0',
        'LOWEST_RATED| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IMDb Lowest Rated| #D7B00B| 1| 1| 0| 0',
        'NEWLY_RELEASED_EPISODES| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Newly Released Episodes| #DC9924| 1| 1| 0| 0',
        'NEWLY_RELEASED| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Newly Released| #DC9924| 1| 1| 0| 0',
        'NEW_EPISODES| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | New Episodes| #DC9924| 1| 1| 0| 0',
        'MOVIES_LEAVING_SOON| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plex Movies Leaving Soon| #DC9924| 1| 1| 0| 0',
        'SHOWS_LEAVING_SOON| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plex Shows Leaving Soon| #DC9924| 1| 1| 0| 0',
        'EPISODES_LEAVING_SOON| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plex Episodes Leaving Soon| #DC9924| 1| 1| 0| 0',
        'NEW_PREMIERES| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | New Premieres| #DC9924| 1| 1| 0| 0',
        'NOW_PLAYING| TMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TMDb Now Playing| #062AC8| 1| 1| 0| 0',
        'NOW_PLAYING| Trakt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trakt Now Playing| #CD1A20| 1| 1| 0| 0',
        'ON_THE_AIR| TMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TMDb On The Air| #062AC8| 1| 1| 0| 0',
        'PILOTS| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pilots| #DC9924| 1| 1| 0| 0',
        'PLEX_MUST_SEE_MOVIES| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Must See Movies| #DC9924| 1| 1| 0| 0',
        'PLEX_MUST_SEE_SHOWS| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Must See Shows| #DC9924| 1| 1| 0| 0',
        'PLEX_MUST_WATCH_MOVIES| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Must Watch Movies| #DC9924| 1| 1| 0| 0',
        'PLEX_MUST_WATCH_MOVIES| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Must Watch Shows| #DC9924| 1| 1| 0| 0',
        'PLEX_PEOPLE_WATCHING| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plex People Watching| #DC9924| 1| 1| 0| 0',
        'PLEX_PERSONAL_MOVIES_PICKS| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | My Personal Movie Picks| #DC9924| 1| 1| 0| 0',
        'PLEX_PERSONAL_SHOWS_PICKS| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | My Personal Show Picks| #DC9924| 1| 1| 0| 0',
        'PLEX_PILOTS| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plex Pilots| #DC9924| 1| 1| 0| 0',
        'PLEX_POPULAR| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plex Popular| #DC9924| 1| 1| 0| 0',
        'PLEX_WATCHED| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plex Watched| #DC9924| 1| 1| 0| 0',
        'POPULAR| AniDB.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AniDB Popular| #FF7E17| 1| 1| 0| 0',
        'POPULAR| AniList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AniList Popular| #414A81| 1| 1| 0| 0',
        'POPULAR| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IMDb Popular| #D7B00B| 1| 1| 0| 0',
        'POPULAR| MyAnimeList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MyAnimeList Popular| #304DA6| 1| 1| 0| 0',
        'POPULAR| Tautulli.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tautulli Popular| #B9851F| 1| 1| 0| 0',
        'POPULAR| TMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TMDb Popular| #062AC8| 1| 1| 0| 0',
        'POPULAR| Trakt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trakt Popular| #CD1A20| 1| 1| 0| 0',
        'RECENTLY_ADDED| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Recently Added| #DC9924| 1| 1| 0| 0',
        'RECENTLY_AIRED| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Recently Aired| #DC9924| 1| 1| 0| 0',
        'RECOMMENDED| Trakt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trakt Recommended| #CD1A20| 1| 1| 0| 0',
        'RETURNING_SOON| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Returning Soon| #DC9924| 1| 1| 0| 0',
        'NEXT_AIRING| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Next Airing| #DC9924| 1| 1| 0| 0',
        'SEASON| AniList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AniList Season| #414A81| 1| 1| 0| 0',
        'SEASON| MyAnimeList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MyAnimeList Season| #304DA6| 1| 1| 0| 0',
        'POPULAR_MOVIES| StevenLu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | StevenLu''s Popular Movies| #1D2D51| 1| 1| 0| 0',
        'THIS_DAY_IN_HISTORY| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | This Day in History| #DC9924| 1| 1| 0| 0',
        'THIS_MONTH_IN_HISTORY| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | This Month in History| #DC9924| 1| 1| 0| 0',
        'THIS_WEEK_IN_HISTORY| Plex.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | This Week in History| #DC9924| 1| 1| 0| 0',
        'TOP_1| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_1| #464646| 1| 1| 0| 0',
        'TOP_2| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_2| #464646| 1| 1| 0| 0',
        'TOP_3| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_3| #464646| 1| 1| 0| 0',
        'TOP_4| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_4| #464646| 1| 1| 0| 0',
        'TOP_5| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_5| #464646| 1| 1| 0| 0',
        'TOP_6| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_6| #464646| 1| 1| 0| 0',
        'TOP_7| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_7| #464646| 1| 1| 0| 0',
        'TOP_8| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_8| #464646| 1| 1| 0| 0',
        'TOP_9| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_9| #464646| 1| 1| 0| 0',
        'TOP_10| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_10| #464646| 1| 1| 0| 0',
        'TOP_11| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_11| #464646| 1| 1| 0| 0',
        'TOP_12| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_12| #464646| 1| 1| 0| 0',
        'TOP_13| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_13| #464646| 1| 1| 0| 0',
        'TOP_14| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_14| #464646| 1| 1| 0| 0',
        'TOP_15| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_15| #464646| 1| 1| 0| 0',
        'TOP_16| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_16| #464646| 1| 1| 0| 0',
        'TOP_17| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_17| #464646| 1| 1| 0| 0',
        'TOP_18| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_18| #464646| 1| 1| 0| 0',
        'TOP_19| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_19| #464646| 1| 1| 0| 0',
        'TOP_20| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_20| #464646| 1| 1| 0| 0',
        'TOP_21| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_21| #464646| 1| 1| 0| 0',
        'TOP_22| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_22| #464646| 1| 1| 0| 0',
        'TOP_23| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_23| #464646| 1| 1| 0| 0',
        'TOP_24| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_24| #464646| 1| 1| 0| 0',
        'TOP_25| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_25| #464646| 1| 1| 0| 0',
        'TOP_26| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_26| #464646| 1| 1| 0| 0',
        'TOP_27| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_27| #464646| 1| 1| 0| 0',
        'TOP_28| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_28| #464646| 1| 1| 0| 0',
        'TOP_29| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_29| #464646| 1| 1| 0| 0',
        'TOP_30| Starz.png| +-500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starz_top_30| #464646| 1| 1| 0| 0',
        'TOP_1| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_1| #494949| 1| 1| 0| 0',
        'TOP_1| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_1| #002CA1| 1| 1| 0| 0',
        'TOP_1| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_1| #910F6A| 1| 1| 0| 0',
        'TOP_1| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_1| #4C0870| 1| 1| 0| 0',
        'TOP_1| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_1| #1BB68A| 1| 1| 0| 0',
        'TOP_1| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_1| #D7B00B| 1| 1| 0| 0',
        'TOP_1| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_1| #D500CC| 1| 1| 0| 0',
        'TOP_1| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_1| #002BE7| 1| 1| 0| 0',
        'TOP_1| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_1| #5E0A11| 1| 1| 0| 0',
        'TOP_1| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_1| #1641C3| 1| 1| 0| 0',
        'TOP_1| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_1| #43ABCE| 1| 1| 0| 0',
        'TOP_1| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_1| #4A3159| 1| 1| 0| 0',
        'TOP_1| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_1| #26497F| 1| 1| 0| 0',
        'TOP_2| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_2| #494949| 1| 1| 0| 0',
        'TOP_2| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_2| #002CA1| 1| 1| 0| 0',
        'TOP_2| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_2| #910F6A| 1| 1| 0| 0',
        'TOP_2| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_2| #4C0870| 1| 1| 0| 0',
        'TOP_2| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_2| #1BB68A| 1| 1| 0| 0',
        'TOP_2| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_2| #D7B00B| 1| 1| 0| 0',
        'TOP_2| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_2| #D500CC| 1| 1| 0| 0',
        'TOP_2| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_2| #002BE7| 1| 1| 0| 0',
        'TOP_2| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_2| #5E0A11| 1| 1| 0| 0',
        'TOP_2| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_2| #1641C3| 1| 1| 0| 0',
        'TOP_2| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_2| #43ABCE| 1| 1| 0| 0',
        'TOP_2| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_2| #4A3159| 1| 1| 0| 0',
        'TOP_2| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_2| #26497F| 1| 1| 0| 0',
        'TOP_3| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_3| #494949| 1| 1| 0| 0',
        'TOP_3| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_3| #002CA1| 1| 1| 0| 0',
        'TOP_3| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_3| #910F6A| 1| 1| 0| 0',
        'TOP_3| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_3| #4C0870| 1| 1| 0| 0',
        'TOP_3| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_3| #1BB68A| 1| 1| 0| 0',
        'TOP_3| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_3| #D7B00B| 1| 1| 0| 0',
        'TOP_3| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_3| #D500CC| 1| 1| 0| 0',
        'TOP_3| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_3| #002BE7| 1| 1| 0| 0',
        'TOP_3| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_3| #5E0A11| 1| 1| 0| 0',
        'TOP_3| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_3| #1641C3| 1| 1| 0| 0',
        'TOP_3| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_3| #43ABCE| 1| 1| 0| 0',
        'TOP_3| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_3| #4A3159| 1| 1| 0| 0',
        'TOP_3| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_3| #26497F| 1| 1| 0| 0',
        'TOP_4| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_4| #494949| 1| 1| 0| 0',
        'TOP_4| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_4| #002CA1| 1| 1| 0| 0',
        'TOP_4| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_4| #910F6A| 1| 1| 0| 0',
        'TOP_4| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_4| #4C0870| 1| 1| 0| 0',
        'TOP_4| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_4| #1BB68A| 1| 1| 0| 0',
        'TOP_4| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_4| #D7B00B| 1| 1| 0| 0',
        'TOP_4| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_4| #D500CC| 1| 1| 0| 0',
        'TOP_4| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_4| #002BE7| 1| 1| 0| 0',
        'TOP_4| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_4| #5E0A11| 1| 1| 0| 0',
        'TOP_4| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_4| #1641C3| 1| 1| 0| 0',
        'TOP_4| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_4| #43ABCE| 1| 1| 0| 0',
        'TOP_4| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_4| #4A3159| 1| 1| 0| 0',
        'TOP_4| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_4| #26497F| 1| 1| 0| 0',
        'TOP_5| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_5| #494949| 1| 1| 0| 0',
        'TOP_5| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_5| #002CA1| 1| 1| 0| 0',
        'TOP_5| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_5| #910F6A| 1| 1| 0| 0',
        'TOP_5| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_5| #4C0870| 1| 1| 0| 0',
        'TOP_5| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_5| #1BB68A| 1| 1| 0| 0',
        'TOP_5| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_5| #D7B00B| 1| 1| 0| 0',
        'TOP_5| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_5| #D500CC| 1| 1| 0| 0',
        'TOP_5| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_5| #002BE7| 1| 1| 0| 0',
        'TOP_5| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_5| #5E0A11| 1| 1| 0| 0',
        'TOP_5| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_5| #1641C3| 1| 1| 0| 0',
        'TOP_5| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_5| #43ABCE| 1| 1| 0| 0',
        'TOP_5| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_5| #4A3159| 1| 1| 0| 0',
        'TOP_5| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_5| #26497F| 1| 1| 0| 0',
        'TOP_6| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_6| #494949| 1| 1| 0| 0',
        'TOP_6| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_6| #002CA1| 1| 1| 0| 0',
        'TOP_6| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_6| #910F6A| 1| 1| 0| 0',
        'TOP_6| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_6| #4C0870| 1| 1| 0| 0',
        'TOP_6| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_6| #1BB68A| 1| 1| 0| 0',
        'TOP_6| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_6| #D7B00B| 1| 1| 0| 0',
        'TOP_6| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_6| #D500CC| 1| 1| 0| 0',
        'TOP_6| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_6| #002BE7| 1| 1| 0| 0',
        'TOP_6| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_6| #5E0A11| 1| 1| 0| 0',
        'TOP_6| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_6| #1641C3| 1| 1| 0| 0',
        'TOP_6| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_6| #43ABCE| 1| 1| 0| 0',
        'TOP_6| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_6| #4A3159| 1| 1| 0| 0',
        'TOP_6| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_6| #26497F| 1| 1| 0| 0',
        'TOP_7| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_7| #494949| 1| 1| 0| 0',
        'TOP_7| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_7| #002CA1| 1| 1| 0| 0',
        'TOP_7| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_7| #910F6A| 1| 1| 0| 0',
        'TOP_7| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_7| #4C0870| 1| 1| 0| 0',
        'TOP_7| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_7| #1BB68A| 1| 1| 0| 0',
        'TOP_7| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_7| #D7B00B| 1| 1| 0| 0',
        'TOP_7| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_7| #D500CC| 1| 1| 0| 0',
        'TOP_7| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_7| #002BE7| 1| 1| 0| 0',
        'TOP_7| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_7| #5E0A11| 1| 1| 0| 0',
        'TOP_7| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_7| #1641C3| 1| 1| 0| 0',
        'TOP_7| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_7| #43ABCE| 1| 1| 0| 0',
        'TOP_7| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_7| #4A3159| 1| 1| 0| 0',
        'TOP_7| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_7| #26497F| 1| 1| 0| 0',
        'TOP_8| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_8| #494949| 1| 1| 0| 0',
        'TOP_8| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_8| #002CA1| 1| 1| 0| 0',
        'TOP_8| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_8| #910F6A| 1| 1| 0| 0',
        'TOP_8| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_8| #4C0870| 1| 1| 0| 0',
        'TOP_8| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_8| #1BB68A| 1| 1| 0| 0',
        'TOP_8| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_8| #D7B00B| 1| 1| 0| 0',
        'TOP_8| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_8| #D500CC| 1| 1| 0| 0',
        'TOP_8| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_8| #002BE7| 1| 1| 0| 0',
        'TOP_8| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_8| #5E0A11| 1| 1| 0| 0',
        'TOP_8| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_8| #1641C3| 1| 1| 0| 0',
        'TOP_8| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_8| #43ABCE| 1| 1| 0| 0',
        'TOP_8| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_8| #4A3159| 1| 1| 0| 0',
        'TOP_8| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_8| #26497F| 1| 1| 0| 0',
        'TOP_9| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_9| #494949| 1| 1| 0| 0',
        'TOP_9| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_9| #002CA1| 1| 1| 0| 0',
        'TOP_9| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_9| #910F6A| 1| 1| 0| 0',
        'TOP_9| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_9| #4C0870| 1| 1| 0| 0',
        'TOP_9| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_9| #1BB68A| 1| 1| 0| 0',
        'TOP_9| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_9| #D7B00B| 1| 1| 0| 0',
        'TOP_9| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_9| #D500CC| 1| 1| 0| 0',
        'TOP_9| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_9| #002BE7| 1| 1| 0| 0',
        'TOP_9| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_9| #5E0A11| 1| 1| 0| 0',
        'TOP_9| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_9| #1641C3| 1| 1| 0| 0',
        'TOP_9| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_9| #43ABCE| 1| 1| 0| 0',
        'TOP_9| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_9| #4A3159| 1| 1| 0| 0',
        'TOP_9| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_9| #26497F| 1| 1| 0| 0',
        'TOP_10| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_10| #494949| 1| 1| 0| 0',
        'TOP_10| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_10| #002CA1| 1| 1| 0| 0',
        'TOP_10| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_10| #910F6A| 1| 1| 0| 0',
        'TOP_10| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_10| #4C0870| 1| 1| 0| 0',
        'TOP_10| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_10| #1BB68A| 1| 1| 0| 0',
        'TOP_10| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_10| #D7B00B| 1| 1| 0| 0',
        'TOP_10| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_10| #D500CC| 1| 1| 0| 0',
        'TOP_10| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_10| #002BE7| 1| 1| 0| 0',
        'TOP_10| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_10| #5E0A11| 1| 1| 0| 0',
        'TOP_10| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_10| #1641C3| 1| 1| 0| 0',
        'TOP_10| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_10| #43ABCE| 1| 1| 0| 0',
        'TOP_10| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_10| #4A3159| 1| 1| 0| 0',
        'TOP_10| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_10| #26497F| 1| 1| 0| 0',
        'TOP_10_PIRATED| Pirated.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top 10 Pirated Movies of the Week| #93561D| 1| 1| 0| 0',
        'TOP_10| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top| #494949| 1| 1| 0| 0',
        'TOP_10| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top| #002CA1| 1| 1| 0| 0',
        'TOP_10| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top| #910F6A| 1| 1| 0| 0',
        'TOP_10| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top| #4C0870| 1| 1| 0| 0',
        'TOP_10| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top| #1BB68A| 1| 1| 0| 0',
        'TOP_10| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top| #D7B00B| 1| 1| 0| 0',
        'TOP_10| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top| #D500CC| 1| 1| 0| 0',
        'TOP_10| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top| #002BE7| 1| 1| 0| 0',
        'TOP_10| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top| #5E0A11| 1| 1| 0| 0',
        'TOP_10| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top| #1641C3| 1| 1| 0| 0',
        'TOP_10| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top| #43ABCE| 1| 1| 0| 0',
        'TOP_10| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top| #4A3159| 1| 1| 0| 0',
        'TOP_10| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top| #26497F| 1| 1| 0| 0',
        'TOP_11| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_11| #494949| 1| 1| 0| 0',
        'TOP_11| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_11| #002CA1| 1| 1| 0| 0',
        'TOP_11| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_11| #910F6A| 1| 1| 0| 0',
        'TOP_11| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_11| #4C0870| 1| 1| 0| 0',
        'TOP_11| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_11| #1BB68A| 1| 1| 0| 0',
        'TOP_11| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_11| #D7B00B| 1| 1| 0| 0',
        'TOP_11| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_11| #D500CC| 1| 1| 0| 0',
        'TOP_11| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_11| #002BE7| 1| 1| 0| 0',
        'TOP_11| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_11| #5E0A11| 1| 1| 0| 0',
        'TOP_11| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_11| #1641C3| 1| 1| 0| 0',
        'TOP_11| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_11| #43ABCE| 1| 1| 0| 0',
        'TOP_11| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_11| #4A3159| 1| 1| 0| 0',
        'TOP_11| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_11| #26497F| 1| 1| 0| 0',
        'TOP_12| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_12| #494949| 1| 1| 0| 0',
        'TOP_12| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_12| #002CA1| 1| 1| 0| 0',
        'TOP_12| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_12| #910F6A| 1| 1| 0| 0',
        'TOP_12| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_12| #4C0870| 1| 1| 0| 0',
        'TOP_12| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_12| #1BB68A| 1| 1| 0| 0',
        'TOP_12| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_12| #D7B00B| 1| 1| 0| 0',
        'TOP_12| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_12| #D500CC| 1| 1| 0| 0',
        'TOP_12| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_12| #002BE7| 1| 1| 0| 0',
        'TOP_12| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_12| #5E0A11| 1| 1| 0| 0',
        'TOP_12| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_12| #1641C3| 1| 1| 0| 0',
        'TOP_12| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_12| #43ABCE| 1| 1| 0| 0',
        'TOP_12| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_12| #4A3159| 1| 1| 0| 0',
        'TOP_12| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_12| #26497F| 1| 1| 0| 0',
        'TOP_13| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_13| #494949| 1| 1| 0| 0',
        'TOP_13| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_13| #002CA1| 1| 1| 0| 0',
        'TOP_13| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_13| #910F6A| 1| 1| 0| 0',
        'TOP_13| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_13| #4C0870| 1| 1| 0| 0',
        'TOP_13| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_13| #1BB68A| 1| 1| 0| 0',
        'TOP_13| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_13| #D7B00B| 1| 1| 0| 0',
        'TOP_13| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_13| #D500CC| 1| 1| 0| 0',
        'TOP_13| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_13| #002BE7| 1| 1| 0| 0',
        'TOP_13| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_13| #5E0A11| 1| 1| 0| 0',
        'TOP_13| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_13| #1641C3| 1| 1| 0| 0',
        'TOP_13| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_13| #43ABCE| 1| 1| 0| 0',
        'TOP_13| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_13| #4A3159| 1| 1| 0| 0',
        'TOP_13| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_13| #26497F| 1| 1| 0| 0',
        'TOP_14| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_14| #494949| 1| 1| 0| 0',
        'TOP_14| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_14| #002CA1| 1| 1| 0| 0',
        'TOP_14| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_14| #910F6A| 1| 1| 0| 0',
        'TOP_14| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_14| #4C0870| 1| 1| 0| 0',
        'TOP_14| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_14| #1BB68A| 1| 1| 0| 0',
        'TOP_14| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_14| #D7B00B| 1| 1| 0| 0',
        'TOP_14| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_14| #D500CC| 1| 1| 0| 0',
        'TOP_14| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_14| #002BE7| 1| 1| 0| 0',
        'TOP_14| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_14| #5E0A11| 1| 1| 0| 0',
        'TOP_14| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_14| #1641C3| 1| 1| 0| 0',
        'TOP_14| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_14| #43ABCE| 1| 1| 0| 0',
        'TOP_14| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_14| #4A3159| 1| 1| 0| 0',
        'TOP_14| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_14| #26497F| 1| 1| 0| 0',
        'TOP_15| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_15| #494949| 1| 1| 0| 0',
        'TOP_15| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_15| #002CA1| 1| 1| 0| 0',
        'TOP_15| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_15| #910F6A| 1| 1| 0| 0',
        'TOP_15| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_15| #4C0870| 1| 1| 0| 0',
        'TOP_15| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_15| #1BB68A| 1| 1| 0| 0',
        'TOP_15| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_15| #D7B00B| 1| 1| 0| 0',
        'TOP_15| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_15| #D500CC| 1| 1| 0| 0',
        'TOP_15| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_15| #002BE7| 1| 1| 0| 0',
        'TOP_15| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_15| #5E0A11| 1| 1| 0| 0',
        'TOP_15| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_15| #1641C3| 1| 1| 0| 0',
        'TOP_15| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_15| #43ABCE| 1| 1| 0| 0',
        'TOP_15| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_15| #4A3159| 1| 1| 0| 0',
        'TOP_15| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_15| #26497F| 1| 1| 0| 0',
        'TOP_16| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_16| #494949| 1| 1| 0| 0',
        'TOP_16| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_16| #002CA1| 1| 1| 0| 0',
        'TOP_16| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_16| #910F6A| 1| 1| 0| 0',
        'TOP_16| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_16| #4C0870| 1| 1| 0| 0',
        'TOP_16| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_16| #1BB68A| 1| 1| 0| 0',
        'TOP_16| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_16| #D7B00B| 1| 1| 0| 0',
        'TOP_16| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_16| #D500CC| 1| 1| 0| 0',
        'TOP_16| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_16| #002BE7| 1| 1| 0| 0',
        'TOP_16| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_16| #5E0A11| 1| 1| 0| 0',
        'TOP_16| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_16| #1641C3| 1| 1| 0| 0',
        'TOP_16| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_16| #43ABCE| 1| 1| 0| 0',
        'TOP_16| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_16| #4A3159| 1| 1| 0| 0',
        'TOP_16| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_16| #26497F| 1| 1| 0| 0',
        'TOP_17| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_17| #494949| 1| 1| 0| 0',
        'TOP_17| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_17| #002CA1| 1| 1| 0| 0',
        'TOP_17| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_17| #910F6A| 1| 1| 0| 0',
        'TOP_17| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_17| #4C0870| 1| 1| 0| 0',
        'TOP_17| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_17| #1BB68A| 1| 1| 0| 0',
        'TOP_17| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_17| #D7B00B| 1| 1| 0| 0',
        'TOP_17| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_17| #D500CC| 1| 1| 0| 0',
        'TOP_17| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_17| #002BE7| 1| 1| 0| 0',
        'TOP_17| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_17| #5E0A11| 1| 1| 0| 0',
        'TOP_17| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_17| #1641C3| 1| 1| 0| 0',
        'TOP_17| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_17| #43ABCE| 1| 1| 0| 0',
        'TOP_17| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_17| #4A3159| 1| 1| 0| 0',
        'TOP_17| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_17| #26497F| 1| 1| 0| 0',
        'TOP_18| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_18| #494949| 1| 1| 0| 0',
        'TOP_18| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_18| #002CA1| 1| 1| 0| 0',
        'TOP_18| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_18| #910F6A| 1| 1| 0| 0',
        'TOP_18| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_18| #4C0870| 1| 1| 0| 0',
        'TOP_18| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_18| #1BB68A| 1| 1| 0| 0',
        'TOP_18| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_18| #D7B00B| 1| 1| 0| 0',
        'TOP_18| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_18| #D500CC| 1| 1| 0| 0',
        'TOP_18| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_18| #002BE7| 1| 1| 0| 0',
        'TOP_18| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_18| #5E0A11| 1| 1| 0| 0',
        'TOP_18| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_18| #1641C3| 1| 1| 0| 0',
        'TOP_18| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_18| #43ABCE| 1| 1| 0| 0',
        'TOP_18| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_18| #4A3159| 1| 1| 0| 0',
        'TOP_18| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_18| #26497F| 1| 1| 0| 0',
        'TOP_19| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_19| #494949| 1| 1| 0| 0',
        'TOP_19| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_19| #002CA1| 1| 1| 0| 0',
        'TOP_19| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_19| #910F6A| 1| 1| 0| 0',
        'TOP_19| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_19| #4C0870| 1| 1| 0| 0',
        'TOP_19| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_19| #1BB68A| 1| 1| 0| 0',
        'TOP_19| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_19| #D7B00B| 1| 1| 0| 0',
        'TOP_19| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_19| #D500CC| 1| 1| 0| 0',
        'TOP_19| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_19| #002BE7| 1| 1| 0| 0',
        'TOP_19| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_19| #5E0A11| 1| 1| 0| 0',
        'TOP_19| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_19| #1641C3| 1| 1| 0| 0',
        'TOP_19| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_19| #43ABCE| 1| 1| 0| 0',
        'TOP_19| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_19| #4A3159| 1| 1| 0| 0',
        'TOP_19| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_19| #26497F| 1| 1| 0| 0',
        'TOP_20| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_20| #494949| 1| 1| 0| 0',
        'TOP_20| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_20| #002CA1| 1| 1| 0| 0',
        'TOP_20| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_20| #910F6A| 1| 1| 0| 0',
        'TOP_20| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_20| #4C0870| 1| 1| 0| 0',
        'TOP_20| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_20| #1BB68A| 1| 1| 0| 0',
        'TOP_20| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_20| #D7B00B| 1| 1| 0| 0',
        'TOP_20| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_20| #D500CC| 1| 1| 0| 0',
        'TOP_20| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_20| #002BE7| 1| 1| 0| 0',
        'TOP_20| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_20| #5E0A11| 1| 1| 0| 0',
        'TOP_20| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_20| #1641C3| 1| 1| 0| 0',
        'TOP_20| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_20| #43ABCE| 1| 1| 0| 0',
        'TOP_20| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_20| #4A3159| 1| 1| 0| 0',
        'TOP_20| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_20| #26497F| 1| 1| 0| 0',
        'TOP_21| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_21| #494949| 1| 1| 0| 0',
        'TOP_21| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_21| #002CA1| 1| 1| 0| 0',
        'TOP_21| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_21| #910F6A| 1| 1| 0| 0',
        'TOP_21| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_21| #4C0870| 1| 1| 0| 0',
        'TOP_21| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_21| #1BB68A| 1| 1| 0| 0',
        'TOP_21| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_21| #D7B00B| 1| 1| 0| 0',
        'TOP_21| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_21| #D500CC| 1| 1| 0| 0',
        'TOP_21| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_21| #002BE7| 1| 1| 0| 0',
        'TOP_21| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_21| #5E0A11| 1| 1| 0| 0',
        'TOP_21| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_21| #1641C3| 1| 1| 0| 0',
        'TOP_21| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_21| #43ABCE| 1| 1| 0| 0',
        'TOP_21| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_21| #4A3159| 1| 1| 0| 0',
        'TOP_21| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_21| #26497F| 1| 1| 0| 0',
        'TOP_22| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_22| #494949| 1| 1| 0| 0',
        'TOP_22| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_22| #002CA1| 1| 1| 0| 0',
        'TOP_22| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_22| #910F6A| 1| 1| 0| 0',
        'TOP_22| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_22| #4C0870| 1| 1| 0| 0',
        'TOP_22| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_22| #1BB68A| 1| 1| 0| 0',
        'TOP_22| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_22| #D7B00B| 1| 1| 0| 0',
        'TOP_22| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_22| #D500CC| 1| 1| 0| 0',
        'TOP_22| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_22| #002BE7| 1| 1| 0| 0',
        'TOP_22| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_22| #5E0A11| 1| 1| 0| 0',
        'TOP_22| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_22| #1641C3| 1| 1| 0| 0',
        'TOP_22| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_22| #43ABCE| 1| 1| 0| 0',
        'TOP_22| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_22| #4A3159| 1| 1| 0| 0',
        'TOP_22| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_22| #26497F| 1| 1| 0| 0',
        'TOP_23| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_23| #494949| 1| 1| 0| 0',
        'TOP_23| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_23| #002CA1| 1| 1| 0| 0',
        'TOP_23| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_23| #910F6A| 1| 1| 0| 0',
        'TOP_23| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_23| #4C0870| 1| 1| 0| 0',
        'TOP_23| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_23| #1BB68A| 1| 1| 0| 0',
        'TOP_23| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_23| #D7B00B| 1| 1| 0| 0',
        'TOP_23| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_23| #D500CC| 1| 1| 0| 0',
        'TOP_23| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_23| #002BE7| 1| 1| 0| 0',
        'TOP_23| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_23| #5E0A11| 1| 1| 0| 0',
        'TOP_23| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_23| #1641C3| 1| 1| 0| 0',
        'TOP_23| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_23| #43ABCE| 1| 1| 0| 0',
        'TOP_23| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_23| #4A3159| 1| 1| 0| 0',
        'TOP_23| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_23| #26497F| 1| 1| 0| 0',
        'TOP_24| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_24| #494949| 1| 1| 0| 0',
        'TOP_24| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_24| #002CA1| 1| 1| 0| 0',
        'TOP_24| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_24| #910F6A| 1| 1| 0| 0',
        'TOP_24| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_24| #4C0870| 1| 1| 0| 0',
        'TOP_24| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_24| #1BB68A| 1| 1| 0| 0',
        'TOP_24| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_24| #D7B00B| 1| 1| 0| 0',
        'TOP_24| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_24| #D500CC| 1| 1| 0| 0',
        'TOP_24| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_24| #002BE7| 1| 1| 0| 0',
        'TOP_24| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_24| #5E0A11| 1| 1| 0| 0',
        'TOP_24| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_24| #1641C3| 1| 1| 0| 0',
        'TOP_24| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_24| #43ABCE| 1| 1| 0| 0',
        'TOP_24| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_24| #4A3159| 1| 1| 0| 0',
        'TOP_24| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_24| #26497F| 1| 1| 0| 0',
        'TOP_25| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_25| #494949| 1| 1| 0| 0',
        'TOP_25| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_25| #002CA1| 1| 1| 0| 0',
        'TOP_25| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_25| #910F6A| 1| 1| 0| 0',
        'TOP_25| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_25| #4C0870| 1| 1| 0| 0',
        'TOP_25| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_25| #1BB68A| 1| 1| 0| 0',
        'TOP_25| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_25| #D7B00B| 1| 1| 0| 0',
        'TOP_25| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_25| #D500CC| 1| 1| 0| 0',
        'TOP_25| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_25| #002BE7| 1| 1| 0| 0',
        'TOP_25| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_25| #5E0A11| 1| 1| 0| 0',
        'TOP_25| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_25| #1641C3| 1| 1| 0| 0',
        'TOP_25| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_25| #43ABCE| 1| 1| 0| 0',
        'TOP_25| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_25| #4A3159| 1| 1| 0| 0',
        'TOP_25| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_25| #26497F| 1| 1| 0| 0',
        'TOP_26| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_26| #494949| 1| 1| 0| 0',
        'TOP_26| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_26| #002CA1| 1| 1| 0| 0',
        'TOP_26| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_26| #910F6A| 1| 1| 0| 0',
        'TOP_26| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_26| #4C0870| 1| 1| 0| 0',
        'TOP_26| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_26| #1BB68A| 1| 1| 0| 0',
        'TOP_26| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_26| #D7B00B| 1| 1| 0| 0',
        'TOP_26| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_26| #D500CC| 1| 1| 0| 0',
        'TOP_26| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_26| #002BE7| 1| 1| 0| 0',
        'TOP_26| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_26| #5E0A11| 1| 1| 0| 0',
        'TOP_26| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_26| #1641C3| 1| 1| 0| 0',
        'TOP_26| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_26| #43ABCE| 1| 1| 0| 0',
        'TOP_26| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_26| #4A3159| 1| 1| 0| 0',
        'TOP_26| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_26| #26497F| 1| 1| 0| 0',
        'TOP_27| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_27| #494949| 1| 1| 0| 0',
        'TOP_27| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_27| #002CA1| 1| 1| 0| 0',
        'TOP_27| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_27| #910F6A| 1| 1| 0| 0',
        'TOP_27| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_27| #4C0870| 1| 1| 0| 0',
        'TOP_27| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_27| #1BB68A| 1| 1| 0| 0',
        'TOP_27| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_27| #D7B00B| 1| 1| 0| 0',
        'TOP_27| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_27| #D500CC| 1| 1| 0| 0',
        'TOP_27| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_27| #002BE7| 1| 1| 0| 0',
        'TOP_27| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_27| #5E0A11| 1| 1| 0| 0',
        'TOP_27| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_27| #1641C3| 1| 1| 0| 0',
        'TOP_27| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_27| #43ABCE| 1| 1| 0| 0',
        'TOP_27| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_27| #4A3159| 1| 1| 0| 0',
        'TOP_27| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_27| #26497F| 1| 1| 0| 0',
        'TOP_28| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_28| #494949| 1| 1| 0| 0',
        'TOP_28| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_28| #002CA1| 1| 1| 0| 0',
        'TOP_28| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_28| #910F6A| 1| 1| 0| 0',
        'TOP_28| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_28| #4C0870| 1| 1| 0| 0',
        'TOP_28| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_28| #1BB68A| 1| 1| 0| 0',
        'TOP_28| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_28| #D7B00B| 1| 1| 0| 0',
        'TOP_28| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_28| #D500CC| 1| 1| 0| 0',
        'TOP_28| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_28| #002BE7| 1| 1| 0| 0',
        'TOP_28| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_28| #5E0A11| 1| 1| 0| 0',
        'TOP_28| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_28| #1641C3| 1| 1| 0| 0',
        'TOP_28| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_28| #43ABCE| 1| 1| 0| 0',
        'TOP_28| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_28| #4A3159| 1| 1| 0| 0',
        'TOP_28| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_28| #26497F| 1| 1| 0| 0',
        'TOP_29| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_29| #494949| 1| 1| 0| 0',
        'TOP_29| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_29| #002CA1| 1| 1| 0| 0',
        'TOP_29| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_29| #910F6A| 1| 1| 0| 0',
        'TOP_29| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_29| #4C0870| 1| 1| 0| 0',
        'TOP_29| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_29| #1BB68A| 1| 1| 0| 0',
        'TOP_29| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_29| #D7B00B| 1| 1| 0| 0',
        'TOP_29| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_29| #D500CC| 1| 1| 0| 0',
        'TOP_29| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_29| #002BE7| 1| 1| 0| 0',
        'TOP_29| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_29| #5E0A11| 1| 1| 0| 0',
        'TOP_29| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_29| #1641C3| 1| 1| 0| 0',
        'TOP_29| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_29| #43ABCE| 1| 1| 0| 0',
        'TOP_29| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_29| #4A3159| 1| 1| 0| 0',
        'TOP_29| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_29| #26497F| 1| 1| 0| 0',
        'TOP_30| Apple TV+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | apple_top_30| #494949| 1| 1| 0| 0',
        'TOP_30| Disney+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disney_top_30| #002CA1| 1| 1| 0| 0',
        'TOP_30| google_play.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | google_top_30| #910F6A| 1| 1| 0| 0',
        'TOP_30| HBO Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hbo_top_30| #4C0870| 1| 1| 0| 0',
        'TOP_30| hulu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hulu_top_30| #1BB68A| 1| 1| 0| 0',
        'TOP_30| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | imdb_top_30| #D7B00B| 1| 1| 0| 0',
        'TOP_30| itunes.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | itunes_top_30| #D500CC| 1| 1| 0| 0',
        'TOP_30| Max.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | max_top_30| #002BE7| 1| 1| 0| 0',
        'TOP_30| Netflix.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | netflix_top_30| #5E0A11| 1| 1| 0| 0',
        'TOP_30| Paramount+.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | paramount_top_30| #1641C3| 1| 1| 0| 0',
        'TOP_30| Prime Video.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | prime_top_30| #43ABCE| 1| 1| 0| 0',
        'TOP_30| star_plus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star_plus_top_30| #4A3159| 1| 1| 0| 0',
        'TOP_30| vudu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vudu_top_30| #26497F| 1| 1| 0| 0',
        'TOP_250| IMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IMDb Top 250| #D7B00B| 1| 1| 0| 0',
        'TOP_AIRING| MyAnimeList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MyAnimeList Top Airing| #304DA6| 1| 1| 0| 0',
        'TOP_RATED| AniList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AniList Top Rated| #414A81| 1| 1| 0| 0',
        'TOP_RATED| MyAnimeList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MyAnimeList Top Rated| #304DA6| 1| 1| 0| 0',
        'TOP_RATED| TMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TMDb Top Rated| #062AC8| 1| 1| 0| 0',
        'TRENDING| AniList.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AniList Trending| #414A81| 1| 1| 0| 0',
        'TRENDING| TMDb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TMDb Trending| #062AC8| 1| 1| 0| 0',
        'TRENDING| Trakt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trakt Trending| #CD1A20| 1| 1| 0| 0',
        'WATCHED| Tautulli.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tautulli Watched| #B9851F| 1| 1| 0| 0',
        'WATCHED| Trakt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trakt Watched| #CD1A20| 1| 1| 0| 0',
        'WATCHLIST| Trakt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trakt Watchlist| #CD1A20| 1| 1| 0| 0'
        ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination chart\color

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\white\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }


    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination chart\white
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
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    $logo_offset = -500
    $logo_resize = 1800
    $text_offset = "+850"
    $font = "ComfortAa-Medium"
    $font_color = "#FFFFFF"
    $border = 0
    $border_width = 15
    $border_color = "#FFFFFF"
    $avg_color_image = ""
    $base_color = ""
    $gradient = 1
    $clean = 1
    $avg_color = 0
    $white_wash = 1

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'content_ratings_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination content_rating

    $base_color = "#1AA931"
    $arr = @()
    for ($i = 1; $i -lt 19; $i++) {
        $value = (Get-YamlPropertyValue -PropertyPath "key_names.age" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        $value = "$value $i+"
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\cs.png`" -logo_offset $logo_offset -logo_resize $logo_resize -text `"$value`" -text_offset $text_offset -font `"$font`" -font_size $optimalFontSize -font_color `"$font_color`" -border $border -border_width $border_width -border_color `"$border_color`" -avg_color_image `"$avg_color_image`" -out_name `"$i`" -base_color `"$base_color`" -gradient $gradient -avg_color $avg_color -clean $clean -white_wash $white_wash"
    }
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.NOT_RATED" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\cs.png`" -logo_offset $logo_offset -logo_resize $logo_resize -text `"$value`" -text_offset $text_offset -font `"$font`" -font_size $optimalFontSize -font_color `"$font_color`" -border $border -border_width $border_width -border_color `"$border_color`" -avg_color_image `"$avg_color_image`" -out_name `"NR`" -base_color `"$base_color`" -gradient $gradient -avg_color $avg_color -clean $clean -white_wash $white_wash"
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination content_rating\cs
    
    $content_rating = "G", "PG", "PG-13", "R", "R+", "Rx"
    $base_color = "#2444D1"
    $arr = @()
    foreach ( $cr in $content_rating ) { 
        $value = (Get-YamlPropertyValue -PropertyPath "key_names.RATED" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        $value = "$value $cr"
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\mal.png`" -logo_offset $logo_offset -logo_resize $logo_resize -text `"$value`" -text_offset $text_offset -font `"$font`" -font_size $optimalFontSize -font_color `"$font_color`" -border $border -border_width $border_width -border_color `"$border_color`" -avg_color_image `"$avg_color_image`" -out_name `"$cr`" -base_color `"$base_color`" -gradient $gradient -avg_color $avg_color -clean $clean -white_wash $white_wash"
    }
    $value = (Get-YamlPropertyValue -PropertyPath "key_names.NOT_RATED" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
    $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\mal.png`" -logo_offset $logo_offset -logo_resize $logo_resize -text `"$value`" -text_offset $text_offset -font `"$font`" -font_size $optimalFontSize -font_color `"$font_color`" -border $border -border_width $border_width -border_color `"$border_color`" -avg_color_image `"$avg_color_image`" -out_name `"NR`" -base_color `"$base_color`" -gradient $gradient -avg_color $avg_color -clean $clean -white_wash $white_wash"
    LaunchScripts -ScriptPaths $arr
    
    Move-Item -Path output -Destination content_rating\mal

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| uk12.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 12| #FF7D13| 1| 1| 0| 1',
        '| uk12A.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 12A| #FF7D13| 1| 1| 0| 1',
        '| uk15.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 15| #FC4E93| 1| 1| 0| 1',
        '| uk18.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 18| #DC0A0B| 1| 1| 0| 1',
        '| uknr.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NR| #0E84A3| 1| 1| 0| 1',
        '| ukpg.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PG| #FBAE00| 1| 1| 0| 1',
        '| ukr18.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | R18| #016ED3| 1| 1| 0| 1',
        '| uku.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | U| #0BC700| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination content_rating\uk

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| de0c.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 0| #868786| 1| 1| 0| 1',
        '| de6c.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 6| #FFEA3E| 1| 1| 0| 1',
        '| de12c.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 12| #37B653| 1| 1| 0| 1',
        '| de16c.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 16| #3CA9E7| 1| 1| 0| 1',
        '| de18c.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 18| #F51924| 1| 1| 0| 1',
        '| debpjmc.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BPjM| #DC1924| 1| 1| 0| 1',
        '| denr.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NR| #0E84A3| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination content_rating\de

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| au_g.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | G| #0DB14B| 1| 1| 0| 1',
        '| au_ma.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MA15+| #ED1C24| 1| 1| 0| 1',
        '| au_m.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | M| #00AEEF| 1| 1| 0| 1',
        '| au_pg.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PG| #FFF200| 1| 1| 0| 1',
        '| au_r.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | R18+| #231F20| 1| 1| 0| 1',
        '| au_x.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | X18+| #221f20| 1| 1| 0| 1',
        '| au_nr.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NR| #0D3843| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination content_rating\au

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| nz_g.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | G| #04934F| 1| 1| 0| 1',
        '| nz_m.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | M| #FFEC00| 1| 1| 0| 1',
        '| nz_pg.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PG| #FFEC00| 1| 1| 0| 1',
        '| nz_r13.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | R13| #FF0000| 1| 1| 0| 1',
        '| nz_r15.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | R15| #FF0000| 1| 1| 0| 1',
        '| nz_r16.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | R16| #FF0000| 1| 1| 0| 1',
        '| nz_r18.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | R18| #FF0000| 1| 1| 0| 1',
        '| nz_r.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | R| #FF0000| 1| 1| 0| 1',
        '| nz_rp13.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RP13| #FF0000| 1| 1| 0| 1',
        '| nz_rp16.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RP16| #FF0000| 1| 1| 0| 1',
        '| nz_RP18.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RP18| #FF0000| 1| 1| 0| 1',
        '| nz_nr.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NR| #0D3843| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination content_rating\nz

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| usg.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | G| #79EF06| 1| 1| 0| 1',
        '| usnc-17.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NC-17| #EE45A4| 1| 1| 0| 1',
        '| usnr.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NR| #0E84A3| 1| 1| 0| 1',
        '| uspg.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PG| #918CE2| 1| 1| 0| 1',
        '| uspg-13.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PG-13| #A124CC| 1| 1| 0| 1',
        '| usr.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | R| #FB5226| 1| 1| 0| 1',
        '| ustv-14.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV-14| #C29CC1| 1| 1| 0| 1',
        '| ustv-g.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV-G| #98A5BB| 1| 1| 0| 1',
        '| ustv-ma.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV-MA| #DB8689| 1| 1| 0| 1',
        '| ustv-pg.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV-PG| #5B0EFD| 1| 1| 0| 1',
        '| ustv-y.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV-Y| #3EB3C1| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
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
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'country_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Countries| #FF2000| 1| 1| 0| 1',
        'region_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Regions| #FF2000| 1| 1| 0| 1',
        'continent_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Continents| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'AFGHANISTAN| af.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Afghanistan| #831F36| 1| 1| 0| 0',
        'AFRICA| Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Africa| #158B0A| 1| 1| 0| 0',
        'ALBANIA| al.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Albania| #D889BF| 1| 1| 0| 0',
        'ALGERIA| dz.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Algeria| #F731AB| 1| 1| 0| 0',
        'ANDEAN| Andean.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Andean| #BFEFDF| 1| 1| 0| 0',
        'AMERICAS| Americas.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Americas| #00BFFF| 1| 1| 0| 0',
        'ANDORRA| ad.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Andorra| #0DB2F4| 1| 1| 0| 0',
        'ANGOLA| ao.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Angola| #618274| 1| 1| 0| 0',
        'ANGUILLA| ai.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Anguilla| #BC9090| 1| 1| 0| 0',
        'ANTARCTICA_REGION| Antarctica Region.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Antarctica Region| #E01CD8| 1| 1| 0| 0',
        'ANTARCTICA| aq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Antarctica| #7F5E9E| 1| 1| 0| 0',
        'ANTIGUA| ag.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Antigua| #B10C43| 1| 1| 0| 0',
        'ARGENTINA| ar.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Argentina| #F05610| 1| 1| 0| 0',
        'ARMENIA| am.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Armenia| #3B23BE| 1| 1| 0| 0',
        'ARUBA| aw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Aruba| #44D61B| 1| 1| 0| 0',
        'ASIA| Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Asia| #ACEC61| 1| 1| 0| 0',
        'AUSTRALIA_AND_NEW_ZEALAND| Australia and New Zealand.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Australia and New Zealand| #BAFCA5| 1| 1| 0| 0',
        'AUSTRALIAN| Australian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Australian| #50558D| 1| 1| 0| 0',
        'AUSTRALIA| au.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Australia| #D5237B| 1| 1| 0| 0',
        'AUSTRIA| at.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Austria| #F5E6AE| 1| 1| 0| 0',
        'AZERBAIJAN| az.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Azerbaijan| #DD7DBB| 1| 1| 0| 0',
        'BAHAMAS| bs.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bahamas| #F6CDF0| 1| 1| 0| 0',
        'BAHRAIN| bh.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bahrain| #A71949| 1| 1| 0| 0',
        'BALKANS| Balkans.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Balkans| #C41AA8| 1| 1| 0| 0',
        'BALKAN| Balkan.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Balkan| #48B999| 1| 1| 0| 0',
        'BANGLADESH| bd.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bangladesh| #870AD4| 1| 1| 0| 0',
        'BARBADOS| bb.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Barbados| #DCB0BF| 1| 1| 0| 0',
        'BELARUS| by.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Belarus| #429751| 1| 1| 0| 0',
        'BELGIUM| be.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Belgium| #AC98DB| 1| 1| 0| 0',
        'BELIZE| bz.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Belize| #E37BB0| 1| 1| 0| 0',
        'BENELUX| Benelux.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Benelux| #36A83E| 1| 1| 0| 0',
        'BENIN| bj.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Benin| #378A76| 1| 1| 0| 0',
        'BERMUDA| bm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bermuda| #250B48| 1| 1| 0| 0',
        'BHUTAN| bt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bhutan| #FA5F2F| 1| 1| 0| 0',
        'BOLIVIA| bo.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bolivia| #DBAD5A| 1| 1| 0| 0',
        'BONAIRE| bq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bonaire| #25394A| 1| 1| 0| 0',
        'BOSNIA_AND_HERZEGOVINA| ba.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bosnia and Herzegovina| #4B6FFB| 1| 1| 0| 0',
        'BOTSWANA| bw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Botswana| #2610C6| 1| 1| 0| 0',
        'BRAZILIAN| Brazilian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Brazilian| #BF550A| 1| 1| 0| 0',
        'BRAZIL| br.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Brazil| #EE9DA9| 1| 1| 0| 0',
        'BRUNEI| bn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Brunei| #1C6041| 1| 1| 0| 0',
        'BULGARIA| bg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bulgaria| #79AB96| 1| 1| 0| 0',
        'BURKINA_FASO| bf.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Burkina Faso| #1DCADF| 1| 1| 0| 0',
        'BURUNDI| bi.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Burundi| #283538| 1| 1| 0| 0',
        'CABO_VERDE| cv.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cabo Verde| #7F7E3F| 1| 1| 0| 0',
        'CAMBODIA| kh.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cambodia| #2CA052| 1| 1| 0| 0',
        'CAMEROON| cm.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cameroon| #A6FD37| 1| 1| 0| 0',
        'CANADA| ca.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Canada| #32DE58| 1| 1| 0| 0',
        'CANADIAN| Canadian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Canadian| #93E6D4| 1| 1| 0| 0',
        'CARIBBEAN| Caribbean.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Caribbean| #D2736B| 1| 1| 0| 0',
        'CAUCASIAN| Caucasian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Caucasian| #A738B5| 1| 1| 0| 0',
        'CAUCASUS| Caucasus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Caucasus| #37B00B| 1| 1| 0| 0',
        'CENTRAL_AFRICAN_REPUBLIC| cf.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central African Republic| #5521E1| 1| 1| 0| 0',
        'CENTRAL_AFRICAN| Central African.png| -500| 1300| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central African| #368A36| 1| 1| 0| 0',
        'CENTRAL_AFRICA| Central Africa.png| -500| 1300| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central Africa| #C3DCF9| 1| 1| 0| 0',
        'CENTRAL_AMERICA| Central America.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central America| #D4C503| 1| 1| 0| 0',
        'CENTRAL_AMERICAN| Central American.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central American| #0D2A1D| 1| 1| 0| 0',
        'CENTRAL_AMERICAS| Central Americas.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central Americas| #FDEC7B| 1| 1| 0| 0',
        'CENTRAL_ASIAN| Central Asian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central Asian| #8A8861| 1| 1| 0| 0',
        'CENTRAL_ASIA| Central Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central Asia| #83F3B0| 1| 1| 0| 0',
        'CENTRAL_EUROPEAN| Central European.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central European| #68FC75| 1| 1| 0| 0',
        'CHAD| td.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chad| #4752FF| 1| 1| 0| 0',
        'CHILE| cl.png| -500| 350| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chile| #AAC41F| 1| 1| 0| 0',
        'CHINA| cn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | China| #902A62| 1| 1| 0| 0',
        'CHINESE_AND_MONGOLIAN| Chinese and Mongolian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chinese and Mongolian| #C1549F| 1| 1| 0| 0',
        'CHRISTMAS_ISLAND| cx.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Christmas Island| #09C73E| 1| 1| 0| 0',
        'COCOS_(KEELING)_ISLANDS| cc.png| -500| 450| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cocos (Keeling) Islands| #357080| 1| 1| 0| 0',
        'COLOMBIA| co.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Colombia| #C24337| 1| 1| 0| 0',
        'COMOROS| km.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Comoros| #DC8549| 1| 1| 0| 0',
        'COSTA_RICA| cr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Costa Rica| #41F306| 1| 1| 0| 0',
        'CROATIA| hr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Croatia| #62BF53| 1| 1| 0| 0',
        'CUBA| cu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cuba| #BE71FC| 1| 1| 0| 0',
        'CURAÇAO| cw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Curaçao| #9C012D| 1| 1| 0| 0',
        'CYPRUS| cy.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cyprus| #BF5DEE| 1| 1| 0| 0',
        'CZECH_REPUBLIC| cz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Czech Republic| #9ECE8F| 1| 1| 0| 0',
        'CÔTE_DIVOIRE| ci.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Côte d''Ivoire| #70D5FC| 1| 1| 0| 0',
        'DEMOCRATIC_REPUBLIC_OF_THE_CONGO| cd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Democratic Republic of the Congo| #301A79| 1| 1| 0| 0',
        'DENMARK| dk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Denmark| #685ECB| 1| 1| 0| 0',
        'DJIBOUTI| dj.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Djibouti| #6D1F93| 1| 1| 0| 0',
        'DOMINICAN_REPUBLIC| do.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dominican Republic| #83F0A2| 1| 1| 0| 0',
        'DOMINICA| dm.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dominica| #912876| 1| 1| 0| 0',
        'EASTERN_AFRICAN| Eastern African.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern African| #E1B5B6| 1| 1| 0| 0',
        'EASTERN_AFRICA| Eastern Africa.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern Africa| #7A0C71| 1| 1| 0| 0',
        'EASTERN_ASIA| Eastern Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern Asia| #51477F| 1| 1| 0| 0',
        'EASTERN_EUROPEAN| Eastern European.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern European| #7AB6F9| 1| 1| 0| 0',
        'EASTERN_EUROPE| Eastern Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern Europe| #34509F| 1| 1| 0| 0',
        'ECUADOR| ec.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ecuador| #D2BBB1| 1| 1| 0| 0',
        'EGYPT| eg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Egypt| #86B137| 1| 1| 0| 0',
        'EL_SALVADOR| sv.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | El Salvador| #201068| 1| 1| 0| 0',
        'EQUATORIAL_GUINEA| gq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Equatorial Guinea| #BF1A15| 1| 1| 0| 0',
        'ERITREA| er.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eritrea| #738CA0| 1| 1| 0| 0',
        'ESTONIA| ee.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Estonia| #5145DA| 1| 1| 0| 0',
        'ESWATINI| sz.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eswatini| #0A361B| 1| 1| 0| 0',
        'ETHIOPIA| et.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ethiopia| #F2D585| 1| 1| 0| 0',
        'EUROPE| Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Europe| #E4B4ED| 1| 1| 0| 0',
        'FALKLAND_ISLANDS| fk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Falkland Islands| #21EB92| 1| 1| 0| 0',
        'FAROE_ISLANDS| fo.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Faroe Islands| #9F01CC| 1| 1| 0| 0',
        'FIJI| fj.png| -500| 1700| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fiji| #ABA3D5| 1| 1| 0| 0',
        'FINLAND| fi.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Finland| #856518| 1| 1| 0| 0',
        'FRANCE| fr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | France| #D0404D| 1| 1| 0| 0',
        'FRENCH_GUIANA| gf.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | French Guiana| #0FC361| 1| 1| 0| 0',
        'FRENCH_POLYNESIA| pf.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | French Polynesia| #01ED76| 1| 1| 0| 0',
        'FRENCH| French.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | French| #35EB07| 1| 1| 0| 0',
        'GABON| ga.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gabon| #C41135| 1| 1| 0| 0',
        'GAMBIA| gm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gambia| #1C71D5| 1| 1| 0| 0',
        'GEORGIA| ge.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Georgia| #9B4B36| 1| 1| 0| 0',
        'GERMANY| de.png| -500| 1400| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Germany| #97FDAE| 1| 1| 0| 0',
        'GERMAN| German.png| -500| 1400| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | German| #72FE02| 1| 1| 0| 0',
        'GHANA| gh.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ghana| #D23528| 1| 1| 0| 0',
        'GIBRALTAR| gi.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gibraltar| #4E8651| 1| 1| 0| 0',
        'GREECE| gr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Greece| #431832| 1| 1| 0| 0',
        'GREEK| Greek.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Greek| #13F909| 1| 1| 0| 0',
        'GREENLAND| gl.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Greenland| #8248B8| 1| 1| 0| 0',
        'GRENADA| gd.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Grenada| #0256EF| 1| 1| 0| 0',
        'GUADELOUPE| gp.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guadeloupe| #7BE653| 1| 1| 0| 0',
        'GUATEMALA| gt.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guatemala| #257C8C| 1| 1| 0| 0',
        'GUERNSEY| gg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guernsey| #6D81EC| 1| 1| 0| 0',
        'GUINEA-BISSAU| gw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guinea-Bissau| #D06905| 1| 1| 0| 0',
        'GUINEA| gn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guinea| #0D48F7| 1| 1| 0| 0',
        'GUYANA| gy.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guyana| #72280E| 1| 1| 0| 0',
        'HAITI| ht.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Haiti| #C16905| 1| 1| 0| 0',
        'HOLY_SEE| va.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Holy See| #9386CF| 1| 1| 0| 0',
        'HONDURAS| hn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Honduras| #2B115E| 1| 1| 0| 0',
        'HONG_KONG_AND_MACAO| Hong Kong and Macao.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hong Kong and Macao| #58ED70| 1| 1| 0| 0',
        'HONG_KONG| hk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hong Kong| #F6B541| 1| 1| 0| 0',
        'HUNGARY| hu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hungary| #E5983C| 1| 1| 0| 0',
        'IBERIAN| Iberian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iberian| #D7230B| 1| 1| 0| 0',
        'IBERIA| Iberia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iberia| #14B650| 1| 1| 0| 0',
        'ICELAND| is.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iceland| #CE31A0| 1| 1| 0| 0',
        'INDIA| in.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | India| #A6404A| 1| 1| 0| 0',
        'INDONESIA| id.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Indonesia| #3E33E4| 1| 1| 0| 0',
        'IRAN| ir.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iran| #2AAC15| 1| 1| 0| 0',
        'IRAQ| iq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iraq| #46B596| 1| 1| 0| 0',
        'IRELAND| ie.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ireland| #C6377E| 1| 1| 0| 0',
        'IRISH| Irish.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Irish| #C22C32| 1| 1| 0| 0',
        'ISLE_OF_MAN| im.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Isle of Man| #5B8465| 1| 1| 0| 0',
        'ISRAEL| il.png| -500| 650| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Israel| #41E0A9| 1| 1| 0| 0',
        'ITALIAN| Italian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Italian| #B4DA3F| 1| 1| 0| 0',
        'ITALY| it.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Italy| #57B9BF| 1| 1| 0| 0',
        'JAMAICA| jm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jamaica| #979507| 1| 1| 0| 0',
        'JAPANESE| Japanese.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Japanese| #2D4B56| 1| 1| 0| 0',
        'JAPAN| jp.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Japan| #4FCF54| 1| 1| 0| 0',
        'JERSEY| je.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jersey| #2D0B6C| 1| 1| 0| 0',
        'JORDAN| jo.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jordan| #B2B6CB| 1| 1| 0| 0',
        'KAZAKHSTAN| kz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kazakhstan| #25A869| 1| 1| 0| 0',
        'KENYA| ke.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kenya| #4C9128| 1| 1| 0| 0',
        'KIRIBATI| ki.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kiribati| #D950EE| 1| 1| 0| 0',
        'KOREAN| Korean.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Korean| #724396| 1| 1| 0| 0',
        'KOREA| kr.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Korea| #127FFE| 1| 1| 0| 0',
        'KOSOVO| kosovo.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kosovo| #6A50B1| 1| 1| 0| 0',
        'KUWAIT| kw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kuwait| #4DC94B| 1| 1| 0| 0',
        'KYRGYZSTAN| kg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kyrgyzstan| #25EA7B| 1| 1| 0| 0',
        'LAOS| la.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Laos| #DDC651| 1| 1| 0| 0',
        'LATIN_AMERICA| latin america.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Latin America| #3785B6| 1| 1| 0| 0',
        'LATVIA| lv.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Latvia| #5326A3| 1| 1| 0| 0',
        'LEBANON| lb.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lebanon| #C9C826| 1| 1| 0| 0',
        'LESOTHO| ls.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lesotho| #8337E7| 1| 1| 0| 0',
        'LIBERIA| lr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Liberia| #E07AE0| 1| 1| 0| 0',
        'LIBYA| ly.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Libya| #08D150| 1| 1| 0| 0',
        'LIECHTENSTEIN| li.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Liechtenstein| #32725A| 1| 1| 0| 0',
        'LITHUANIA| lt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lithuania| #215819| 1| 1| 0| 0',
        'LUXEMBOURG| lu.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Luxembourg| #C90586| 1| 1| 0| 0',
        'MACAO| mo.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Macao| #6E8D6D| 1| 1| 0| 0',
        'NORTH_MACEDONIA| mk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | North Macedonia| #9636FC| 1| 1| 0| 0',
        'MADAGASCAR| mg.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Madagascar| #1D1556| 1| 1| 0| 0',
        'MALAWI| mw.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Malawi| #988B47| 1| 1| 0| 0',
        'MALAYSIA| my.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Malaysia| #9630B4| 1| 1| 0| 0',
        'MALDIVES| mv.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Maldives| #E71FD4| 1| 1| 0| 0',
        'MALI| ml.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mali| #A254BD| 1| 1| 0| 0',
        'MALTA| mt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Malta| #DB6EC4| 1| 1| 0| 0',
        'MARTINIQUE| mq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Martinique| #2135EC| 1| 1| 0| 0',
        'MAURITANIA| mr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mauritania| #24C888| 1| 1| 0| 0',
        'MAURITIUS| mu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mauritius| #4F51A6| 1| 1| 0| 0',
        'MELANESIA| Melanesia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Melanesia| #F3A910| 1| 1| 0| 0',
        'MEXICAN| Mexican.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mexican| #74F02B| 1| 1| 0| 0',
        'MEXICO| mx.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mexico| #964F76| 1| 1| 0| 0',
        'MICRONESIA| Micronesia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Micronesia| #ED26F3| 1| 1| 0| 0',
        'MIDDLE_EASTERN| Middle Eastern.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Middle Eastern| #A39F2D| 1| 1| 0| 0',
        'MIDDLE_EAST| Middle East.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Middle East| #6DA8D3| 1| 1| 0| 0',
        'MOLDOVA| md.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Moldova| #8680C6| 1| 1| 0| 0',
        'MONACO| mc.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Monaco| #766F22| 1| 1| 0| 0',
        'MONGOLIA| mn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mongolia| #AC2354| 1| 1| 0| 0',
        'MONTENEGRO| me.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Montenegro| #609861| 1| 1| 0| 0',
        'MONTSERRAT| ms.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Montserrat| #443C5D| 1| 1| 0| 0',
        'MOROCCO| ma.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Morocco| #B28BDC| 1| 1| 0| 0',
        'MOZAMBIQUE| mz.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mozambique| #8CF4CF| 1| 1| 0| 0',
        'MYANMAR| mm.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Myanmar| #B1E9E2| 1| 1| 0| 0',
        'NAMIBIA| na.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Namibia| #C43E0A| 1| 1| 0| 0',
        'NEPAL| np.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nepal| #3F847B| 1| 1| 0| 0',
        'NETHERLANDS| nl.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Netherlands| #B14FAA| 1| 1| 0| 0',
        'NEW_CALEDONIA| nc.png| -500| 1700| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | New Caledonia| #2464FE| 1| 1| 0| 0',
        'NEW_ZEALAND| nz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | New Zealand| #E0A486| 1| 1| 0| 0',
        'NICARAGUA| ni.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nicaragua| #2B20F9| 1| 1| 0| 0',
        'NIGERIA| ng.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nigeria| #4113B6| 1| 1| 0| 0',
        'NIGER| ne.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Niger| #74A28E| 1| 1| 0| 0',
        'NORDIC| Nordic.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nordic| #A12398| 1| 1| 0| 0',
        'NORTHERN_AFRICAN| Northern African.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Northern African| #C7E021| 1| 1| 0| 0',
        'NORTHERN_AFRICA| Northern Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Northern Africa| #175190| 1| 1| 0| 0',
        'NORTHERN_AMERICA| Northern America.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Northern America| #210794| 1| 1| 0| 0',
        'NORTH_AMERICA| North America.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | North America| #65E95D| 1| 1| 0| 0',
        'NORTHERN_EUROPE| Northern Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Northern Europe| #3E23F6| 1| 1| 0| 0',
        'NORWAY| no.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Norway| #AC320E| 1| 1| 0| 0',
        'OCEANIA| Oceania.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Oceania| #CCB503| 1| 1| 0| 0',
        'OMAN| om.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Oman| #908B45| 1| 1| 0| 0',
        'PACIFIC_ISLANDS| Pacific Islands.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pacific Islands| #34D3BD| 1| 1| 0| 0',
        'PACIFIC_ISLAND| Pacific Island.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pacific Island| #D8FF8E| 1| 1| 0| 0',
        'PAKISTAN| pk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pakistan| #6FF34E| 1| 1| 0| 0',
        'PALAU| pw.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Palau| #805BA6| 1| 1| 0| 0',
        'PALESTINE| ps.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Palestine| #37089C| 1| 1| 0| 0',
        'PANAMA| pa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Panama| #417818| 1| 1| 0| 0',
        'PAPUA_NEW_GUINEA| pg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Papua New Guinea| #318DF8| 1| 1| 0| 0',
        'PARAGUAY| py.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paraguay| #711CB1| 1| 1| 0| 0',
        'PERU| pe.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Peru| #803704| 1| 1| 0| 0',
        'PHILIPPINES| ph.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Philippines| #2DF423| 1| 1| 0| 0',
        'POLAND| pl.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Poland| #BAF6C2| 1| 1| 0| 0',
        'POLYNESIA| Polynesia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Polynesia| #6DDCA0| 1| 1| 0| 0',
        'PORTUGAL| pt.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Portugal| #A1DE3F| 1| 1| 0| 0',
        'PUERTO_RICO| pr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Puerto Rico| #48ED66| 1| 1| 0| 0',
        'QATAR| qa.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Qatar| #4C1FCC| 1| 1| 0| 0',
        'REPUBLIC_OF_THE_CONGO| cg.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Republic of the Congo| #9D3C85| 1| 1| 0| 0',
        'SAINT_PIERRE_AND_MIQUELON| pm.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saint Pierre and Miquelon| #29C4C6| 1| 1| 0| 0',        
        'CAYMAN_ISLANDS| ky.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cayman Islands| #9589CC| 1| 1| 0| 0',        
        'RÉUNION| re.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Réunion| #502892| 1| 1| 0| 0',
        'ROMANIA| ro.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Romania| #ABD0CF| 1| 1| 0| 0',
        'RUSSIAN| Russian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Russian| #05C9B6| 1| 1| 0| 0',
        'RUSSIA| ru.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Russia| #97D820| 1| 1| 0| 0',
        'RWANDA| rw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Rwanda| #C5D47C| 1| 1| 0| 0',
        'SAINT_BARTHÉLEMY| bl.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saint Barthélemy| #AC3F43| 1| 1| 0| 0',
        'SAINT_KITTS_AND_NEVIS| lc.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saint Kitts and Nevis| #918BFE| 1| 1| 0| 0',
        'SAINT_LUCIA| lc.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saint Lucia| #C97D38| 1| 1| 0| 0',
        'SAMOA| ws.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Samoa| #7789CB| 1| 1| 0| 0',
        'SAN_MARINO| sm.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | San Marino| #B9A87E| 1| 1| 0| 0',
        'SAO_TOME_AND_PRINCIPE| st.png| -500| 1100| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sao Tome and Principe| #2EC918| 1| 1| 0| 0',
        'SAUDI_ARABIA| sa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saudi Arabia| #D34B83| 1| 1| 0| 0',
        'SENEGAL| sn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Senegal| #233F74| 1| 1| 0| 0',
        'SERBIA| rs.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Serbia| #7E0D8E| 1| 1| 0| 0',
        'SEYCHELLES| sc.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Seychelles| #18759E| 1| 1| 0| 0',
        'SIERRA_LEONE| sl.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sierra Leone| #0E4C79| 1| 1| 0| 0',
        'SINGAPORE| sg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Singapore| #0328DB| 1| 1| 0| 0',
        'SLOVAKIA| sk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Slovakia| #04447C| 1| 1| 0| 0',
        'SLOVENIA| si.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Slovenia| #36050D| 1| 1| 0| 0',
        'SOLOMON_ISLANDS| sb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Solomon Islands| #C8DC56| 1| 1| 0| 0',
        'SOMALIA| so.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Somalia| #F8DF1D| 1| 1| 0| 0',
        'SOUTH-EAST_ASIAN| South-East Asian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South-East Asian| #2B0DE1| 1| 1| 0| 0',
        'SOUTH-EAST_ASIA| South-East Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South-East Asia| #C7868C| 1| 1| 0| 0',
        'SOUTHERN_AFRICAN| Southern African.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern African| #6003D5| 1| 1| 0| 0',
        'SOUTHERN_AFRICA| Southern Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern Africa| #5CFEDC| 1| 1| 0| 0',
        'SOUTHERN_CONE| Southern Cone.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern Cone| #B68D1D| 1| 1| 0| 0',
        'SOUTH_AFRICA| za.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Africa| #E7BB4A| 1| 1| 0| 0',
        'SOUTH_AMERICA| South America.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South America| #9EDFF8| 1| 1| 0| 0',
        'SOUTH_ASIAN| South Asian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Asian| #6AF106| 1| 1| 0| 0',
        'SOUTH_ASIA| South Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Asia| #D09F06| 1| 1| 0| 0',
        'SOUTH_SUDAN| ss.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Sudan| #D4A4C5| 1| 1| 0| 0',
        'SOUTHEASTERN_ASIA| South-Eastern Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South-Eastern Asia| #276841| 1| 1| 0| 0',
        'SOUTHERN_ASIA| Southern Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern Asia| #757D90| 1| 1| 0| 0',
        'SOUTHERN_EUROPE| Southern Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern Europe| #2F51DF| 1| 1| 0| 0',
        'SPAIN| es.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spain| #99DA4B| 1| 1| 0| 0',
        'NORTH_KOREA| kp.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | North Korea| #9CACBF| 1| 1| 0| 0',
        'SOUTH_KOREA| kr.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Korea| #127FFE| 1| 1| 0| 0',
        'SRI_LANKA| lk.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sri Lanka| #6415FD| 1| 1| 0| 0',
        'SUB-SAHARAN_AFRICA| Sub-Saharan Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sub-Saharan Africa| #E87D39| 1| 1| 0| 0',
        'SUDAN| sd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sudan| #F877E4| 1| 1| 0| 0',
        'SURINAME| sr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Suriname| #4647C5| 1| 1| 0| 0',
        'SVALBARD_AND_JAN_MAYEN| sj.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Svalbard and Jan Mayen| #10CACA| 1| 1| 0| 0',
        'SWEDEN| se.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sweden| #E3C61A| 1| 1| 0| 0',
        'SWITZERLAND| ch.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Switzerland| #5803F1| 1| 1| 0| 0',
        'SYRIA| sy.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Syria| #E6CD56| 1| 1| 0| 0',
        'TAIWANESE| Taiwanese.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Taiwanese| #66872B| 1| 1| 0| 0',
        'TAIWAN| tw.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Taiwan| #ABE3E0| 1| 1| 0| 0',
        'TAJIKISTAN| tj.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tajikistan| #94F7D2| 1| 1| 0| 0',
        'TANZANIA| tz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tanzania| #E80290| 1| 1| 0| 0',
        'THAILAND| th.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Thailand| #32DBD9| 1| 1| 0| 0',
        'TIMOR-LESTE| tl.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Timor-Leste| #FEE0EF| 1| 1| 0| 0',
        'TOGO| tg.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Togo| #2940B7| 1| 1| 0| 0',
        'TONGA| to.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tonga| #08313F| 1| 1| 0| 0',
        'TRINIDAD_AND_TOBAGO| tt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trinidad and Tobago| #4AD42A| 1| 1| 0| 0',
        'TUNISIA| tn.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tunisia| #CBC6CC| 1| 1| 0| 0',
        'TURKEY| tr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Turkey| #CD90D1| 1| 1| 0| 0',
        'TURKMENISTAN| tm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Turkmenistan| #FC3E09| 1| 1| 0| 0',
        'TURKS_AND_CAICOS_ISLANDS| tc.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Turks and Caicos Islands| #B130FF| 1| 1| 0| 0',
        'UGANDA| ug.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Uganda| #27E46C| 1| 1| 0| 0',
        'UKRAINE| ua.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ukraine| #1640B6| 1| 1| 0| 0',
        'UK| UK.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | UK| #121D0A| 1| 1| 0| 0',
        'UNITED_ARAB_EMIRATES| ae.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United Arab Emirates| #BC9C16| 1| 1| 0| 0',
        'UNITED_KINGDOM| gb.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United Kingdom| #C7B89D| 1| 1| 0| 0',
        'UNITED_STATES_OF_AMERICA| us.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United States of America| #D2A345| 1| 1| 0| 0',
        'UNITED_STATES| us.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United States| #D2A345| 1| 1| 0| 0',
        'URUGUAY| uy.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Uruguay| #D59CC1| 1| 1| 0| 0',
        'USA| USA.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | USA| #CA9B8E| 1| 1| 0| 0',
        'UZBEKISTAN| uz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Uzbekistan| #9115AF| 1| 1| 0| 0',
        'VANUATU| vu.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Vanuatu| #694F3D| 1| 1| 0| 0',
        'VENEZUELA| ve.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Venezuela| #38FCA6| 1| 1| 0| 0',
        'VIETNAM| vn.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Vietnam| #19156E| 1| 1| 0| 0',
        'WESTERN_AFRICAN| Western African.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western African| #9F878C| 1| 1| 0| 0',
        'WESTERN_AFRICA| Western Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western Africa| #C85C78| 1| 1| 0| 0',
        'WESTERN_ASIA| Western Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western Asia| #1BE9AC| 1| 1| 0| 0',
        'WESTERN_EUROPE| Western Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western Europe| #875222| 1| 1| 0| 0',
        'YEMEN| ye.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Yemen| #A19DD9| 1| 1| 0| 0',
        'ZAMBIA| zm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zambia| #AB1780| 1| 1| 0| 0',
        'ZIMBABWE| zw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zimbabwe| #A44C98| 1| 1| 0| 0',
        'ÅLAND_ISLANDS| ax.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Åland Islands| #B7E412| 1| 1| 0| 0'
        ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination country\color

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'AFGHANISTAN| af.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Afghanistan| #831F36| 1| 1| 0| 1',
        'AFRICA| Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Africa| #158B0A| 1| 1| 0| 1',
        'ALBANIA| al.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Albania| #D889BF| 1| 1| 0| 1',
        'ALGERIA| dz.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Algeria| #F731AB| 1| 1| 0| 1',
        'ANDEAN| Andean.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Andean| #BFEFDF| 1| 1| 0| 1',
        'AMERICAS| Americas.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Americas| #00BFFF| 1| 1| 0| 1',
        'ANDORRA| ad.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Andorra| #0DB2F4| 1| 1| 0| 1',
        'ANGOLA| ao.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Angola| #618274| 1| 1| 0| 1',
        'ANGUILLA| ai.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Anguilla| #BC9090| 1| 1| 0| 1',
        'ANTARCTICA_REGION| Antarctica Region.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Antarctica Region| #E01CD8| 1| 1| 0| 1',
        'ANTARCTICA| aq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Antarctica| #7F5E9E| 1| 1| 0| 1',
        'ANTIGUA| ag.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Antigua| #B10C43| 1| 1| 0| 1',
        'ARGENTINA| ar.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Argentina| #F05610| 1| 1| 0| 1',
        'ARMENIA| am.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Armenia| #3B23BE| 1| 1| 0| 1',
        'ARUBA| aw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Aruba| #44D61B| 1| 1| 0| 1',
        'ASIA| Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Asia| #ACEC61| 1| 1| 0| 1',
        'AUSTRALIA_AND_NEW_ZEALAND| Australia and New Zealand.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Australia and New Zealand| #BAFCA5| 1| 1| 0| 1',
        'AUSTRALIAN| Australian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Australian| #50558D| 1| 1| 0| 1',
        'AUSTRALIA| au.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Australia| #D5237B| 1| 1| 0| 1',
        'AUSTRIA| at.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Austria| #F5E6AE| 1| 1| 0| 1',
        'AZERBAIJAN| az.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Azerbaijan| #DD7DBB| 1| 1| 0| 1',
        'BAHAMAS| bs.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bahamas| #F6CDF0| 1| 1| 0| 1',
        'BAHRAIN| bh.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bahrain| #A71949| 1| 1| 0| 1',
        'BALKANS| Balkans.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Balkans| #C41AA8| 1| 1| 0| 1',
        'BALKAN| Balkan.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Balkan| #48B999| 1| 1| 0| 1',
        'BANGLADESH| bd.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bangladesh| #870AD4| 1| 1| 0| 1',
        'BARBADOS| bb.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Barbados| #DCB0BF| 1| 1| 0| 1',
        'BELARUS| by.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Belarus| #429751| 1| 1| 0| 1',
        'BELGIUM| be.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Belgium| #AC98DB| 1| 1| 0| 1',
        'BELIZE| bz.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Belize| #E37BB0| 1| 1| 0| 1',
        'BENELUX| Benelux.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Benelux| #36A83E| 1| 1| 0| 1',
        'BENIN| bj.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Benin| #378A76| 1| 1| 0| 1',
        'BERMUDA| bm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bermuda| #250B48| 1| 1| 0| 1',
        'BHUTAN| bt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bhutan| #FA5F2F| 1| 1| 0| 1',
        'BOLIVIA| bo.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bolivia| #DBAD5A| 1| 1| 0| 1',
        'BONAIRE| bq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bonaire| #25394A| 1| 1| 0| 1',
        'BOSNIA_AND_HERZEGOVINA| ba.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bosnia and Herzegovina| #4B6FFB| 1| 1| 0| 1',
        'BOTSWANA| bw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Botswana| #2610C6| 1| 1| 0| 1',
        'BRAZILIAN| Brazilian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Brazilian| #BF550A| 1| 1| 0| 1',
        'BRAZIL| br.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Brazil| #EE9DA9| 1| 1| 0| 1',
        'BRUNEI| bn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Brunei| #1C6041| 1| 1| 0| 1',
        'BULGARIA| bg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bulgaria| #79AB96| 1| 1| 0| 1',
        'BURKINA_FASO| bf.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Burkina Faso| #1DCADF| 1| 1| 0| 1',
        'BURUNDI| bi.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Burundi| #283538| 1| 1| 0| 1',
        'CABO_VERDE| cv.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cabo Verde| #7F7E3F| 1| 1| 0| 1',
        'CAMBODIA| kh.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cambodia| #2CA052| 1| 1| 0| 1',
        'CAMEROON| cm.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cameroon| #A6FD37| 1| 1| 0| 1',
        'CANADA| ca.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Canada| #32DE58| 1| 1| 0| 1',
        'CANADIAN| Canadian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Canadian| #93E6D4| 1| 1| 0| 1',
        'CARIBBEAN| Caribbean.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Caribbean| #D2736B| 1| 1| 0| 1',
        'CAUCASIAN| Caucasian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Caucasian| #A738B5| 1| 1| 0| 1',
        'CAUCASUS| Caucasus.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Caucasus| #37B00B| 1| 1| 0| 1',
        'CENTRAL_AFRICAN_REPUBLIC| cf.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central African Republic| #5521E1| 1| 1| 0| 1',
        'CENTRAL_AFRICAN| Central African.png| -500| 1300| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central African| #368A36| 1| 1| 0| 1',
        'CENTRAL_AFRICA| Central Africa.png| -500| 1300| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central Africa| #C3DCF9| 1| 1| 0| 1',
        'CENTRAL_AMERICA| Central America.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central America| #D4C503| 1| 1| 0| 1',
        'CENTRAL_AMERICAN| Central American.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central American| #0D2A1D| 1| 1| 0| 1',
        'CENTRAL_AMERICAS| Central Americas.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central Americas| #FDEC7B| 1| 1| 0| 1',
        'CENTRAL_ASIAN| Central Asian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central Asian| #8A8861| 1| 1| 0| 1',
        'CENTRAL_ASIA| Central Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central Asia| #83F3B0| 1| 1| 0| 1',
        'CENTRAL_EUROPEAN| Central European.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Central European| #68FC75| 1| 1| 0| 1',
        'CHAD| td.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chad| #4752FF| 1| 1| 0| 1',
        'CHILE| cl.png| -500| 350| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chile| #AAC41F| 1| 1| 0| 1',
        'CHINA| cn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | China| #902A62| 1| 1| 0| 1',
        'CHINESE_AND_MONGOLIAN| Chinese and Mongolian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chinese and Mongolian| #C1549F| 1| 1| 0| 1',
        'CHRISTMAS_ISLAND| cx.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Christmas Island| #09C73E| 1| 1| 0| 1',
        'COCOS_(KEELING)_ISLANDS| cc.png| -500| 450| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cocos (Keeling) Islands| #357080| 1| 1| 0| 1',
        'COLOMBIA| co.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Colombia| #C24337| 1| 1| 0| 1',
        'COMOROS| km.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Comoros| #DC8549| 1| 1| 0| 1',
        'COSTA_RICA| cr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Costa Rica| #41F306| 1| 1| 0| 1',
        'CROATIA| hr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Croatia| #62BF53| 1| 1| 0| 1',
        'CUBA| cu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cuba| #BE71FC| 1| 1| 0| 1',
        'CURAÇAO| cw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Curaçao| #9C012D| 1| 1| 0| 1',
        'CYPRUS| cy.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cyprus| #BF5DEE| 1| 1| 0| 1',
        'CZECH_REPUBLIC| cz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Czech Republic| #9ECE8F| 1| 1| 0| 1',
        'CÔTE_DIVOIRE| ci.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Côte d''Ivoire| #70D5FC| 1| 1| 0| 1',
        'DEMOCRATIC_REPUBLIC_OF_THE_CONGO| cd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Democratic Republic of the Congo| #301A79| 1| 1| 0| 1',
        'DENMARK| dk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Denmark| #685ECB| 1| 1| 0| 1',
        'DJIBOUTI| dj.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Djibouti| #6D1F93| 1| 1| 0| 1',
        'DOMINICAN_REPUBLIC| do.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dominican Republic| #83F0A2| 1| 1| 0| 1',
        'DOMINICA| dm.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dominica| #912876| 1| 1| 0| 1',
        'EASTERN_AFRICAN| Eastern African.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern African| #E1B5B6| 1| 1| 0| 1',
        'EASTERN_AFRICA| Eastern Africa.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern Africa| #7A0C71| 1| 1| 0| 1',
        'EASTERN_ASIA| Eastern Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern Asia| #51477F| 1| 1| 0| 1',
        'EASTERN_EUROPEAN| Eastern European.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern European| #7AB6F9| 1| 1| 0| 1',
        'EASTERN_EUROPE| Eastern Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eastern Europe| #34509F| 1| 1| 0| 1',
        'ECUADOR| ec.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ecuador| #D2BBB1| 1| 1| 0| 1',
        'EGYPT| eg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Egypt| #86B137| 1| 1| 0| 1',
        'EL_SALVADOR| sv.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | El Salvador| #201068| 1| 1| 0| 1',
        'EQUATORIAL_GUINEA| gq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Equatorial Guinea| #BF1A15| 1| 1| 0| 1',
        'ERITREA| er.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eritrea| #738CA0| 1| 1| 0| 1',
        'ESTONIA| ee.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Estonia| #5145DA| 1| 1| 0| 1',
        'ESWATINI| sz.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eswatini| #0A361B| 1| 1| 0| 1',
        'ETHIOPIA| et.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ethiopia| #F2D585| 1| 1| 0| 1',
        'EUROPE| Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Europe| #E4B4ED| 1| 1| 0| 1',
        'FALKLAND_ISLANDS| fk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Falkland Islands| #21EB92| 1| 1| 0| 1',
        'FAROE_ISLANDS| fo.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Faroe Islands| #9F01CC| 1| 1| 0| 1',
        'FIJI| fj.png| -500| 1700| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fiji| #ABA3D5| 1| 1| 0| 1',
        'FINLAND| fi.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Finland| #856518| 1| 1| 0| 1',
        'FRANCE| fr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | France| #D0404D| 1| 1| 0| 1',
        'FRENCH_GUIANA| gf.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | French Guiana| #0FC361| 1| 1| 0| 1',
        'FRENCH_POLYNESIA| pf.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | French Polynesia| #01ED76| 1| 1| 0| 1',
        'FRENCH| French.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | French| #35EB07| 1| 1| 0| 1',
        'GABON| ga.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gabon| #C41135| 1| 1| 0| 1',
        'GAMBIA| gm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gambia| #1C71D5| 1| 1| 0| 1',
        'GEORGIA| ge.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Georgia| #9B4B36| 1| 1| 0| 1',
        'GERMANY| de.png| -500| 1400| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Germany| #97FDAE| 1| 1| 0| 1',
        'GERMAN| German.png| -500| 1400| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | German| #72FE02| 1| 1| 0| 1',
        'GHANA| gh.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ghana| #D23528| 1| 1| 0| 1',
        'GIBRALTAR| gi.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gibraltar| #4E8651| 1| 1| 0| 1',
        'GREECE| gr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Greece| #431832| 1| 1| 0| 1',
        'GREEK| Greek.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Greek| #13F909| 1| 1| 0| 1',
        'GREENLAND| gl.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Greenland| #8248B8| 1| 1| 0| 1',
        'GRENADA| gd.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Grenada| #0256EF| 1| 1| 0| 1',
        'GUADELOUPE| gp.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guadeloupe| #7BE653| 1| 1| 0| 1',
        'GUATEMALA| gt.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guatemala| #257C8C| 1| 1| 0| 1',
        'GUERNSEY| gg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guernsey| #6D81EC| 1| 1| 0| 1',
        'GUINEA-BISSAU| gw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guinea-Bissau| #D06905| 1| 1| 0| 1',
        'GUINEA| gn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guinea| #0D48F7| 1| 1| 0| 1',
        'GUYANA| gy.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guyana| #72280E| 1| 1| 0| 1',
        'HAITI| ht.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Haiti| #C16905| 1| 1| 0| 1',
        'HOLY_SEE| va.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Holy See| #9386CF| 1| 1| 0| 1',
        'HONDURAS| hn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Honduras| #2B115E| 1| 1| 0| 1',
        'HONG_KONG_AND_MACAO| Hong Kong and Macao.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hong Kong and Macao| #58ED70| 1| 1| 0| 1',
        'HONG_KONG| hk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hong Kong| #F6B541| 1| 1| 0| 1',
        'HUNGARY| hu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hungary| #E5983C| 1| 1| 0| 1',
        'IBERIAN| Iberian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iberian| #D7230B| 1| 1| 0| 1',
        'IBERIA| Iberia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iberia| #14B650| 1| 1| 0| 1',
        'ICELAND| is.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iceland| #CE31A0| 1| 1| 0| 1',
        'INDIA| in.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | India| #A6404A| 1| 1| 0| 1',
        'INDONESIA| id.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Indonesia| #3E33E4| 1| 1| 0| 1',
        'IRAN| ir.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iran| #2AAC15| 1| 1| 0| 1',
        'IRAQ| iq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Iraq| #46B596| 1| 1| 0| 1',
        'IRELAND| ie.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ireland| #C6377E| 1| 1| 0| 1',
        'IRISH| Irish.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Irish| #C22C32| 1| 1| 0| 1',
        'ISLE_OF_MAN| im.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Isle of Man| #5B8465| 1| 1| 0| 1',
        'ISRAEL| il.png| -500| 650| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Israel| #41E0A9| 1| 1| 0| 1',
        'ITALIAN| Italian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Italian| #B4DA3F| 1| 1| 0| 1',
        'ITALY| it.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Italy| #57B9BF| 1| 1| 0| 1',
        'JAMAICA| jm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jamaica| #979507| 1| 1| 0| 1',
        'JAPANESE| Japanese.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Japanese| #2D4B56| 1| 1| 0| 1',
        'JAPAN| jp.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Japan| #4FCF54| 1| 1| 0| 1',
        'JERSEY| je.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jersey| #2D0B6C| 1| 1| 0| 1',
        'JORDAN| jo.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jordan| #B2B6CB| 1| 1| 0| 1',
        'KAZAKHSTAN| kz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kazakhstan| #25A869| 1| 1| 0| 1',
        'KENYA| ke.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kenya| #4C9128| 1| 1| 0| 1',
        'KIRIBATI| ki.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kiribati| #D950EE| 1| 1| 0| 1',
        'KOREAN| Korean.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Korean| #724396| 1| 1| 0| 1',
        'KOREA| kr.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Korea| #127FFE| 1| 1| 0| 1',
        'KOSOVO| kosovo.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kosovo| #6A50B1| 1| 1| 0| 1',
        'KUWAIT| kw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kuwait| #4DC94B| 1| 1| 0| 1',
        'KYRGYZSTAN| kg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kyrgyzstan| #25EA7B| 1| 1| 0| 1',
        'LAOS| la.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Laos| #DDC651| 1| 1| 0| 1',
        'LATIN_AMERICA| latin america.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Latin America| #3785B6| 1| 1| 0| 1',
        'LATVIA| lv.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Latvia| #5326A3| 1| 1| 0| 1',
        'LEBANON| lb.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lebanon| #C9C826| 1| 1| 0| 1',
        'LESOTHO| ls.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lesotho| #8337E7| 1| 1| 0| 1',
        'LIBERIA| lr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Liberia| #E07AE0| 1| 1| 0| 1',
        'LIBYA| ly.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Libya| #08D150| 1| 1| 0| 1',
        'LIECHTENSTEIN| li.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Liechtenstein| #32725A| 1| 1| 0| 1',
        'LITHUANIA| lt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lithuania| #215819| 1| 1| 0| 1',
        'LUXEMBOURG| lu.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Luxembourg| #C90586| 1| 1| 0| 1',
        'MACAO| mo.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Macao| #6E8D6D| 1| 1| 0| 1',
        'NORTH_MACEDONIA| mk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | North Macedonia| #9636FC| 1| 1| 0| 1',
        'MADAGASCAR| mg.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Madagascar| #1D1556| 1| 1| 0| 1',
        'MALAWI| mw.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Malawi| #988B47| 1| 1| 0| 1',
        'MALAYSIA| my.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Malaysia| #9630B4| 1| 1| 0| 1',
        'MALDIVES| mv.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Maldives| #E71FD4| 1| 1| 0| 1',
        'MALI| ml.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mali| #A254BD| 1| 1| 0| 1',
        'MALTA| mt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Malta| #DB6EC4| 1| 1| 0| 1',
        'MARTINIQUE| mq.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Martinique| #2135EC| 1| 1| 0| 1',
        'MAURITANIA| mr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mauritania| #24C888| 1| 1| 0| 1',
        'MAURITIUS| mu.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mauritius| #4F51A6| 1| 1| 0| 1',
        'MELANESIA| Melanesia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Melanesia| #F3A910| 1| 1| 0| 1',
        'MEXICAN| Mexican.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mexican| #74F02B| 1| 1| 0| 1',
        'MEXICO| mx.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mexico| #964F76| 1| 1| 0| 1',
        'MICRONESIA| Micronesia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Micronesia| #ED26F3| 1| 1| 0| 1',
        'MIDDLE_EASTERN| Middle Eastern.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Middle Eastern| #A39F2D| 1| 1| 0| 1',
        'MIDDLE_EAST| Middle East.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Middle East| #6DA8D3| 1| 1| 0| 1',
        'MOLDOVA| md.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Moldova| #8680C6| 1| 1| 0| 1',
        'MONACO| mc.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Monaco| #766F22| 1| 1| 0| 1',
        'MONGOLIA| mn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mongolia| #AC2354| 1| 1| 0| 1',
        'MONTENEGRO| me.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Montenegro| #609861| 1| 1| 0| 1',
        'MONTSERRAT| ms.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Montserrat| #443C5D| 1| 1| 0| 1',
        'MOROCCO| ma.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Morocco| #B28BDC| 1| 1| 0| 1',
        'MOZAMBIQUE| mz.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mozambique| #8CF4CF| 1| 1| 0| 1',
        'MYANMAR| mm.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Myanmar| #B1E9E2| 1| 1| 0| 1',
        'NAMIBIA| na.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Namibia| #C43E0A| 1| 1| 0| 1',
        'NEPAL| np.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nepal| #3F847B| 1| 1| 0| 1',
        'NETHERLANDS| nl.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Netherlands| #B14FAA| 1| 1| 0| 1',
        'NEW_CALEDONIA| nc.png| -500| 1700| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | New Caledonia| #2464FE| 1| 1| 0| 1',
        'NEW_ZEALAND| nz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | New Zealand| #E0A486| 1| 1| 0| 1',
        'NICARAGUA| ni.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nicaragua| #2B20F9| 1| 1| 0| 1',
        'NIGERIA| ng.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nigeria| #4113B6| 1| 1| 0| 1',
        'NIGER| ne.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Niger| #74A28E| 1| 1| 0| 1',
        'NORDIC| Nordic.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nordic| #A12398| 1| 1| 0| 1',
        'NORTHERN_AFRICAN| Northern African.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Northern African| #C7E021| 1| 1| 0| 1',
        'NORTHERN_AFRICA| Northern Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Northern Africa| #175190| 1| 1| 0| 1',
        'NORTHERN_AMERICA| Northern America.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Northern America| #210794| 1| 1| 0| 1',
        'NORTH_AMERICA| North America.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | North America| #65E95D| 1| 1| 0| 1',
        'NORTHERN_EUROPE| Northern Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Northern Europe| #3E23F6| 1| 1| 0| 1',
        'NORWAY| no.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Norway| #AC320E| 1| 1| 0| 1',
        'OCEANIA| Oceania.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Oceania| #CCB503| 1| 1| 0| 1',
        'OMAN| om.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Oman| #908B45| 1| 1| 0| 1',
        'PACIFIC_ISLANDS| Pacific Islands.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pacific Islands| #34D3BD| 1| 1| 0| 1',
        'PACIFIC_ISLAND| Pacific Island.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pacific Island| #D8FF8E| 1| 1| 0| 1',
        'PAKISTAN| pk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pakistan| #6FF34E| 1| 1| 0| 1',
        'PALAU| pw.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Palau| #805BA6| 1| 1| 0| 1',
        'PALESTINE| ps.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Palestine| #37089C| 1| 1| 0| 1',
        'PANAMA| pa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Panama| #417818| 1| 1| 0| 1',
        'PAPUA_NEW_GUINEA| pg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Papua New Guinea| #318DF8| 1| 1| 0| 1',
        'PARAGUAY| py.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paraguay| #711CB1| 1| 1| 0| 1',
        'PERU| pe.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Peru| #803704| 1| 1| 0| 1',
        'PHILIPPINES| ph.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Philippines| #2DF423| 1| 1| 0| 1',
        'POLAND| pl.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Poland| #BAF6C2| 1| 1| 0| 1',
        'POLYNESIA| Polynesia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Polynesia| #6DDCA0| 1| 1| 0| 1',
        'PORTUGAL| pt.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Portugal| #A1DE3F| 1| 1| 0| 1',
        'PUERTO_RICO| pr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Puerto Rico| #48ED66| 1| 1| 0| 1',
        'QATAR| qa.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Qatar| #4C1FCC| 1| 1| 0| 1',
        'REPUBLIC_OF_THE_CONGO| cg.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Republic of the Congo| #9D3C85| 1| 1| 0| 1',
        'SAINT_PIERRE_AND_MIQUELON| pm.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saint Pierre and Miquelon| #29C4C6| 1| 1| 0| 1',        
        'CAYMAN_ISLANDS| ky.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cayman Islands| #9589CC| 1| 1| 0| 1',        
        'RÉUNION| re.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Réunion| #502892| 1| 1| 0| 1',
        'ROMANIA| ro.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Romania| #ABD0CF| 1| 1| 0| 1',
        'RUSSIAN| Russian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Russian| #05C9B6| 1| 1| 0| 1',
        'RUSSIA| ru.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Russia| #97D820| 1| 1| 0| 1',
        'RWANDA| rw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Rwanda| #C5D47C| 1| 1| 0| 1',
        'SAINT_BARTHÉLEMY| bl.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saint Barthélemy| #AC3F43| 1| 1| 0| 1',
        'SAINT_KITTS_AND_NEVIS| lc.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saint Kitts and Nevis| #918BFE| 1| 1| 0| 1',
        'SAINT_LUCIA| lc.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saint Lucia| #C97D38| 1| 1| 0| 1',
        'SAMOA| ws.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Samoa| #7789CB| 1| 1| 0| 1',
        'SAN_MARINO| sm.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | San Marino| #B9A87E| 1| 1| 0| 1',
        'SAO_TOME_AND_PRINCIPE| st.png| -500| 1100| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sao Tome and Principe| #2EC918| 1| 1| 0| 1',
        'SAUDI_ARABIA| sa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saudi Arabia| #D34B83| 1| 1| 0| 1',
        'SENEGAL| sn.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Senegal| #233F74| 1| 1| 0| 1',
        'SERBIA| rs.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Serbia| #7E0D8E| 1| 1| 0| 1',
        'SEYCHELLES| sc.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Seychelles| #18759E| 1| 1| 0| 1',
        'SIERRA_LEONE| sl.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sierra Leone| #0E4C79| 1| 1| 0| 1',
        'SINGAPORE| sg.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Singapore| #0328DB| 1| 1| 0| 1',
        'SLOVAKIA| sk.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Slovakia| #04447C| 1| 1| 0| 1',
        'SLOVENIA| si.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Slovenia| #36050D| 1| 1| 0| 1',
        'SOLOMON_ISLANDS| sb.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Solomon Islands| #C8DC56| 1| 1| 0| 1',
        'SOMALIA| so.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Somalia| #F8DF1D| 1| 1| 0| 1',
        'SOUTH-EAST_ASIAN| South-East Asian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South-East Asian| #2B0DE1| 1| 1| 0| 1',
        'SOUTH-EAST_ASIA| South-East Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South-East Asia| #C7868C| 1| 1| 0| 1',
        'SOUTHERN_AFRICAN| Southern African.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern African| #6003D5| 1| 1| 0| 1',
        'SOUTHERN_AFRICA| Southern Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern Africa| #5CFEDC| 1| 1| 0| 1',
        'SOUTHERN_CONE| Southern Cone.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern Cone| #B68D1D| 1| 1| 0| 1',
        'SOUTH_AFRICA| za.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Africa| #E7BB4A| 1| 1| 0| 1',
        'SOUTH_AMERICA| South America.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South America| #9EDFF8| 1| 1| 0| 1',
        'SOUTH_ASIAN| South Asian.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Asian| #6AF106| 1| 1| 0| 1',
        'SOUTH_ASIA| South Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Asia| #D09F06| 1| 1| 0| 1',
        'SOUTH_SUDAN| ss.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Sudan| #D4A4C5| 1| 1| 0| 1',
        'SOUTHEASTERN_ASIA| South-Eastern Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South-Eastern Asia| #276841| 1| 1| 0| 1',
        'SOUTHERN_ASIA| Southern Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern Asia| #757D90| 1| 1| 0| 1',
        'SOUTHERN_EUROPE| Southern Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Southern Europe| #2F51DF| 1| 1| 0| 1',
        'SPAIN| es.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spain| #99DA4B| 1| 1| 0| 1',
        'NORTH_KOREA| kp.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | North Korea| #9CACBF| 1| 1| 0| 1',
        'SOUTH_KOREA| kr.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | South Korea| #127FFE| 1| 1| 0| 1',
        'SRI_LANKA| lk.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sri Lanka| #6415FD| 1| 1| 0| 1',
        'SUB-SAHARAN_AFRICA| Sub-Saharan Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sub-Saharan Africa| #E87D39| 1| 1| 0| 1',
        'SUDAN| sd.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sudan| #F877E4| 1| 1| 0| 1',
        'SURINAME| sr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Suriname| #4647C5| 1| 1| 0| 1',
        'SVALBARD_AND_JAN_MAYEN| sj.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Svalbard and Jan Mayen| #10CACA| 1| 1| 0| 1',
        'SWEDEN| se.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sweden| #E3C61A| 1| 1| 0| 1',
        'SWITZERLAND| ch.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Switzerland| #5803F1| 1| 1| 0| 1',
        'SYRIA| sy.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Syria| #E6CD56| 1| 1| 0| 1',
        'TAIWANESE| Taiwanese.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Taiwanese| #66872B| 1| 1| 0| 1',
        'TAIWAN| tw.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Taiwan| #ABE3E0| 1| 1| 0| 1',
        'TAJIKISTAN| tj.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tajikistan| #94F7D2| 1| 1| 0| 1',
        'TANZANIA| tz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tanzania| #E80290| 1| 1| 0| 1',
        'THAILAND| th.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Thailand| #32DBD9| 1| 1| 0| 1',
        'TIMOR-LESTE| tl.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Timor-Leste| #FEE0EF| 1| 1| 0| 1',
        'TOGO| tg.png| -500| 750| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Togo| #2940B7| 1| 1| 0| 1',
        'TONGA| to.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tonga| #08313F| 1| 1| 0| 1',
        'TRINIDAD_AND_TOBAGO| tt.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trinidad and Tobago| #4AD42A| 1| 1| 0| 1',
        'TUNISIA| tn.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tunisia| #CBC6CC| 1| 1| 0| 1',
        'TURKEY| tr.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Turkey| #CD90D1| 1| 1| 0| 1',
        'TURKMENISTAN| tm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Turkmenistan| #FC3E09| 1| 1| 0| 1',
        'TURKS_AND_CAICOS_ISLANDS| tc.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Turks and Caicos Islands| #B130FF| 1| 1| 0| 1',
        'UGANDA| ug.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Uganda| #27E46C| 1| 1| 0| 1',
        'UKRAINE| ua.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ukraine| #1640B6| 1| 1| 0| 1',
        'UK| UK.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | UK| #121D0A| 1| 1| 0| 1',
        'UNITED_ARAB_EMIRATES| ae.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United Arab Emirates| #BC9C16| 1| 1| 0| 1',
        'UNITED_KINGDOM| gb.png| -500| 1200| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United Kingdom| #C7B89D| 1| 1| 0| 1',
        'UNITED_STATES_OF_AMERICA| us.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United States of America| #D2A345| 1| 1| 0| 1',
        'UNITED_STATES| us.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United States| #D2A345| 1| 1| 0| 1',
        'URUGUAY| uy.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Uruguay| #D59CC1| 1| 1| 0| 1',
        'USA| USA.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | USA| #CA9B8E| 1| 1| 0| 1',
        'UZBEKISTAN| uz.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Uzbekistan| #9115AF| 1| 1| 0| 1',
        'VANUATU| vu.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Vanuatu| #694F3D| 1| 1| 0| 1',
        'VENEZUELA| ve.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Venezuela| #38FCA6| 1| 1| 0| 1',
        'VIETNAM| vn.png| -500| 850| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Vietnam| #19156E| 1| 1| 0| 1',
        'WESTERN_AFRICAN| Western African.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western African| #9F878C| 1| 1| 0| 1',
        'WESTERN_AFRICA| Western Africa.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western Africa| #C85C78| 1| 1| 0| 1',
        'WESTERN_ASIA| Western Asia.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western Asia| #1BE9AC| 1| 1| 0| 1',
        'WESTERN_EUROPE| Western Europe.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western Europe| #875222| 1| 1| 0| 1',
        'YEMEN| ye.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Yemen| #A19DD9| 1| 1| 0| 1',
        'ZAMBIA| zm.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zambia| #AB1780| 1| 1| 0| 1',
        'ZIMBABWE| zw.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zimbabwe| #A44C98| 1| 1| 0| 1',
        'ÅLAND_ISLANDS| ax.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Åland Islands| #B7E412| 1| 1| 0| 1'
        ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'country_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Countries| #FF2000| 1| 1| 0| 1'
        'region_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Regions| #FF2000| 1| 1| 0| 1'
        'continent_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Continents| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
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
    WriteToLogFile "ImageMagick Commands for     : Decades"

    Move-Item -Path output -Destination output-orig

    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'decade_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $theMaxWidth = 1900
    $theMaxHeight = 550
    $minPointSize = 250
    $maxPointSize = 1000

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '1880s| transparent.png| +0| 0| +0| Rye-Regular| 453| #FFFFFF| 0| 15| #FFFFFF| | 1880| #44EF10| 1| 1| 0| 1',
        '1890s| transparent.png| +0| 0| +0| Limelight-Regular| 453| #FFFFFF| 0| 15| #FFFFFF| | 1890| #44EF10| 1| 1| 0| 1',
        '1900s| transparent.png| +0| 0| +0| BoecklinsUniverse| 453| #FFFFFF| 0| 15| #FFFFFF| | 1900| #44EF10| 1| 1| 0| 1',
        '1910s| transparent.png| +0| 0| +0| UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1910| #44EF10| 1| 1| 0| 1',
        '1920s| transparent.png| +0| 0| +0| Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1920| #44EF10| 1| 1| 0| 1',
        '1930s| transparent.png| +0| 0| +0| Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1930| #44EF10| 1| 1| 0| 1',
        '1940s| transparent.png| +0| 0| +0| Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1940| #44EF10| 1| 1| 0| 1',
        '1950s| transparent.png| +0| 0| +0| Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1950| #44EF10| 1| 1| 0| 1',
        '1960s| transparent.png| +0| 0| +0| Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1960| #44EF10| 1| 1| 0| 1',
        '1970s| transparent.png| +0| 0| +0| Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1970| #44EF10| 1| 1| 0| 1',
        '1980s| transparent.png| +0| 0| +0| Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1980| #44EF10| 1| 1| 0| 1',
        '1990s| transparent.png| +0| 0| +0| Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1990| #44EF10| 1| 1| 0| 1',
        '2000s| transparent.png| +0| 0| +0| Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2000| #44EF10| 1| 1| 0| 1',
        '2010s| transparent.png| +0| 0| +0| Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2010| #44EF10| 1| 1| 0| 1',
        '2020s| transparent.png| +0| 0| +0| Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2020| #44EF10| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        $value = $($item.key_name)
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $($item.font_size)
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    WriteToLogFile "MonitorProcess               : Waiting for all processes to end before continuing..."
    Start-Sleep -Seconds 3
    MonitorProcess -ProcessName "magick.exe"
    
    Move-Item -Path output -Destination decade

    $pre_value = Get-YamlPropertyValue -PropertyPath "key_names.BEST_OF" -ConfigObject $global:ConfigObj -CaseSensitivity Upper

    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 200

    $arr = @()
    for ($i = 1880; $i -lt 2030; $i += 10) {
        $value = $pre_value
        $optimalFontSize = Get-OptimalPointSize -text $value -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\decade\$i.jpg`" -logo_offset +0 -logo_resize 2000 -text `"$value`" -text_offset -400 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"#FFFFFF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    }
    LaunchScripts -ScriptPaths $arr
    Start-Sleep -Seconds 3
    MonitorProcess -ProcessName "magick.exe"
    Move-Item -Path output -Destination "$script_path\decade\best"
    Move-Item -Path output-orig -Destination output

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

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| John Wick.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | John Wick| #1A1F2B| 1| 1| 0| 0',
        '| John Wick2.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | John Wick2| #1A1F2B| 1| 1| 0| 0',
        '| Bosch.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bosch| #2C2C2C| 1| 1| 0| 0',
        '| Hellboy.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hellboy| #601C1C| 1| 1| 0| 0',
        '| RoboCop.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RoboCop| #1A2639| 1| 1| 0| 0',
        '| 28 Days Weeks Later.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 28 Days Weeks Later| #B93033| 1| 1| 0| 0',
        '| Power.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Power| #63E2C5| 1| 1| 0| 0',
        '| Game of Thrones.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Game of Thrones| #25972E| 1| 1| 0| 0',
        '| 9-1-1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 9-1-1| #C62B2B| 1| 1| 0| 1',
        '| A Nightmare on Elm Street.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | A Nightmare on Elm Street| #BE3C3E| 1| 1| 0| 1',
        '| Alien Predator.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Alien Predator| #1EAC1B| 1| 1| 0| 1',
        '| Alien.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Alien| #18BC56| 1| 1| 0| 1',
        '| American Pie.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | American Pie| #C24940| 1| 1| 0| 1',
        '| Anaconda.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Anaconda| #A42E2D| 1| 1| 0| 1',
        '| Angels In The.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Angels In The| #4869BD| 1| 1| 0| 1',
        '| Appleseed.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Appleseed| #986E22| 1| 1| 0| 1',
        '| Archie Comics.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Archie Comics| #DFB920| 1| 1| 0| 1',
        '| Arrowverse.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Arrowverse| #2B8F40| 1| 1| 0| 1',
        '| Barbershop.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Barbershop| #2399AF| 1| 1| 0| 1',
        '| Batman.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Batman| #525252| 1| 1| 0| 1',
        '| Bourne.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bourne| #383838| 1| 1| 0| 0',
        '| Charlie Brown.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Charlie Brown| #C8BF2B| 1| 1| 0| 1',
        '| Cloverfield.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cloverfield| #0E1672| 1| 1| 0| 1',
        '| Cornetto Trilogy.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cornetto Trilogy| #6C9134| 1| 1| 0| 1',
        '| CSI.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CSI| #969322| 1| 1| 0| 1',
        '| DC Super Hero Girls.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DC Super Hero Girls| #299CB1| 1| 1| 0| 1',
        '| DC Universe.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DC Universe| #213DB6| 1| 1| 0| 1',
        '| Deadpool.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Deadpool| #BD393C| 1| 1| 0| 1',
        '| Despicable Me.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Despicable Me| #C77344| 1| 1| 0| 1',
        '| Doctor Who.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Doctor Who| #1C38B4| 1| 1| 0| 1',
        '| Escape From.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Escape From| #B82026| 1| 1| 0| 1',
        '| Fantastic Beasts.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fantastic Beasts| #9E972B| 1| 1| 0| 1',
        '| Fast & Furious.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fast & Furious| #8432C4| 1| 1| 0| 1',
        '| FBI.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | FBI| #FFD32C| 1| 1| 0| 1',
        '| Final Fantasy.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Final Fantasy| #86969F| 1| 1| 0| 1',
        '| Friday the 13th.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Friday the 13th| #B9242A| 1| 1| 0| 1',
        '| Frozen.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Frozen| #2A5994| 1| 1| 0| 1',
        '| Garfield.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Garfield| #C28117| 1| 1| 0| 1',
        '| Ghostbusters.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ghostbusters| #414141| 1| 1| 0| 1',
        '| Godzilla (Heisei).png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Godzilla (Heisei)| #BFB330| 1| 1| 0| 1',
        '| Godzilla (Showa).png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Godzilla (Showa)| #BDB12A| 1| 1| 0| 1',
        '| Godzilla.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Godzilla| #B82737| 1| 1| 0| 1',
        '| Halloween.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Halloween| #BB2D22| 1| 1| 0| 1',
        '| Halo.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Halo| #556A92| 1| 1| 0| 1',
        '| Hannibal Lecter.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hannibal Lecter| #383838| 1| 1| 0| 1',
        '| Harry Potter.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Harry Potter| #9D9628| 1| 1| 0| 1',
        '| Has Fallen.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Has Fallen| #3B3B3B| 1| 1| 0| 1',
        '| Ice Age.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ice Age| #5EA0BB| 1| 1| 0| 1',
        '| In Association with Marvel.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | In Association with Marvel| #C42424| 1| 1| 0| 1',
        '| Indiana Jones.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Indiana Jones| #D97724| 1| 1| 0| 1',
        '| IP Man.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IP Man| #8D7E63| 1| 1| 0| 0',
        '| James Bond 007.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | James Bond 007| #414141| 1| 1| 0| 1',
        '| Jurassic Park.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jurassic Park| #902E32| 1| 1| 0| 1',
        '| Karate Kid.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Karate Kid| #AC6822| 1| 1| 0| 1',
        '| Law & Order.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Law & Order| #5B87AB| 1| 1| 0| 1',
        '| Lord of the Rings.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lord of the Rings| #C38B27| 1| 1| 0| 1',
        '| Madagascar.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Madagascar| #AD8F27| 1| 1| 0| 1',
        '| Marvel Cinematic Universe.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Marvel Cinematic Universe| #AD2B2B| 1| 1| 0| 1',
        '| Marx Brothers.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Marx Brothers| #347294| 1| 1| 0| 1',
        '| Middle Earth.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Middle Earth| #C28A25| 1| 1| 0| 1',
        '| Mission Impossible.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mission Impossible| #BF1616| 1| 1| 0| 1',
        '| Monty Python.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Monty Python| #B61C22| 1| 1| 0| 1',
        '| Mortal Kombat.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mortal Kombat| #BA4D29| 1| 1| 0| 1',
        '| Mothra.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mothra| #9C742A| 1| 1| 0| 1',
        '| NCIS.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NCIS| #AC605F| 1| 1| 0| 1',
        '| One Chicago.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | One Chicago| #BE7C30| 1| 1| 0| 1',
        '| Oz.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Oz| #AD8F27| 1| 1| 0| 1',
        '| Pet Sematary.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pet Sematary| #B71F25| 1| 1| 0| 1',
        '| Pirates of the Caribbean.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pirates of the Caribbean| #7F6936| 1| 1| 0| 1',
        '| Planet of the Apes.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Planet of the Apes| #4E4E4E| 1| 1| 0| 1',
        '| Pokémon.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pokémon| #FECA06| 1| 1| 0| 1',
        '| Power Rangers.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Power Rangers| #24AA60| 1| 1| 0| 1',
        '| Pretty Little Liars.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pretty Little Liars| #BD0F0F| 1| 1| 0| 1',
        '| Resident Evil Biohazard.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Resident Evil Biohazard| #930B0B| 1| 1| 0| 1',
        '| Resident Evil.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Resident Evil| #940E0F| 1| 1| 0| 1',
        '| Rocky Creed.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Rocky Creed| #C52A2A| 1| 1| 0| 1',
        '| Rocky.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Rocky| #C22121| 1| 1| 0| 1',
        '| RuPaul''s Drag Race.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RuPaul''s Drag Race| #FF5757| 1| 1| 0| 1',
        '| Scooby-Doo!.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Scooby-Doo!| #5F3879| 1| 1| 0| 1',
        '| Shaft.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shaft| #382637| 1| 1| 0| 1',
        '| Shrek.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shrek| #3DB233| 1| 1| 0| 1',
        '| Spider-Man.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spider-Man| #C11B1B| 1| 1| 0| 1',
        '| Star Trek Alternate Reality.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Star Trek Alternate Reality| #C78639| 1| 1| 0| 1',
        '| Star Trek The Next Generation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Star Trek The Next Generation| #B7AE4C| 1| 1| 0| 1',
        '| Star Trek The Original Series.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Star Trek The Original Series| #BB5353| 1| 1| 0| 1',
        '| Star Trek.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Star Trek| #C2A533| 1| 1| 0| 1',
        '| Star Wars Legends.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Star Wars Legends| #BAA416| 1| 1| 0| 1',
        '| Star Wars Skywalker Saga.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Star Wars Skywalker Saga| #5C5C5C| 1| 1| 0| 1',
        '| Star Wars.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Star Wars| #C2A21B| 1| 1| 0| 1',
        '| Stargate.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stargate| #6C73A1| 1| 1| 0| 1',
        '| Street Fighter.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Street Fighter| #C5873F| 1| 1| 0| 1',
        '| Superman.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Superman| #C34544| 1| 1| 0| 1',
        '| Teenage Mutant Ninja Turtles.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Teenage Mutant Ninja Turtles| #78A82E| 1| 1| 0| 1',
        '| The Hunger Games.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Hunger Games| #619AB5| 1| 1| 0| 1',
        '| The Man With No Name.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Man With No Name| #9A7B40| 1| 1| 0| 1',
        '| The Mummy.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Mummy| #C28A25| 1| 1| 0| 1',
        '| The Real Housewives.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Real Housewives| #400EA4| 1| 1| 0| 1',
        '| The Rookie.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Rookie| #DC5A2B| 1| 1| 0| 1',
        '| The Texas Chainsaw Massacre.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Texas Chainsaw Massacre| #B15253| 1| 1| 0| 1',
        '| The Three Stooges.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Three Stooges| #B9532A| 1| 1| 0| 1',
        '| The Twilight Zone.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Twilight Zone| #16245F| 1| 1| 0| 1',
        '| The Walking Dead.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Walking Dead| #797F48| 1| 1| 0| 1',
        '| Tom and Jerry.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tom and Jerry| #B9252B| 1| 1| 0| 1',
        '| Tomb Raider.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tomb Raider| #620D0E| 1| 1| 0| 1',
        '| Toy Story.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Toy Story| #CEB423| 1| 1| 0| 1',
        '| Transformers.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Transformers| #B02B2B| 1| 1| 0| 1',
        '| Tron.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tron| #5798B2| 1| 1| 0| 1',
        '| Twilight.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Twilight| #3B3B3B| 1| 1| 0| 1',
        '| Unbreakable.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Unbreakable| #445DBB| 1| 1| 0| 1',
        '| Wallace & Gromit.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wallace & Gromit| #BA2A20| 1| 1| 0| 1',
        '| Wizarding World.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wizarding World| #7B7A33| 1| 1| 0| 1',
        '| X-Men.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | X-Men| #636363| 1| 1| 0| 1',
        '| Yellowstone.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Yellowstone| #441515| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
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
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'genre_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'MOVIES_THAT_DEFINED_OUR_CHILDHOOD| Movies That Defined Our Childhood.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Movies That Defined Our Childhood| #82CFD8| 1| 1| 0| 1',
        '1001_MOVIES_YOU_MUST_SEE_BEFORE_YOU_DIE| 1001 Movies You Must See Before You Die.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1001 Movies You Must See Before You Die| #606723| 1| 1| 0| 1',
        'MAY_THE_FOURTH| May the Fourth.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | May the Fourth | #14F001| 1| 1| 0| 1',
        'NEW_YEARS_EVE| New Years Eve.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | New Years Eve | #E315C9| 1| 1| 0| 1',
        'DISNEY| Disney.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney | #8AD6D2| 1| 1| 0| 1',
        'PIXAR| Pixar.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pixar| #0195C1| 1| 1| 0| 1',
        'DREAMWORKS| Dreamworks.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dreamworks| #4CECB4| 1| 1| 0| 0',
        'DISNEY_PIXAR_DREAMWORKS| Disney Pixar Dreamworks.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney Pixar Dreamworks| #D4C687| 1| 1| 0| 0',
        'VISUALLY_INSANE| Visually Insane.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Visually Insane| #8328A0| 1| 1| 0| 1',
        'GUILTY_PLEASURE| Guilty Pleasure.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Guilty Pleasure| #B721A3| 1| 1| 0| 1',
        'LOST_TREASURE| Lost Treasure.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lost Treasure| #A8AF16| 1| 1| 0| 1',
        'ABSURDISM| Absurdism.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Absurdism| #032E2E| 1| 1| 0| 1',
        'ABSURD_COMEDY| Absurd Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Absurd Comedy| #D16496| 1| 1| 0| 0',
        'ACTION_ADVENTURE| Action & adventure.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Action & adventure| #65AEA5| 1| 1| 0| 1',
        'ACTION_COMEDY| Action Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Action Comedy|#EA8B2B| 1| 1| 0| 0',
        'ACTION| Action.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Action| #387DBF| 1| 1| 0| 1',
        'ADULT_CARTOONS| Adult Cartoons.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Adult Cartoons| #5408E9| 1| 1| 0| 1',
        'ADULT_CARTOON| Adult Cartoon.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Adult Cartoon| #D49BD5| 1| 1| 0| 1',
        'ADULT| Adult.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Adult| #D02D2D| 1| 1| 0| 1',
        'ADVENTURE| Adventure.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Adventure| #40B997| 1| 1| 0| 1',
        'ALIEN| Alien.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Alien| #88C9B2| 1| 1| 0| 1',
        'ALTERNATE_HISTORY| Alternate History.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Alternate History| #8C47AA| 1| 1| 0| 1',
        'AMERICA| America.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | America| #00E55E| 1| 1| 0| 1',
        'ANIMALS| Animals.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Animals| #3B66AD| 1| 1| 0| 1',
        'ANIMAL| Animal.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Animal| #04E7FE| 1| 1| 0| 1',
        'ANIMATED_SHORTS| Animated Shorts.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Animated Shorts| #2A9906| 1| 1| 0| 1',
        'ANIMATED_SHORT| Animated Short.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Animated Short| #F60AD3| 1| 1| 0| 1',
        'ANIMATION| Animation.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Animation| #9035BE| 1| 1| 0| 1',
        'ANIME| Anime.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Anime| #41A4BE| 1| 1| 0| 1',
        'ANTHOLOGY| Anthology.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Anthology| #BF413F| 1| 1| 0| 1',
        'ANTI-HERO| Anti-Hero.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Anti-Hero| #2B319B| 1| 1| 0| 1',
        'APOCALYPSE| Apocalypse.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Apocalypse| #270811| 1| 1| 0| 1',
        'ARTHOUSE| Arthouse.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Arthouse| #DFFE83| 1| 1| 0| 0',
        'ARTIFICIAL_INTELLIGENCE| Artificial Intelligence.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Artificial Intelligence| #299206| 1| 1| 0| 1',
        'ASSASSIN| Assassin.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Assassin| #C52124| 1| 1| 0| 1',
        'ASTRONAUT| Astronaut.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Astronaut| #773A54| 1| 1| 0| 1',
        'BACKROADS_HORROR| Backroads Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Backroads Horror| #6EAB36| 1| 1| 0| 1',
        'BETRAYAL| Betrayal.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Betrayal| #06CE03| 1| 1| 0| 1',
        'BIOGRAPHY| Biography.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Biography| #C1A13E| 1| 1| 0| 1',
        'BIOPIC| Biopic.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Biopic| #C1A13E| 1| 1| 0| 1',
        'BLAXPLOITATION| Blaxploitation.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Blaxploitation| #4634B1| 1| 1| 0| 0',
        'BODY_HORROR| Body Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Body Horror| #F48FB1| 1| 1| 0| 0',
        'BOXING| Boxing.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Boxing| #3DB73F| 1| 1| 0| 1',
        'BOYS_LOVE| Boys Love.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Boys Love| #85ADAC| 1| 1| 0| 1',
        'BUDDY_COMEDY| Buddy Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Buddy Comedy| #1A3180| 1| 1| 0| 1',
        'BUG| Bug.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bug| #5C4D4F| 1| 1| 0| 1',
        'BUILDING| Building.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Building| #959AC5| 1| 1| 0| 1',
        'CANNIBAL| Cannibal.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cannibal| #B82C2C| 1| 1| 0| 0',
        'CAPER| Caper.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Caper| #C575C1| 1| 1| 0| 1',
        'CARS| Cars.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cars| #7B36D2| 1| 1| 0| 1',
        'CHICK_FLICK| Chick Flick.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chick Flick| #7992F1| 1| 1| 0| 1',
        'CHILDRENS_CARTOONS| Children''s Cartoons.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Children''s Cartoons| #C5413A| 1| 1| 0| 1',
        'CHILDRENS_CARTOON| Children''s Cartoon.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Children''s Cartoon| #A65AB7| 1| 1| 0| 1',
        'CHILDREN| Children.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Children| #9C42C2| 1| 1| 0| 1',
        'CHRISTMAS| Christmas.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Christmas| #D52411| 1| 1| 0| 1',
        'COLORADO| Colorado.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Colorado| #75735E| 1| 1| 0| 1',
        'COMEDY_HORROR| Comedy Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Comedy Horror| #289951| 1| 1| 0| 1',
        'COMEDY| Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Comedy| #B7363E| 1| 1| 0| 1',
        'COMING_OF_AGE| Coming of Age.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Coming of Age| #A57660| 1| 1| 0| 1',
        'COMPETITION| Competition.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Competition| #55BF48| 1| 1| 0| 1',
        'CONSPIRACY| Conspiracy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Conspiracy| #3F4284| 1| 1| 0| 1',
        'CON_ARTIST| Con Artist.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Con Artist| #C7A5A1| 1| 1| 0| 1',
        'COP| Cop.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cop| #6E5902| 1| 1| 0| 1',
        'COSTUME_DRAMA| Costume Drama.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Costume Drama| #482B67| 1| 1| 0| 1',
        'COURTROOM| Courtroom.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Courtroom| #91EAF0| 1| 1| 0| 1',
        'CREATURE_FEATURE| Creature Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Creature Feature| #AD8603| 1| 1| 0| 0',
        'CREATURE_HORROR| Creature Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Creature Horror| #AD8603| 1| 1| 0| 1',
        'CRIME_COMEDY| Crime Comedy.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crime Comedy| #22EADE| 1| 1| 0| 0',
        'CRIME| Crime.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crime| #888888| 1| 1| 0| 1',
        'CRITERION_COLLECTION| Criterion Collection.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Criterion Collection| #7E1D03| 1| 1| 0| 1',
        'CULT_CLASSICS| Cult Classics.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cult Classics| #156D88| 1| 1| 0| 1',
        'CYBERPUNK| Cyberpunk.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cyberpunk| #0A0D7E| 1| 1| 0| 1',
        'CYBER_THRILLER| Cyber-Thriller.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cyber-Thriller| #8F0520| 1| 1| 0| 1',
        'DARK_COMEDY| Dark Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dark Comedy| #09F1A3| 1| 1| 0| 1',
        'DARK_FANTASY| Dark Fantasy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dark Fantasy| #CAC96E| 1| 1| 0| 1',
        'DEMONS| Demons.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Demons| #9A2A2A| 1| 1| 0| 1',
        'DETECTIVE| Detective.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Detective| #611FEF| 1| 1| 0| 1',
        'DINOSAURS| Dinosaurs.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dinosaurs| #5E6955| 1| 1| 0| 1',
        'DINOSAUR| Dinosaur.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dinosaur| #38129E| 1| 1| 0| 1',
        'DOCUMENTARY| Documentary.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Documentary| #2C4FA8| 1| 1| 0| 1',
        'DRAGON| Dragon.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dragon| #9EB798| 1| 1| 0| 1',
        'DRAMA| Drama.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Drama| #A22C2C| 1| 1| 0| 1',
        'DRAMEDY| Dramedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dramedy| #CF5A61| 1| 1| 0| 1',
        'DYSTOPIAN| Dystopian.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dystopian| #FCC7A3| 1| 1| 0| 1',
        'ECCHI| Ecchi.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ecchi| #C592C0| 1| 1| 0| 1',
        'ELEVATED_HORROR| Elevated Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Elevated Horror| #C408BD| 1| 1| 0| 0',
        'ENGINEERING_DISASTERS| Engineering Disasters.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Engineering Disasters| #3D3448| 1| 1| 0| 1',
        'ENGINEERING_DISASTER| Engineering Disaster.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Engineering Disaster| #E82CB5| 1| 1| 0| 1',
        'ENGINEERING| Engineering.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Engineering| #AA9864| 1| 1| 0| 1',
        'EPIC| Epic.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Epic| #7FE464| 1| 1| 0| 1',
        'EROTICA| Erotica.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Erotica| #CA9FC9| 1| 1| 0| 1',
        'ESPIONAGE| Espionage.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Espionage| #35E254| 1| 1| 0| 1',
        'EXPERIMENTAL| Experimental.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Experimental| #4BB407| 1| 1| 0| 1',
        'EXPLOITATION| Exploitation.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Exploitation| #ED696B| 1| 1| 0| 0',
        'EXTREME| Extreme.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Extreme| #FF4081| 1| 1| 0| 0',
        'FAIRY_TALE| Fairy Tale.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fairy Tale| #FF8BBA| 1| 1| 0| 1',
        'FAMILY| Family.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Family| #BABA6C| 1| 1| 0| 1',
        'FANTASY_HORROR| Fantasy Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fantasy Horror| #4C48CC| 1| 1| 0| 0',
        'FANTASY| Fantasy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fantasy| #CC2BC6| 1| 1| 0| 1',
        'FILM_NOIR| Film Noir.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Film Noir| #5B5B5B| 1| 1| 0| 1',
        'FIRST_RESPONDER| First Responder.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | First Responder| #31592E| 1| 1| 0| 1',
        'FOLK_HORROR| Folk Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Folk Horror| #E7F026| 1| 1| 0| 0',
        'FOOD| Food.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Food| #A145C1| 1| 1| 0| 1',
        'FOOTBALL| Football.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Football| #B080BB| 1| 1| 0| 1',
        'FOREIGN_GIALLO| Foreign Giallo.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Foreign Giallo| #FC8535| 1| 1| 0| 0',
        'FOREIGN_NOIR| Foreign Noir.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Foreign Noir| #ABB7C8| 1| 1| 0| 0',
        'FOREIGN| Foreign.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Foreign| #F5D4C7| 1| 1| 0| 1',
        'FOUND_FOOTAGE_HORROR| Found Footage Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Found Footage Horror| #2C3B08| 1| 1| 0| 1',
        'FOUND_FOOTAGE| Found Footage.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Found Footage| #2C3B08| 1| 1| 0| 0',
        'FRINGE| Fringe.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fringe| #511C2C| 1| 1| 0| 1',
        'FUGITIVE| Fugitive.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fugitive| #00B8C2| 1| 1| 0| 1',
        'FUNNY_SCI-FI| Funny Sci-Fi.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Funny Sci-Fi| #192897| 1| 1| 0| 1',
        'GAIJINSPLOITATION| Gaijinsploitation.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gaijinsploitation| #CB002D| 1| 1| 0| 0',
        'GAME_SHOW| Game Show.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Game Show| #32D184| 1| 1| 0| 1',
        'GAME| Game.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Game| #70BD98| 1| 1| 0| 1',
        'GANGSTER| Gangster.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gangster| #77ACBD| 1| 1| 0| 1',
        'GHOST| Ghost.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ghost| #4362D3| 1| 1| 0| 1',
        'GIRLS_LOVE| Girls Love.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Girls Love| #AC86AD| 1| 1| 0| 1',
        'GOTHIC| Gothic.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gothic| #EDFAE9| 1| 1| 0| 1',
        'GOURMET| Gourmet.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gourmet| #83AC8F| 1| 1| 0| 1',
        'HAREM| Harem.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Harem| #7DB0C5| 1| 1| 0| 1',
        'HEARTBREAK| Heartbreak.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Heartbreak| #73A493| 1| 1| 0| 1',
        'HEIST| Heist.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Heist| #4281C9| 1| 1| 0| 1',
        'HENTAI| Hentai.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hentai| #B274BF| 1| 1| 0| 1',
        'HISTORICAL_EVENT| Historical Event.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Historical Event| #44C099| 1| 1| 0| 1',
        'HISTORICAL_FICTION| Historical Fiction.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Historical Fiction| #549503| 1| 1| 0| 1',
        'HISTORY| History.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | History| #B7A95D| 1| 1| 0| 1',
        'HOME_AND_GARDEN| Home and Garden.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Home and Garden| #8CC685| 1| 1| 0| 1',
        'HORROR_PARODY| Horror Parody.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Horror Parody| #78E5E3| 1| 1| 0| 0',
        'HORROR| Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Horror| #B94948| 1| 1| 0| 1',
        'HOSTAGE| Hostage.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hostage| #11C755| 1| 1| 0| 1',
        'HUMAN_BODY| Human Body.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Human Body| #FADA7D| 1| 1| 0| 1',
        'HUSTLE| Hustle.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hustle| #FAE67F| 1| 1| 0| 1',
        'INDIE| Indie.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Indie| #BB7493| 1| 1| 0| 1',
        'INSPIRATIONAL| Inspirational.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Inspirational| #DBBFAA| 1| 1| 0| 1',
        'JUNGLE_ADVENTURE| Jungle Adventure.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jungle Adventure| #C3B914| 1| 1| 0| 1',
        'KIDS| Kids.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kids| #9F40C6| 1| 1| 0| 1',
        'LGBTQ| LGBTQ+.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | LGBTQ+| #BD86C4| 1| 1| 0| 1',
        'LOUISIANA| Louisiana.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Louisiana| #F33659| 1| 1| 0| 1',
        'LOVECRAFTIAN| Lovecraftian.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lovecraftian| #00695C| 1| 1| 0| 0',
        'MANUFACTURING| Manufacturing.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Manufacturing| #89DB95| 1| 1| 0| 1',
        'MARTIAL_ARTS| Martial Arts.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Martial Arts| #777777| 1| 1| 0| 1',
        'MECHA| Mecha.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mecha| #8B8B8B| 1| 1| 0| 1',
        'MEDICAL| Medical.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Medical| #547138| 1| 1| 0| 1',
        'MEDIEVAL| Medieval.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Medieval| #9E62B4| 1| 1| 0| 1',
        'MELODRAMA| Melodrama.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Melodrama| #6F4D62| 1| 1| 0| 1',
        'MILITARY| Military.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Military| #87552F| 1| 1| 0| 1',
        'MIND_BEND| Mind-Bend.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mind-Bend| #619DA2| 1| 1| 0| 1',
        'MIND_F**K| Mind-Fuck2.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mind-Fuck2| #619DA2| 1| 1| 0| 1',
        'MIND_FUCK| Mind-Fuck.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mind-Fuck| #619DA2| 1| 1| 0| 1',
        'MINI_SERIES| Mini-Series.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mini-Series| #66B7BE| 1| 1| 0| 1',
        'MMA| MMA.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MMA| #69E39F| 1| 1| 0| 1',
        'MOCKUMENTARY| Mockumentary.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mockumentary| #5994A0| 1| 1| 0| 1',
        'MONSTER| Monster.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Monster| #E8A33C| 1| 1| 0| 1',
        'MUSICAL| Musical.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Musical| #C38CB7| 1| 1| 0| 1',
        'MUSIC| Music.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Music| #3CC79C| 1| 1| 0| 1',
        'MYSTERY_BOX| Mystery Box.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mystery Box| #FDA4C7| 1| 1| 0| 1',
        'MYSTERY| Mystery.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mystery| #867CB5| 1| 1| 0| 1',
        'MYTHOLOGY| Mythology.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mythology| #EEC389| 1| 1| 0| 1',
        'NATURAL_DISASTER| Natural Disaster.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Natural Disaster| #A318F9| 1| 1| 0| 1',
        'NATURE| Nature.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nature| #8B4646| 1| 1| 0| 1',
        'NAVAL| Naval.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Naval| #ECF6FA| 1| 1| 0| 1',
        'NEO-NOIR| Neo-Noir.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Neo-Noir| #9F9F91| 1| 1| 0| 0',
        'NEWS_POLITICS| News & Politics.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | News & Politics| #C83131| 1| 1| 0| 1',
        'NEWS| News.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | News| #C83131| 1| 1| 0| 1',
        'NINJA| Ninja.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ninja| #ADFFD3| 1| 1| 0| 1',
        'OCCULT| Occult.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Occult| #8AA22C| 1| 1| 0| 1',
        'OUTDOOR_ADVENTURE| Outdoor Adventure.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Outdoor Adventure| #56C89C| 1| 1| 0| 1',
        'OUTLAW| Outlaw.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Outlaw| #E4F4E8| 1| 1| 0| 1',
        'PANDEMIC| Pandemic.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pandemic| #57C3D6| 1| 1| 0| 1',
        'PARANORMAL| Paranormal.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paranormal| #66549E| 1| 1| 0| 1',
        'PARODY| Parody.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Parody| #83A9A2| 1| 1| 0| 1',
        'PERIOD_DRAMA| Period Drama.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Period Drama| #B7A3A8| 1| 1| 0| 1',
        'PHILOSOPHY| Philosophy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Philosophy| #B30B6B| 1| 1| 0| 1',
        'PINKU| Pinku.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pinku| #C1788B| 1| 1| 0| 0',
        'PLANTS| Plants.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plants| #E227EF| 1| 1| 0| 1',
        'PLANT| Plant.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plant| #EE7B1A| 1| 1| 0| 1',
        'POLICE| Police.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Police| #262398| 1| 1| 0| 1',
        'POLITICS| Politics.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Politics| #3F5FC0| 1| 1| 0| 1',
        'POST_APOCALYPTIC| Post-Apocalyptic.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Post-Apocalyptic| #399A30| 1| 1| 0| 1',
        'PREHISTORIC| Prehistoric.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prehistoric| #CB5825| 1| 1| 0| 1',
        'PRESIDENT| President.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | President| #76979A| 1| 1| 0| 1',
        'PRISON| Prison.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prison| #3A3686| 1| 1| 0| 1',
        'PSYCHEDELIC| Psychedelic.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Psychedelic| #E973F6| 1| 1| 0| 0',
        'PSYCHOLOGICAL_HORROR| Psychological Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Psychological Horror| #AC5969| 1| 1| 0| 1',
        'PSYCHOLOGICAL| Psychological.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Psychological| #C79367| 1| 1| 0| 1',
        'REALITY| Reality.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Reality| #7CB6AE| 1| 1| 0| 1',
        'RELIGION| Religion.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Religion| #7F8D16| 1| 1| 0| 1',
        'REMAKE| Remake.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Remake| #2496B3| 1| 1| 0| 1',
        'REVENGE| Revenge.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Revenge| #8484E1| 1| 1| 0| 1',
        'ROBOT| Robot.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Robot| #B1050D| 1| 1| 0| 1',
        'ROMANCE| Romance.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Romance| #B6398E| 1| 1| 0| 1',
        'ROMANTIC_COMEDY| Romantic Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Romantic Comedy| #B2445D| 1| 1| 0| 1',
        'ROMANTIC_DRAMA| Romantic Drama.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Romantic Drama| #AB89C0| 1| 1| 0| 1',
        'SAMURAI| Samurai.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Samurai| #C0C282| 1| 1| 0| 1',
        'SATIRE| Satire.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Satire| #0E8E35| 1| 1| 0| 1',
        'SCHOOL| School.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | School| #4DC369| 1| 1| 0| 1',
        'SCI-FI_&_FANTASY| Sci-Fi & Fantasy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sci-Fi & Fantasy| #9254BA| 1| 1| 0| 1',
        'SCI-FI_HORROR| Sci-Fi Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sci-Fi Horror| #63BDA9| 1| 1| 0| 0',
        'SCIENCE_FICTION| Science Fiction.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Science Fiction| #545FBA| 1| 1| 0| 1',
        'SEDUCTIVE| Seductive.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Seductive| #2670FB| 1| 1| 0| 1',
        'SERIAL_KILLER| Serial Killer.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Serial Killer| #163F56| 1| 1| 0| 1',
        'SEXPLOITATION| Sexploitation.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sexploitation| #CC33FF| 1| 1| 0| 0',
        'SHORT| Short.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Short| #BCBB7B| 1| 1| 0| 1',
        'SHOUJO| Shoujo.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shoujo| #89529D| 1| 1| 0| 1',
        'SHOUNEN| Shounen.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shounen| #505E99| 1| 1| 0| 1',
        'SILENT| Silent.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Silent2| #84CBC8| 1| 1| 0| 0',
        'SILENT| Silent.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Silent| #84CBC8| 1| 1| 0| 0',
        'SLAPSTICK| Slapstick.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Slapstick| #C5C88F| 1| 1| 0| 0',
        'SLASHER| Slasher.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Slasher| #B75157| 1| 1| 0| 1',
        'SLEAZY| Sleazy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sleazy| #C291DD| 1| 1| 0| 0',
        'SLICE_OF_LIFE| Slice of Life.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Slice of Life| #C696C4| 1| 1| 0| 1',
        'SOAP| Soap.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Soap| #AF7CC0| 1| 1| 0| 1',
        'SPACE_OPERA| Space Opera.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Space Opera| #D2522B| 1| 1| 0| 1',
        'SPACE| Space.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Space| #A793C1| 1| 1| 0| 1',
        'SPAGHETTI_WESTERN| Spaghetti Western.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spaghetti Western| #2ABAB3| 1| 1| 0| 1',
        'SPLATTER| Splatter.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Splatter| #416939| 1| 1| 0| 1',
        'SPLATTER| Splatter.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Splatter| #990000| 1| 1| 0| 0',
        'SPORT| Sport.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sport| #587EB1| 1| 1| 0| 1',
        'SPY| Spy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spy| #B7D99F| 1| 1| 0| 1',
        'STAND-UP_COMEDY| Stand-Up Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stand-Up Comedy| #CF8A49| 1| 1| 0| 1',
        'STEAMPUNK| Steampunk.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Steampunk| #B102D8| 1| 1| 0| 1',
        'STEPHEN_KING| Stephen King.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stephen King| #B2A8C0| 1| 1| 0| 1',
        'STONER_COMEDY| Stoner Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stoner Comedy| #79D14D| 1| 1| 0| 1',
        'STOP-MOTION| Stop-Motion.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stop-Motion| #277D79| 1| 1| 0| 1',
        'SUPERHERO| Superhero.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Superhero| #DA8536| 1| 1| 0| 1',
        'SUPERNATURAL| Supernatural.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Supernatural| #262693| 1| 1| 0| 1',
        'SUPER_POWER| Super Power.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Super Power| #279552| 1| 1| 0| 1',
        'SURREALISM| Surrealism.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Surrealism| #F66626| 1| 1| 0| 1',
        'SURREAL_COMEDY| Surreal Comedy.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Surreal Comedy| #4D81DE| 1| 1| 0| 0',
        'SURREAL_HORROR| Surreal Horror.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Surreal Horror| #8A3B73| 1| 1| 0| 0',
        'SURREAL| Surrealism.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Surreal| #F66626| 1| 1| 0| 0',
        'SURVIVAL| Survival.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Survival| #434447| 1| 1| 0| 1',
        'SUSPENSE| Suspense.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Suspense| #AE5E37| 1| 1| 0| 1',
        'SWASHBUCKLER| Swashbuckler.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Swashbuckler| #E74867| 1| 1| 0| 1',
        'SWORD_SANDAL| Sword & Sandal.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sword & Sandal| #BD8DDB| 1| 1| 0| 1',
        'SWORD_SORCERY| Sword & Sorcery.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sword & Sorcery| #B44FBA| 1| 1| 0| 1',
        'TALK_SHOW| Talk Show.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Talk Show| #82A2B5| 1| 1| 0| 1',
        'TECHNOLOGY| Technology.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Technology| #218333| 1| 1| 0| 1',
        'THE_ARTS| The Arts.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Arts| #E1F6D6| 1| 1| 0| 1',
        'THRILLER| Thriller.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Thriller| #C3602B| 1| 1| 0| 1',
        'TIME_TRAVEL| Time Travel.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Time Travel| #2C3294| 1| 1| 0| 1',
        'TIME_LOOP| Time Travel.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Time Loop| #88D761| 1| 1| 0| 1',
        'TOP_GROSSING_FILMS_ANNUALLY| Top Grossing Films Annually.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top Grossing Films Annually| #CA1E1B| 1| 1| 0| 1',
        'TOP_GROSSING_FILMS_OF_ALL-TIME| Top Grossing Films of All-Time.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Top Grossing Films of All-Time| #8ED310| 1| 1| 0| 1',
        'TRAINS| Trains.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trains| #430CB1| 1| 1| 0| 1',
        'TRAVEL| Travel.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Travel| #B6BA6D| 1| 1| 0| 1',
        'TREASURE_HUNT| Treasure Hunt.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Treasure Hunt| #AFBE09| 1| 1| 0| 1',
        'TRUE_CRIME| True Crime.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | True Crime| #C706DE| 1| 1| 0| 1',
        'TV_MOVIE| TV Movie.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV Movie| #85A5B4| 1| 1| 0| 1',
        'UFO| Ufo.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ufo| #529D82| 1| 1| 0| 1',
        'ULTIMATE_BASS| Ultimate Bass.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ultimate Bass| #7335B5| 1| 1| 0| 1',
        'UNEXPECTEDLY_AMAZING| Unexpectedly Amazing.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Unexpectedly Amazing| #40E6BB| 1| 1| 0| 1',
        'URBAN_FANTASY| Urban Fantasy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Urban Fantasy| #0E7018| 1| 1| 0| 1',
        'UTOPIA| Utopia.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Utopia| #81E8E5| 1| 1| 0| 1',
        'VAMPIRE| Vampire.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Vampire| #7D2627| 1| 1| 0| 1',
        'VIDEO_GAME| Video Game.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Video Game| #A4F408| 1| 1| 0| 1',
        'VIDEO_NASTY| Video Nasty.png| -500| 1500| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Video Nasty| #FF2E00| 1| 1| 0| 0',
        'WAR_POLITICS| War & Politics.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | War & Politics| #4ABF6E| 1| 1| 0| 1',
        'WAR| War.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | War| #63AB62| 1| 1| 0| 1',
        'WEATHER| Weather.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Weather| #201BFB| 1| 1| 0| 1',
        'WEREWOLF| Werewolf.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Werewolf| #836CB6| 1| 1| 0| 1',
        'WESTERN| Western.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Western| #AD9B6D| 1| 1| 0| 1',
        'WHODUNIT| Whodunit.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Whodunit| #2E4DA9| 1| 1| 0| 1',
        'WITCH| Witch.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Witch| #C958AC| 1| 1| 0| 1',
        'WIZARDRY_WITCHCRAFT| Wizardry & Witchcraft.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wizardry & Witchcraft| #77E0AA| 1| 1| 0| 1',
        'WORLD_WAR| World War.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | World War| #336188| 1| 1| 0| 1',
        'WUXIA| Wuxia.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wuxia| #BA3CC0| 1| 1| 0| 0',
        'ZOMBIE_COMEDY| Zombie Comedy.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zombie Comedy| #04B69C| 1| 1| 0| 0',
        'ZOMBIE_HORROR| Zombie Horror.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zombie Horror| #909513| 1| 1| 0| 1',
        'ZOMBIE| Zombie.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zombie| #909513| 1| 1| 0| 0'
        ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
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
    Find-Path "$script_path\network"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'network_kids_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Kids Networks| #FF2000| 1| 1| 0| 1',
        'network_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Networks| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        ' | #0.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | #0| #7BE7A1| 1| 1| 0| 0',
        ' | ANIMAX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ANIMAX| #6301F6| 1| 1| 0| 0',
        ' | 7mate.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 7mate| #2F3C13| 1| 1| 0| 0',
        ' | A&E.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | A&E| #676767| 1| 1| 0| 0',
        ' | ABC Family.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ABC Family| #73D444| 1| 1| 0| 0',
        ' | ABC Kids.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ABC Kids| #6172B9| 1| 1| 0| 0',
        ' | ABC TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ABC TV| #CEC281| 1| 1| 0| 0',
        ' | ABC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ABC| #403993| 1| 1| 0| 0',
        ' | ABS-CBN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ABS-CBN| #127B09| 1| 1| 0| 0',
        ' | Acorn TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Acorn TV| #182034| 1| 1| 0| 0',
        ' | Adult Swim.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Adult Swim| #C0A015| 1| 1| 0| 0',
        ' | AHC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AHC| #B2D3A2| 1| 1| 0| 0',
        ' | Alibi.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Alibi| #5E6CC2| 1| 1| 0| 0',
        ' | AltBalaji.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AltBalaji| #00CC30| 1| 1| 0| 0',
        ' | Amazon Kids+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Amazon Kids+| #8E2AAF| 1| 1| 0| 0',
        ' | Amazon.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Amazon| #9B8832| 1| 1| 0| 0',
        ' | AMC+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AMC+| #B80F05| 1| 1| 0| 0',
        ' | AMC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AMC| #4A9472| 1| 1| 0| 0',
        ' | Angel Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Angel Studios| #98FC35| 1| 1| 0| 0',
        ' | Animal Planet.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Animal Planet| #390ACB| 1| 1| 0| 0',
        ' | Antena 3.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Antena 3| #306A94| 1| 1| 0| 0',
        ' | Apple TV+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Apple TV+| #313131| 1| 1| 0| 0',
        ' | ARD.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ARD| #3F76D7| 1| 1| 0| 0',
        ' | Arte.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Arte| #D70889| 1| 1| 0| 0',
        ' | AT-X.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AT-X| #BEDA86| 1| 1| 0| 0',
        ' | Atres Player.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Atres Player| #822AC4| 1| 1| 0| 0',
        ' | Atresplayer Premium.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Atresplayer Premium| #822AC4| 1| 1| 0| 0',
        ' | Audience.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Audience| #EE7706| 1| 1| 0| 0',
        ' | AXN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AXN| #2EF8CB| 1| 1| 0| 0',
        ' | Azteca Uno.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Azteca Uno| #F70AC3| 1| 1| 0| 0',
        ' | BBC America.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC America| #C83535| 1| 1| 0| 0',
        ' | BBC Four.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC Four| #F3E9E3| 1| 1| 0| 0',
        ' | BBC iPlayer.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC iPlayer| #467CE9| 1| 1| 0| 0',
        ' | BBC One.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC One| #3A38C6| 1| 1| 0| 0',
        ' | BBC Scotland.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC Scotland| #16204F| 1| 1| 0| 0',
        ' | BBC Three.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC Three| #550BAA| 1| 1| 0| 0',
        ' | BBC Two.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC Two| #6A08E0| 1| 1| 0| 0',
        ' | BBC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC| #A24649| 1| 1| 0| 0',
        ' | BET+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BET+| #FCAD65| 1| 1| 0| 0',
        ' | BET.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BET| #942C2C| 1| 1| 0| 0',
        ' | bilibili.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bilibili| #FB4A88| 1| 1| 0| 0',
        ' | Binge.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Binge| #0D29C9| 1| 1| 0| 0',
        ' | BluTV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BluTV| #1E6DA3| 1| 1| 0| 0',
        ' | Boomerang.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Boomerang| #6190B3| 1| 1| 0| 0',
        ' | Bravo.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bravo| #6D6D6D| 1| 1| 0| 0',
        ' | BritBox.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BritBox| #22790D| 1| 1| 0| 0',
        ' | C More.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | C More| #36623E| 1| 1| 0| 0',
        ' | Canal+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Canal+| #FB78AE| 1| 1| 0| 0',
        ' | Canale 5.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Canale 5| #A02124| 1| 1| 0| 0',
        ' | Cartoon Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cartoon Network| #6084A0| 1| 1| 0| 0',
        ' | Cartoonito.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cartoonito| #2D9EB2| 1| 1| 0| 0',
        ' | CBC Television.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CBC Television| #8F96BA| 1| 1| 0| 0',
        ' | CBC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CBC| #9D3B3F| 1| 1| 0| 0',
        ' | Cbeebies.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cbeebies| #3E0EA0| 1| 1| 0| 0',
        ' | CBS.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CBS| #2926C0| 1| 1| 0| 0',
        ' | Channel 3.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Channel 3| #FF85AF| 1| 1| 0| 0',
        ' | Channel 4.png| +0| 1000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Channel 4| #2B297D| 1| 1| 0| 0',
        ' | Channel 5.png| +0| 1000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Channel 5| #8C28AD| 1| 1| 0| 0',
        ' | CHCH-DT.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CHCH-DT| #F75C5A| 1| 1| 0| 0',
        ' | Cinemax.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cinemax| #B4AB22| 1| 1| 0| 0',
        ' | Citytv.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Citytv| #C23B40| 1| 1| 0| 0',
        ' | CNN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CNN| #AE605C| 1| 1| 0| 0',
        ' | Comedy Central.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Comedy Central| #BFB516| 1| 1| 0| 0',
        ' | Cooking Channel.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cooking Channel| #C29B16| 1| 1| 0| 0',
        ' | Crackle.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crackle| #88D6B9| 1| 1| 0| 0',
        ' | Crave.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crave| #F2C019| 1| 1| 0| 0',
        ' | Criterion Channel.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Criterion Channel| #810BA7| 1| 1| 0| 0',
        ' | Crunchyroll.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crunchyroll| #8372D1| 1| 1| 0| 0',
        ' | CTV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CTV| #1FAA3C| 1| 1| 0| 0',
        ' | Cuatro.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cuatro| #D46CD7| 1| 1| 0| 0',
        ' | Curiosity Stream.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Curiosity Stream| #BF983F| 1| 1| 0| 0',
        ' | Dave.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dave| #32336C| 1| 1| 0| 0',
        ' | DC Universe.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DC Universe| #9B0221| 1| 1| 0| 0',
        ' | Discovery Kids.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Discovery Kids| #1C7A1E| 1| 1| 0| 0',
        ' | discovery+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | discovery+| #2175D9| 1| 1| 0| 0',
        ' | Discovery.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Discovery| #1E1CBD| 1| 1| 0| 0',
        ' | Disney Channel.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney Channel| #3679C4| 1| 1| 0| 0',
        ' | Disney Junior.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney Junior| #09AEEF| 1| 1| 0| 0',
        ' | Disney XD.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney XD| #6BAB6D| 1| 1| 0| 0',
        ' | Disney+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney+| #0F2FA4| 1| 1| 0| 0',
        ' | DR1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DR1| #DEFF1E| 1| 1| 0| 0',
        ' | Dropout.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dropout| #853211| 1| 1| 0| 0',
        ' | E!.png| +0| 500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | E!| #BF3137| 1| 1| 0| 0',
        ' | Eden.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eden| #D1A72C| 1| 1| 0| 0',
        ' | Elisa Viihde Viaplay.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Elisa Viihde Viaplay| #692C72| 1| 1| 0| 0',
        ' | Elisa Viihde.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Elisa Viihde| #1DF3B7| 1| 1| 0| 0',
        ' | ENA.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ENA| #0F2590| 1| 1| 0| 0',
        ' | Epix.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Epix| #8E782B| 1| 1| 0| 0',
        ' | ESPN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ESPN| #2C8B0A| 1| 1| 0| 0',
        ' | EXXEN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | EXXEN| #5996D4| 1| 1| 0| 0',
        ' | Facebook Watch.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Facebook Watch| #E7F7B1| 1| 1| 0| 0',
        ' | Family Channel.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Family Channel| #3841B6| 1| 1| 0| 0',
        ' | Ficción Producciones.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ficción Producciones| #DE282F| 1| 1| 0| 0',
        ' | Flooxer.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Flooxer| #AD128E| 1| 1| 0| 0',
        ' | Food Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Food Network| #B97A7C| 1| 1| 0| 0',
        ' | Fox Kids.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fox Kids| #B7282D| 1| 1| 0| 0',
        ' | FOX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | FOX| #474EAB| 1| 1| 0| 0',
        ' | France 2.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | France 2| #A17059| 1| 1| 0| 0',
        ' | Freeform.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Freeform| #3C9C3E| 1| 1| 0| 0',
        ' | Freevee.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Freevee| #B5CF1B| 1| 1| 0| 0',
        ' | Fuji TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fuji TV| #29319C| 1| 1| 0| 0',
        ' | funnyordie.com.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | funnyordie.com| #1F80A8| 1| 1| 0| 0',
        ' | FX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | FX| #4A51A9| 1| 1| 0| 0',
        ' | FXX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | FXX| #5070A7| 1| 1| 0| 0',
        ' | Game Show Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Game Show Network| #BA27BF| 1| 1| 0| 0',
        ' | GAİN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | GAİN| #EA8897| 1| 1| 0| 0',
        ' | Global TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Global TV| #409E42| 1| 1| 0| 0',
        ' | Globoplay.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Globoplay| #775E92| 1| 1| 0| 0',
        ' | GMA Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | GMA Network| #A755A4| 1| 1| 0| 0',
        ' | Hallmark.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hallmark| #601CB4| 1| 1| 0| 0',
        ' | HBO.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HBO| #458EAD| 1| 1| 0| 0',
        ' | HBO Max.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HBO Max| #4C0870| 1| 1| 0| 0',
        ' | HGTV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HGTV| #3CA38F| 1| 1| 0| 0',
        ' | History.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | History| #A57E2E| 1| 1| 0| 0',
        ' | HOT3.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HOT3| #934C19| 1| 1| 0| 0',
        ' | Hulu.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hulu| #A52633| 1| 1| 0| 0',
        ' | ICTV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ICTV| #6AF88D| 1| 1| 0| 0',
        ' | IFC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IFC| #296FB4| 1| 1| 0| 0',
        ' | IMDb TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IMDb TV| #C1CD2F| 1| 1| 0| 0',
        ' | Investigation Discovery.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Investigation Discovery| #3AE9E3| 1| 1| 0| 0',
        ' | ION Television.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ION Television| #850ECC| 1| 1| 0| 0',
        ' | iQiyi.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | iQiyi| #F26F4C| 1| 1| 0| 0',
        ' | ITV Encore.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITV Encore| #A0EE56| 1| 1| 0| 0',
        ' | ITV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITV| #B024B5| 1| 1| 0| 0',
        ' | ITV1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITV1| #9523F9| 1| 1| 0| 0',
        ' | ITV2.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITV2| #1B65E1| 1| 1| 0| 0',
        ' | ITV3.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITV3| #29B067| 1| 1| 0| 0',
        ' | ITV4.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITV4| #346DF9| 1| 1| 0| 0',
        ' | ITVBe.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITVBe| #CC4EE9| 1| 1| 0| 0',
        ' | ITVX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITVX| #E8298D| 1| 1| 0| 0',
        ' | JioCinema.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | JioCinema| #6A3B33| 1| 1| 0| 0',
        ' | joyn.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | joyn| #D35503| 1| 1| 0| 0',
        ' | JTBC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | JTBC| #2E8D84| 1| 1| 0| 0',
        ' | Kan 11.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kan 11| #F73F64| 1| 1| 0| 0',
        ' | Kanal 5.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kanal 5| #19805A| 1| 1| 0| 0',
        ' | KBS2.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | KBS2| #0D197B| 1| 1| 0| 0',
        ' | Kids WB.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kids WB| #B52429| 1| 1| 0| 0',
        ' | La 1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | La 1| #21FEF9| 1| 1| 0| 0',
        ' | La Une.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | La Une| #E8AD81| 1| 1| 0| 0',
        ' | Las Estrellas.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Las Estrellas| #DD983B| 1| 1| 0| 0',
        ' | Lifetime.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lifetime| #0F1736| 1| 1| 0| 0',
        ' | Lionsgate+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lionsgate+| #F627E7| 1| 1| 0| 0',
        ' | Logo.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Logo| #E5DA88| 1| 1| 0| 0',
        ' | M-Net.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | M-Net| #29C617| 1| 1| 0| 0',
        ' | Magnolia Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Magnolia Network| #F958C2| 1| 1| 0| 0',
        ' | MasterClass.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MasterClass| #4D4D4D| 1| 1| 0| 0',
        ' | Max.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Max| #DE9F02| 1| 1| 0| 0',
        ' | MBC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MBC| #AF1287| 1| 1| 0| 0',
        ' | MBN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MBN| #E40023| 1| 1| 0| 0',
        ' | MGM+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MGM+| #3F35AD| 1| 1| 0| 0',
        ' | mitele.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mitele| #DAF0CE| 1| 1| 0| 0',
        ' | Movistar Plus+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Movistar Plus+| #A6C708| 1| 1| 0| 0',
        ' | MTV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MTV| #76A3AF| 1| 1| 0| 0',
        ' | National Geographic.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | National Geographic| #C6B31B| 1| 1| 0| 0',
        ' | NBC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NBC| #703AAC| 1| 1| 0| 0',
        ' | Netflix.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Netflix| #748EC2| 1| 1| 0| 0',
        ' | Network 10.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Network 10| #28846E| 1| 1| 0| 0',
        ' | NFL Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NFL Network| #78BDFF| 1| 1| 0| 0',
        ' | NHK.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NHK| #F3D015| 1| 1| 0| 0',
        ' | Nick Jr.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nick Jr| #4290A4| 1| 1| 0| 0',
        ' | Nick.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nick| #B68021| 1| 1| 0| 0',
        ' | Nickelodeon.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nickelodeon| #42017F| 1| 1| 0| 0',
        ' | Nicktoons.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nicktoons| #C56B17| 1| 1| 0| 0',
        ' | Nine Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nine Network| #9DE6E4| 1| 1| 0| 0',
        ' | Nippon TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nippon TV| #7E180F| 1| 1| 0| 0',
        ' | NRK1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NRK1| #8C17EF| 1| 1| 0| 0',
        ' | OCS City.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | OCS City| #806AA6| 1| 1| 0| 0',
        ' | OCS Max.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | OCS Max| #CCCC46| 1| 1| 0| 0',
        ' | ORF.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ORF| #11EA47| 1| 1| 0| 0',
        ' | Oxygen.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Oxygen| #CBB23E| 1| 1| 0| 0',
        ' | Pantaya.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pantaya| #64C78B| 1| 1| 0| 0',
        ' | Paramount Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount Network| #D8F7E6| 1| 1| 0| 0',
        ' | Paramount+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount+| #2A67CC| 1| 1| 0| 0',
        ' | PBS Kids.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PBS Kids| #47A149| 1| 1| 0| 0',
        ' | PBS.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PBS| #8F321D| 1| 1| 0| 0',
        ' | Peacock.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Peacock| #DA4428| 1| 1| 0| 0',
        ' | Planète+ A&E.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Planète+ A&E| #038502| 1| 1| 0| 0',
        ' | Prime Video.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prime Video| #CB2770| 1| 1| 0| 0',
        ' | Quibi.png| +0| 1400| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Quibi| #FFF9C4| 1| 1| 0| 0',
        ' | Rai 1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Rai 1| #BC1E71| 1| 1| 0| 0',
        ' | Reelz.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Reelz| #0C1668| 1| 1| 0| 0',
        ' | RTL Télé.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RTL Télé| #6790B5| 1| 1| 0| 0',
        ' | RTL.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RTL| #21354A| 1| 1| 0| 0',
        ' | RTP1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RTP1| #7C7906| 1| 1| 0| 0',
        ' | RTÉ One.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RTÉ One| #8F2C48| 1| 1| 0| 0',
        ' | RÚV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RÚV| #773351| 1| 1| 0| 0',
        ' | S4C.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | S4C| #E105D9| 1| 1| 0| 0',
        ' | SAT.1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SAT.1| #E1847D| 1| 1| 0| 0',
        ' | SBS.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SBS| #BEBC19| 1| 1| 0| 0',
        ' | Science.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Science| #DA2988| 1| 1| 0| 0',
        ' | Seeso.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Seeso| #0A0379| 1| 1| 0| 0',
        ' | Seven Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Seven Network| #DA54DA| 1| 1| 0| 0',
        ' | Shahid.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shahid| #7FEB9A| 1| 1| 0| 0',
        ' | Showcase.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Showcase| #4D4D4D| 1| 1| 0| 0',
        ' | Showmax.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Showmax| #22D2D6| 1| 1| 0| 0',
        ' | Showtime.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Showtime| #C2201F| 1| 1| 0| 0',
        ' | Shudder.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shudder| #0D0C89| 1| 1| 0| 0',
        ' | Sky.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sky| #BC3272| 1| 1| 0| 0',
        ' | Smithsonian.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Smithsonian| #303F8F| 1| 1| 0| 0',
        ' | Space.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Space| #990BA9| 1| 1| 0| 0',
        ' | Spectrum.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spectrum| #0997E1| 1| 1| 0| 0',
        ' | Spike.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spike| #454CAF| 1| 1| 0| 0',
        ' | Stan.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stan| #227CC0| 1| 1| 0| 0',
        ' | STAR+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | STAR+| #B263B8| 1| 1| 0| 0',
        ' | Starz.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Starz| #464646| 1| 1| 0| 0',
        ' | Stöð 2.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stöð 2| #83CC89| 1| 1| 0| 0',
        ' | Sundance TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sundance TV| #424242| 1| 1| 0| 0',
        ' | SVT Play.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SVT Play| #5B4F8F| 1| 1| 0| 0',
        ' | SVT.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SVT| #C3ACE5| 1| 1| 0| 0',
        ' | SVT1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SVT1| #94BE7C| 1| 1| 0| 0',
        ' | Syfy.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Syfy| #BEB42D| 1| 1| 0| 0',
        ' | Syndication.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Syndication| #523E40| 1| 1| 0| 0',
        ' | TBS.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TBS| #A139BF| 1| 1| 0| 0',
        ' | Telecinco.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Telecinco| #190874| 1| 1| 0| 0',
        ' | Telefe.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Telefe| #D6DBFC| 1| 1| 0| 0',
        ' | Telemundo.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Telemundo| #407160| 1| 1| 0| 0',
        ' | Televisión de Galicia.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Televisión de Galicia| #156A6E| 1| 1| 0| 0',
        ' | Televisión Pública Argentina.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Televisión Pública Argentina| #F47B8E| 1| 1| 0| 0',
        ' | Tencent Video.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tencent Video| #DE90F0| 1| 1| 0| 0',
        ' | TF1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TF1| #43D582| 1| 1| 0| 0',
        ' | The CW.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The CW| #397F96| 1| 1| 0| 0',
        ' | The Daily Wire.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Daily Wire| #5C3BC9| 1| 1| 0| 0',
        ' | The Roku Channel.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Roku Channel| #4C5C75| 1| 1| 0| 0',
        ' | The WB.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The WB| #08F615| 1| 1| 0| 0',
        ' | TLC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TLC| #BA6C70| 1| 1| 0| 0',
        ' | TNT.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TNT| #C1B83A| 1| 1| 0| 0',
        ' | Tokyo MX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tokyo MX| #0407A9| 1| 1| 0| 0',
        ' | Travel Channel.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Travel Channel| #D4FFD9| 1| 1| 0| 0',
        ' | truTV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | truTV| #C79F26| 1| 1| 0| 0',
        ' | tubi.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tubi| #873AEF| 1| 1| 0| 0',
        ' | Turner Classic Movies.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Turner Classic Movies| #616161| 1| 1| 0| 0',
        ' | TV 2.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV 2| #8040C7| 1| 1| 0| 0',
        ' | tv asahi.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tv asahi| #97A092| 1| 1| 0| 0',
        ' | TV Globo.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV Globo| #C8A69F| 1| 1| 0| 0',
        ' | TV Land.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV Land| #78AFB4| 1| 1| 0| 0',
        ' | TV Tokyo.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV Tokyo| #EC00E2| 1| 1| 0| 0',
        ' | TV3.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV3| #FACED0| 1| 1| 0| 0',
        ' | TV4 Play.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV4 Play| #AE56EC| 1| 1| 0| 0',
        ' | TV4.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TV4| #82E7BF| 1| 1| 0| 0',
        ' | TVB Jade.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TVB Jade| #C6582F| 1| 1| 0| 0',
        ' | tving.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tving| #B2970D| 1| 1| 0| 0',
        ' | tvN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tvN| #510F23| 1| 1| 0| 0',
        ' | TVNZ 1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TVNZ 1| #BF8B82| 1| 1| 0| 0',
        ' | TVNZ 2.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TVNZ 2| #895639| 1| 1| 0| 0',
        ' | TVP1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TVP1| #412AF2| 1| 1| 0| 0',
        ' | U+ Mobile TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | U+ Mobile TV| #10F57D| 1| 1| 0| 0',
        ' | UKTV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | UKTV| #2EADB1| 1| 1| 0| 0',
        ' | UniMás.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | UniMás| #3A4669| 1| 1| 0| 0',
        ' | Universal Kids.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Universal Kids| #2985A1| 1| 1| 0| 0',
        ' | Universal TV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Universal TV| #29D252| 1| 1| 0| 0',
        ' | Univision.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Univision| #28BE59| 1| 1| 0| 0',
        ' | UPN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | UPN| #C6864E| 1| 1| 0| 0',
        ' | USA Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | USA Network| #F7EB20| 1| 1| 0| 0',
        ' | VH1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | VH1| #8E3BB1| 1| 1| 0| 0',
        ' | Viaplay.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Viaplay| #30F7FB| 1| 1| 0| 0',
        ' | Vice.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Vice| #D3D3D3| 1| 1| 0| 0',
        ' | Virgin Media One.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Virgin Media One| #79095A| 1| 1| 0| 0',
        ' | ViuTV.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ViuTV| #F93EDE| 1| 1| 0| 0',
        ' | ViX+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ViX+| #00AA96| 1| 1| 0| 0',
        ' | ViX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ViX| #586CA6| 1| 1| 0| 0',
        ' | VRT 1.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | VRT 1| #680F46| 1| 1| 0| 0',
        ' | VRT Max.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | VRT Max| #0BDA4C| 1| 1| 0| 0',
        ' | VTM.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | VTM| #9164A7| 1| 1| 0| 0',
        ' | W.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | W| #E60A55| 1| 1| 0| 0',
        ' | WE tv.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | WE tv| #15DD51| 1| 1| 0| 0',
        ' | Xbox Live.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Xbox Live| #1771F3| 1| 1| 0| 0',
        ' | YLE.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | YLE| #3A8722| 1| 1| 0| 0',
        ' | Youku.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Youku| #42809E| 1| 1| 0| 0',
        ' | YouTube.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | YouTube| #C51414| 1| 1| 0| 0',
        ' | ZDF.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ZDF| #C58654| 1| 1| 0| 0',
        ' | ZEE5.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ZEE5| #8704C1| 1| 1| 0| 0'
        ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination network\color

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\white\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'network_kids_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Kids Networks| #FF2000| 1| 1| 0| 1',
        'network_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Other Networks| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination network\white
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
    $theMaxWidth = 1600
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 140

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'TIMELINE_ORDER| Arrowverse.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | Arrowverse (Timeline Order)| #2B8F40| 1| 1| 0| 1',
        'TIMELINE_ORDER| DragonBall.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | Dragon Ball (Timeline Order)| #E39D30| 1| 1| 0| 1',
        'TIMELINE_ORDER| Marvel Cinematic Universe.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | Marvel Cinematic Universe (Timeline Order)| #AD2B2B| 1| 1| 0| 1',
        'TIMELINE_ORDER| Star Trek.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | Star Trek (Timeline Order)| #0193DD| 1| 1| 0| 1',
        'TIMELINE_ORDER| Pokémon.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | Pokémon (Timeline Order)| #FECA06| 1| 1| 0| 1',
        'TIMELINE_ORDER| dca.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | DC Animated Universe (Timeline Order)| #2832C4| 1| 1| 0| 1',
        'TIMELINE_ORDER| X-men.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | X-Men (Timeline Order)| #636363| 1| 1| 0| 1',
        'TIMELINE_ORDER| Star Wars The Clone Wars.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | Star Wars The Clone Wars (Timeline Order)| #ED1C24| 1| 1| 0| 1',
        'TIMELINE_ORDER| Star Wars.png| -200| 1600| +450| Bebas-Regular| | #FFFFFF| 0| 15| #FFFFFF| | Star Wars (Timeline Order)| #F8C60A| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

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
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250
    
    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'resolutions_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| 4K.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 4k| #8A46CF| 1| 1| 0| 1',
        '| 8K.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 8k| #95BCDC| 1| 1| 0| 1',
        '| 144p.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 144| #F0C5E5| 1| 1| 0| 1',
        '| 240p.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 240| #DFA172| 1| 1| 0| 1',
        '| 360p.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 360| #6D3FDC| 1| 1| 0| 1',
        '| 480p.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 480| #3996D3| 1| 1| 0| 1',
        '| 576p.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 576| #DED1B2| 1| 1| 0| 1',
        '| 720p.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 720| #30DC76| 1| 1| 0| 1',
        '| 1080p.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1080| #D60C0C| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'


    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination resolution
    
    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'resolutions_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| ultrahd.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 4k| #8A46CF| 1| 1| 0| 1',
        '| sd.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 480| #95BCDC| 1| 1| 0| 1',
        '| hdready.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 720| #F0C5E5| 1| 1| 0| 1',
        '| fullhd.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1080| #DFA172| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_resolution\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

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
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '4/20| 420.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 420| #43C32F| 1| 1| 0| 1',
        'ASIAN_AMERICAN_PACIFIC_ISLANDER_HERITAGE_MONTH| APAC month.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | aapi| #0EC26B| 1| 1| 0| 1',
        'BLACK_HISTORY_MONTH| Black History.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | black_history| #D86820| 1| 1| 0| 0',
        'BLACK_HISTORY_MONTH| Black History2.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | black_history2| #D86820| 1| 1| 0| 1',
        'CHRISTMAS| christmas.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | christmas| #D52414| 1| 1| 0| 1',
        'CHRISTMAS_CARTOONS| christmas.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | christmas_cartoons| #D52414| 1| 1| 0| 1',
        'CHRISTMAS_EPISODES| christmas.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | christmas_episodes| #D52414| 1| 1| 0| 1',
        'DAY_OF_PERSONS_WITH_DISABILITIES| Disabilities.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | disabilities| #40B9FE| 1| 1| 0| 1',
        'EASTER| easter.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | easter| #46D69D| 1| 1| 0| 1',
        'FATHERS_DAY| father.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | father| #7CDA83| 1| 1| 0| 1',
        'HALLOWEEN| halloween.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | halloween| #DA8B25| 1| 1| 0| 1',
        'INDEPENDENCE_DAY| independence.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | independence| #2931CB| 1| 1| 0| 1',
        'LABOR_DAY| labor.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | labor| #DA5C5E| 1| 1| 0| 1',
        'LATINX_HERITAGE_MONTH| LatinX Month.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | latinx| #FF5F5F| 1| 1| 0| 1',
        'LGBTQ_PRIDE_MONTH| LGBTQ+ Month.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lgbtq| #FF3B3C| 1| 1| 0| 1',
        'MEMORIAL_DAY| memorial.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | memorial| #917C5C| 1| 1| 0| 1',
        'MOTHERS_DAY| mother.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mother| #DB81D6| 1| 1| 0| 1',
        'ST_PATRICKS_DAY| patrick.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | patrick| #26A53E| 1| 1| 0| 1',
        'THANKSGIVING| thanksgiving.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | thanksgiving| #A1841E| 1| 1| 0| 1',
        'VALENTINES_DAY| valentine.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | valentine| #D12AAE| 1| 1| 0| 1',
        'VETERANS_DAY| veteran.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | veteran| #B6AD93| 1| 1| 0| 1',
        'WOMENS_HISTORY_MONTH| Womens History.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | women| #874E83| 1| 1| 0| 1',
        'NEW_YEAR| years.png| -500| 1800| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | years| #444444| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

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
    Set-Location $script_path
    Move-Item -Path output -Destination output-orig
    Find-Path "$script_path\output"
    $colors = @('amethyst', 'aqua', 'blue', 'forest', 'fuchsia', 'gold', 'gray', 'green', 'navy', 'ocean', 'olive', 'orchid', 'orig', 'pink', 'plum', 'purple', 'red', 'rust', 'salmon', 'sand', 'stb', 'tan')
    foreach ($color in $colors) {
        Find-Path "$script_path\output\$color"
    }

    $value = Get-YamlPropertyValue -PropertyPath "collections.COLLECTIONLESS.name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper

    .\create_poster.ps1 -logo "$script_path\logos_chart\Plex.png" -logo_offset -500 -logo_resize 1500 -text "$value" -text_offset +850 -font "ComfortAa-Medium" -font_size 195 -font_color "#FFFFFF" -border 0 -border_width 15 -border_color "#FFFFFF" -avg_color_image "" -out_name "collectionless" -base_color "#DC9924" -gradient 1 -avg_color 0 -clean 1 -white_wash 1
    Move-Item -Path $script_path\output\collectionless.jpg -Destination $script_path\collectionless.jpg

    $theMaxWidth = 1900
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 203

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'COLLECTIONLESS| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | collectionless| | 0| 1| 0| 0',
        'ACTOR| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | actor| | 0| 1| 0| 0',
        'ASPECT_RATIO| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | aspect| | 0| 1| 0| 0',
        'AUDIO_LANGUAGE| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | audio_language| | 0| 1| 0| 0',
        'AWARD| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | award| | 0| 1| 0| 0',
        'CHART| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | chart| | 0| 1| 0| 0',
        'CONTENT_RATINGS| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | content_rating| | 0| 1| 0| 0',
        'COUNTRY| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | country| | 0| 1| 0| 0',
        'CONTINENT| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | continent| | 0| 1| 0| 0',
        'DECADE| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | decade| | 0| 1| 0| 0',
        'DIRECTOR| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | director| | 0| 1| 0| 0',
        'FRANCHISE| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | franchise| | 0| 1| 0| 0',
        'GENRE| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | genre| | 0| 1| 0| 0',
        'KIDS_NETWORK| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | network_kids| | 0| 1| 0| 0',
        'MOVIE_CHART| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | movie_chart| | 0| 1| 0| 0',
        'NETWORK| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | network| | 0| 1| 0| 0',
        'PERSONAL| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | personal| | 0| 1| 0| 0',
        'PRODUCER| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | producer| | 0| 1| 0| 0',
        'REGION| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | region| | 0| 1| 0| 0',
        'RESOLUTION| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | resolution| | 0| 1| 0| 0',
        'SEASONAL| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | seasonal| | 0| 1| 0| 0',
        'STREAMING| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | streaming| | 0| 1| 0| 0',
        'STUDIO_ANIMATION| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | studio_animation| | 0| 1| 0| 0',
        'STUDIO| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | studio| | 0| 1| 0| 0',
        'SUBTITLE| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | subtitle_language| | 0| 1| 0| 0',
        'TV_CHART| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tv_chart| | 0| 1| 0| 0',
        'UK_NETWORK| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | network_uk| | 0| 1| 0| 0',
        'UK_STREAMING| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | streaming_uk| | 0| 1| 0| 0',
        'UNIVERSE| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | universe| | 0| 1| 0| 0',
        'US_NETWORK| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | network_us| | 0| 1| 0| 0',
        'US_STREAMING| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | streaming_us| | 0| 1| 0| 0',
        'WRITER| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | writer| | 0| 1| 0| 0',
        'YEAR| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | year| | 0| 1| 0| 0',
        'BASED_ON| | +0| 2000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | based| | 0| 1| 0| 0'
    ) | ConvertFrom-Csv -Delimiter '|'

    $pre_value = Get-YamlPropertyValue -PropertyPath "collections.separator.name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper

    $arr = @()
    foreach ($item in $myArray) {
        $value = Set-TextBetweenDelimiters -InputString $pre_value -ReplacementString (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        foreach ($color in $colors) {
            $arr += ".\create_poster.ps1 -logo `"$script_path\@base\$color.png`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"\$color\$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination separators
    Copy-Item -Path "@base" -Destination "separators\@base" -Recurse
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateStreaming
# Description:  Creates Streaming
################################################################################
Function CreateStreaming {
    Write-Host "Creating Streaming"
    Set-Location $script_path
    Find-Path "$script_path\streaming"
    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| All 4.png| +0| 1000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | All 4| #14AE9A| 1| 1| 0| 0',
        '| AMC+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AMC+| #B80F05| 1| 1| 0| 0',
        '| Apple TV+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Apple TV+| #494949| 1| 1| 0| 0',
        '| Atres Player.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Atres Player| #822AC4| 1| 1| 0| 0',
        '| BET+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BET+| #8A2978| 1| 1| 0| 0',
        '| BritBox.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BritBox| #198CA8| 1| 1| 0| 0',
        '| Channel 4.png| +0| 1000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Channel 4| #292929| 1| 1| 0| 0',
        '| Crave.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crave| #29C2F1| 1| 1| 0| 0',
        '| Crunchyroll.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crunchyroll| #9A5C16| 1| 1| 0| 0',
        '| discovery+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | discovery+| #2175D9| 1| 1| 0| 0',
        '| Disney+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney+| #0F2FA4| 1| 1| 0| 0',
        '| Filmin.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Filmin| #145ED1| 1| 1| 0| 0',
        '| Funimation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Funimation| #D6CFF1| 1| 1| 0| 0',
        '| hayu.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hayu| #9B3E55| 1| 1| 0| 0',
        '| HBO Max.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HBO Max| #4C0870| 1| 1| 0| 0',
        '| Hulu.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hulu| #1BC073| 1| 1| 0| 0',
        '| ITVX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITVX| #00303E| 1| 1| 0| 0',
        '| Max.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Max| #002BE7| 1| 1| 0| 0',
        '| Movistar Plus+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Movistar Plus+| #A6C708| 1| 1| 0| 0',
        '| My 5.png| +0| 1000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | My 5| #426282| 1| 1| 0| 0',
        '| Netflix.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Netflix| #5E0A11| 1| 1| 0| 0',
        '| NOW.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NOW| #688587| 1| 1| 0| 0',
        '| Paramount+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount+| #2A67CC| 1| 1| 0| 0',
        '| Peacock.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Peacock| #DA4428| 1| 1| 0| 0',
        '| Prime Video.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prime Video| #11607E| 1| 1| 0| 0',
        '| Quibi.png| +0| 1400| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Quibi| #FFF9C4| 1| 1| 0| 0',
        '| Showtime.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Showtime| #8F1212| 1| 1| 0| 0',
        '| Stan.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stan| #227CC0| 1| 1| 0| 0',
        '| tubi.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tubi| #873AEF| 1| 1| 0| 0',
        '| YouTube.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | YouTube| #CD201F| 1| 1| 0| 0',
        'MOVIES| All 4.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | All 4_movies| #14AE9A| 1| 1| 0| 0',
        'MOVIES| AMC+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AMC+_movies| #B80F05| 1| 1| 0| 0',
        'MOVIES| Apple TV+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Apple TV+_movies| #494949| 1| 1| 0| 0',
        'MOVIES| Atres Player.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Atres Player_movies| #822AC4| 1| 1| 0| 0',
        'MOVIES| BET+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BET+_movies| #8A2978| 1| 1| 0| 0',
        'MOVIES| BritBox.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BritBox_movies| #198CA8| 1| 1| 0| 0',
        'MOVIES| Channel 4.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Channel 4_movies| #292929| 1| 1| 0| 0',
        'MOVIES| Crave.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crave_movies| #29C2F1| 1| 1| 0| 0',
        'MOVIES| Crunchyroll.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crunchyroll_movies| #9A5C16| 1| 1| 0| 0',
        'MOVIES| discovery+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | discovery+_movies| #2175D9| 1| 1| 0| 0',
        'MOVIES| Disney+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney+_movies| #0F2FA4| 1| 1| 0| 0',
        'MOVIES| Filmin.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Filmin_movies| #145ED1| 1| 1| 0| 0',
        'MOVIES| Funimation.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Funimation_movies| #D6CFF1| 1| 1| 0| 0',
        'MOVIES| hayu.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hayu_movies| #9B3E55| 1| 1| 0| 0',
        'MOVIES| HBO Max.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HBO Max_movies| #4C0870| 1| 1| 0| 0',
        'MOVIES| Hulu.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hulu_movies| #1BC073| 1| 1| 0| 0',
        'MOVIES| ITVX.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITVX_movies| #00303E| 1| 1| 0| 0',
        'MOVIES| Max.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Max_movies| #002BE7| 1| 1| 0| 0',
        'MOVIES| Movistar Plus+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Movistar Plus+_movies| #A6C708| 1| 1| 0| 0',
        'MOVIES| My 5.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | My 5_movies| #426282| 1| 1| 0| 0',
        'MOVIES| Netflix.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Netflix_movies| #5E0A11| 1| 1| 0| 0',
        'MOVIES| NOW.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NOW_movies| #688587| 1| 1| 0| 0',
        'MOVIES| Paramount+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount+_movies| #2A67CC| 1| 1| 0| 0',
        'MOVIES| Peacock.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Peacock_movies| #DA4428| 1| 1| 0| 0',
        'MOVIES| Prime Video.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prime Video_movies| #11607E| 1| 1| 0| 0',
        'MOVIES| Quibi.png| -500| 1400| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Quibi_movies| #FFF9C4| 1| 1| 0| 0',
        'MOVIES| Showtime.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Showtime_movies| #8F1212| 1| 1| 0| 0',
        'MOVIES| Stan.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stan_movies| #227CC0| 1| 1| 0| 0',
        'MOVIES| tubi.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tubi_movies| #873AEF| 1| 1| 0| 0',
        'MOVIES| YouTube.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | YouTube_movies| #CD201F| 1| 1| 0| 0',
        'SHOWS| All 4.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | All 4_shows| #14AE9A| 1| 1| 0| 0',
        'SHOWS| AMC+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AMC+_shows| #B80F05| 1| 1| 0| 0',
        'SHOWS| Apple TV+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Apple TV+_shows| #494949| 1| 1| 0| 0',
        'SHOWS| Atres Player.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Atres Player_shows| #822AC4| 1| 1| 0| 0',
        'SHOWS| BET+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BET+_shows| #8A2978| 1| 1| 0| 0',
        'SHOWS| BritBox.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BritBox_shows| #198CA8| 1| 1| 0| 0',
        'SHOWS| Channel 4.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Channel 4_shows| #292929| 1| 1| 0| 0',
        'SHOWS| Crave.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crave_shows| #29C2F1| 1| 1| 0| 0',
        'SHOWS| Crunchyroll.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crunchyroll_shows| #9A5C16| 1| 1| 0| 0',
        'SHOWS| discovery+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | discovery+_shows| #2175D9| 1| 1| 0| 0',
        'SHOWS| Disney+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney+_shows| #0F2FA4| 1| 1| 0| 0',
        'SHOWS| Filmin.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Filmin_shows| #145ED1| 1| 1| 0| 0',
        'SHOWS| Funimation.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Funimation_shows| #D6CFF1| 1| 1| 0| 0',
        'SHOWS| hayu.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hayu_shows| #9B3E55| 1| 1| 0| 0',
        'SHOWS| HBO Max.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HBO Max_shows| #4C0870| 1| 1| 0| 0',
        'SHOWS| Hulu.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hulu_shows| #1BC073| 1| 1| 0| 0',
        'SHOWS| ITVX.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITVX_shows| #00303E| 1| 1| 0| 0',
        'SHOWS| Max.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Max_shows| #002BE7| 1| 1| 0| 0',
        'SHOWS| Movistar Plus+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Movistar Plus+_shows| #A6C708| 1| 1| 0| 0',
        'SHOWS| My 5.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | My 5_shows| #426282| 1| 1| 0| 0',
        'SHOWS| Netflix.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Netflix_shows| #5E0A11| 1| 1| 0| 0',
        'SHOWS| NOW.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NOW_shows| #688587| 1| 1| 0| 0',
        'SHOWS| Paramount+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount+_shows| #2A67CC| 1| 1| 0| 0',
        'SHOWS| Peacock.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Peacock_shows| #DA4428| 1| 1| 0| 0',
        'SHOWS| Prime Video.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prime Video_shows| #11607E| 1| 1| 0| 0',
        'SHOWS| Quibi.png| -500| 1400| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Quibi_shows| #FFF9C4| 1| 1| 0| 0',
        'SHOWS| Showtime.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Showtime_shows| #8F1212| 1| 1| 0| 0',
        'SHOWS| Stan.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stan_shows| #227CC0| 1| 1| 0| 0',
        'SHOWS| tubi.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tubi_shows| #873AEF| 1| 1| 0| 0',
        'SHOWS| YouTube.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | YouTube_shows| #CD201F| 1| 1| 0| 0',
        'ORIGINALS| All 4.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | All 4_originals| #14AE9A| 1| 1| 0| 0',
        'ORIGINALS| AMC+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AMC+_originals| #B80F05| 1| 1| 0| 0',
        'ORIGINALS| Apple TV+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Apple TV+_originals| #494949| 1| 1| 0| 0',
        'ORIGINALS| Atres Player.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Atres Player_originals| #822AC4| 1| 1| 0| 0',
        'ORIGINALS| BET+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BET+_originals| #8A2978| 1| 1| 0| 0',
        'ORIGINALS| BritBox.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BritBox_originals| #198CA8| 1| 1| 0| 0',
        'ORIGINALS| Channel 4.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Channel 4_originals| #292929| 1| 1| 0| 0',
        'ORIGINALS| Crave.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crave_originals| #29C2F1| 1| 1| 0| 0',
        'ORIGINALS| Crunchyroll.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Crunchyroll_originals| #9A5C16| 1| 1| 0| 0',
        'ORIGINALS| discovery+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | discovery+_originals| #2175D9| 1| 1| 0| 0',
        'ORIGINALS| Disney+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Disney+_originals| #0F2FA4| 1| 1| 0| 0',
        'ORIGINALS| Filmin.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Filmin_originals| #145ED1| 1| 1| 0| 0',
        'ORIGINALS| Funimation.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Funimation_originals| #D6CFF1| 1| 1| 0| 0',
        'ORIGINALS| hayu.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hayu_originals| #9B3E55| 1| 1| 0| 0',
        'ORIGINALS| HBO Max.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HBO Max_originals| #4C0870| 1| 1| 0| 0',
        'ORIGINALS| Hulu.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hulu_originals| #1BC073| 1| 1| 0| 0',
        'ORIGINALS| ITVX.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ITVX_originals| #00303E| 1| 1| 0| 0',
        'ORIGINALS| Movistar Plus+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Max_originals| #002BE7| 1| 1| 0| 0',
        'ORIGINALS| Max.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Movistar Plus+_originals| #A6C708| 1| 1| 0| 0',
        'ORIGINALS| My 5.png| -500| 1000| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | My 5_originals| #426282| 1| 1| 0| 0',
        'ORIGINALS| Netflix.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Netflix_originals| #5E0A11| 1| 1| 0| 0',
        'ORIGINALS| NOW.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NOW_originals| #688587| 1| 1| 0| 0',
        'ORIGINALS| Paramount+.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount+_originals| #2A67CC| 1| 1| 0| 0',
        'ORIGINALS| Peacock.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Peacock_originals| #DA4428| 1| 1| 0| 0',
        'ORIGINALS| Prime Video.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prime Video_originals| #11607E| 1| 1| 0| 0',
        'ORIGINALS| Quibi.png| -500| 1400| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Quibi_originals| #FFF9C4| 1| 1| 0| 0',
        'ORIGINALS| Showtime.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Showtime_originals| #8F1212| 1| 1| 0| 0',
        'ORIGINALS| Stan.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stan_originals| #227CC0| 1| 1| 0| 0',
        'ORIGINALS| tubi.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tubi_originals| #873AEF| 1| 1| 0| 0',
        'ORIGINALS| YouTube.png| -500| 1600| +850| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | YouTube_originals| #CD201F| 1| 1| 0| 0'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination streaming\color


    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_streaming\white\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }

    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination streaming\white
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
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'studio_animation_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other_animation| #FF2000| 1| 1| 0| 1',
        'studio_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| 101 Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 101 Studios| #B69367| 1| 1| 0| 0',
'| Disney Television Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| #D19068| Disney Television Animation| #D19068| 1| 1| 0| 0',
'| DisneyToon Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DisneyToon Studios| #867CE1| 1| 1| 0| 0',
'| Dynamic Planning.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dynamic Planning| #1316DE| 1| 1| 0| 0',
'| Film4 Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Film4 Productions| #B2FCEC| 1| 1| 0| 0',
'| Golden Harvest.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Golden Harvest| #A21FBF| 1| 1| 0| 0',
'| Hungry Man.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hungry Man| #7C3476| 1| 1| 0| 0',
'| Screen Gems.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Screen Gems| #7A7A70| 1| 1| 0| 0',
'| Shaw Brothers.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shaw Brothers| #F45C0B| 1| 1| 0| 0',
'| Studio Live.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Live| #62C64A| 1| 1| 0| 0',
'| The Stone Quarry.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Stone Quarry| #6727FA| 1| 1| 0| 0',
        '| Codeblack Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Codeblack Entertainment| #0CE02A| 1| 1| 0| 0',
        '| Dimension Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dimension Films| #D13B12| 1| 1| 0| 0',
        '| Broken Lizard Industries.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Broken Lizard Industries| #DA4FD2| 1| 1| 0| 0',
        '| Magic Light Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Magic Light Pictures| #BD5DEF| 1| 1| 0| 0',
        '| 1492 Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 1492 Pictures| #2BACFC| 1| 1| 0| 0',
        '| 20th Century Animation.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 20th Century Animation| #9F3137| 1| 1| 0| 0',
        '| 20th Century Fox Television.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 20th Century Fox Television| #EF3F42| 1| 1| 0| 0',
        '| 20th Century Studios.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 20th Century Studios| #3387C6| 1| 1| 0| 0',
        '| 21 Laps Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 21 Laps Entertainment| #FEC130| 1| 1| 0| 0',
        '| 3 Arts Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 3 Arts Entertainment| #245674| 1| 1| 0| 0',
        '| 6th & Idaho.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 6th & Idaho| #9539BB| 1| 1| 0| 0',
        '| 87Eleven.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 87Eleven| #00B982| 1| 1| 0| 0',
        '| 87North Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 87North Productions| #3C13A1| 1| 1| 0| 0',
        '| 8bit.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | 8bit| #365F71| 1| 1| 0| 0',
        '| A Bigger Boat.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | A Bigger Boat| #681664| 1| 1| 0| 0',
        '| A+E Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | A+E Studios| #35359B| 1| 1| 0| 0',
        '| A-1 Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | A-1 Pictures| #5776A8| 1| 1| 0| 0',
        '| A.C.G.T..png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | A.C.G.T.| #9C46DE| 1| 1| 0| 0',
        '| A24.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | A24| #B13098| 1| 1| 0| 0',
        '| Aamir Khan Productions.png| +0| 1000| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Aamir Khan Productions| #F2A153| 1| 1| 0| 0',
        '| Aardman.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Aardman| #259EA2| 1| 1| 0| 0',
        '| ABC Signature.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ABC Signature| #C127DA| 1| 1| 0| 0',
        '| ABC Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ABC Studios| #62D6AC| 1| 1| 0| 0',
        '| Acca effe.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Acca effe| #1485D0| 1| 1| 0| 0',
        '| Ace Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ace Entertainment| #C39769| 1| 1| 0| 0',
        '| Actas.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Actas| #C9C4FF| 1| 1| 0| 0',
        '| AGBO.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AGBO| #3D976E| 1| 1| 0| 0',
        '| AIC.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AIC| #6DF7FB| 1| 1| 0| 0',
        '| Ajia-Do.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ajia-Do| #665AC4| 1| 1| 0| 0',
        '| Akatsuki.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Akatsuki| #8CC0AE| 1| 1| 0| 0',
        '| Amazon Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Amazon Studios| #D28109| 1| 1| 0| 0',
        '| Amblin Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Amblin Entertainment| #394E76| 1| 1| 0| 0',
        '| AMC Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AMC Studios| #AE8434| 1| 1| 0| 0',
        '| Anima Sola Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Anima Sola Productions| #2F6DBA| 1| 1| 0| 0',
        '| Animation Do.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Animation Do| #408FE3| 1| 1| 0| 0',
        '| Ankama.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ankama| #CD717E| 1| 1| 0| 0',
        '| Annapurna Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Annapurna Pictures| #204682| 1| 1| 0| 0',
        '| APPP.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | APPP| #4D4AAD| 1| 1| 0| 0',
        '| Ardustry Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ardustry Entertainment| #DDC8F4| 1| 1| 0| 0',
        '| Arms.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Arms| #50A8C3| 1| 1| 0| 0',
        '| Artisan Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Artisan Entertainment| #DE7427| 1| 1| 0| 0',
        '| Artists First.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Artists First| #85858F| 1| 1| 0| 0',
        '| Artland.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Artland| #6157CB| 1| 1| 0| 0',
        '| Artmic.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Artmic| #7381BE| 1| 1| 0| 0',
        '| Arvo Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Arvo Animation| #6117D1| 1| 1| 0| 0',
        '| Asahi Production.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Asahi Production| #BC9A43| 1| 1| 0| 0',
        '| Ashi Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ashi Productions| #6AB420| 1| 1| 0| 0',
        '| asread..png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | asread.| #6CCDB4| 1| 1| 0| 0',
        '| AtelierPontdarc.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | AtelierPontdarc| #CD0433| 1| 1| 0| 0',
        '| Atlas Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Atlas Entertainment| #5F3C91| 1| 1| 0| 0',
        '| Atresmedia.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Atresmedia| #822EC8| 1| 1| 0| 0',
        '| B.CMAY PICTURES.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | B.CMAY PICTURES| #873E7F| 1| 1| 0| 0',
        '| Bad Hat Harry Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bad Hat Harry Productions| #FFFF00| 1| 1| 0| 0',
        '| Bad Robot.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bad Robot| #DCCCF6| 1| 1| 0| 0',
        '| Bad Wolf.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bad Wolf| #54F762| 1| 1| 0| 0',
        '| Bakken Record.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bakken Record| #4B3EDE| 1| 1| 0| 0',
        '| Bandai Namco Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bandai Namco Pictures| #4FC739| 1| 1| 0| 0',
        '| Bardel Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bardel Entertainment| #5009A5| 1| 1| 0| 0',
        '| Barunson E&A.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Barunson E&A| #E67BB5| 1| 1| 0| 0',
        '| BBC Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BBC Studios| #8E9BF1| 1| 1| 0| 0',
        '| Bee Train.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bee Train| #804F23| 1| 1| 0| 0',
        '| Berlanti Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Berlanti Productions| #03F5AB| 1| 1| 0| 0',
        '| Bibury Animation Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bibury Animation Studios| #A7FAAA| 1| 1| 0| 0',
        '| bilibili.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bilibili| #E85486| 1| 1| 0| 0',
        '| Bill Melendez Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bill Melendez Productions| #88B0AB| 1| 1| 0| 0',
        '| Blade.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Blade| #17D53B| 1| 1| 0| 0',
        '| Bleecker Street.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bleecker Street| #6561E4| 1| 1| 0| 0',
        '| Blown Deadline Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Blown Deadline Productions| #134419| 1| 1| 0| 0',
        '| Blue Ice Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Blue Ice Pictures| #072F0B| 1| 1| 0| 0',
        '| Blue Sky Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Blue Sky Studios| #1E4678| 1| 1| 0| 0',
        '| Bluegrass Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bluegrass Films| #2ABD7F| 1| 1| 0| 0',
        '| Blueprint Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Blueprint Pictures| #57F934| 1| 1| 0| 0',
        '| Blumhouse Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Blumhouse Productions| #353535| 1| 1| 0| 0',
        '| Blur Studio.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Blur Studio| #88623F| 1| 1| 0| 0',
        '| Bold Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bold Films| #853DC3| 1| 1| 0| 0',
        '| Bona Film Group.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bona Film Group| #401248| 1| 1| 0| 0',
        '| Bonanza Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bonanza Productions| #B131DE| 1| 1| 0| 0',
        '| Bones.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bones| #C4AE14| 1| 1| 0| 0',
        '| Boo Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Boo Pictures| #830777| 1| 1| 0| 0',
        '| Bosque Ranch Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bosque Ranch Productions| #604BA1| 1| 1| 0| 0',
        '| Box to Box Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Box to Box Films| #D87A5A| 1| 1| 0| 0',
        '| Brain''s Base.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Brain''s Base| #8A530E| 1| 1| 0| 0',
        '| Brandywine Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Brandywine Productions| #C47FF8| 1| 1| 0| 0',
        '| Bridge.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Bridge| #F0FF7F| 1| 1| 0| 0',
        '| Broken Road Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Broken Road Productions| #28460E| 1| 1| 0| 0',
        '| BUG FILMS.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | BUG FILMS| #A4024F| 1| 1| 0| 0',
        '| C-Station.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | C-Station| #B40C76| 1| 1| 0| 0',
        '| C2C.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | C2C| #320AE4| 1| 1| 0| 0',
        '| Calt Production.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Calt Production| #F4572C| 1| 1| 0| 0',
        '| Canal+.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Canal+| #488681| 1| 1| 0| 0',
        '| Carnival Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Carnival Films| #ABD477| 1| 1| 0| 0',
        '| Carolco.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Carolco| #684F0D| 1| 1| 0| 0',
        '| Carsey-Werner Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Carsey-Werner Company| #DCB758| 1| 1| 0| 0',
        '| Cartoon Saloon.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cartoon Saloon| #A6CB32| 1| 1| 0| 0',
        '| Castle Rock Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Castle Rock Entertainment| #7C2843| 1| 1| 0| 0',
        '| CBS Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CBS Productions| #8E6C3C| 1| 1| 0| 0',
        '| CBS Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CBS Studios| #E6DE92| 1| 1| 0| 0',
        '| CBS Television Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CBS Television Studios| #D34ABC| 1| 1| 0| 0',
        '| Centropolis Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Centropolis Entertainment| #AE1939| 1| 1| 0| 0',
        '| Chernin Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chernin Entertainment| #3D4A64| 1| 1| 0| 0',
        '| Children''s Playground Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Children''s Playground Entertainment| #151126| 1| 1| 0| 0',
        '| Chimp Television.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chimp Television| #1221EB| 1| 1| 0| 0',
        '| Chris Morgan Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Chris Morgan Productions| #DC55D3| 1| 1| 0| 0',
        '| Cinergi Pictures Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cinergi Pictures Entertainment| #A9B9D2| 1| 1| 0| 0',
        '| Cloud Hearts.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cloud Hearts| #47EBDC| 1| 1| 0| 0',
        '| CloverWorks.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CloverWorks| #6D578F| 1| 1| 0| 0',
        '| Colored Pencil Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Colored Pencil Animation| #FB6DFD| 1| 1| 0| 0',
        '| Columbia Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Columbia Pictures| #329763| 1| 1| 0| 0',
        '| CoMix Wave Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CoMix Wave Films| #715AD3| 1| 1| 0| 0',
        '| Connect.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Connect| #2B3FA4| 1| 1| 0| 0',
        '| Constantin Film.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Constantin Film| #343B44| 1| 1| 0| 0',
        '| Cowboy Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cowboy Films| #93F80E| 1| 1| 0| 0',
        '| Craftar Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Craftar Studios| #362BFF| 1| 1| 0| 0',
        '| Creators in Pack.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Creators in Pack| #6057C4| 1| 1| 0| 0',
        '| Cross Creek Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Cross Creek Pictures| #BA5899| 1| 1| 0| 0',
        '| CygamesPictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | CygamesPictures| #8C5677| 1| 1| 0| 0',
        '| Dark Horse Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dark Horse Entertainment| #11F499| 1| 1| 0| 0',
        '| David Production.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | David Production| #AB104E| 1| 1| 0| 0',
        '| Davis Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Davis Entertainment| #000080| 1| 1| 0| 0',
        '| DC Comics.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DC Comics| #4277D7| 1| 1| 0| 0',
        '| Dino De Laurentiis Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dino De Laurentiis Company| #FDA8EB| 1| 1| 0| 0',
        '| Diomedéa.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Diomedéa| #E6A604| 1| 1| 0| 0',
        '| DLE.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DLE| #65450D| 1| 1| 0| 0',
        '| Doga Kobo.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Doga Kobo| #BD0F0F| 1| 1| 0| 0',
        '| domerica.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | domerica| #4CC65F| 1| 1| 0| 0',
        '| Don Simpson Jerry Bruckheimer Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Don Simpson Jerry Bruckheimer Films| #1A1453| 1| 1| 0| 0',
        '| Doozer.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Doozer| #38A897| 1| 1| 0| 0',
        '| Dreams Salon Entertainment Culture.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Dreams Salon Entertainment Culture| #138F97| 1| 1| 0| 0',
        '| DreamWorks Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DreamWorks Pictures| #7F8EE7| 1| 1| 0| 0',
        '| DreamWorks Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | DreamWorks Studios| #F1A7BC| 1| 1| 0| 0',
        '| Drive.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Drive| #C80A46| 1| 1| 0| 0',
        '| Eleventh Hour Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eleventh Hour Films| #301637| 1| 1| 0| 0',
        '| EMJAG Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | EMJAG Productions| #3CD9B2| 1| 1| 0| 0',
        '| EMT Squared.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | EMT Squared| #62F7A1| 1| 1| 0| 0',
        '| Encourage Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Encourage Films| #357C76| 1| 1| 0| 0',
        '| Endeavor Content.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Endeavor Content| #24682A| 1| 1| 0| 0',
        '| ENGI.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ENGI| #B5D798| 1| 1| 0| 0',
        '| Entertainment 360.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Entertainment 360| #FC0D41| 1| 1| 0| 0',
        '| Entertainment One.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Entertainment One| #F3A9F9| 1| 1| 0| 0',
        '| Eon Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Eon Productions| #DA52FB| 1| 1| 0| 0',
        '| Everest Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Everest Entertainment| #75F3AB| 1| 1| 0| 0',
        '| Expectation Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Expectation Entertainment| #AE9483| 1| 1| 0| 0',
        '| Exposure Labs.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Exposure Labs| #A14553| 1| 1| 0| 0',
        '| Fandango.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fandango| #BEC0B6| 1| 1| 0| 0',
        '| feel..png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | feel.| #9268C7| 1| 1| 0| 0',
        '| Felix Film.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Felix Film| #7B2557| 1| 1| 0| 0',
        '| Fenz.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fenz| #A6AD7F| 1| 1| 0| 0',
        '| Fields Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fields Entertainment| #18C40E| 1| 1| 0| 0',
        '| FilmDistrict.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | FilmDistrict| #E5FC8C| 1| 1| 0| 0',
        '| FilmNation Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | FilmNation Entertainment| #98D9EE| 1| 1| 0| 0',
        '| Flynn Picture Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Flynn Picture Company| #35852E| 1| 1| 0| 0',
        '| Focus Features.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Focus Features| #BA30A8| 1| 1| 0| 0',
        '| Food Network.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Food Network| #4634E5| 1| 1| 0| 0',
        '| Fortiche Production.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fortiche Production| #63505B| 1| 1| 0| 0',
        '| Fox Television Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fox Television Studios| #46184A| 1| 1| 0| 0',
        '| Freckle Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Freckle Films| #E1A0D8| 1| 1| 0| 0',
        '| Frederator Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Frederator Studios| #10DF97| 1| 1| 0| 0',
        '| FremantleMedia.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | FremantleMedia| #2C70CC| 1| 1| 0| 0',
        '| Fuqua Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Fuqua Films| #329026| 1| 1| 0| 0',
        '| GAINAX.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | GAINAX| #A73034| 1| 1| 0| 0',
        '| Gallagher Films Ltd.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gallagher Films Ltd| #71ADBB| 1| 1| 0| 0',
        '| Gallop.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gallop| #5EC0A0| 1| 1| 0| 0',
        '| Gary Sanchez Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gary Sanchez Productions| #FED36B| 1| 1| 0| 0',
        '| Gaumont.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gaumont| #8F2734| 1| 1| 0| 0',
        '| Geek Toys.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Geek Toys| #5B5757| 1| 1| 0| 0',
        '| Gekkou.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gekkou| #02AB76| 1| 1| 0| 0',
        '| Gemba.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gemba| #BEE8C2| 1| 1| 0| 0',
        '| GENCO.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | GENCO| #705D63| 1| 1| 0| 0',
        '| Generator Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Generator Entertainment| #5C356A| 1| 1| 0| 0',
        '| Geno Studio.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Geno Studio| #D504AB| 1| 1| 0| 0',
        '| GoHands.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | GoHands| #A683DD| 1| 1| 0| 0',
        '| Gonzo.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gonzo| #C92A69| 1| 1| 0| 0',
        '| Gracie Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Gracie Films| #8094D0| 1| 1| 0| 0',
        '| Graphinica.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Graphinica| #935FBB| 1| 1| 0| 0',
        '| Green Hat Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Green Hat Films| #42F453| 1| 1| 0| 0',
        '| Grindstone Entertainment Group.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Grindstone Entertainment Group| #B66736| 1| 1| 0| 0',
        '| Group Tac.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Group Tac| #157DB4| 1| 1| 0| 0',
        '| Hal Film Maker.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hal Film Maker| #E085A4| 1| 1| 0| 0',
        '| Hallmark.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hallmark| #601CB4| 1| 1| 0| 0',
        '| HandMade Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HandMade Films| #AAB5B2| 1| 1| 0| 0',
        '| Haoliners Animation League.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Haoliners Animation League| #A616E8| 1| 1| 0| 0',
        '| Happy Madison Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Happy Madison Productions| #278761| 1| 1| 0| 0',
        '| HartBeat Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HartBeat Productions| #85F4C5| 1| 1| 0| 0',
        '| Hartswood Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hartswood Films| #904D79| 1| 1| 0| 0',
        '| Hasbro.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hasbro| #5804EB| 1| 1| 0| 0',
        '| HBO.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | HBO| #4B35CD| 1| 1| 0| 0',
        '| Heyday Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Heyday Films| #7ABB2E| 1| 1| 0| 0',
        '| Hoods Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hoods Entertainment| #F5F5D1| 1| 1| 0| 0',
        '| Hotline.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hotline| #45AB9A| 1| 1| 0| 0',
        '| Hughes Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hughes Entertainment| #BC25E4| 1| 1| 0| 0',
        '| Hurwitz & Schlossberg Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hurwitz & Schlossberg Productions| #E903F8| 1| 1| 0| 0',
        '| Hyperobject Industries.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Hyperobject Industries| #C41B1F| 1| 1| 0| 0',
        '| Icon Entertainment International.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Icon Entertainment International| #516F95| 1| 1| 0| 0',
        '| IFC Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | IFC Films| #5CC0D5| 1| 1| 0| 0',
        '| Illumination Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Illumination Entertainment| #C7C849| 1| 1| 0| 0',
        '| Imagin.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Imagin| #241EFD| 1| 1| 0| 0',
        '| Imperative Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Imperative Entertainment| #39136F| 1| 1| 0| 0',
        '| Impossible Factual.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Impossible Factual| #D2E972| 1| 1| 0| 0',
        '| Ingenious Media.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ingenious Media| #729A3B| 1| 1| 0| 0',
        '| Irwin Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Irwin Entertainment| #831F12| 1| 1| 0| 0',
        '| J.C.Staff.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | J.C.Staff| #986BF3| 1| 1| 0| 0',
        '| Jerry Bruckheimer Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jerry Bruckheimer Films| #70C954| 1| 1| 0| 0',
        '| Jessie Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jessie Films| #5CF716| 1| 1| 0| 0',
        '| Jinks-Cohen Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jinks-Cohen Company| #449670| 1| 1| 0| 0',
        '| Jumondou.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Jumondou| #AA58AA| 1| 1| 0| 0',
        '| Kadokawa.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kadokawa| #648E1A| 1| 1| 0| 0',
        '| Kazak Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kazak Productions| #BE6070| 1| 1| 0| 0',
        '| Kennedy Miller Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kennedy Miller Productions| #336937| 1| 1| 0| 0',
        '| Khara.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Khara| #538150| 1| 1| 0| 0',
        '| Kilter Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kilter Films| #CA1893| 1| 1| 0| 0',
        '| Kinema Citrus.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kinema Citrus| #87A92B| 1| 1| 0| 0',
        '| Kjam Media.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kjam Media| #CC0604| 1| 1| 0| 0',
        '| Kudos.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kudos| #4D11E8| 1| 1| 0| 0',
        '| Kurtzman Orci.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kurtzman Orci| #4022D9| 1| 1| 0| 0',
        '| Kyoto Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Kyoto Animation| #1C4744| 1| 1| 0| 0',
        '| Laika Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Laika Entertainment| #CEB2DE| 1| 1| 0| 0',
        '| Lan Studio.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lan Studio| #989DED| 1| 1| 0| 0',
        '| LandQ Studio.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | LandQ Studio| #4667C3| 1| 1| 0| 0',
        '| Landscape Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Landscape Entertainment| #3CBE98| 1| 1| 0| 0',
        '| Laura Ziskin Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Laura Ziskin Productions| #82883F| 1| 1| 0| 0',
        '| Lay-duce.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lay-duce| #0A1988| 1| 1| 0| 0',
        '| Leftfield Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Leftfield Pictures| #4DDAC3| 1| 1| 0| 0',
        '| Legendary Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Legendary Pictures| #303841| 1| 1| 0| 0',
        '| Lerche.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lerche| #D42DAE| 1| 1| 0| 0',
        '| Let''s Not Turn This Into a Whole Big Production.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Let''s Not Turn This Into a Whole Big Production| #7597E6| 1| 1| 0| 0',
        '| Levity Entertainment Group.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Levity Entertainment Group| #612A6D| 1| 1| 0| 0',
        '| LIDENFILMS.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | LIDENFILMS| #EF8907| 1| 1| 0| 0',
        '| Lifetime.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lifetime| #2831EE| 1| 1| 0| 0',
        '| Lightstorm Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lightstorm Entertainment| #75FF24| 1| 1| 0| 0',
        '| Likely Story.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Likely Story| #2F33CA| 1| 1| 0| 0',
        '| Lionsgate.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lionsgate| #7D22A3| 1| 1| 0| 0',
        '| Live Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Live Entertainment| #EB7894| 1| 1| 0| 0',
        '| Lord Miller Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lord Miller Productions| #0F543F| 1| 1| 0| 0',
        '| Lucasfilm Ltd.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Lucasfilm Ltd| #22669B| 1| 1| 0| 0',
        '| M.S.C.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | M.S.C| #44FD9A| 1| 1| 0| 0',
        '| Madhouse.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Madhouse| #C58E2C| 1| 1| 0| 0',
        '| Magic Bus.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Magic Bus| #732AF6| 1| 1| 0| 0',
        '| Magnolia Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Magnolia Pictures| #8B1233| 1| 1| 0| 0',
        '| Maho Film.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Maho Film| #B95BEB| 1| 1| 0| 0',
        '| Malevolent Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Malevolent Films| #5A6B7B| 1| 1| 0| 0',
        '| Mandalay Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mandalay Entertainment| #756373| 1| 1| 0| 0',
        '| Mandarin Motion Pictures Limited.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mandarin Motion Pictures Limited| #509445| 1| 1| 0| 0',
        '| Mandarin.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mandarin| #827715| 1| 1| 0| 0',
        '| Manglobe.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Manglobe| #085B61| 1| 1| 0| 0',
        '| MAPPA.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MAPPA| #376430| 1| 1| 0| 0',
        '| Mars Media Beteiligungs.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Mars Media Beteiligungs| #15C81E| 1| 1| 0| 0',
        '| Marv Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Marv Films| #958F42| 1| 1| 0| 0',
        '| Marvel Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Marvel Animation| #ED171F| 1| 1| 0| 0',
        '| Marvel Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Marvel Studios| #1ED8E3| 1| 1| 0| 0',
        '| Matt Tolmach Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Matt Tolmach Productions| #EAB150| 1| 1| 0| 0',
        '| Maximum Effort.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Maximum Effort| #CE4D0E| 1| 1| 0| 0',
        '| Media Res.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Media Res| #51251D| 1| 1| 0| 0',
        '| Metro-Goldwyn-Mayer.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Metro-Goldwyn-Mayer| #A48221| 1| 1| 0| 0',
        '| Michael Patrick King Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Michael Patrick King Productions| #79FE34| 1| 1| 0| 0',
        '| Millennium Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Millennium Films| #911213| 1| 1| 0| 0',
        '| Millepensee.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Millepensee| #7D9EAC| 1| 1| 0| 0',
        '| Miramax.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Miramax| #344B75| 1| 1| 0| 0',
        '| Namu Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Namu Animation| #FDD8D9| 1| 1| 0| 0',
        '| NAZ.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NAZ| #476C7A| 1| 1| 0| 0',
        '| NEON.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NEON| #e63e3e| 1| 1| 0| 0',
        '| Netflix.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Netflix| #001f3f| 1| 1| 0| 0',
        '| New Line Cinema.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | New Line Cinema| #67857E| 1| 1| 0| 0',
        '| Nexus.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nexus| #F8D946| 1| 1| 0| 0',
        '| Nickelodeon Animation Studio.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nickelodeon Animation Studio| #5E9BFB| 1| 1| 0| 0',
        '| Nippon Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nippon Animation| #4A688B| 1| 1| 0| 0',
        '| Nomad.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nomad| #9FE1BF| 1| 1| 0| 0',
        '| NorthSouth Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | NorthSouth Productions| #69718E| 1| 1| 0| 0',
        '| Nu Boyana Film Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nu Boyana Film Studios| #D08C1E| 1| 1| 0| 0',
        '| Nut.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Nut| #0DAB93| 1| 1| 0| 0',
        '| O2 Filmes.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | O2 Filmes| #F8EEC0| 1| 1| 0| 0',
        '| Okuruto Noboru.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Okuruto Noboru| #88B27E| 1| 1| 0| 0',
        '| OLM.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | OLM| #98FA51| 1| 1| 0| 0',
        '| Open Road Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Open Road Films| #DC0127| 1| 1| 0| 0',
        '| Orange.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Orange| #C4BEF5| 1| 1| 0| 0',
        '| Ordet.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Ordet| #0EEEF6| 1| 1| 0| 0',
        '| Original Film.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Original Film| #364B61| 1| 1| 0| 0',
        '| Orion Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Orion Pictures| #6E6E6E| 1| 1| 0| 0',
        '| OZ.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | OZ| #2EF68F| 1| 1| 0| 0',
        '| P.A. Works.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | P.A. Works| #A21B4B| 1| 1| 0| 0',
        '| P.I.C.S..png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | P.I.C.S.| #A63FA8| 1| 1| 0| 0',
        '| Palomar.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Palomar| #F818FD| 1| 1| 0| 0',
        '| Paramount Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount Animation| #3C3C3C| 1| 1| 0| 0',
        '| Paramount Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount Pictures| #5D94B4| 1| 1| 0| 0',
        '| Paramount Television Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Paramount Television Studios| #E2D6BE| 1| 1| 0| 0',
        '| Participant.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Participant| #F92025| 1| 1| 0| 0',
        '| Passione.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Passione| #970A59| 1| 1| 0| 0',
        '| Pb Animation Co. Ltd.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pb Animation Co. Ltd| #003EB9| 1| 1| 0| 0',
        '| Phoenix Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Phoenix Pictures| #AB0ECF| 1| 1| 0| 0',
        '| Pierrot.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pierrot| #C1CFBC| 1| 1| 0| 0',
        '| Piki Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Piki Films| #52CB78| 1| 1| 0| 0',
        '| Pine Jam.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pine Jam| #4C9C3F| 1| 1| 0| 0',
        '| Pixar.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pixar| #1668B0| 1| 1| 0| 0',
        '| Plan B Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plan B Entertainment| #9084B5| 1| 1| 0| 0',
        '| Platinum Vision.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Platinum Vision| #70A8B4| 1| 1| 0| 0',
        '| PlayStation Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PlayStation Productions| #478D03| 1| 1| 0| 0',
        '| Playtone.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Playtone| #98ED7F| 1| 1| 0| 0',
        '| Plum Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Plum Pictures| #ACCB76| 1| 1| 0| 0',
        '| Polygon Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Polygon Pictures| #741E67| 1| 1| 0| 0',
        '| Pony Canyon.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pony Canyon| #EECA46| 1| 1| 0| 0',
        '| Powerhouse Animation Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Powerhouse Animation Studios| #42A545| 1| 1| 0| 0',
        '| PRA.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | PRA| #DFA26E| 1| 1| 0| 0',
        '| Prescience.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prescience| #03057A| 1| 1| 0| 0',
        '| Production +h..png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Production +h.| #FC07C6| 1| 1| 0| 0',
        '| Production I.G.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Production I.G| #8843C2| 1| 1| 0| 0',
        '| Production IMS.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Production IMS| #169AB7| 1| 1| 0| 0',
        '| Production Reed.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Production Reed| #92F588| 1| 1| 0| 0',
        '| Project No.9.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Project No.9| #FDC471| 1| 1| 0| 0',
        '| Prospect Park.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Prospect Park| #F28C17| 1| 1| 0| 0',
        '| Pulse Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Pulse Films| #8EEB80| 1| 1| 0| 0',
        '| Quad.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Quad| #0CA0BE| 1| 1| 0| 0',
        '| Radar Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Radar Pictures| #DBD684| 1| 1| 0| 0',
        '| RadicalMedia.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RadicalMedia| #E34304| 1| 1| 0| 0',
        '| Radix.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Radix| #1F2D33| 1| 1| 0| 0',
        '| Railsplitter Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Railsplitter Pictures| #9BE2A4| 1| 1| 0| 0',
        '| Rankin Bass Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Rankin Bass Productions| #A9B1D8| 1| 1| 0| 0',
        '| RatPac Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RatPac Entertainment| #91E130| 1| 1| 0| 0',
        '| Red Dog Culture House.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Red Dog Culture House| #46FDF5| 1| 1| 0| 0',
        '| Regency Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Regency Pictures| #1DD664| 1| 1| 0| 0',
        '| Reveille Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Reveille Productions| #1A527C| 1| 1| 0| 0',
        '| Revoroot.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Revoroot| #E8DEB3| 1| 1| 0| 0',
        '| Rip Cord Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Rip Cord Productions| #90580D| 1| 1| 0| 0',
        '| RocketScience.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | RocketScience| #5767E4| 1| 1| 0| 0',
        '| Saetta.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Saetta| #46476A| 1| 1| 0| 0',
        '| SANZIGEN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SANZIGEN| #068509| 1| 1| 0| 0',
        '| Satelight.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Satelight| #D1B2CD| 1| 1| 0| 0',
        '| Savoy Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Savoy Pictures| #9EDDDF| 1| 1| 0| 0',
        '| Scenic Labs.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Scenic Labs| #0B31A8| 1| 1| 0| 0',
        '| Science SARU.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Science SARU| #6948C1| 1| 1| 0| 0',
        '| Scion Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Scion Films| #4FEAC8| 1| 1| 0| 0',
        '| Scott Free Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Scott Free Productions| #A425E7| 1| 1| 0| 0',
        '| Sculptor Media.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sculptor Media| #599D96| 1| 1| 0| 0',
        '| Sean Daniel Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sean Daniel Company| #16EC29| 1| 1| 0| 0',
        '| Searchlight Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Searchlight Pictures| #354672| 1| 1| 0| 0',
        '| Secret Hideout.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Secret Hideout| #3B18AD| 1| 1| 0| 0',
        '| See-Saw Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | See-Saw Films| #2D7D0F| 1| 1| 0| 0',
        '| Sentai Filmworks.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sentai Filmworks| #E00604| 1| 1| 0| 0',
        '| Serendipity Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Serendipity Pictures| #391C49| 1| 1| 0| 0',
        '| Seven Arcs.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Seven Arcs| #7B82BA| 1| 1| 0| 0',
        '| Shaft.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shaft| #2BA8A4| 1| 1| 0| 0',
        '| Shin-Ei Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shin-Ei Animation| #2798DA| 1| 1| 0| 0',
        '| Shogakukan.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shogakukan| #739D5A| 1| 1| 0| 0',
        '| Show East.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Show East| #C1096E| 1| 1| 0| 0',
        '| Showtime Networks.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Showtime Networks| #3EA9E8| 1| 1| 0| 0',
        '| Shuka.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Shuka| #925BD1| 1| 1| 0| 0',
        '| Signal.MD.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Signal.MD| #29113A| 1| 1| 0| 0',
        '| Sil-Metropole Organisation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sil-Metropole Organisation| #48D4F2| 1| 1| 0| 0',
        '| SILVER LINK..png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SILVER LINK.| #06FF01| 1| 1| 0| 0',
        '| Silver.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Silver| #808080| 1| 1| 0| 0',
        '| Silverback Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Silverback Films| #72D71C| 1| 1| 0| 0',
        '| Siren Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Siren Pictures| #323658| 1| 1| 0| 0',
        '| SISTER.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SISTER| #BD6B5C| 1| 1| 0| 0',
        '| Sixteen String Jack Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sixteen String Jack Productions| #6D7D9E| 1| 1| 0| 0',
        '| SKA Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SKA Films| #A2DDB0| 1| 1| 0| 0',
        '| Sky studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sky studios| #5F1D61| 1| 1| 0| 0',
        '| Skydance.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Skydance| #B443B5| 1| 1| 0| 0',
        '| Sony Pictures Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sony Pictures Animation| #498BA9| 1| 1| 0| 0',
        '| Sony Pictures.png| +0| 1200| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sony Pictures| #943EBD| 1| 1| 0| 0',
        '| Sphère Média Plus.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sphère Média Plus| #AEBC44| 1| 1| 0| 0',
        '| Spyglass Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Spyglass Entertainment| #472659| 1| 1| 0| 0',
        '| Square Enix.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Square Enix| #1C0EC5| 1| 1| 0| 0',
        '| Staple Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Staple Entertainment| #E1EB06| 1| 1| 0| 0',
        '| Star Thrower Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Star Thrower Entertainment| #D52526| 1| 1| 0| 0',
        '| Stark Raving Black Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stark Raving Black Productions| #46D38B| 1| 1| 0| 0',
        '| Stöð 2.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Stöð 2| #539F2C| 1| 1| 0| 0',
        '| Studio 3Hz.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio 3Hz| #F7F5BC| 1| 1| 0| 0',
        '| Studio 8.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio 8| #ABC2C3| 1| 1| 0| 0',
        '| Studio A-CAT.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio A-CAT| #049ABA| 1| 1| 0| 0',
        '| Studio Babelsberg.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Babelsberg| #7CAE06| 1| 1| 0| 0',
        '| Studio Bind.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Bind| #E20944| 1| 1| 0| 0',
        '| Studio Blanc..png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Blanc.| #6308CC| 1| 1| 0| 0',
        '| Studio Chizu.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Chizu| #68ACAA| 1| 1| 0| 0',
        '| Studio Comet.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Comet| #2D1337| 1| 1| 0| 0',
        '| Studio Deen.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Deen| #3A6EA8| 1| 1| 0| 0',
        '| Studio Dragon.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Dragon| #3ECAF1| 1| 1| 0| 0',
        '| Studio Elle.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Elle| #511DD7| 1| 1| 0| 0',
        '| Studio Flad.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Flad| #996396| 1| 1| 0| 0',
        '| Studio Ghibli.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Ghibli| #AB2F46| 1| 1| 0| 0',
        '| Studio Gokumi.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Gokumi| #D9C7A0| 1| 1| 0| 0',
        '| Studio Guts.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Guts| #832A64| 1| 1| 0| 0',
        '| Studio Hibari.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Hibari| #4F9E24| 1| 1| 0| 0',
        '| Studio Kafka.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Kafka| #7A2917| 1| 1| 0| 0',
        '| Studio Kai.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Kai| #CA3EC8| 1| 1| 0| 0',
        '| Studio Mir.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Mir| #723564| 1| 1| 0| 0',
        '| studio MOTHER.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | studio MOTHER| #203953| 1| 1| 0| 0',
        '| Studio Palette.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Palette| #5A17AC| 1| 1| 0| 0',
        '| Studio Rikka.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Rikka| #DB5318| 1| 1| 0| 0',
        '| Studio Signpost.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio Signpost| #597F70| 1| 1| 0| 0',
        '| Studio VOLN.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Studio VOLN| #6FDDE8| 1| 1| 0| 0',
        '| STUDIO4°C.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | STUDIO4°C| #33352C| 1| 1| 0| 0',
        '| StudioCanal.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | StudioCanal| #5150CA| 1| 1| 0| 0',
        '| STX Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | STX Entertainment| #7DEF19| 1| 1| 0| 0',
        '| Summit Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Summit Entertainment| #3898B6| 1| 1| 0| 0',
        '| Sunrise Beyond.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sunrise Beyond| #F6E84F| 1| 1| 0| 0',
        '| Sunrise.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Sunrise| #864B89| 1| 1| 0| 0',
        '| Syfy.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Syfy| #535FA5| 1| 1| 0| 0',
        '| Syncopy.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Syncopy| #1E940B| 1| 1| 0| 0',
        '| SynergySP.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | SynergySP| #0E82C8| 1| 1| 0| 0',
        '| T-Street Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | T-Street Productions| #30A4DD| 1| 1| 0| 0',
        '| Tall Ship Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tall Ship Productions| #BD95BF| 1| 1| 0| 0',
        '| Tatsunoko Production.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tatsunoko Production| #5A76B8| 1| 1| 0| 0',
        '| Team Downey.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Team Downey| #2EE0DD| 1| 1| 0| 0',
        '| Telecom Animation Film.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Telecom Animation Film| #2F562B| 1| 1| 0| 0',
        '| Temple Street Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Temple Street Productions| #FDB359| 1| 1| 0| 0',
        '| Tezuka Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tezuka Productions| #10259A| 1| 1| 0| 0',
        '| The Cat in the Hat Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Cat in the Hat Productions| #FDC2D4| 1| 1| 0| 0',
        '| The Donners'' Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Donners'' Company| #625B26| 1| 1| 0| 0',
        '| The Jim Henson Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Jim Henson Company| #478D6A| 1| 1| 0| 0',
        '| The Kennedy-Marshall Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Kennedy-Marshall Company| #78A91F| 1| 1| 0| 0',
        '| The Linson Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Linson Company| #773D61| 1| 1| 0| 0',
        '| The Littlefield Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Littlefield Company| #9FE1C5| 1| 1| 0| 0',
        '| The Mark Gordon Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Mark Gordon Company| #9FD3D8| 1| 1| 0| 0',
        '| The Sea Change Project.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Sea Change Project| #0EC29F| 1| 1| 0| 0',
        '| The Weinstein Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | The Weinstein Company| #927358| 1| 1| 0| 0',
        '| Thunder Road.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Thunder Road| #167CEE| 1| 1| 0| 0',
        '| Tim Burton Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tim Burton Productions| #1D5B96| 1| 1| 0| 0',
        '| Titmouse.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Titmouse| #E5DCBD| 1| 1| 0| 0',
        '| TMS Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TMS Entertainment| #68B823| 1| 1| 0| 0',
        '| TNK.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TNK| #B7D0AF| 1| 1| 0| 0',
        '| Toei Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Toei Animation| #63A2B1| 1| 1| 0| 0',
        '| TOHO.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TOHO| #639BEF| 1| 1| 0| 0',
        '| Tomorrow Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tomorrow Studios| #397DC4| 1| 1| 0| 0',
        '| Topcraft.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Topcraft| #285732| 1| 1| 0| 0',
        '| Touchstone Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Touchstone Pictures| #0C8F4D| 1| 1| 0| 0',
        '| Touchstone Television.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Touchstone Television| #1C493D| 1| 1| 0| 0',
        '| Trademark Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trademark Films| #430F87| 1| 1| 0| 0',
        '| Triage Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Triage Entertainment| #A0C730| 1| 1| 0| 0',
        '| Triangle Staff.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Triangle Staff| #F01AFA| 1| 1| 0| 0',
        '| Tribeca Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Tribeca Productions| #E25EF3| 1| 1| 0| 0',
        '| Trigger.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Trigger| #5C5C5C| 1| 1| 0| 0',
        '| TriStar Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TriStar Pictures| #F24467| 1| 1| 0| 0',
        '| TROYCA.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TROYCA| #2F562B| 1| 1| 0| 0',
        '| TSG Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TSG Entertainment| #F9FEC0| 1| 1| 0| 0',
        '| Twisted Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Twisted Pictures| #DBBE3A| 1| 1| 0| 0',
        '| TYO Animations.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | TYO Animations| #83CC1D| 1| 1| 0| 0',
        '| Typhoon Graphics.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Typhoon Graphics| #C84B2E| 1| 1| 0| 0',
        '| UCP.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | UCP| #2221DA| 1| 1| 0| 0',
        '| ufotable.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ufotable| #F39942| 1| 1| 0| 0',
        '| United Artists.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | United Artists| #89C9A9| 1| 1| 0| 0',
        '| Universal Animation Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Universal Animation Studios| #1C508F| 1| 1| 0| 0',
        '| Universal Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Universal Pictures| #207AAB| 1| 1| 0| 0',
        '| Universal Television.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Universal Television| #AADDF6| 1| 1| 0| 0',
        '| V1 Studio.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | V1 Studio| #961982| 1| 1| 0| 0',
        '| Vancouver Media.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Vancouver Media| #999D92| 1| 1| 0| 0',
        '| Vertigo Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Vertigo Entertainment| #C44810| 1| 1| 0| 0',
        '| Videocraft International.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Videocraft International| #FB7379| 1| 1| 0| 0',
        '| Village Roadshow Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Village Roadshow Pictures| #A76B29| 1| 1| 0| 0',
        '| W-Toon Studio.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | W-Toon Studio| #9EAFE3| 1| 1| 0| 0',
        '| W. Chump and Sons.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | W. Chump and Sons| #0125F4| 1| 1| 0| 0',
        '| Walden Media.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Walden Media| #F8CD5D| 1| 1| 0| 0',
        '| Walt Disney Animation Studios.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Walt Disney Animation Studios| #1290C0| 1| 1| 0| 0',
        '| Walt Disney Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Walt Disney Pictures| #2944AA| 1| 1| 0| 0',
        '| Walt Disney Productions.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Walt Disney Productions| #1E75E1| 1| 1| 0| 0',
        '| Warner Animation Group.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Warner Animation Group| #2C80EE| 1| 1| 0| 0',
        '| Warner Bros. Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Warner Bros. Pictures| #39538F| 1| 1| 0| 0',
        '| Warner Bros. Television.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Warner Bros. Television| #B65CF3| 1| 1| 0| 0',
        '| Warner Premiere.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Warner Premiere| #A46AE0| 1| 1| 0| 0',
        '| warparty.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | warparty| #FE5A77| 1| 1| 0| 0',
        '| Waverly Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Waverly Films| #7CBD11| 1| 1| 0| 0',
        '| Wawayu Animation.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wawayu Animation| #EB7786| 1| 1| 0| 0',
        '| Wayfare Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wayfare Entertainment| #4FD631| 1| 1| 0| 0',
        '| Whitaker Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Whitaker Entertainment| #EF1BA5| 1| 1| 0| 0',
        '| White Fox.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | White Fox| #A86633| 1| 1| 0| 0',
        '| Wiedemann & Berg Television.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wiedemann & Berg Television| #9A2F9F| 1| 1| 0| 0',
        '| Williams Street.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Williams Street| #B5A6C5| 1| 1| 0| 0',
        '| Winkler Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Winkler Films| #A55752| 1| 1| 0| 0',
        '| Wit Studio.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wit Studio| #1F3BB6| 1| 1| 0| 0',
        '| Wolf Entertainment.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wolf Entertainment| #281D15| 1| 1| 0| 0',
        '| Wolfsbane.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Wolfsbane| #8E7689| 1| 1| 0| 0',
        '| Working Title Films.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Working Title Films| #E34945| 1| 1| 0| 0',
        '| Xebec.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Xebec| #051D31| 1| 1| 0| 0',
        '| Yokohama Animation Lab.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Yokohama Animation Lab| #2C3961| 1| 1| 0| 0',
        '| Yostar Pictures.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Yostar Pictures| #9A3DC1| 1| 1| 0| 0',
        '| Yumeta Company.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Yumeta Company| #945E75| 1| 1| 0| 0',
        '| Zero-G.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zero-G| #460961| 1| 1| 0| 0',
        '| Zexcs.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | Zexcs| #E60CB2| 1| 1| 0| 0'
        ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_studio\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination studio
    Copy-Item -Path logos_studio -Destination studio\logos -Recurse
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateSubtitleLanguage
# Description:  Creates Subtitle Language
################################################################################
Function CreateSubtitleLanguage {
    Write-Host `"Creating Subtitle Language`"
    Set-Location $script_path
    # Find-Path `"$script_path\subtitle_language`"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'subtitle_language_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    $pre_value = Get-YamlPropertyValue -PropertyPath "collections.subtitle_language.name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'ABKHAZIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ab| #88F678| 1| 1| 0| 1',
        'AFAR| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | aa| #612A1C| 1| 1| 0| 1',
        'AFRIKAANS| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | af| #60EC40| 1| 1| 0| 1',
        'AKAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ak| #021FBC| 1| 1| 0| 1',
        'ALBANIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sq| #C5F277| 1| 1| 0| 1',
        'AMHARIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | am| #746BC8| 1| 1| 0| 1',
        'ARABIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ar| #37C768| 1| 1| 0| 1',
        'ARAGONESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | an| #4619FD| 1| 1| 0| 1',
        'ARMENIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hy| #5F26E3| 1| 1| 0| 1',
        'ASSAMESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | as| #615C3B| 1| 1| 0| 1',
        'AVARIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | av| #2BCE4A| 1| 1| 0| 1',
        'AVESTAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ae| #CF6EEA| 1| 1| 0| 1',
        'AYMARA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ay| #3D5D3B| 1| 1| 0| 1',
        'AZERBAIJANI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | az| #A48C7A| 1| 1| 0| 1',
        'BAMBARA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bm| #C12E3D| 1| 1| 0| 1',
        'BASHKIR| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ba| #ECD14A| 1| 1| 0| 1',
        'BASQUE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | eu| #89679F| 1| 1| 0| 1',
        'BELARUSIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | be| #1050B0| 1| 1| 0| 1',
        'BENGALI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bn| #EA4C42| 1| 1| 0| 1',
        'BISLAMA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bi| #C39A37| 1| 1| 0| 1',
        'BOSNIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bs| #7DE3FE| 1| 1| 0| 1',
        'BRETON| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | br| #7E1A72| 1| 1| 0| 1',
        'BULGARIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bg| #D5442A| 1| 1| 0| 1',
        'BURMESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | my| #9E5CF0| 1| 1| 0| 1',
        'CATALAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ca| #99BC95| 1| 1| 0| 1',
        'CENTRAL_KHMER| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | km| #6ABDD6| 1| 1| 0| 1',
        'CHAMORRO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ch| #22302F| 1| 1| 0| 1',
        'CHECHEN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ce| #83E832| 1| 1| 0| 1',
        'CHICHEWA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ny| #03E31C| 1| 1| 0| 1',
        'CHINESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | zh| #40EA69| 1| 1| 0| 1',
        'CHURCH_SLAVIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cu| #C76DC2| 1| 1| 0| 1',
        'CHUVASH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cv| #920F92| 1| 1| 0| 1',
        'CORNISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kw| #55137D| 1| 1| 0| 1',
        'CORSICAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | co| #C605DC| 1| 1| 0| 1',
        'CREE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cr| #75D7F3| 1| 1| 0| 1',
        'CROATIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hr| #AB48D3| 1| 1| 0| 1',
        'CZECH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cs| #7804BB| 1| 1| 0| 1',
        'DANISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | da| #87A5BE| 1| 1| 0| 1',
        'DIVEHI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | dv| #FA57EC| 1| 1| 0| 1',
        'DUTCH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nl| #74352E| 1| 1| 0| 1',
        'DZONGKHA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | dz| #F7C931| 1| 1| 0| 1',
        'ENGLISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | en| #DD4A2F| 1| 1| 0| 1',
        'ESPERANTO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | eo| #B65ADE| 1| 1| 0| 1',
        'ESTONIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | et| #AF1569| 1| 1| 0| 1',
        'EWE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ee| #2B7E43| 1| 1| 0| 1',
        'FAROESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fo| #507CCC| 1| 1| 0| 1',
        'FIJIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fj| #7083F9| 1| 1| 0| 1',
        'FILIPINO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fil| #8BEF80| 1| 1| 0| 1',
        'FINNISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fi| #9229A6| 1| 1| 0| 1',
        'FRENCH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fr| #4111A0| 1| 1| 0| 1',
        'FULAH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ff| #649BA7| 1| 1| 0| 1',
        'GAELIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gd| #FBFEC1| 1| 1| 0| 1',
        'GALICIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gl| #DB6769| 1| 1| 0| 1',
        'GANDA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lg| #C71A50| 1| 1| 0| 1',
        'GEORGIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ka| #8517C8| 1| 1| 0| 1',
        'GERMAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | de| #4F5FDC| 1| 1| 0| 1',
        'GREEK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | el| #49B49A| 1| 1| 0| 1',
        'GUARANI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gn| #EDB51C| 1| 1| 0| 1',
        'GUJARATI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gu| #BDF7FF| 1| 1| 0| 1',
        'HAITIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ht| #466EB6| 1| 1| 0| 1',
        'HAUSA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ha| #A949D2| 1| 1| 0| 1',
        'HEBREW| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | he| #E9C58A| 1| 1| 0| 1',
        'HERERO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hz| #E9DF57| 1| 1| 0| 1',
        'HINDI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hi| #77775B| 1| 1| 0| 1',
        'HIRI_MOTU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ho| #3BB41B| 1| 1| 0| 1',
        'HUNGARIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hu| #111457| 1| 1| 0| 1',
        'ICELANDIC| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | is| #0ACE8F| 1| 1| 0| 1',
        'IDO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | io| #75CA6C| 1| 1| 0| 1',
        'IGBO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ig| #757EDE| 1| 1| 0| 1',
        'INDONESIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | id| #52E822| 1| 1| 0| 1',
        'INTERLINGUA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ia| #7F9248| 1| 1| 0| 1',
        'INTERLINGUE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ie| #8F802C| 1| 1| 0| 1',
        'INUKTITUT| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | iu| #43C3B0| 1| 1| 0| 1',
        'INUPIAQ| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ik| #ECF371| 1| 1| 0| 1',
        'IRISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ga| #FB7078| 1| 1| 0| 1',
        'ITALIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | it| #95B5DF| 1| 1| 0| 1',
        'JAPANESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ja| #5D776B| 1| 1| 0| 1',
        'JAVANESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | jv| #5014C5| 1| 1| 0| 1',
        'KALAALLISUT| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kl| #050CF3| 1| 1| 0| 1',
        'KANNADA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kn| #440B43| 1| 1| 0| 1',
        'KANURI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kr| #4F2AAC| 1| 1| 0| 1',
        'KASHMIRI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ks| #842C02| 1| 1| 0| 1',
        'KAZAKH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kk| #665F3D| 1| 1| 0| 1',
        'KIKUYU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ki| #315679| 1| 1| 0| 1',
        'KINYARWANDA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rw| #CE1391| 1| 1| 0| 1',
        'KIRGHIZ| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ky| #5F0D23| 1| 1| 0| 1',
        'KOMI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kv| #9B06C3| 1| 1| 0| 1',
        'KONGO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kg| #74BC47| 1| 1| 0| 1',
        'KOREAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ko| #F5C630| 1| 1| 0| 1',
        'KUANYAMA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | kj| #D8CB60| 1| 1| 0| 1',
        'KURDISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ku| #467330| 1| 1| 0| 1',
        'LAOS| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lo| #DD3B78| 1| 1| 0| 1',
        'LATIN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | la| #A73376| 1| 1| 0| 1',
        'LATVIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lv| #A65EC1| 1| 1| 0| 1',
        'LIMBURGAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | li| #13C252| 1| 1| 0| 1',
        'LINGALA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ln| #BBEE5B| 1| 1| 0| 1',
        'LITHUANIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lt| #E89C3E| 1| 1| 0| 1',
        'LUBA-KATANGA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lu| #4E97F3| 1| 1| 0| 1',
        'LUXEMBOURGISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | lb| #4738EE| 1| 1| 0| 1',
        'MACEDONIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mk| #B69974| 1| 1| 0| 1',
        'MALAGASY| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mg| #29D850| 1| 1| 0| 1',
        'MALAY| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ms| #A74139| 1| 1| 0| 1',
        'MALAYALAM| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ml| #FD4C87| 1| 1| 0| 1',
        'MALTESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mt| #D6EE0B| 1| 1| 0| 1',
        'MANX| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | gv| #3F83E9| 1| 1| 0| 1',
        'MAORI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mi| #8339FD| 1| 1| 0| 1',
        'MARATHI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mr| #93DEF1| 1| 1| 0| 1',
        'MARSHALLESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mh| #11DB75| 1| 1| 0| 1',
        'MAYAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | myn| #7F41FB| 1| 1| 0| 1',
        'MONGOLIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mn| #A107D9| 1| 1| 0| 1',
        'NAURU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | na| #7A0925| 1| 1| 0| 1',
        'NAVAJO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nv| #48F865| 1| 1| 0| 1',
        'NDONGA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ng| #83538B| 1| 1| 0| 1',
        'NEPALI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ne| #5A15FC| 1| 1| 0| 1',
        'NORTH_NDEBELE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nd| #A1533B| 1| 1| 0| 1',
        'NORTHERN_SAMI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | se| #AAD61B| 1| 1| 0| 1',
        'NORWEGIAN_BOKMÅL| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nb| #0AEB4A| 1| 1| 0| 1',
        'NORWEGIAN_NYNORSK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nn| #278B62| 1| 1| 0| 1',
        'NORWEGIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | no| #13FF63| 1| 1| 0| 1',
        'OCCITAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | oc| #B5B607| 1| 1| 0| 1',
        'OJIBWA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | oj| #100894| 1| 1| 0| 1',
        'ORIYA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | or| #0198FF| 1| 1| 0| 1',
        'OROMO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | om| #351BD8| 1| 1| 0| 1',
        'OSSETIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | os| #BF715E| 1| 1| 0| 1',
        'PALI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | pi| #BEB3FA| 1| 1| 0| 1',
        'PASHTO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ps| #A4236C| 1| 1| 0| 1',
        'PERSIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fa| #68A38E| 1| 1| 0| 1',
        'POLISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | pl| #D4F797| 1| 1| 0| 1',
        'PORTUGUESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | pt| #71D659| 1| 1| 0| 1',
        'PUNJABI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | pa| #14F788| 1| 1| 0| 1',
        'QUECHUA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | qu| #268110| 1| 1| 0| 1',
        'ROMANIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ro| #06603F| 1| 1| 0| 1',
        'ROMANSH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rm| #3A73F3| 1| 1| 0| 1',
        'ROMANY| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rom| #790322| 1| 1| 0| 1',
        'RUNDI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rn| #715E84| 1| 1| 0| 1',
        'RUSSIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ru| #DB77DA| 1| 1| 0| 1',
        'SAMOAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sm| #A26738| 1| 1| 0| 1',
        'SANGO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sg| #CA1C7E| 1| 1| 0| 1',
        'SANSKRIT| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sa| #CF9C76| 1| 1| 0| 1',
        'SARDINIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sc| #28AF67| 1| 1| 0| 1',
        'SERBIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sr| #FB3F2C| 1| 1| 0| 1',
        'SHONA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sn| #40F3EC| 1| 1| 0| 1',
        'SICHUAN_YI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ii| #FA3474| 1| 1| 0| 1',
        'SINDHI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sd| #62D1BE| 1| 1| 0| 1',
        'SINHALA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | si| #24787A| 1| 1| 0| 1',
        'SLOVAK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sk| #66104F| 1| 1| 0| 1',
        'SLOVENIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sl| #6F79E6| 1| 1| 0| 1',
        'SOMALI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | so| #A36185| 1| 1| 0| 1',
        'SOUTH_NDEBELE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | nr| #8090E5| 1| 1| 0| 1',
        'SOUTHERN_SOTHO| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | st| #4C3417| 1| 1| 0| 1',
        'SPANISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | es| #7842AE| 1| 1| 0| 1',
        'SUNDANESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | su| #B2D05B| 1| 1| 0| 1',
        'SWAHILI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sw| #D32F20| 1| 1| 0| 1',
        'SWATI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ss| #AA196D| 1| 1| 0| 1',
        'SWEDISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | sv| #0EC5A2| 1| 1| 0| 1',
        'TAGALOG| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tl| #C9DDAC| 1| 1| 0| 1',
        'TAHITIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ty| #32009D| 1| 1| 0| 1',
        'TAI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tai| #2AB44C| 1| 1| 0| 1',
        'TAJIK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tg| #100ECF| 1| 1| 0| 1',
        'TAMIL| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ta| #E71FAE| 1| 1| 0| 1',
        'TATAR| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tt| #C17483| 1| 1| 0| 1',
        'TELUGU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | te| #E34ABD| 1| 1| 0| 1',
        'THAI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | th| #3FB501| 1| 1| 0| 1',
        'TIBETAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bo| #FF2496| 1| 1| 0| 1',
        'TIGRINYA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ti| #9074F0| 1| 1| 0| 1',
        'TONGA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | to| #B3259E| 1| 1| 0| 1',
        'TSONGA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ts| #12687C| 1| 1| 0| 1',
        'TSWANA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tn| #DA3E89| 1| 1| 0| 1',
        'TURKISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tr| #A08D29| 1| 1| 0| 1',
        'TURKMEN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tk| #E70267| 1| 1| 0| 1',
        'TWI| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | tw| #8A6C0F| 1| 1| 0| 1',
        'UIGHUR| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ug| #79BC21| 1| 1| 0| 1',
        'UKRAINIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | uk| #EB60E9| 1| 1| 0| 1',
        'URDU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ur| #57E09D| 1| 1| 0| 1',
        'UZBEK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | uz| #4341F3| 1| 1| 0| 1',
        'VENDA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | ve| #4780ED| 1| 1| 0| 1',
        'VIETNAMESE| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vi| #90A301| 1| 1| 0| 1',
        'VOLAPÜK| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | vo| #77D574| 1| 1| 0| 1',
        'WALLOON| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | wa| #BD440A| 1| 1| 0| 1',
        'WELSH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | cy| #45E39C| 1| 1| 0| 1',
        'WESTERN_FRISIAN| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fy| #01F471| 1| 1| 0| 1',
        'WOLOF| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | wo| #BDD498| 1| 1| 0| 1',
        'XHOSA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | xh| #0C6D9C| 1| 1| 0| 1',
        'YIDDISH| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | yi| #111D14| 1| 1| 0| 1',
        'YORUBA| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | yo| #E815FF| 1| 1| 0| 1',
        'ZHUANG| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | za| #C62A89| 1| 1| 0| 1',
        'ZULU| transparent.png| +0| 0| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | zu| #0049F8| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = Set-TextBetweenDelimiters -InputString $pre_value -ReplacementString (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr
    
    Move-Item -Path output -Destination subtitle_language
    Move-Item -Path output-orig -Destination output
}

################################################################################
# Function: CreateVideoFormat
# Description:  Creates Video Format
################################################################################
Function CreateVideoFormat {
    Write-Host "Creating Video Format"
    Set-Location $script_path
    # Find-Path "$script_path\video_format" 77A5B2
    Move-Item -Path output -Destination output-orig    

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| bluray.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | bluray| #A66321| 1| 1| 0| 0',
        '| dvd.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | dvd| #E4CB63| 1| 1| 0| 0',
        '| hdtv.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | hdtv| #27B618| 1| 1| 0| 0',
        '| MoviesAnywhere.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | MoviesAnywhere| #77A5B2| 1| 1| 0| 0',
        '| remux.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | remux| #32C493| 1| 1| 0| 0',
        '| web.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | web| #56CECE| 1| 1| 0| 0'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_video_format\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr
    
    Move-Item -Path output -Destination video_format
    Copy-Item -Path logos_video_format -Destination video_format\logos -Recurse
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

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '| askew.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | askew| #0F66AD| 1| 1| 0| 1',
        '| avp.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | avp| #2FC926| 1| 1| 0| 1',
        '| arrow.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | arrow| #03451A| 1| 1| 0| 1',
        '| conjuring.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | conjuring| #8A2939| 1| 1| 0| 1',
        '| dca.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | dca| #2832C5| 1| 1| 0| 1',
        '| dcu.png| +0| 1500| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | dcu| #2832C4| 1| 1| 0| 1',
        '| fast.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | fast| #7F1FC8| 1| 1| 0| 1',
        '| marvel.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | marvel| #ED171F| 1| 1| 0| 1',
        '| mcu.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mcu| #C62D21| 1| 1| 0| 1',
        '| middle.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | middle| #D79C2B| 1| 1| 0| 1',
        '| monsterverse.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | monsterverse| #016A15| 1| 1| 0| 0',
        '| mummy.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | mummy| #DBA02F| 1| 1| 0| 1',
        '| rocky.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | rocky| #CC1F10| 1| 1| 0| 1',
        '| star.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star| #FFD64F| 1| 1| 0| 1',
        '| star (1).png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | star (1)| #F2DC1D| 1| 1| 0| 1',
        '| starsky.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | starsky| #0595FB| 1| 1| 0| 1',
        '| trek.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | trek| #ffe15f| 1| 1| 0| 1',
        '| wizard.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | wizard| #878536| 1| 1| 0| 1',
        '| xmen.png| +0| 1800| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | xmen| #636363| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "key_names.$($item.key_name)" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_universe\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
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
    # Find-Path "$script_path\year"
    # Find-Path "$script_path\year\best"
    WriteToLogFile "ImageMagick Commands for     : Years"

    Move-Item -Path output -Destination output-orig

    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        'year_other| transparent.png| +0| 1600| +0| ComfortAa-Medium| | #FFFFFF| 0| 15| #FFFFFF| | other| #FF2000| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.key_name).ToString() -eq "") {
            $value = $null
        }
        else {
            $value = (Get-YamlPropertyValue -PropertyPath "collections.$($item.key_name).name" -ConfigObject $global:ConfigObj -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    # $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1900
    $theMaxHeight = 550
    $minPointSize = 250
    $maxPointSize = 1000

    $myArray = @(
        'key_name| logo| logo_offset| logo_resize| text_offset| font| font_size| font_color| border| border_width| border_color| avg_color_image| out_name| base_color| gradient| clean| avg_color| white_wash',
        '1880| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1880|  #EF10D3| 1| 1| 0| 1',
        '1881| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1881|  #EF102A| 1| 1| 0| 1',
        '1882| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1882|  #EF6210| 1| 1| 0| 1',
        '1883| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1883|  #EFC910| 1| 1| 0| 1',
        '1884| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1884|  #10EFA3| 1| 1| 0| 1',
        '1885| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1885|  #108FEF| 1| 1| 0| 1',
        '1886| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1886|  #A900EF| 1| 1| 0| 1',
        '1887| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1887|  #8D848E| 1| 1| 0| 1',
        '1888| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1888|  #992C2E| 1| 1| 0| 1',
        '1889| transparent.png| +0| 1800| +0|  Rye-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1889|  #131CA1| 1| 1| 0| 1',
        '1890| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1890|  #EF10D3| 1| 1| 0| 1',
        '1891| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1891|  #EF102A| 1| 1| 0| 1',
        '1892| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1892|  #EF6210| 1| 1| 0| 1',
        '1893| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1893|  #EFC910| 1| 1| 0| 1',
        '1894| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1894|  #10EFA3| 1| 1| 0| 1',
        '1895| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1895|  #108FEF| 1| 1| 0| 1',
        '1896| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1896|  #A900EF| 1| 1| 0| 1',
        '1897| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1897|  #8D848E| 1| 1| 0| 1',
        '1898| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1898|  #992C2E| 1| 1| 0| 1',
        '1899| transparent.png| +0| 1800| +0|  Limelight-Regular|  453| #FFFFFF| 0| 15| #FFFFFF| | 1899|  #131CA1| 1| 1| 0| 1',
        '1900| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1900|  #EF10D3| 1| 1| 0| 1',
        '1901| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1901|  #EF102A| 1| 1| 0| 1',
        '1902| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1902|  #EF6210| 1| 1| 0| 1',
        '1903| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1903|  #EFC910| 1| 1| 0| 1',
        '1904| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1904|  #10EFA3| 1| 1| 0| 1',
        '1905| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1905|  #108FEF| 1| 1| 0| 1',
        '1906| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1906|  #A900EF| 1| 1| 0| 1',
        '1907| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1907|  #8D848E| 1| 1| 0| 1',
        '1908| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1908|  #992C2E| 1| 1| 0| 1',
        '1909| transparent.png| +0| 1800| +0|  BoecklinsUniverse|  453| #FFFFFF| 0| 15| #FFFFFF| | 1909|  #131CA1| 1| 1| 0| 1',
        '1910| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1910|  #EF10D3| 1| 1| 0| 1',
        '1911| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1911|  #EF102A| 1| 1| 0| 1',
        '1912| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1912|  #EF6210| 1| 1| 0| 1',
        '1913| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1913|  #EFC910| 1| 1| 0| 1',
        '1914| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1914|  #10EFA3| 1| 1| 0| 1',
        '1915| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1915|  #108FEF| 1| 1| 0| 1',
        '1916| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1916|  #A900EF| 1| 1| 0| 1',
        '1917| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1917|  #8D848E| 1| 1| 0| 1',
        '1918| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1918|  #992C2E| 1| 1| 0| 1',
        '1919| transparent.png| +0| 1800| +0|  UnifrakturCook| 700| #FFFFFF| 0| 15| #FFFFFF| | 1919|  #131CA1| 1| 1| 0| 1',
        '1920| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1920|  #EF10D3| 1| 1| 0| 1',
        '1921| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1921|  #EF102A| 1| 1| 0| 1',
        '1922| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1922|  #EF6210| 1| 1| 0| 1',
        '1923| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1923|  #EFC910| 1| 1| 0| 1',
        '1924| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1924|  #10EFA3| 1| 1| 0| 1',
        '1925| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1925|  #108FEF| 1| 1| 0| 1',
        '1926| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1926|  #A900EF| 1| 1| 0| 1',
        '1927| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1927|  #8D848E| 1| 1| 0| 1',
        '1928| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1928|  #992C2E| 1| 1| 0| 1',
        '1929| transparent.png| +0| 1800| +0|  Trochut| 500| #FFFFFF| 0| 15| #FFFFFF| | 1929|  #131CA1| 1| 1| 0| 1',
        '1930| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1930|  #EF10D3| 1| 1| 0| 1',
        '1931| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1931|  #EF102A| 1| 1| 0| 1',
        '1932| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1932|  #EF6210| 1| 1| 0| 1',
        '1933| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1933|  #EFC910| 1| 1| 0| 1',
        '1934| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1934|  #10EFA3| 1| 1| 0| 1',
        '1935| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1935|  #108FEF| 1| 1| 0| 1',
        '1936| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1936|  #A900EF| 1| 1| 0| 1',
        '1937| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1937|  #8D848E| 1| 1| 0| 1',
        '1938| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1938|  #992C2E| 1| 1| 0| 1',
        '1939| transparent.png| +0| 1800| +0|  Righteous| 500| #FFFFFF| 0| 15| #FFFFFF| | 1939|  #131CA1| 1| 1| 0| 1',
        '1940| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1940|  #EF10D3| 1| 1| 0| 1',
        '1941| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1941|  #EF102A| 1| 1| 0| 1',
        '1942| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1942|  #EF6210| 1| 1| 0| 1',
        '1943| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1943|  #EFC910| 1| 1| 0| 1',
        '1944| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1944|  #10EFA3| 1| 1| 0| 1',
        '1945| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1945|  #108FEF| 1| 1| 0| 1',
        '1946| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1946|  #A900EF| 1| 1| 0| 1',
        '1947| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1947|  #8D848E| 1| 1| 0| 1',
        '1948| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1948|  #992C2E| 1| 1| 0| 1',
        '1949| transparent.png| +0| 1800| +0|  Yesteryear| 700| #FFFFFF| 0| 15| #FFFFFF| | 1949|  #131CA1| 1| 1| 0| 1',
        '1950| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1950|  #EF10D3| 1| 1| 0| 1',
        '1951| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1951|  #EF102A| 1| 1| 0| 1',
        '1952| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1952|  #EF6210| 1| 1| 0| 1',
        '1953| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1953|  #EFC910| 1| 1| 0| 1',
        '1954| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1954|  #10EFA3| 1| 1| 0| 1',
        '1955| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1955|  #108FEF| 1| 1| 0| 1',
        '1956| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1956|  #A900EF| 1| 1| 0| 1',
        '1957| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1957|  #8D848E| 1| 1| 0| 1',
        '1958| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1958|  #992C2E| 1| 1| 0| 1',
        '1959| transparent.png| +0| 1800| +0|  Cherry-Cream-Soda-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1959|  #131CA1| 1| 1| 0| 1',
        '1960| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1960|  #EF10D3| 1| 1| 0| 1',
        '1961| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1961|  #EF102A| 1| 1| 0| 1',
        '1962| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1962|  #EF6210| 1| 1| 0| 1',
        '1963| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1963|  #EFC910| 1| 1| 0| 1',
        '1964| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1964|  #10EFA3| 1| 1| 0| 1',
        '1965| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1965|  #108FEF| 1| 1| 0| 1',
        '1966| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1966|  #A900EF| 1| 1| 0| 1',
        '1967| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1967|  #8D848E| 1| 1| 0| 1',
        '1968| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1968|  #992C2E| 1| 1| 0| 1',
        '1969| transparent.png| +0| 1800| +0|  Boogaloo-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 1969|  #131CA1| 1| 1| 0| 1',
        '1970| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1970|  #EF10D3| 1| 1| 0| 1',
        '1971| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1971|  #EF102A| 1| 1| 0| 1',
        '1972| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1972|  #EF6210| 1| 1| 0| 1',
        '1973| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1973|  #EFC910| 1| 1| 0| 1',
        '1974| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1974|  #10EFA3| 1| 1| 0| 1',
        '1975| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1975|  #108FEF| 1| 1| 0| 1',
        '1976| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1976|  #A900EF| 1| 1| 0| 1',
        '1977| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1977|  #8D848E| 1| 1| 0| 1',
        '1978| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1978|  #992C2E| 1| 1| 0| 1',
        '1979| transparent.png| +0| 1800| +0|  Monoton| 500| #FFFFFF| 0| 15| #FFFFFF| | 1979|  #131CA1| 1| 1| 0| 1',
        '1980| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1980|  #EF10D3| 1| 1| 0| 1',
        '1981| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1981|  #EF102A| 1| 1| 0| 1',
        '1982| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1982|  #EF6210| 1| 1| 0| 1',
        '1983| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1983|  #EFC910| 1| 1| 0| 1',
        '1984| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1984|  #10EFA3| 1| 1| 0| 1',
        '1985| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1985|  #108FEF| 1| 1| 0| 1',
        '1986| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1986|  #A900EF| 1| 1| 0| 1',
        '1987| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1987|  #8D848E| 1| 1| 0| 1',
        '1988| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1988|  #992C2E| 1| 1| 0| 1',
        '1989| transparent.png| +0| 1800| +0|  Press-Start-2P| 300| #FFFFFF| 0| 15| #FFFFFF| | 1989|  #131CA1| 1| 1| 0| 1',
        '1990| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1990|  #EF10D3| 1| 1| 0| 1',
        '1991| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1991|  #EF102A| 1| 1| 0| 1',
        '1992| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1992|  #EF6210| 1| 1| 0| 1',
        '1993| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1993|  #EFC910| 1| 1| 0| 1',
        '1994| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1994|  #10EFA3| 1| 1| 0| 1',
        '1995| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1995|  #108FEF| 1| 1| 0| 1',
        '1996| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1996|  #A900EF| 1| 1| 0| 1',
        '1997| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1997|  #8D848E| 1| 1| 0| 1',
        '1998| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1998|  #992C2E| 1| 1| 0| 1',
        '1999| transparent.png| +0| 1800| +0|  Jura-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 1999|  #131CA1| 1| 1| 0| 1',
        '2000| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2000|  #EF10D3| 1| 1| 0| 1',
        '2001| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2001|  #EF102A| 1| 1| 0| 1',
        '2002| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2002|  #EF6210| 1| 1| 0| 1',
        '2003| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2003|  #EFC910| 1| 1| 0| 1',
        '2004| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2004|  #10EFA3| 1| 1| 0| 1',
        '2005| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2005|  #108FEF| 1| 1| 0| 1',
        '2006| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2006|  #A900EF| 1| 1| 0| 1',
        '2007| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2007|  #8D848E| 1| 1| 0| 1',
        '2008| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2008|  #992C2E| 1| 1| 0| 1',
        '2009| transparent.png| +0| 1800| +0|  Special-Elite-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2009|  #131CA1| 1| 1| 0| 1',
        '2010| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2010|  #EF10D3| 1| 1| 0| 1',
        '2011| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2011|  #EF102A| 1| 1| 0| 1',
        '2012| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2012|  #EF6210| 1| 1| 0| 1',
        '2013| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2013|  #EFC910| 1| 1| 0| 1',
        '2014| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2014|  #10EFA3| 1| 1| 0| 1',
        '2015| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2015|  #108FEF| 1| 1| 0| 1',
        '2016| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2016|  #A900EF| 1| 1| 0| 1',
        '2017| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2017|  #8D848E| 1| 1| 0| 1',
        '2018| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2018|  #992C2E| 1| 1| 0| 1',
        '2019| transparent.png| +0| 1800| +0|  Barlow-Regular| 500| #FFFFFF| 0| 15| #FFFFFF| | 2019|  #131CA1| 1| 1| 0| 1',
        '2020| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2020|  #EF10D3| 1| 1| 0| 1',
        '2021| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2021|  #EF102A| 1| 1| 0| 1',
        '2022| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2022|  #EF6210| 1| 1| 0| 1',
        '2023| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2023|  #EFC910| 1| 1| 0| 1',
        '2024| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2024|  #10EFA3| 1| 1| 0| 1',
        '2025| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2025|  #108FEF| 1| 1| 0| 1',
        '2026| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2026|  #A900EF| 1| 1| 0| 1',
        '2027| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2027|  #8D848E| 1| 1| 0| 1',
        '2028| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2028|  #992C2E| 1| 1| 0| 1',
        '2029| transparent.png| +0| 1800| +0|  Helvetica-Bold| 500| #FFFFFF| 0| 15| #FFFFFF| | 2029|  #131CA1| 1| 1| 0| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $value = $($item.key_name)
        $optimalFontSize = Get-OptimalPointSize -text $value -font $($item.font) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $($item.font_size)
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.logo)`" -logo_offset $($item.logo_offset) -logo_resize $($item.logo_resize) -text `"$value`" -text_offset $($item.text_offset) -font `"$($item.font)`" -font_size $optimalFontSize -font_color `"$($item.font_color)`" -border $($item.border) -border_width $($item.border_width) -border_color `"$($item.border_color)`" -avg_color_image `"$($item.avg_color_image)`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient $($item.gradient) -avg_color $($item.avg_color) -clean $($item.clean) -white_wash $($item.white_wash)"
    }
    LaunchScripts -ScriptPaths $arr

    WriteToLogFile "MonitorProcess               : Waiting for all processes to end before continuing..."
    Start-Sleep -Seconds 3
    MonitorProcess -ProcessName "magick.exe"
    
    Move-Item -Path output -Destination year

    $pre_value = Get-YamlPropertyValue -PropertyPath "key_names.BEST_OF" -ConfigObject $global:ConfigObj -CaseSensitivity Upper

    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 200

    $arr = @()
    for ($i = 1880; $i -lt 2030; $i++) {
        $value = $pre_value
        $optimalFontSize = Get-OptimalPointSize -text $value -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\year\$i.jpg`" -logo_offset +0 -logo_resize 2000 -text `"$value`" -text_offset -400 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"#FFFFFF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    }
    LaunchScripts -ScriptPaths $arr
    Start-Sleep -Seconds 3
    MonitorProcess -ProcessName "magick.exe"
    Move-Item -Path output -Destination "$script_path\year\best"
    Move-Item -Path output-orig -Destination output

}

################################################################################
# Function: CreateOverlays
# Description:  Creates Overlay Icons
################################################################################
Function CreateOverlays {
    Write-Host "Creating Overlays"
    Set-Location $script_path
    
    $directories = @("award", "chart", "chart\white", "country", "franchise", "network", "network\white", "playlist", "resolution", "streaming", "streaming\white", "universe")
    $directories_no_trim = @("aspect", "content_rating", "genre", "seasonal", "studio", "video_format")
    $size1 = "285x85"
    $size2 = "440x100"
    
    Foreach ($dir in $directories_no_trim) {
        $path = Join-Path $script_path $dir
        $outputPath = Join-Path $path "overlays"
        $outputPath = Join-Path $outputPath "standard"
        $inputPath = Join-Path $script_path "logos_$dir"
        Find-Path $path
        Find-Path $outputPath
        $joinpath = (Join-Path $inputPath "*.png")
        WriteToLogFile "Resizing overlays            : magick mogrify -colorspace sRGB -strip -path $outputPath -resize $size1 $joinpath"
        magick mogrify -colorspace sRGB -strip -path $outputPath -resize $size1 $joinpath
    }

    Foreach ($dir in $directories) {
        $path = Join-Path $script_path $dir
        $outputPath = Join-Path $path "overlays"
        $outputPath = Join-Path $outputPath "standard"
        $inputPath = Join-Path $script_path "logos_$dir"
        Find-Path $path
        Find-Path $outputPath
        $joinpath = (Join-Path $inputPath "*.png")
        WriteToLogFile "Resizing overlays            : magick mogrify -colorspace sRGB -strip -trim -path $outputPath -resize $size1 $joinpath"
        magick mogrify -colorspace sRGB -strip -trim -path $outputPath -resize $size1 $joinpath
    }

    Foreach ($dir in $directories_no_trim) {
        $path = Join-Path $script_path $dir
        $outputPath = Join-Path $path "overlays"
        $outputPath = Join-Path $outputPath "bigger"
        $inputPath = Join-Path $script_path "logos_$dir"
        Find-Path $path
        Find-Path $outputPath
        $joinpath = (Join-Path $inputPath "*.png")
        WriteToLogFile "Resizing overlays            : magick mogrify -colorspace sRGB -strip -path $outputPath -resize $size2 $joinpath"
        magick mogrify -colorspace sRGB -strip -path $outputPath -resize $size2 $joinpath
    }

    Foreach ($dir in $directories) {
        $path = Join-Path $script_path $dir
        $outputPath = Join-Path $path "overlays"
        $outputPath = Join-Path $outputPath "bigger"
        $inputPath = Join-Path $script_path "logos_$dir"
        Find-Path $path
        Find-Path $outputPath
        $joinpath = (Join-Path $inputPath "*.png")
        WriteToLogFile "Resizing overlays            : magick mogrify -colorspace sRGB -strip -trim -path $outputPath -resize $size2 $joinpath"
        magick mogrify -colorspace sRGB -strip -trim -path $outputPath -resize $size2 $joinpath
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
# Function: CheckSum-Files
# Description: Prints the list of possible parameters
################################################################################
Function Get-Checksum-Files {
    param(
        [string]$script_path
    )

    Set-Location $script_path
    WriteToLogFile "CheckSum Files               : Checking dependency files."

    $sep1 = "amethyst.png"
    $sep2 = "aqua.png"
    $sep3 = "blue.png"
    $sep4 = "forest.png"
    $sep5 = "fuchsia.png"
    $sep6 = "gold.png"
    $sep7 = "gray.png"
    $sep8 = "green.png"
    $sep9 = "navy.png"
    $sep10 = "ocean.png"
    $sep11 = "olive.png"
    $sep12 = "orchid.png"
    $sep13 = "orig.png"
    $sep14 = "pink.png"
    $sep15 = "plum.png"
    $sep16 = "purple.png"
    $sep17 = "red.png"
    $sep18 = "rust.png"
    $sep19 = "salmon.png"
    $sep20 = "sand.png"
    $sep21 = "stb.png"
    $sep22 = "tan.png"

    $ttf1 = "Boogaloo-Regular.ttf"
    $ttf2 = "Righteous-Regular.ttf"
    $ttf3 = "Bebas-Regular.ttf"
    $ttf4 = "BoecklinsUniverse.ttf"
    $ttf5 = "Comfortaa-Medium.ttf"
    $ttf6 = "UnifrakturCook-Bold.ttf"
    $ttf7 = "Helvetica-Bold.ttf"
    $ttf8 = "Limelight-Regular.ttf"
    $ttf9 = "Monoton-Regular.ttf"
    $ttf10 = "Jura-Bold.ttf"
    $ttf11 = "Press-Start-2P.ttf"
    $ttf12 = "Yesteryear-Regular.ttf"
    $ttf13 = "Rye-Regular.ttf"
    $ttf14 = "CherryCreamSoda-Regular.ttf"
    $ttf15 = "Barlow-Regular.ttf"
    $ttf16 = "SpecialElite-Regular.ttf"
    $ttf17 = "Trochut-Regular.ttf"
    
    $fade1 = "@bottom-top-fade.png"
    $fade2 = "@bottom-up-fade.png"
    $fade3 = "@center-out-fade.png"
    $fade4 = "@none.png"
    $fade5 = "@top-down-fade.png"
    
    $trans1 = "transparent.png"
    
    $expectedChecksum_sep1 = "8FFEF200F9AA2126052684FBAF5BB1B96F402FAF3055532FBBFFCABF610D9573"
    $expectedChecksum_sep2 = "940E5F5BD81B0C7388BDA0B6E639D59BAEFAABAD78F04F41982440D49BAE8871"
    $expectedChecksum_sep3 = "AB8DBC5FCE661BDFC643F9697EEC1463CD2CDE90E4594B232A6B92C272DE0561"
    $expectedChecksum_sep4 = "78DDD1552B477308047A1E6396407B96965F1B90DD738435F92187F02DA60467"
    $expectedChecksum_sep5 = "F8A173A71758B89D7EE22F04DB570A7D604F1DC5C17B5FD2D8F278C5440E0348"
    $expectedChecksum_sep6 = "9BB273DE826C9968D3B335701F0DB8C978C371C5ABF5DC1A5E554973BCDD255C"
    $expectedChecksum_sep7 = "9570B1E86BEC71CAED6DDFD6D2F18023A7C5D408B6A6D5B50C045672D4310772"
    $expectedChecksum_sep8 = "89951DFC6338ABC64444635F6F2835472418BF779A1EB5C342078AF0B8365F80"
    $expectedChecksum_sep9 = "FBFBF94423C96410EB65891CB3048B45C60586D52B71DF99550EA738F6D17AE4"
    $expectedChecksum_sep10 = "0AE3BB7DD7FE7ADDB6F788A49625224082E6DD43D3A7CD6517D15EE984E41021"
    $expectedChecksum_sep11 = "3B3B74A45A94DCA46BB82F8CAF32E39B12B9D7BF1868B9075E269A221AA3AF9B"
    $expectedChecksum_sep12 = "926D14FBBF6E113984E2F5D69BEF8620B37E0FF08C6FE4BBCDB5680C6698DEFC"
    $expectedChecksum_sep13 = "98E161CD70C3300D30340257D674FCC18B11FDADEE3FFF9B80D09C4AB09C1483"
    $expectedChecksum_sep14 = "E0B6DA722447ABB0BC47DDD93E847B37BCD3D3CA9897DB1818E5616D250DA2DA"
    $expectedChecksum_sep15 = "D383FCD9E2813144339F3FDE6A048C5A0D00EAA9443019B1B61FB2C24FF9BB2A"
    $expectedChecksum_sep16 = "3768CA736B6BD1CAD0CD02827A6BA7BDBCA2077B1A109802C57144C31B379477"
    $expectedChecksum_sep17 = "03E9026430C8F0ABD031B608225BF40CB87FD1983899C113E410A511CC5622A7"
    $expectedChecksum_sep18 = "5F72369DA3F652388A386D92F96995F1F1819F2B1FBAE90BC68DE049A426B298"
    $expectedChecksum_sep19 = "9A5E38AA7982846B47E85BF9C4FD99843D26187D37E4301F7A429F37612677C3"
    $expectedChecksum_sep20 = "4814E8E1E8A0BB65267C4B6B658390BFE79F4E6CFECA57039F98DF19E8658DB9"
    $expectedChecksum_sep21 = "A01695FAB8646079331811F381A38A529E76AFC31538285E7EE60600CA07ADC1"
    $expectedChecksum_sep22 = "8B9B71415CE0F8F1B229C2329C70D761DE99100D2FD5C49537B483B8A5A720E1"

    $expectedChecksum_ttf1 = "6AA7C9F7096B090A6783E31278ABF907EC84A4BD98F280C925AB033D1FE91EB7"
    $expectedChecksum_ttf2 = "4C3CDC5DE2D70C4EE75FC9C1723A6B8F2D7316F49B383335FD8257A17DD88ADE"
    $expectedChecksum_ttf3 = "39D2EB178FDD52B4C350AC6DEE3D2090AE5A7C187225B0D161A1473CCBB6320D"
    $expectedChecksum_ttf4 = "5F6F6396EDEE3FA1FE9443258D7463F82E6B2512A03C5102A90295A095339FB5"
    $expectedChecksum_ttf5 = "992F89F3C26BE37CCEBF784B294D36F40B96ED96AD9A3CC1396F4D389FC69D0C"
    $expectedChecksum_ttf6 = "B9ED8DA80463792A29675199B0F6580871025C35B2C539CAD7D5DE050D216A0C"
    $expectedChecksum_ttf7 = "D19CCD4211E3CAAAC2C7F1AE544456F5C67CD912E2BDFB1EFB6602C090C724EE"
    $expectedChecksum_ttf8 = "5D2C9F43D8CB4D49481A39A33CDC2A9157B1FCBFB381063A11617EDE209A105C"
    $expectedChecksum_ttf9 = "1565B395F454D5C2642D0F411030051E7342FBAF6D5BFC5DA5899C47ECD3511E"
    $expectedChecksum_ttf10 = "1A3B4D7412F10CC17C34289C357E00C5E91BB2EC61B123C2A72CB975E0CBE94D"
    $expectedChecksum_ttf11 = "17EC7D250FF590971A6D966B4FDC5AA04D5E39A7694F4A0BECB515B6A70A7228"
    $expectedChecksum_ttf12 = "B9D7736030DCA2B5849F4FA565A75F91065CC5DED8B6023444BD74445A263C77"
    $expectedChecksum_ttf13 = "722825F800CF7CEAE4791B274D45DA9DF517DB7CF7A07BFAFD34452B787C5354"
    $expectedChecksum_ttf14 = "D70EAFE96ABBAAD50D94538B11077D88BB91AC3538DD0E70F0BDC0CE04E410E9"
    $expectedChecksum_ttf15 = "77FB1AC54D2CEB980E3EBDFA7A9D0F64E85A66E4FDFB7F914A7B0AA08FB33A5D"
    $expectedChecksum_ttf16 = "14780EA85064DCB150C23C9A87E2B870439C38668B6D8F1DAD5C6DB701AB9520"
    $expectedChecksum_ttf17 = "EC48B8641254BDCACC417B77992F7776A747A14F8A16C5D5AF9D1B75F4BEC17D"

    $expectedChecksum_fade1 = "79D93B7455A694820A4DF4B27B4418EA0063AF59400ED778FC66F83648DAA110"
    $expectedChecksum_fade2 = "7ED182E395A08B4035B687E6F0661029EF938F8027923EC9434EBCBC5D144CFD"
    $expectedChecksum_fade3 = "6D36359197363DDC092FDAA8AA4590838B01B8A22C3BF4B6DED76D65BC85A87C"
    $expectedChecksum_fade4 = "5E89879184510E91E477D41C61BD86A0E9209E9ECC17909A7B0EE20427950CBC"
    $expectedChecksum_fade5 = "CBBF0B235A893410E02977419C89EE6AD97DF253CBAEE382E01D088D2CCE6B39"

    $expectedChecksum_trans1 = "64A0A1D637FF0687CCBCAECA31B8E6B7235002B1EE8528E7A60BE6A7D636F1FC"

    $failFlag = [ref] $false
    Write-Output "Begin: " $failFlag.Value

    Compare-FileChecksum -Path $script_path\@base\$sep1 -ExpectedChecksum $expectedChecksum_sep1 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep2 -ExpectedChecksum $expectedChecksum_sep2 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep3 -ExpectedChecksum $expectedChecksum_sep3 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep4 -ExpectedChecksum $expectedChecksum_sep4 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep5 -ExpectedChecksum $expectedChecksum_sep5 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep6 -ExpectedChecksum $expectedChecksum_sep6 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep7 -ExpectedChecksum $expectedChecksum_sep7 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep8 -ExpectedChecksum $expectedChecksum_sep8 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep9 -ExpectedChecksum $expectedChecksum_sep9 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep10 -ExpectedChecksum $expectedChecksum_sep10 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep11 -ExpectedChecksum $expectedChecksum_sep11 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep12 -ExpectedChecksum $expectedChecksum_sep12 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep13 -ExpectedChecksum $expectedChecksum_sep13 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep14 -ExpectedChecksum $expectedChecksum_sep14 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep15 -ExpectedChecksum $expectedChecksum_sep15 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep16 -ExpectedChecksum $expectedChecksum_sep16 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep17 -ExpectedChecksum $expectedChecksum_sep17 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep18 -ExpectedChecksum $expectedChecksum_sep18 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep19 -ExpectedChecksum $expectedChecksum_sep19 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep20 -ExpectedChecksum $expectedChecksum_sep20 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep21 -ExpectedChecksum $expectedChecksum_sep21 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\@base\$sep22 -ExpectedChecksum $expectedChecksum_sep22 -failFlag $failFlag
    
    Compare-FileChecksum -Path $script_path\fonts\$ttf1 -ExpectedChecksum $expectedChecksum_ttf1 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf2 -ExpectedChecksum $expectedChecksum_ttf2 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf3 -ExpectedChecksum $expectedChecksum_ttf3 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf4 -ExpectedChecksum $expectedChecksum_ttf4 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf5 -ExpectedChecksum $expectedChecksum_ttf5 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf6 -ExpectedChecksum $expectedChecksum_ttf6 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf7 -ExpectedChecksum $expectedChecksum_ttf7 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf8 -ExpectedChecksum $expectedChecksum_ttf8 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf9 -ExpectedChecksum $expectedChecksum_ttf9 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf10 -ExpectedChecksum $expectedChecksum_ttf10 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf11 -ExpectedChecksum $expectedChecksum_ttf11 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf12 -ExpectedChecksum $expectedChecksum_ttf12 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf13 -ExpectedChecksum $expectedChecksum_ttf13 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf14 -ExpectedChecksum $expectedChecksum_ttf14 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf15 -ExpectedChecksum $expectedChecksum_ttf15 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf16 -ExpectedChecksum $expectedChecksum_ttf16 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fonts\$ttf17 -ExpectedChecksum $expectedChecksum_ttf17 -failFlag $failFlag
    
    Compare-FileChecksum -Path $script_path\fades\$fade1 -ExpectedChecksum $expectedChecksum_fade1 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fades\$fade2 -ExpectedChecksum $expectedChecksum_fade2 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fades\$fade3 -ExpectedChecksum $expectedChecksum_fade3 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fades\$fade4 -ExpectedChecksum $expectedChecksum_fade4 -failFlag $failFlag
    Compare-FileChecksum -Path $script_path\fades\$fade5 -ExpectedChecksum $expectedChecksum_fade5 -failFlag $failFlag
    
    Compare-FileChecksum -Path $script_path\$trans1 -ExpectedChecksum $expectedChecksum_trans1 -failFlag $failFlag
        
    Write-Output "End:" $failFlag.Value

    if ($failFlag.Value) {
        WriteToLogFile "Checksums [ERROR]            : At least one checksum verification failed. Aborting..."
        exit
    }
    else {
        WriteToLogFile "Checksums                    : All checksum verifications succeeded."
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
    Write-Host "AudioLanguage, Awards, Based, Charts, ContentRating, Country, Decades, Franchise, Genres, Network, Playlist, Resolution, Streaming, Studio, Seasonal, Separators, SubtitleLanguages, Universe, VideoFormat, Years, All"
    exit
}

#################################
# MAIN
#################################
Set-Location $script_path
Add-Content $playback "START"

$font_flag = $null
if (!(Test-Path "$scriptLogPath" -ErrorAction SilentlyContinue)) {
    New-Item "$scriptLogPath" -ItemType Directory | Out-Null
}
Update-LogFile -LogPath $scriptLog

WriteToLogFile "#### START ####"

$Stopwatch = [System.Diagnostics.Stopwatch]::new()
$Stopwatch.Start()
Clear-Log
New-SQLCache
Import-YamlModule

#################################
# Language Code
#################################
$LanguageCodes = @("ar", "en", "da", "de", "es", "fr", "it", "nb_NO", "nl", "pt-br", "sv")
$DefaultLanguageCode = "en"
$LanguageCode = Read-Host "Enter language code ($($LanguageCodes -join ', ')). Press Enter to use the default language code: $DefaultLanguageCode"

if (-not [string]::IsNullOrWhiteSpace($LanguageCode) -and $LanguageCodes -notcontains $LanguageCode) {
    Write-Error "Error: Invalid language code."
    return
}

if ([string]::IsNullOrWhiteSpace($LanguageCode)) {
    $LanguageCode = $DefaultLanguageCode
}

$BranchOptions = @("master", "develop", "nightly")
$DefaultBranchOption = "nightly"
$BranchOption = Read-Host "Enter branch option ($($BranchOptions -join ', ')). Press Enter to use the default branch option: $DefaultBranchOption"

if (-not [string]::IsNullOrWhiteSpace($BranchOption) -and $BranchOptions -notcontains $BranchOption) {
    Write-Error "Error: Invalid branch option."
    return
}

if ([string]::IsNullOrWhiteSpace($BranchOption)) {
    $BranchOption = $DefaultBranchOption
}

Get-TranslationFile -LanguageCode $LanguageCode -BranchOption $BranchOption
Read-Host -Prompt "If you have a custom translation file, overwrite the downloaded one now and then Press any key to continue..."

$TranslationFilePath = Join-Path $script_path -ChildPath "@translations"
$TranslationFilePath = Join-Path $TranslationFilePath -ChildPath "$LanguageCode.yml"
$DefaultsPath = Join-Path $script_path -ChildPath "defaults-$LanguageCode"

Read-Yaml

#################################
# Imagemagick version check
#################################
. .\create_poster.ps1
Test-ImageMagick
$test = $global:magick

#################################
# Powershell version check
#################################
$pversion = $null
$pversion = $PSVersionTable.PSVersion.ToString()

WriteToLogFile "#######################"
WriteToLogFile "# SETTINGS"
WriteToLogFile "#######################"
WriteToLogFile "Script Path                  : $script_path"
WriteToLogFile "Original command line        : $($MyInvocation.Line)"
WriteToLogFile "Powershell Version           : $pversion"
WriteToLogFile "Imagemagick                  : $global:magick"
WriteToLogFile "LanguageCode                 : $LanguageCode"
WriteToLogFile "BranchOption                 : $BranchOption"
WriteToLogFile "#### PROCESSING CHECKS NOW ####"

Get-CheckSum-Files -script_path $script_path

if ($null -eq $test) {
    WriteToLogFile "Imagemagick [ERROR]          : Imagemagick is NOT installed. Aborting.... Imagemagick must be installed - https://imagemagick.org/script/download.php"
    exit 1
}
else {
    WriteToLogFile "Imagemagick                  : Imagemagick is installed."
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    WriteToLogFile "Powershell Version [ERROR]   : Error: This script requires PowerShell version 7 or higher."
    exit 1
}
else {
    WriteToLogFile "Powershell Version           : PowerShell version 7 or higher found."
}

if (-not (InstallFontsIfNeeded)) {
    # If the function returns $false, exit the script
    WriteToLogFile "Fonts Check [ERROR]          : Error: Fonts are not visible/installed for ImageMagick to use."
    exit 1
}
else {
    WriteToLogFile "Fonts Check                  : Fonts visible/installed for ImageMagick to use."
}

WriteToLogFile "#### PROCESSING POSTERS NOW ####"

#################################
# Cleanup Folders
#################################
Set-Location $script_path
Remove-Folders

#################################
# Create Paths if needed
#################################
Find-Path "$script_path\@base"
Find-Path $DefaultsPath
Find-Path "$script_path\fonts"
Find-Path "$script_path\output"


#################################
# Determine parameters passed from command line
#################################
Set-Location $script_path

foreach ($param in $args) {
    Switch ($param) {
        "Aspect" { CreateAspect }
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
        "Overlay" { CreateOverlays }
        "Overlays" { CreateOverlays }
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
        "VideoFormat" { CreateVideoFormat }
        "VideoFormats" { CreateVideoFormat }
        "Year" { CreateYear }
        "Years" { CreateYear }
        "All" {
            CreateAspect
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
            CreateVideoFormat
            CreateYear
            CreateOverlays
        }
        default {
            ShowFunctions
        }
    }
}

if (!$args) {
    ShowFunctions
    # CreateCountry
    # CreateAspect
    # CreateContentRating
    # CreateAwards
    # CreateResolution
    # CreateOverlays
    # CreateSeparators
    # CreateNetwork
    # CreateYear
    # CreateBased
    # CreateAudioLanguage
}

#######################
# Set current directory
#######################
Set-Location $script_path

#######################
# Wait for processes to end and then MoveFiles
#######################
Set-Location $script_path
WriteToLogFile "MonitorProcess               : Waiting for all processes to end..."
Start-Sleep -Seconds 3
MonitorProcess -ProcessName "magick.exe"
WriteToLogFile "#### PROCESSING POSTERS DONE ####"

MoveFiles

#######################
# Count files created
#######################
Set-Location $script_path
$tmp = (Get-ChildItem $DefaultsPath -Recurse -File | Measure-Object).Count
$files_to_process = $tmp

#######################
# Output files created to a file
#######################
Set-Location $script_path
Get-ChildItem -Recurse $DefaultsPath -Name -File | ForEach-Object { '"{0}"' -f $_ } | Out-File defaults-${LanguageCode}_list.txt

#######################
# Count [ERROR] lines
#######################
$errorCount1 = (Get-Content $scriptLog | Select-String -Pattern "\[ERROR\]" | Measure-Object).Count

if (Test-Path -Path $scriptLog2) {
    $errorCount2 = (Get-Content $scriptLog2 | Select-String -Pattern "\[ERROR\]" | Measure-Object).Count
}
else {
    $errorCount2 = 0
}

#######################
# SUMMARY
#######################
Set-Location $script_path
WriteToLogFile "#######################"
WriteToLogFile "# SUMMARY"
WriteToLogFile "#######################"
WriteToLogFile "Script Path                           : $script_path"
WriteToLogFile "Original command line                 : $($MyInvocation.Line)"
WriteToLogFile "Powershell Version                    : $pversion"
WriteToLogFile "Imagemagick                           : $global:magick"
WriteToLogFile "LanguageCode                          : $LanguageCode"
WriteToLogFile "BranchOption                          : $BranchOption"
WriteToLogFile "[ERROR] lines in create_default_poster: $errorCount1"
WriteToLogFile "[ERROR] lines in create_poster        : $errorCount2"

$x = [math]::Round($Stopwatch.Elapsed.TotalMinutes, 2)
$speed = [math]::Round($files_to_process / $Stopwatch.Elapsed.TotalMinutes, 2)
$y = [math]::Round($Stopwatch.Elapsed.TotalMinutes, 2)
$string = "Elapsed time is                       : $x minutes"
WriteToLogFile $string

$string = "Files Processed                       : $files_to_process in $y minutes"
WriteToLogFile $string

$string = "Posters per minute                    : " + $speed.ToString()
WriteToLogFile $string
WriteToLogFile "#### END ####"

# Check for errors
if ($errorCount1 -ne 0 -or $errorCount2 -ne 0) {
    # Display a flashing red console message with more details
    $flashCount = 20

    Write-Host ("*" * 100) -ForegroundColor Red
    Write-Host ("* Errors detected in script. Check the log file for details:") -ForegroundColor Red
    Write-Host ("* [ERROR] lines in create_default_poster: $errorCount1") -ForegroundColor Red
    Write-Host ("* [ERROR] lines in create_poster        : $errorCount2") -ForegroundColor Red
    Write-Host ("*" * 100) -ForegroundColor Red


    for ($i = 0; $i -lt $flashCount; $i++) {
        if ($i % 2 -eq 0) {
            Write-Host "Flashing message. Check the log for details." -ForegroundColor Red -NoNewline
        } else {
            Write-Host "Flashing message. Check the log for details." -ForegroundColor Yellow -NoNewline
        }
    
        Start-Sleep -Milliseconds 500
        Write-Host -NoNewline ("`r" + (" " * [System.Console]::BufferWidth) + "`r")
        Start-Sleep -Milliseconds 500
    }
}