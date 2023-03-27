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

#################################
# collect paths
#################################
$script_path = $PSScriptRoot
Set-Location $script_path
$scriptName = $MyInvocation.MyCommand.Name
$scriptLogPath = Join-Path $script_path -ChildPath "logs"
$scriptLog = Join-Path $scriptLogPath -ChildPath "$scriptName.log"
$databasePath = Join-Path $script_path -ChildPath "OptimalPointSizeCache.db"

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
    $folders = "audio_language", "award", "based", "chart", "content_rating", "country",
    "decade", "defaults", "franchise", "genre", "network", "playlist", "resolution",
    "seasonal", "separators", "streaming", "studio", "subtitle_language",
    "translations", "universe", "year"
    
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

    $GitHubRepository = "https://raw.githubusercontent.com/meisnate12/Plex-Meta-Manager/$BranchOption/defaults/translations"
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
# Function: Get-TranslatedValue
# Description:  gets the translated value for the poster
################################################################################
Function Get-TranslatedValue {
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
                if ($TranslationFilePath.EndsWith("default.yml")) {
                    $TranslationDictionary[$Matches[1]] = $Matches[1]
                }
            }
        }

        if ($TranslationFilePath.EndsWith("default.yml")) {
            # Loop through the file again to add the commented key-value pairs
            Get-Content $TranslationFilePath | ForEach-Object {
                $Line = $_.Trim()
                if ($Line -match "^#\s*(.+):\s+(.+)$") {
                    $TranslationDictionary[$Matches[1]] = $Matches[2]
                }
            }
        }

        # Get the translated value
        $EnglishValue = $EnglishValue.Replace("\n", " ")
        $TranslatedValue = $TranslationDictionary[$EnglishValue]

        if ($null -eq $TranslatedValue) {
            Write-Output "TRANSLATION NOT FOUND"
            WriteToLogFile "TranslatedValue [ERROR]      : ${EnglishValue}: TRANSLATION NOT FOUND in $TranslationFilePath"
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
        WriteToLogFile "TranslatedValue              : ${EnglishValue}: $TranslatedValue in $TranslationFilePath"
    }
    catch {
        Write-Error "Error: Value not found in dictionary."
        return
    }
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

    # Execute command and get point size
    $current_pointsize = [int](Invoke-Expression $cmd | Out-String).Trim()
    WriteToLogFile "Caption point size           : $current_pointsize"

    # Apply point size limits
    if ($current_pointsize -gt $max_pointsize) {
        WriteToLogFile "Optimal Point Size           : Font size limit reached"
        $current_pointsize = $max_pointsize
    }
    elseif ($current_pointsize -lt $min_pointsize) {
        WriteToLogFile "Optimal Point Size ERROR     : Text is too small and will be truncated"
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
    $defaultsPath = Join-Path $script_path -ChildPath "defaults"

    $foldersToMove = @(
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
        "year"
    )

    $filesToMove = @(
        "collectionless.jpg"
    )

    foreach ($folder in $foldersToMove) {
        Move-Item -Path (Join-Path $script_path -ChildPath $folder) -Destination $defaultsPath -Force -ErrorAction SilentlyContinue
    }

    foreach ($file in $filesToMove) {
        Move-Item -Path (Join-Path $script_path -ChildPath $file) -Destination $defaultsPath -Force -ErrorAction SilentlyContinue
    }
}

################################################################################
# Function: CreateAudioLanguage
# Description:  Creates audio language
################################################################################
Function CreateAudioLanguage {
    Write-Host "Creating Audio Language"
    Set-Location $script_path
    # Find-Path "$script_path\audio_language"
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| audio_language_other_name| other| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr

    $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "audio_language_name" -CaseSensitivity Upper) 

    $myArray = @(
        'Name| out_name| base_color| other_setting',
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
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
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
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    ########################
    # BAFTA #9C7C26
    ########################
    WriteToLogFile "ImageMagick Commands for     : BAFTA"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'BAFTA.png| 1800| WINNERS| winner| #9C7C26| 1',
        'BAFTA.png| 1800| NOMINATIONS| nomination| #9C7C26| 1'
        'BAFTA.png| 1800| BEST DIRECTOR WINNERS| best_director_winner| #9C7C26| 1',
        'BAFTA.png| 1800| BEST PICTURE WINNERS| best_picture_winner| #9C7C26| 1',
        'BAFTA.png| 1800| | BAFTA| #9C7C26| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'BAFTA.png| 1800| WINNERS| winner| #9C7C26| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\bafta

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'BAFTA.png| 1800| WINNERS| winner| #9C7C26| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\bafta\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'BAFTA.png| 1800| NOMINATIONS| nomination| #9C7C26| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\bafta\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'BAFTA.png| 1800| BEST PICTURE WINNER| winner| #9C7C26| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\bafta\best

    # ########################
    # # Berlinale #BB0B34
    # ########################
    WriteToLogFile "ImageMagick Commands for     : Berlinale"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Berlinale.png| 1000| WINNERS| winner| #BB0B34| 1',
        'Berlinale.png| 1000| NOMINATIONS| nomination| #BB0B34| 1'
        'Berlinale.png| 1000| BEST DIRECTOR WINNERS| best_director_winner| #BB0B34| 1',
        'Berlinale.png| 1000| BEST PICTURE WINNERS| best_picture_winner| #BB0B34| 1',
        'Berlinale.png| 1000| | Berlinale| #BB0B34| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Berlinale.png| 1000| WINNERS| winner| #BB0B34| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1951; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\berlinale

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Berlinale.png| 1000| WINNERS| winner| #BB0B34| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1951; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\berlinale\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Berlinale.png| 1000| NOMINATIONS| nomination| #BB0B34| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1951; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\berlinale\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Berlinale.png| 1000| BEST PICTURE WINNER| winner| #BB0B34| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1951; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\berlinale\best

    ########################
    # Cannes #AF8F51
    ########################
    WriteToLogFile "ImageMagick Commands for     : Cannes"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cannes.png| 1800| WINNERS| winner| #AF8F51| 1',
        'Cannes.png| 1800| NOMINATIONS| nomination| #AF8F51| 1'
        'Cannes.png| 1800| BEST DIRECTOR WINNERS| best_director_winner| #AF8F51| 1',
        'Cannes.png| 1800| BEST PICTURE WINNERS| best_picture_winner| #AF8F51| 1',
        'Cannes.png| 1800| | Cannes| #AF8F51| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cannes.png| 1800| WINNERS| winner| #AF8F51| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1938; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cannes

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cannes.png| 1800| WINNERS| winner| #AF8F51| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1938; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cannes\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cannes.png| 1800| NOMINATIONS| nomination| #AF8F51| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1938; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cannes\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cannes.png| 1800| BEST PICTURE WINNER| winner| #AF8F51| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1938; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cannes\best

    ########################
    # Cesar #E2A845
    ########################
    WriteToLogFile "ImageMagick Commands for     : Cesar"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cesar.png| 1800| WINNERS| winner| #E2A845| 1',
        'Cesar.png| 1800| NOMINATIONS| nomination| #E2A845| 1'
        'Cesar.png| 1800| BEST DIRECTOR WINNERS| best_director_winner| #E2A845| 1',
        'Cesar.png| 1800| BEST PICTURE WINNERS| best_picture_winner| #E2A845| 1',
        'Cesar.png| 1800| | Cesar| #E2A845| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cesar.png| 1800| WINNERS| winner| #E2A845| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1976; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cesar

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cesar.png| 1800| WINNERS| winner| #E2A845| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1976; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cesar\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cesar.png| 1800| NOMINATIONS| nomination| #E2A845| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1976; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cesar\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Cesar.png| 1800| BEST PICTURE WINNER| winner| #E2A845| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1976; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\cesar\best

    ########################
    # Choice #AC7427
    ########################
    WriteToLogFile "ImageMagick Commands for     : Choice"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Choice.png| 600| WINNERS| winner| #AC7427| 1',
        'Choice.png| 600| NOMINATIONS| nomination| #AC7427| 1'
        'Choice.png| 600| BEST DIRECTOR WINNERS| best_director_winner| #AC7427| 1',
        'Choice.png| 600| BEST PICTURE WINNERS| best_picture_winner| #AC7427| 1',
        'Choice.png| 600|| Choice| #AC7427| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Choice.png| 600| WINNERS| winner| #AC7427| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1929; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\choice

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Choice.png| 600| WINNERS| winner| #AC7427| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1929; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\choice\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Choice.png| 600| NOMINATIONS| nomination| #AC7427| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1929; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\choice\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Choice.png| 600| BEST PICTURE WINNER| winner| #AC7427| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1929; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\choice\best

    ########################
    # Emmys #D89C27
    ########################
    WriteToLogFile "ImageMagick Commands for     : Awards-Emmys-Winner"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Emmys.png| 1500| WINNERS| winner| #D89C27| 1',
        'Emmys.png| 1500| NOMINATIONS| nomination| #D89C27| 1'
        'Emmys.png| 1500| BEST DIRECTOR WINNERS| best_director_winner| #D89C27| 1',
        'Emmys.png| 1500| BEST PICTURE WINNERS| best_picture_winner| #D89C27| 1',
        'Emmys.png| 1500|| Emmys| #D89C27| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Emmys.png| 1500| WINNERS| winner| #D89C27| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\emmys

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Emmys.png| 1500| WINNERS| winner| #D89C27| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\emmys\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Emmys.png| 1500| NOMINATIONS| nomination| #D89C27| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\emmys\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Emmys.png| 1500| BEST PICTURE WINNER| winner| #D89C27| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1947; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\emmys\best

    ########################
    # Golden #D0A047
    ########################
    WriteToLogFile "ImageMagick Commands for     : Golden"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Golden.png| 1500| WINNERS| winner| #D0A047| 1',
        'Golden.png| 1500| NOMINATIONS| nomination| #D0A047| 1'
        'Golden.png| 1500| BEST DIRECTOR WINNERS| best_director_winner| #D0A047| 1',
        'Golden.png| 1500| BEST PICTURE WINNERS| best_picture_winner| #D0A047| 1',
        'Golden.png| 1500| | Golden| #D0A047| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Golden.png| 1500| WINNERS| winner| #D0A047| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1943; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\golden

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Golden.png| 1500| WINNERS| winner| #D0A047| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1943; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\golden\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Golden.png| 1500| NOMINATIONS| nomination| #D0A047| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1943; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\golden\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Golden.png| 1500| BEST PICTURE WINNER| winner| #D0A047| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1943; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\golden\best

    ########################
    # Oscars #A9842E
    ########################
    WriteToLogFile "ImageMagick Commands for     : Oscars"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Oscars.png| 1500| WINNERS| winner| #A9842E| 1',
        'Oscars.png| 1500| NOMINATIONS| nomination| #A9842E| 1'
        'Oscars.png| 1500| BEST DIRECTOR WINNERS| best_director_winner| #A9842E| 1',
        'Oscars.png| 1500| BEST PICTURE WINNERS| best_picture_winner| #A9842E| 1',
        'Oscars.png| 1500| | Oscars| #A9842E| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Oscars.png| 1500| WINNERS| winner| #A9842E| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Oscars.png| 1500| WINNERS| winner| #A9842E| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Oscars.png| 1500| NOMINATIONS| nomination| #A9842E| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Oscars.png| 1500| BEST PICTURE WINNER| winner| #A9842E| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1927; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\oscars\best

    ########################
    # Razzie #FF0C0C
    ########################
    WriteToLogFile "ImageMagick Commands for     : Razzie"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Razzie.png| 1000| WINNERS| winner| #FF0C0C| 1',
        'Razzie.png| 1000| NOMINATIONS| nomination| #FF0C0C| 1',
        'Razzie.png| 1000| BEST DIRECTOR WINNERS| best_director_winner| #FF0C0C| 1',
        'Razzie.png| 1000| BEST PICTURE WINNERS| best_picture_winner| #FF0C0C| 1',
        'Razzie.png| 1000| | Razzie| #FF0C0C| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Razzie.png| 1000| WINNERS| winner| #FF0C0C| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1980; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzies

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Razzie.png| 1000| WINNERS| winner| #FF0C0C| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1980; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzies\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Razzie.png| 1000| NOMINATIONS| nomination| #FF0C0C| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1980; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzies\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Razzie.png| 1000| BEST PICTURE WINNER| winner| #FF0C0C| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1980; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\razzies\best

    ########################
    # Spirit #4662E7
    ########################
    WriteToLogFile "ImageMagick Commands for     : Spirit"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Spirit.png| 1000| WINNERS| winner| #4662E7| 1',
        'Spirit.png| 1000| NOMINATIONS| nomination| #4662E7| 1'
        'Spirit.png| 1000| BEST DIRECTOR WINNERS| best_director_winner| #4662E7| 1',
        'Spirit.png| 1000| BEST PICTURE WINNERS| best_picture_winner| #4662E7| 1',
        'Spirit.png| 1000| | Spirit| #4662E7| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Spirit.png| 1000| WINNERS| winner| #4662E7| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1986; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\spirit

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Spirit.png| 1000| WINNERS| winner| #4662E7| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1986; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\spirit\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Spirit.png| 1000| NOMINATIONS| nomination| #4662E7| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1986; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\spirit\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Spirit.png| 1000| BEST PICTURE WINNER| winner| #4662E7| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1986; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\spirit\best

    ########################
    # Sundance #7EB2CF
    ########################
    WriteToLogFile "ImageMagick Commands for     : Sundance"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Sundance.png| 1500| WINNERS| winner| #7EB2CF| 1',
        'Sundance.png| 1500| NOMINATIONS| nomination| #7EB2CF| 1'
        'Sundance.png| 1500| BEST DIRECTOR WINNERS| best_director_winner| #7EB2CF| 1',
        'Sundance.png| 1500| BEST PICTURE WINNERS| best_picture_winner| #7EB2CF| 1',
        'Sundance.png| 1500| GRAND JURY WINNERS| grand_jury_winner| #7EB2CF| 1',
        'Sundance.png| 1500| | Sundance| #7EB2CF| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Sundance.png| 1500| WINNERS| winner| #7EB2CF| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sundance

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Sundance.png| 1500| WINNERS| winner| #7EB2CF| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sundance\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Sundance.png| 1500| NOMINATIONS| nomination| #7EB2CF| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sundance\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Sundance.png| 1500| BEST PICTURE WINNER| winner| #7EB2CF| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1978; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\sundance\best

    ########################
    # Venice #D21635
    ########################
    WriteToLogFile "ImageMagick Commands for     : Venice"
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Venice.png| 1500| WINNERS| winner| #D21635| 1',
        'Venice.png| 1500| NOMINATIONS| nomination| #D21635| 1'
        'Venice.png| 1500| BEST DIRECTOR WINNERS| best_director_winner| #D21635| 1',
        'Venice.png| 1500| BEST PICTURE WINNERS| best_picture_winner| #D21635| 1',
        'Venice.png| 1500| | Venice| #D21635| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        if ($($item.Name).ToString() -eq "") {
            $myvar = $null
        }
        else {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        }
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Venice.png| 1500| WINNERS| winner| #D21635| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1932; $i -lt 2030; $i++) {
            $myvar = $i
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\venice

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Venice.png| 1500| WINNERS| winner| #D21635| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1932; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\venice\winner

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Venice.png| 1500| NOMINATIONS| nomination| #D21635| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1932; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination award\venice\nomination
 
    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'Venice.png| 1500| BEST PICTURE WINNER| winner| #D21635| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        for ($i = 1932; $i -lt 2030; $i++) {
            $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
            $myvar = "$myvar $i"
            $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
            $arr += ".\create_poster.ps1 -logo `"$script_path\logos_award\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
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
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Name| out_name| base_color| other_setting',
        'BASED ON A BOOK| Book| #131CA1| NA',
        'BASED ON A COMIC| Comic| #7856EF| NA',
        'BASED ON A TRUE STORY| True Story| #BC0638| NA',
        'BASED ON A VIDEO GAME| Video Game| #38CC66| NA'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper) 
        $myvar = $myvar1
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
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
    # Find-Path "$script_path\chart"
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1500
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color| ww',
        'AniDB.png| 1800| POPULAR| AniDB Popular| #FF7E17| 1',
        'AniList.png| 1500| POPULAR| AniList Popular| #414A81| 1',
        'AniList.png| 1500| SEASON| AniList Season| #414A81| 1',
        'AniList.png| 1500| TOP RATED| AniList Top Rated| #414A81| 1',
        'AniList.png| 1500| TRENDING| AniList Trending| #414A81| 1',
        'Apple TV+.png| 1500| TOP 10| apple_top| #494949| 1',
        'Disney+.png| 1500| TOP 10| disney_top| #002CA1| 1',
        'HBO Max.png| 1500| TOP 10| hbo_top| #9015C5| 1',
        'IMDb.png| 1500| BOTTOM RATED| IMDb Bottom Rated| #D7B00B| 1',
        'IMDb.png| 1500| BOX OFFICE| IMDb Box Office| #D7B00B| 1',
        'IMDb.png| 1500| LOWEST RATED| IMDb Lowest Rated| #D7B00B| 1',
        'IMDb.png| 1500| POPULAR| IMDb Popular| #D7B00B| 1',
        'IMDb.png| 1500| TOP 10| imdb_top| #D7B00B| 1',
        'IMDb.png| 1500| TOP 250| IMDb Top 250| #D7B00B| 1',
        'MyAnimeList.png| 1500| FAVORITED| MyAnimeList Favorited| #304DA6| 1',
        'MyAnimeList.png| 1500| POPULAR| MyAnimeList Popular| #304DA6| 1',
        'MyAnimeList.png| 1500| SEASON| MyAnimeList Season| #304DA6| 1',
        'MyAnimeList.png| 1500| TOP AIRING| MyAnimeList Top Airing| #304DA6| 1',
        'MyAnimeList.png| 1500| TOP RATED| MyAnimeList Top Rated| #304DA6| 1',
        'Netflix.png| 1500| TOP 10| netflix_top| #B4121D| 1',
        'Paramount+.png| 1500| TOP 10| paramount_top| #1641C3| 1',
        'Pirated.png| 1500| TOP 10 PIRATED| Top 10 Pirated Movies of the Week| #93561D| 1',
        'Plex.png| 1500| NEW EPISODES| New Episodes| #DC9924| 1',
        'Plex.png| 1500| NEW PREMIERES| New Premieres| #DC9924| 1',
        'Plex.png| 1500| NEWLY RELEASED EPISODES| Newly Released Episodes| #DC9924| 1',
        'Plex.png| 1500| NEWLY RELEASED| Newly Released| #DC9924| 1',
        'Plex.png| 1500| PILOTS| Pilots| #DC9924| 1',
        'Plex.png| 1500| PLEX PEOPLE WATCHING| Plex People Watching| #DC9924| 1',
        'Plex.png| 1500| PLEX PILOTS| Plex Pilots| #DC9924| 1',
        'Plex.png| 1500| PLEX POPULAR| Plex Popular| #DC9924| 1',
        'Plex.png| 1500| PLEX WATCHED| Plex Watched| #DC9924| 1',
        'Plex.png| 1500| RECENTLY ADDED| Recently Added| #DC9924| 1',
        'Plex.png| 1500| RECENTLY AIRED| Recently Aired| #DC9924| 1',
        'Prime Video.png| 1500| TOP 10| prime_top| #43ABCE| 1',
        'StevenLu.png| 1500| STEVENLU''S POPULAR MOVIES| StevenLu''s Popular Movies| #1D2D51| 1',
        'TMDb.png| 1500| AIRING TODAY| TMDb Airing Today| #062AC8| 1',
        'TMDb.png| 1500| NOW PLAYING| TMDb Now Playing| #062AC8| 1',
        'TMDb.png| 1500| ON THE AIR| TMDb On The Air| #062AC8| 1',
        'TMDb.png| 1500| POPULAR| TMDb Popular| #062AC8| 1',
        'TMDb.png| 1500| TOP RATED| TMDb Top Rated| #062AC8| 1',
        'TMDb.png| 1500| TRENDING| TMDb Trending| #062AC8| 1',
        'Tautulli.png| 1500| POPULAR| Tautulli Popular| #B9851F| 1',
        'Tautulli.png| 1500| WATCHED| Tautulli Watched| #B9851F| 1',
        'Trakt.png| 1500| COLLECTED| Trakt Collected| #CD1A20| 1',
        'Trakt.png| 1500| NOW PLAYING| Trakt Now Playing| #CD1A20| 1',
        'Trakt.png| 1500| POPULAR| Trakt Popular| #CD1A20| 1',
        'Trakt.png| 1500| RECOMMENDED| Trakt Recommended| #CD1A20| 1',
        'Trakt.png| 1500| TRENDING| Trakt Trending| #CD1A20| 1',
        'Trakt.png| 1500| WATCHED| Trakt Watched| #CD1A20| 1',
        'Trakt.png| 1500| WATCHLIST| Trakt Watchlist| #CD1A20| 1',
        'css.png| 1500| FAMILIES| Common Sense Selection| #1AA931| 1',
        'google_play.png| 1500| TOP 10| google_top| #B81282| 1',
        'hulu.png| 1500| TOP 10| hulu_top| #1BB68A| 1',
        'itunes.png| 1500| TOP 10| itunes_top| #D500CC| 1',
        'star_plus.png| 1500| TOP 10| star_plus_top| #4A3159| 1',
        'vudu.png| 1500| TOP 10| vudu_top| #3567AC| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_chart\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
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
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250
    # $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "content_rating_name" -CaseSensitivity Upper) 

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| content_ratings_other_name| other| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination content_rating
    
    $arr = @()
    for ($i = 1; $i -lt 19; $i++) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "AGE" -CaseSensitivity Upper)
        $myvar = "$myvar $i+"
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\cs.png`" -logo_offset -500 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"#1AA931`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "NOT RATED" -CaseSensitivity Upper)
    $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\cs.png`" -logo_offset -500 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NR`" -base_color `"#1AA931`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination content_rating\cs
    
    $content_rating = "G", "PG", "PG-13", "R", "R+", "Rx"
    $arr = @()
    foreach ( $cr in $content_rating ) { 
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "RATED" -CaseSensitivity Upper)
        $myvar = "$myvar $cr"
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\mal.png`" -logo_offset -500 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$cr`" -base_color `"#2444D1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "NOT RATED" -CaseSensitivity Upper)
    $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_content_rating\mal.png`" -logo_offset -500 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NR`" -base_color `"#2444D1`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
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
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250
    $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "country_name" -CaseSensitivity Upper) 

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| country_other_name| Other Countries| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'Logo| logo_resize| Name| out_name| base_color',
        'ae.png| 1500| UNITED ARAB EMIRATES| United Arab Emirates| #BC9C16',
        'ar.png| 750| ARGENTINA| Argentina| #F05610',
        'at.png| 1500| AUSTRIA| Austria| #F5E6AE',
        'au.png| 1500| AUSTRALIA| Australia| #D5237B',
        'be.png| 1500| BELGIUM| Belgium| #AC98DB',
        'bg.png| 1500| BULGARIA| Bulgaria| #79AB96',
        'br.png| 1500| BRAZIL| Brazil| #EE9DA9',
        'bs.png| 1500| BAHAMAS| Bahamas| #F6CDF0',
        'ca.png| 1500| CANADA| Canada| #32DE58',
        'ch.png| 1500| SWITZERLAND| Switzerland| #5803F1',
        'cl.png| 1500| CHILE| Chile| #AAC41F',
        'cn.png| 1500| CHINA| China| #902A62',
        'cr.png| 1500| COSTA RICA| Costa Rica| #41F306',
        'cz.png| 1500| CZECH REPUBLIC| Czech Republic| #9ECE8F',
        'de.png| 1500| GERMANY| Germany| #97FDAE',
        'dk.png| 1500| DENMARK| Denmark| #685ECB',
        'do.png| 1500| DOMINICAN REPUBLIC| Dominican Republic| #83F0A2',
        'ee.png| 1500| ESTONIA| Estonia| #5145DA',
        'eg.png| 1500| EGYPT| Egypt| #86B137',
        'es.png| 1500| SPAIN| Spain| #99DA4B',
        'fi.png| 750| FINLAND| Finland| #856518',
        'fr.png| 1500| FRANCE| France| #D0404D',
        'gb.png| 1500| UNITED KINGDOM| United Kingdom| #C7B89D',
        'gr.png| 1500| GREECE| Greece| #431832',
        'hk.png| 1500| HONG KONG| Hong Kong| #F6B541',
        'hr.png| 1500| CROATIA| Croatia| #62BF53',
        'hu.png| 1500| HUNGARY| Hungary| #E5983C',
        'id.png| 1500| INDONESIA| Indonesia| #3E33E4',
        'ie.png| 1500| IRELAND| Ireland| #C6377E',
        'il.png| 650| ISRAEL| Israel| #41E0A9',
        'in.png| 1500| INDIA| India| #A6404A',
        'is.png| 1500| ICELAND| Iceland| #CE31A0',
        'it.png| 1500| ITALY| Italy| #57B9BF',
        'ir.png| 1500| IRAN| Iran| #2AAC15',
        'jp.png| 1500| JAPAN| Japan| #4FCF54',
        'kr.png| 1500| KOREA| Korea| #127FFE',
        'lk.png| 750| SRI LANKA| Sri Lanka| #6415FD',
        'lu.png| 750| LUXEMBOURG| Luxembourg| #C90586',
        'lv.png| 1500| LATVIA| Latvia| #5326A3',
        'ma.png| 1500| MOROCCO| Morocco| #B28BDC',
        'mx.png| 1500| MEXICO| Mexico| #964F76',
        'my.png| 1500| MALAYSIA| Malaysia| #9630B4',
        'nl.png| 1500| NETHERLANDS| Netherlands| #B14FAA',
        'no.png| 1500| NORWAY| Norway| #AC320E',
        'np.png| 1500| NEPAL| Nepal| #3F847B',
        'nz.png| 1500| NEW ZEALAND| New Zealand| #E0A486',
        'pa.png| 1500| PANAMA| Panama| #417818',
        'pe.png| 750| PERU| Peru| #803704',
        'ph.png| 1500| PHILIPPINES| Philippines| #2DF423',
        'pk.png| 1500| PAKISTAN| Pakistan| #6FF34E',
        'pl.png| 1500| POLAND| Poland| #BAF6C2',
        'pt.png| 1500| PORTUGAL| Portugal| #A1DE3F',
        'qa.png| 750| QATAR| Qatar| #4C1FCC',
        'ro.png| 1500| ROMANIA| Romania| #ABD0CF',
        'rs.png| 1500| SERBIA| Serbia| #7E0D8E',
        'ru.png| 1500| RUSSIA| Russia| #97D820',
        'sa.png| 1500| SAUDI ARABIA| Saudi Arabia| #D34B83',
        'se.png| 1500| SWEDEN| Sweden| #E3C61A',
        'sg.png| 1500| SINGAPORE| Singapore| #0328DB',
        'th.png| 1500| THAILAND| Thailand| #32DBD9',
        'tr.png| 1500| TURKEY| Turkey| #CD90D1',
        'ua.png| 1500| UKRAINE| Ukraine| #1640B6',
        'us.png| 1500| UNITED STATES OF AMERICA| United States of America| #D2A345',
        'vn.png| 1500| VIETNAM| Vietnam| #19156E',
        'za.png| 1500| SOUTH AFRICA| South Africa| #E7BB4A'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    }
    LaunchScripts -ScriptPaths $arr

    Move-Item -Path output -Destination country\color

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_country\$($item.Logo)`" -logo_offset -500 -logo_resize $($item.logo_resize) -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| country_other_name| Other Countries| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
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
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| decade_other_name| other| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr

    # $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1900
    $theMaxHeight = 550
    $minPointSize = 250
    $maxPointSize = 1000

    $myArray = @(
        'Name| out_name| base_color| font_name| font_size',
        '1880s| 1880| #44EF10| Rye-Regular| 453',
        '1890s| 1890| #44EF10| Limelight-Regular| 453',
        '1900s| 1900| #44EF10| BoecklinsUniverse| 453',
        '1910s| 1910| #44EF10| UnifrakturCook| 700',
        '1920s| 1920| #44EF10| Trochut| 500',
        '1930s| 1930| #44EF10| Righteous| 500',
        '1940s| 1940| #44EF10| Yesteryear| 700',
        '1950s| 1950| #44EF10| Cherry-Cream-Soda-Regular| 500',
        '1960s| 1960| #44EF10| Boogaloo-Regular| 500',
        '1970s| 1970| #44EF10| Monoton| 500',
        '1980s| 1980| #44EF10| Press-Start-2P| 300',
        '1990s| 1990| #44EF10| Jura-Bold| 500',
        '2000s| 2000| #44EF10| Special-Elite-Regular| 500',
        '2010s| 2010| #44EF10| Barlow-Regular| 500',
        '2020s| 2020| #44EF10| Helvetica-Bold| 500'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        $myvar = $($item.Name)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $($item.font_name) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $($item.font_size)
        $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$($item.font_name)`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }

    LaunchScripts -ScriptPaths $arr
    WriteToLogFile "MonitorProcess               : Waiting for all processes to end before continuing..."
    Start-Sleep -Seconds 3
    MonitorProcess -ProcessName "magick.exe"
    
    Move-Item -Path output -Destination decade

    $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "BEST OF" -CaseSensitivity Upper) 

    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 200

    $arr = @()
    for ($i = 1880; $i -lt 2030; $i += 10) {
        $myvar = $myvar1
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\decade\$i.jpg`" -logo_offset +0 -logo_resize 2000 -text `"$myvar`" -text_offset -400 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"#FFFFFF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
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
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\RuPaul's Drag Race.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"RuPaul's Drag Race`" -base_color `"#FF5757`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
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
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\The Real Housewives.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The Real Housewives`" -base_color `"#400EA4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
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
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_franchise\Yellowstone.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Yellowstone`" -base_color `"#441515`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
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
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    # $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "genre_name" -CaseSensitivity Upper) 

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| genre_other_name| other| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'Action & adventure.png| ACTION & ADVENTURE| Action & adventure| #65AEA5| 1',
        'Action.png| ACTION| Action| #387DBF| 1',
        'Adult.png| ADULT| Adult| #D02D2D| 1',
        'Adventure.png| ADVENTURE| Adventure| #40B997| 1',
        'Animation.png| ANIMATION| Animation| #9035BE| 1',
        'Anime.png| ANIME| Anime| #41A4BE| 1',
        'APAC month.png| ASIAN AMERICAN & PACIFIC ISLANDER HERITAGE MONTH| APAC month| #0EC26B| 1',
        'Assassin.png| ASSASSIN| Assasin| #C52124| 1',
        'Biography.png| BIOGRAPHY| Biography| #C1A13E| 1',
        'Biopic.png| BIOPIC| Biopic| #C1A13E| 1',
        'Black History.png| BLACK HISTORY MONTH| Black History| #D86820| 0',
        'Black History2.png| BLACK HISTORY MONTH| Black History2| #D86820| 1',
        'Boys Love.png| BOYS LOVE| Boys Love| #85ADAC| 1',
        'Cars.png| CARS| Cars| #7B36D2| 1',
        'Children.png| CHILDREN| Children| #9C42C2| 1',
        'Comedy.png| COMEDY| Comedy| #B7363E| 1',
        'Competition.png| COMPETITION| Competition| #55BF48| 1',
        'Con Artist.png| CON ARTIST| Con Artist| #C7A5A1| 1',
        'Creature Horror.png| CREATURE HORROR| Creature Horror| #AD8603| 1',
        'Crime.png| CRIME| Crime| #888888| 1',
        'Demons.png| DEMONS| Demons| #9A2A2A| 1',
        'Disabilities.png| DAY OF PERSONS WITH DISABILITIES| Disabilities| #40B9FE| 1',
        'Documentary.png| DOCUMENTARY| Documentary| #2C4FA8| 1',
        'Drama.png| DRAMA| Drama| #A22C2C| 1',
        'Ecchi.png| ECCHI| Ecchi| #C592C0| 1',
        'Erotica.png| EROTICA| Erotica| #CA9FC9| 1',
        'Family.png| FAMILY| Family| #BABA6C| 1',
        'Fantasy.png| FANTASY| Fantasy| #CC2BC6| 1',
        'Film Noir.png| FILM NOIR| Film Noir| #5B5B5B| 1',
        'Food.png| FOOD| Food| #A145C1| 1',
        'Found Footage Horror.png| FOUND FOOTAGE HORROR| Found Footage Horror| #2C3B08| 1',
        'Game Show.png| GAME SHOW| Game Show| #32D184| 1',
        'Game.png| GAME| Game| #70BD98| 1',
        'Gangster.png| GANGSTER| Gangster| #77ACBD| 1',
        'Girls Love.png| GIRLS LOVE| Girls Love| #AC86AD| 1',
        'Gourmet.png| GOURMET| Gourmet| #83AC8F| 1',
        'Harem.png| HAREM| Harem| #7DB0C5| 1',
        'Heist.png| HEIST| Heist| #4281C9| 1',
        'Hentai.png| HENTAI| Hentai| #B274BF| 1',
        'History.png| HISTORY| History| #B7A95D| 1',
        'Home and Garden.png| HOME AND GARDEN| Home and Garden| #8CC685| 1',
        'Horror.png| HORROR| Horror| #B94948| 1',
        'Indie.png| INDIE| Indie| #BB7493| 1',
        'Kids.png| KIDS| Kids| #9F40C6| 1',
        'LatinX Month.png| LATINX HERITAGE MONTH| LatinX| #FF5F5F| 1',
        'LGBTQ+.png| LGBTQ+| LGBTQ+| #BD86C4| 1',
        'LGBTQ+ Month.png| LGBTQ+ PRIDE MONTH| LGBTQ+ Month| #FF3B3C| 1',
        'Martial Arts.png| MARTIAL ARTS| Martial Arts| #777777| 1',
        'Mecha.png| MECHA| Mecha| #8B8B8B| 1',
        'Military.png| MILITARY| Military| #87552F| 1',
        'Mind-Bend.png| MIND-BEND| Mind-Bend| #619DA2| 1',
        'Mind-Fuck.png| MIND-FUCK| Mind-Fuck| #619DA2| 1',
        'Mind-Fuck2.png| MIND-F**K| Mind-Fuck2| #619DA2| 1',
        'Mini-Series.png| MINI-SERIES| Mini-Series| #66B7BE| 1',
        'Music.png| MUSIC| Music| #3CC79C| 1',
        'Musical.png| MUSICAL| Musical| #C38CB7| 1',
        'Mystery.png| MYSTERY| Mystery| #867CB5| 1',
        'News & Politics.png| NEWS & POLITICS| News & Politics| #C83131| 1',
        'News.png| NEWS| News| #C83131| 1',
        'Outdoor Adventure.png| OUTDOOR ADVENTURE| Outdoor Adventure| #56C89C| 1',
        'Parody.png| PARODY| Parody| #83A9A2| 1',
        'Police.png| POLICE| Police| #262398| 1',
        'Politics.png| POLITICS| Politics| #3F5FC0| 1',
        'Psychedelic.png| PSYCHEDELIC| Psychedelic| #E973F6| 0',
        'Psychological Horror.png| PSYCHOLOGICAL\nHORROR| Psychological Horror| #AC5969| 1',
        'Psychological.png| PSYCHOLOGICAL| Psychological| #C79367| 1',
        'Reality.png| REALITY| Reality| #7CB6AE| 1',
        'Romance.png| ROMANCE| Romance| #B6398E| 1',
        'Romantic Comedy.png| ROMANTIC COMEDY| Romantic Comedy| #B2445D| 1',
        'Romantic Drama.png| ROMANTIC DRAMA| Romantic Drama| #AB89C0| 1',
        'Samurai.png| SAMURAI| Samurai| #C0C282| 1',
        'School.png| SCHOOL| School| #4DC369| 1',
        'Sci-Fi & Fantasy.png| SCI-FI & FANTASY| Sci-Fi & Fantasy| #9254BA| 1',
        'Science Fiction.png| SCIENCE FICTION| Science Fiction| #545FBA| 1',
        'Serial Killer.png| SERIAL KILLER| Serial Killer| #163F56| 1',
        'Short.png| SHORT| Short| #BCBB7B| 1',
        'Shoujo.png| SHOUJO| Shoujo| #89529D| 1',
        'Shounen.png| SHOUNEN| Shounen| #505E99| 1',
        'Slasher.png| SLASHER| Slasher| #B75157| 1',
        'Slice of Life.png| SLICE OF LIFE| Slice of Life| #C696C4| 1',
        'Soap.png| SOAP| Soap| #AF7CC0| 1',
        'Space.png| SPACE| Space| #A793C1| 1',
        'Sport.png| SPORT| Sport| #587EB1| 1',
        'Spy.png| SPY| Spy| #B7D99F| 1',
        'Stand-Up Comedy.png| STAND-UP COMEDY| Stand-Up Comedy| #CF8A49| 1',
        'Stoner Comedy.png| STONER COMEDY| Stoner Comedy| #79D14D| 1',
        'Super Power.png| SUPER POWER| Super Power| #279552| 1',
        'Superhero.png| SUPERHERO| Superhero| #DA8536| 1',
        'Supernatural.png| SUPERNATURAL| Supernatural| #262693| 1',
        'Survival.png| SURVIVAL| Survival| #434447| 1',
        'Suspense.png| SUSPENSE| Suspense| #AE5E37| 1',
        'Sword & Sorcery.png| SWORD & SORCERY| Sword & Sorcery| #B44FBA| 1',
        'TV Movie.png| TV MOVIE| TV Movie| #85A5B4| 1',
        'Talk Show.png| TALK SHOW| Talk Show| #82A2B5| 1',
        'Thriller.png| THRILLER| Thriller| #C3602B| 1',
        'Travel.png| TRAVEL| Travel| #B6BA6D| 1',
        'Vampire.png| VAMPIRE| Vampire| #7D2627| 1',
        'War & Politics.png| WAR & POLITICS| War & Politics| #4ABF6E| 1',
        'War.png| WAR| War| #63AB62| 1',
        'Western.png| WESTERN| Western| #AD9B6D| 1',
        'Womens History.png| WOMEN''S HISTORY MONTH| Womens Month| #874E83| 1',
        'Zombie Horror.png| ZOMBIE HORROR| Zombie Horror| #909513| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_genre\$($item.Logo)`" -logo_offset -500 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
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
    # Find-Path "$script_path\network"
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250
    $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "network_name" -CaseSensitivity Upper) 

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| network_kids_other_name| Other Kids Networks| #FF2000| 1',
        'transparent.png| network_other_name| Other Networks| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr
    $arr = @()
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\A&E.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"A&E`" -base_color `"#676767`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABC (AU).png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABC (AU)`" -base_color `"#CEC281`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABC Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABC Kids`" -base_color `"#6172B9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABC`" -base_color `"#403993`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABC TV`" -base_color `"#403993`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABC_Family.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABC_Family`" -base_color `"#73D444`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ABS-CBN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ABS-CBN`" -base_color `"#16F67B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\AltBalaji.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"AltBalaji`" -base_color `"#00CC30`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ARD.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ARD`" -base_color `"#3F76D7`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Arte.png`" -logo_offset +0 -logo_resize 400 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Arte`" -base_color `"#378BC4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\AT-X.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"AT-X`" -base_color `"#BEDA86`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC_Four.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC_Four`" -base_color `"#02A0D2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\bilibili.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"bilibili`" -base_color `"#677626`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BluTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BluTV`" -base_color `"#1E6DA3`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Canal+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Canal+`" -base_color `"#FB78AE`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Channel_3.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Channel_3`" -base_color `"#FF85AF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Game_Show_Network.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Game_Show_Network`" -base_color `"#BA27BF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Globoplay.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Globoplay`" -base_color `"#775E92`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\GMA_Network.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"GMA_Network`" -base_color `"#A755A4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ION_Television.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ION_Television`" -base_color `"#850ECC`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\iQiyi.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"iQiyi`" -base_color `"#F26F4C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BET+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BET+`" -base_color `"#B3359C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CBC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CBC Television`" -base_color `"#9D3B3F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\discovery+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"discovery+`" -base_color `"#2175D9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\KBS2.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"KBS2`" -base_color `"#0D197B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Las Estrellas.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Las Estrellas`" -base_color `"#DD983B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\MBC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"MBC`" -base_color `"#AF1287`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nippon TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nippon TV`" -base_color `"#7E180F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Paramount Network.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Paramount Network`" -base_color `"#9DE60E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\RTL.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"RTL`" -base_color `"#21354A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\SBS.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"SBS`" -base_color `"#BEBC19`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Shahid.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Shahid`" -base_color `"#7FEB9A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\SVT1.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"SVT1`" -base_color `"#94BE7C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Telemundo.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Telemundo`" -base_color `"#407160`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Tencent Video.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Tencent Video`" -base_color `"#DE90F0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TF1.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TF1`" -base_color `"#43D582`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Travel Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Travel Channel`" -base_color `"#D4FFD9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TV 2.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV 2`" -base_color `"#8040C7`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TV3.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV3`" -base_color `"#FACED0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\tv asahi.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tv asahi`" -base_color `"#DD1A67`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TV Globo.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV Globo`" -base_color `"#C8A69F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TV Tokyo.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV Tokyo`" -base_color `"#EC00E2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TVB Jade.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TVB Jade`" -base_color `"#C6582F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\tving.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tving`" -base_color `"#B2970D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\tvN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"tvN`" -base_color `"#510F23`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\UniMás.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"UniMás`" -base_color `"#3A4669`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Univision.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Univision`" -base_color `"#28BE59`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\USA Network.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"USA Network`" -base_color `"#F7EB20`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Viaplay.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Viaplay`" -base_color `"#30F7FB`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ViuTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ViuTV`" -base_color `"#D3ADE3`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Youku.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Youku`" -base_color `"#42809E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ZEE5.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ZEE5`" -base_color `"#8704C1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\AcornTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"AcornTV`" -base_color `"#182034`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Adult Swim.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Adult Swim`" -base_color `"#C0A015`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Amazon Kids+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Amazon Kids+`" -base_color `"#8E2AAF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Amazon.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Amazon`" -base_color `"#9B8832`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\AMC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"AMC`" -base_color `"#4A9472`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Animal Planet.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Animal Planet`" -base_color `"#4389BA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Antena 3.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Antena 3`" -base_color `"#306A94`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Apple TV+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Apple TV+`" -base_color `"#313131`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC America.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC America`" -base_color `"#C83535`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC One.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC One`" -base_color `"#3A38C6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC Two.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC Two`" -base_color `"#9130B1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BBC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BBC`" -base_color `"#A24649`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BET.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BET`" -base_color `"#942C2C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Boomerang.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Boomerang`" -base_color `"#6190B3`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Bravo.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Bravo`" -base_color `"#6D6D6D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\BritBox.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"BritBox`" -base_color `"#198CA8`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cartoon Network.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cartoon Network`" -base_color `"#6084A0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cartoonito.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cartoonito`" -base_color `"#2D9EB2`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CBC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CBC`" -base_color `"#9D3B3F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cbeebies.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cbeebies`" -base_color `"#AFA619`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CBS.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CBS`" -base_color `"#2926C0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Channel 4.png`" -logo_offset +0 -logo_resize 1000 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Channel 4`" -base_color `"#2B297D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Channel 5.png`" -logo_offset +0 -logo_resize 1000 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Channel 5`" -base_color `"#8C28AD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cinemax.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cinemax`" -base_color `"#B4AB22`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Citytv.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Citytv`" -base_color `"#C23B40`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CNN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CNN`" -base_color `"#AE605C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Comedy Central.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Comedy Central`" -base_color `"#BFB516`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Cooking Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Cooking Channel`" -base_color `"#C29B16`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Criterion Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Criterion Channel`" -base_color `"#810BA7`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Crunchyroll.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Crunchyroll`" -base_color `"#C9761D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\CTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"CTV`" -base_color `"#1FAA3C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Curiosity Stream.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Curiosity Stream`" -base_color `"#BF983F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Dave.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Dave`" -base_color `"#32336C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Discovery Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Discovery Kids`" -base_color `"#1C7A1E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Discovery.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Discovery`" -base_color `"#1E1CBD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Disney Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney Channel`" -base_color `"#3679C4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Disney Junior.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney Junior`" -base_color `"#C33B40`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Disney XD.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney XD`" -base_color `"#6BAB6D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Disney+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Disney+`" -base_color `"#0F2FA4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\E!.png`" -logo_offset +0 -logo_resize 500 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"E!`" -base_color `"#BF3137`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Epix.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Epix`" -base_color `"#8E782B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ESPN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ESPN`" -base_color `"#B82B30`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Family Channel.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Family Channel`" -base_color `"#3841B6`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Food Network.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Food Network`" -base_color `"#B97A7C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Fox Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Fox Kids`" -base_color `"#B7282D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\FOX.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"FOX`" -base_color `"#474EAB`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Freeform.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Freeform`" -base_color `"#3C9C3E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Freevee.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Freevee`" -base_color `"#B5CF1B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Fuji TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Fuji TV`" -base_color `"#29319C`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\FX.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"FX`" -base_color `"#4A51A9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\FXX.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"FXX`" -base_color `"#5070A7`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Global TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Global TV`" -base_color `"#409E42`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Hallmark.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hallmark`" -base_color `"#601CB4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\HBO Max.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"HBO Max`" -base_color `"#7870B9`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\HBO.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"HBO`" -base_color `"#458EAD`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\HGTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"HGTV`" -base_color `"#3CA38F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\History.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"History`" -base_color `"#A57E2E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Hulu.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Hulu`" -base_color `"#1BC073`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\IFC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"IFC`" -base_color `"#296FB4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\IMDb TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"IMDb TV`" -base_color `"#C1CD2F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Investigation Discovery.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Investigation Discovery`" -base_color `"#BD5054`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ITV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ITV`" -base_color `"#B024B5`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Kids WB.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Kids WB`" -base_color `"#B52429`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Lifetime.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Lifetime`" -base_color `"#B61F64`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\MasterClass.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"MasterClass`" -base_color `"#4D4D4D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\MTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"MTV`" -base_color `"#76A3AF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\National Geographic.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"National Geographic`" -base_color `"#C6B31B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\NBC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"NBC`" -base_color `"#703AAC`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Netflix.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Netflix`" -base_color `"#B42A33`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nick Jr.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nick Jr`" -base_color `"#4290A4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nick.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nick`" -base_color `"#B68021`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nickelodeon.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nickelodeon`" -base_color `"#C56A16`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Nicktoons.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Nicktoons`" -base_color `"#C56B17`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Oxygen.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Oxygen`" -base_color `"#CBB23E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Paramount+.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Paramount+`" -base_color `"#2A67CC`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\PBS Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"PBS Kids`" -base_color `"#47A149`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\PBS.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"PBS`" -base_color `"#3A4894`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Peacock.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Peacock`" -base_color `"#DA4428`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Prime Video.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Prime Video`" -base_color `"#11607E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Showcase.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Showcase`" -base_color `"#4D4D4D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Showtime.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Showtime`" -base_color `"#C2201F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Shudder.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Shudder`" -base_color `"#0D0C89`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Sky.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sky`" -base_color `"#BC3272`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Smithsonian.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Smithsonian`" -base_color `"#303F8F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Spike TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Spike TV`" -base_color `"#ADAE74`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Stan.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Stan`" -base_color `"#227CC0`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Starz.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Starz`" -base_color `"#464646`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Sundance TV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Sundance TV`" -base_color `"#424242`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Syfy.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Syfy`" -base_color `"#BEB42D`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TBS.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TBS`" -base_color `"#A139BF`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\The CW.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"The CW`" -base_color `"#397F96`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TLC.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TLC`" -base_color `"#BA6C70`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TNT.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TNT`" -base_color `"#C1B83A`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TOKYO MX.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TOKYO MX`" -base_color `"#8662EA`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\truTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"truTV`" -base_color `"#C79F26`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Turner Classic Movies.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Turner Classic Movies`" -base_color `"#616161`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\TV Land.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"TV Land`" -base_color `"#78AFB4`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\UKTV.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"UKTV`" -base_color `"#2EADB1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Universal Kids.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Universal Kids`" -base_color `"#2985A1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\UPN.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"UPN`" -base_color `"#C6864E`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\USA.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"USA`" -base_color `"#C0565B`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\VH1.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"VH1`" -base_color `"#8E3BB1`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Vice.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Vice`" -base_color `"#D3D3D3`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\Warner Bros..png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"Warner Bros.`" -base_color `"#39538F`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\YouTube.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"YouTube`" -base_color `"#C51414`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
    # $arr += ".\create_poster.ps1 -logo `"$script_path\logos_network\ZDF.png`" -logo_offset +0 -logo_resize 1600 -text `"`" -text_offset +0 -font `"ComfortAa-Medium`" -font_size 250 -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"ZDF`" -base_color `"#C58654`" -gradient 1 -clean 1 -avg_color 0 -white_wash 1"
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
    $theFont = "Bebas-Regular"
    $theMaxWidth = 1600
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 140

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'Arrowverse.png| TIMELINE ORDER| Arrowverse (Timeline Order)| #2B8F40| 1',
        'DragonBall.png| TIMELINE ORDER| Dragon Ball (Timeline Order)| #E39D30| 1',
        'Marvel Cinematic Universe.png| TIMELINE ORDER| Marvel Cinematic Universe (Timeline Order)| #AD2B2B| 1',
        'Star Trek.png| TIMELINE ORDER| Star Trek (Timeline Order)| #0193DD| 1',
        'Pokémon.png| TIMELINE ORDER| Pokémon (Timeline Order)| #FECA06| 1',
        'dca.png| TIMELINE ORDER| DC Animated Universe (Timeline Order)| #2832C4| 1',
        'X-men.png| TIMELINE ORDER| X-Men (Timeline Order)| #636363| 1',
        'Star Wars The Clone Wars.png| TIMELINE ORDER| Star Wars The Clone Wars (Timeline Order)| #ED1C24| 1',
        'Star Wars.png| TIMELINE ORDER| Star Wars (Timeline Order)| #F8C60A| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_playlist\$($item.Logo)`" -logo_offset -200 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +450 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
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
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250
    
    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| resolutions_other_name| other| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr

    # $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "resolution_name" -CaseSensitivity Upper) 

    $arr = @()
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
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr

    $arr = @()
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
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        '420.png| 4/20| 420| #43C32F| 1',
        'christmas.png| CHRISTMAS| christmas| #D52414| 1',
        'easter.png| EASTER| easter| #46D69D| 1',
        'father.png| FATHER''S DAY| father| #7CDA83| 1',
        'halloween.png| HALLOWEEN| halloween| #DA8B25| 1',
        'independence.png| INDEPENDENCE DAY| independence| #2931CB| 1',
        'labor.png| LABOR DAY| labor| #DA5C5E| 1',
        'memorial.png| MEMORIAL DAY| memorial| #917C5C| 1',
        'mother.png| MOTHER''S DAY| mother| #DB81D6| 1',
        'patrick.png| ST. PATRICK''S DAY| patrick| #26A53E| 1',
        'thanksgiving.png| THANKSGIVING| thanksgiving| #A1841E| 1',
        'valentine.png| VALENTINE''S DAY| valentine| #D12AAE| 1',
        'years.png| NEW YEAR| years| #444444| 1'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\logos_seasonal\$($item.Logo)`" -logo_offset -500 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +850 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
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
    $colors = @('blue', 'gray', 'red', 'purple', 'green', 'orig', 'stb')
    foreach ($color in $colors) {
        Find-Path "$script_path\output\$color"
    }

    .\create_poster.ps1 -logo "$script_path\logos_chart\Plex.png" -logo_offset -500 -logo_resize 1500 -text "COLLECTIONLESS" -text_offset +850 -font "ComfortAa-Medium" -font_size 195 -font_color "#FFFFFF" -border 0 -border_width 15 -border_color "#FFFFFF" -avg_color_image "" -out_name "collectionless" -base_color "#DC9924" -gradient 1 -avg_color 0 -clean 1 -white_wash 1
    Move-Item -Path $script_path\output\collectionless.jpg -Destination $script_path\collectionless.jpg

    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1900
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 203

    $myArray = @(
        'Name| out_name| base_color| other_setting',
        'collectionless_name| collectionless| #FFFFFF| NA',
        'ACTOR| actor| #FFFFFF| NA',
        'AUDIO LANGUAGE| audio_language| #FFFFFF| NA',
        'AWARD| award| #FFFFFF| NA',
        'CHART| chart| #FFFFFF| NA',
        'CONTENT RATINGS| content_rating| #FFFFFF| NA',
        'COUNTRY| country| #FFFFFF| NA',
        'DECADE| decade| #FFFFFF| NA',
        'DIRECTOR| director| #FFFFFF| NA',
        'FRANCHISE| franchise| #FFFFFF| NA',
        'GENRE| genre| #FFFFFF| NA',
        'KIDS NETWORK| network_kids| #FFFFFF| NA',
        'MOVIE CHART| movie_chart| #FFFFFF| NA',
        'NETWORK| network| #FFFFFF| NA',
        'PERSONAL| personal| #FFFFFF| NA',
        'PRODUCER| producer| #FFFFFF| NA',
        'RESOLUTION| resolution| #FFFFFF| NA',
        'SEASONAL| seasonal| #FFFFFF| NA',
        'STREAMING| streaming| #FFFFFF| NA',
        'STUDIO ANIMATION| studio_animation| #FFFFFF| NA',
        'STUDIO| studio| #FFFFFF| NA',
        'SUBTITLE| subtitle_language| #FFFFFF| NA',
        'TV CHART| tv_chart| #FFFFFF| NA',
        'UK NETWORK| network_uk| #FFFFFF| NA',
        'UK STREAMING| streaming_uk| #FFFFFF| NA',
        'UNIVERSE| universe| #FFFFFF| NA',
        'US NETWORK| network_us| #FFFFFF| NA',
        'US STREAMING| streaming_us| #FFFFFF| NA',
        'WRITER| writer| #FFFFFF| NA',
        'YEAR| year| #FFFFFF| NA',
        'BASED ON...| based| #FFFFFF| NA'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "separator_name" -CaseSensitivity Upper) 
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        foreach ($color in $colors) {
            $arr += ".\create_poster.ps1 -logo `"$script_path\@base\$color.png`" -logo_offset +0 -logo_resize 2000 -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"\$color\$($item.out_name)`" -base_color `"#FFFFFF`" -gradient 0 -avg_color 0 -clean 1 -white_wash 0"
        }
    }
    LaunchScripts -ScriptPaths $arr
    Move-Item -Path output -Destination separators
    Move-Item -Path output-orig -Destination output
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
    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250
    $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "studio_name" -CaseSensitivity Upper) 

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| studio_animation_other_name| other_animation| #FF2000| 1',
        'transparent.png| studio_other_name| other| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr

    $arr = @()
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
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 250

    Move-Item -Path output -Destination output-orig

    $myArray = @(
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| subtitle_language_other_name| other| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash $($item.ww)"
    }
    LaunchScripts -ScriptPaths $arr

    $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "subtitle_language_name" -CaseSensitivity Upper) 

    $myArray = @(
        'Name| out_name| base_color| other_setting',
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
        $myvar = Set-TextBetweenDelimiters -InputString $myvar1 -ReplacementString (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
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
        'Logo| Name| out_name| base_color| ww',
        'transparent.png| year_other_name| other| #FF2000| 1'
    ) | ConvertFrom-Csv -Delimiter '|'

    $arr = @()
    foreach ($item in $myArray) {
        $myvar = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue $($item.Name) -CaseSensitivity Upper)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\$($item.Logo)`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }
    LaunchScripts -ScriptPaths $arr


    # $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1900
    $theMaxHeight = 550
    $minPointSize = 250
    $maxPointSize = 1000

    $myArray = @(
        'Name| out_name| base_color| font_name| font_size',
        '1880| 1880| #EF10D3| Rye-Regular| 453',
        '1881| 1881| #EF102A| Rye-Regular| 453',
        '1882| 1882| #EF6210| Rye-Regular| 453',
        '1883| 1883| #EFC910| Rye-Regular| 453',
        '1884| 1884| #10EFA3| Rye-Regular| 453',
        '1885| 1885| #108FEF| Rye-Regular| 453',
        '1886| 1886| #A900EF| Rye-Regular| 453',
        '1887| 1887| #8D848E| Rye-Regular| 453',
        '1888| 1888| #992C2E| Rye-Regular| 453',
        '1889| 1889| #131CA1| Rye-Regular| 453',
        '1890| 1890| #EF10D3| Limelight-Regular| 453',
        '1891| 1891| #EF102A| Limelight-Regular| 453',
        '1892| 1892| #EF6210| Limelight-Regular| 453',
        '1893| 1893| #EFC910| Limelight-Regular| 453',
        '1894| 1894| #10EFA3| Limelight-Regular| 453',
        '1895| 1895| #108FEF| Limelight-Regular| 453',
        '1896| 1896| #A900EF| Limelight-Regular| 453',
        '1897| 1897| #8D848E| Limelight-Regular| 453',
        '1898| 1898| #992C2E| Limelight-Regular| 453',
        '1899| 1899| #131CA1| Limelight-Regular| 453',
        '1900| 1900| #EF10D3| BoecklinsUniverse| 453',
        '1901| 1901| #EF102A| BoecklinsUniverse| 453',
        '1902| 1902| #EF6210| BoecklinsUniverse| 453',
        '1903| 1903| #EFC910| BoecklinsUniverse| 453',
        '1904| 1904| #10EFA3| BoecklinsUniverse| 453',
        '1905| 1905| #108FEF| BoecklinsUniverse| 453',
        '1906| 1906| #A900EF| BoecklinsUniverse| 453',
        '1907| 1907| #8D848E| BoecklinsUniverse| 453',
        '1908| 1908| #992C2E| BoecklinsUniverse| 453',
        '1909| 1909| #131CA1| BoecklinsUniverse| 453',
        '1910| 1910| #EF10D3| UnifrakturCook| 700',
        '1911| 1911| #EF102A| UnifrakturCook| 700',
        '1912| 1912| #EF6210| UnifrakturCook| 700',
        '1913| 1913| #EFC910| UnifrakturCook| 700',
        '1914| 1914| #10EFA3| UnifrakturCook| 700',
        '1915| 1915| #108FEF| UnifrakturCook| 700',
        '1916| 1916| #A900EF| UnifrakturCook| 700',
        '1917| 1917| #8D848E| UnifrakturCook| 700',
        '1918| 1918| #992C2E| UnifrakturCook| 700',
        '1919| 1919| #131CA1| UnifrakturCook| 700',
        '1920| 1920| #EF10D3| Trochut| 500',
        '1921| 1921| #EF102A| Trochut| 500',
        '1922| 1922| #EF6210| Trochut| 500',
        '1923| 1923| #EFC910| Trochut| 500',
        '1924| 1924| #10EFA3| Trochut| 500',
        '1925| 1925| #108FEF| Trochut| 500',
        '1926| 1926| #A900EF| Trochut| 500',
        '1927| 1927| #8D848E| Trochut| 500',
        '1928| 1928| #992C2E| Trochut| 500',
        '1929| 1929| #131CA1| Trochut| 500',
        '1930| 1930| #EF10D3| Righteous| 500',
        '1931| 1931| #EF102A| Righteous| 500',
        '1932| 1932| #EF6210| Righteous| 500',
        '1933| 1933| #EFC910| Righteous| 500',
        '1934| 1934| #10EFA3| Righteous| 500',
        '1935| 1935| #108FEF| Righteous| 500',
        '1936| 1936| #A900EF| Righteous| 500',
        '1937| 1937| #8D848E| Righteous| 500',
        '1938| 1938| #992C2E| Righteous| 500',
        '1939| 1939| #131CA1| Righteous| 500',
        '1940| 1940| #EF10D3| Yesteryear| 700',
        '1941| 1941| #EF102A| Yesteryear| 700',
        '1942| 1942| #EF6210| Yesteryear| 700',
        '1943| 1943| #EFC910| Yesteryear| 700',
        '1944| 1944| #10EFA3| Yesteryear| 700',
        '1945| 1945| #108FEF| Yesteryear| 700',
        '1946| 1946| #A900EF| Yesteryear| 700',
        '1947| 1947| #8D848E| Yesteryear| 700',
        '1948| 1948| #992C2E| Yesteryear| 700',
        '1949| 1949| #131CA1| Yesteryear| 700',
        '1950| 1950| #EF10D3| Cherry-Cream-Soda-Regular| 500',
        '1951| 1951| #EF102A| Cherry-Cream-Soda-Regular| 500',
        '1952| 1952| #EF6210| Cherry-Cream-Soda-Regular| 500',
        '1953| 1953| #EFC910| Cherry-Cream-Soda-Regular| 500',
        '1954| 1954| #10EFA3| Cherry-Cream-Soda-Regular| 500',
        '1955| 1955| #108FEF| Cherry-Cream-Soda-Regular| 500',
        '1956| 1956| #A900EF| Cherry-Cream-Soda-Regular| 500',
        '1957| 1957| #8D848E| Cherry-Cream-Soda-Regular| 500',
        '1958| 1958| #992C2E| Cherry-Cream-Soda-Regular| 500',
        '1959| 1959| #131CA1| Cherry-Cream-Soda-Regular| 500',
        '1960| 1960| #EF10D3| Boogaloo-Regular| 500',
        '1961| 1961| #EF102A| Boogaloo-Regular| 500',
        '1962| 1962| #EF6210| Boogaloo-Regular| 500',
        '1963| 1963| #EFC910| Boogaloo-Regular| 500',
        '1964| 1964| #10EFA3| Boogaloo-Regular| 500',
        '1965| 1965| #108FEF| Boogaloo-Regular| 500',
        '1966| 1966| #A900EF| Boogaloo-Regular| 500',
        '1967| 1967| #8D848E| Boogaloo-Regular| 500',
        '1968| 1968| #992C2E| Boogaloo-Regular| 500',
        '1969| 1969| #131CA1| Boogaloo-Regular| 500',
        '1970| 1970| #EF10D3| Monoton| 500',
        '1971| 1971| #EF102A| Monoton| 500',
        '1972| 1972| #EF6210| Monoton| 500',
        '1973| 1973| #EFC910| Monoton| 500',
        '1974| 1974| #10EFA3| Monoton| 500',
        '1975| 1975| #108FEF| Monoton| 500',
        '1976| 1976| #A900EF| Monoton| 500',
        '1977| 1977| #8D848E| Monoton| 500',
        '1978| 1978| #992C2E| Monoton| 500',
        '1979| 1979| #131CA1| Monoton| 500',
        '1980| 1980| #EF10D3| Press-Start-2P| 300',
        '1981| 1981| #EF102A| Press-Start-2P| 300',
        '1982| 1982| #EF6210| Press-Start-2P| 300',
        '1983| 1983| #EFC910| Press-Start-2P| 300',
        '1984| 1984| #10EFA3| Press-Start-2P| 300',
        '1985| 1985| #108FEF| Press-Start-2P| 300',
        '1986| 1986| #A900EF| Press-Start-2P| 300',
        '1987| 1987| #8D848E| Press-Start-2P| 300',
        '1988| 1988| #992C2E| Press-Start-2P| 300',
        '1989| 1989| #131CA1| Press-Start-2P| 300',
        '1990| 1990| #EF10D3| Jura-Bold| 500',
        '1991| 1991| #EF102A| Jura-Bold| 500',
        '1992| 1992| #EF6210| Jura-Bold| 500',
        '1993| 1993| #EFC910| Jura-Bold| 500',
        '1994| 1994| #10EFA3| Jura-Bold| 500',
        '1995| 1995| #108FEF| Jura-Bold| 500',
        '1996| 1996| #A900EF| Jura-Bold| 500',
        '1997| 1997| #8D848E| Jura-Bold| 500',
        '1998| 1998| #992C2E| Jura-Bold| 500',
        '1999| 1999| #131CA1| Jura-Bold| 500',
        '2000| 2000| #EF10D3| Special-Elite-Regular| 500',
        '2001| 2001| #EF102A| Special-Elite-Regular| 500',
        '2002| 2002| #EF6210| Special-Elite-Regular| 500',
        '2003| 2003| #EFC910| Special-Elite-Regular| 500',
        '2004| 2004| #10EFA3| Special-Elite-Regular| 500',
        '2005| 2005| #108FEF| Special-Elite-Regular| 500',
        '2006| 2006| #A900EF| Special-Elite-Regular| 500',
        '2007| 2007| #8D848E| Special-Elite-Regular| 500',
        '2008| 2008| #992C2E| Special-Elite-Regular| 500',
        '2009| 2009| #131CA1| Special-Elite-Regular| 500',
        '2010| 2010| #EF10D3| Barlow-Regular| 500',
        '2011| 2011| #EF102A| Barlow-Regular| 500',
        '2012| 2012| #EF6210| Barlow-Regular| 500',
        '2013| 2013| #EFC910| Barlow-Regular| 500',
        '2014| 2014| #10EFA3| Barlow-Regular| 500',
        '2015| 2015| #108FEF| Barlow-Regular| 500',
        '2016| 2016| #A900EF| Barlow-Regular| 500',
        '2017| 2017| #8D848E| Barlow-Regular| 500',
        '2018| 2018| #992C2E| Barlow-Regular| 500',
        '2019| 2019| #131CA1| Barlow-Regular| 500',
        '2020| 2020| #EF10D3| Helvetica-Bold| 500',
        '2021| 2021| #EF102A| Helvetica-Bold| 500',
        '2022| 2022| #EF6210| Helvetica-Bold| 500',
        '2023| 2023| #EFC910| Helvetica-Bold| 500',
        '2024| 2024| #10EFA3| Helvetica-Bold| 500',
        '2025| 2025| #108FEF| Helvetica-Bold| 500',
        '2026| 2026| #A900EF| Helvetica-Bold| 500',
        '2027| 2027| #8D848E| Helvetica-Bold| 500',
        '2028| 2028| #992C2E| Helvetica-Bold| 500',
        '2029| 2029| #131CA1| Helvetica-Bold| 500'
    ) | ConvertFrom-Csv -Delimiter '|'
    
    $arr = @()
    foreach ($item in $myArray) {
        $myvar = $($item.Name)
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $($item.font_name) -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $($item.font_size)
        $arr += ".\create_poster.ps1 -logo `"$script_path\transparent.png`" -logo_offset +0 -logo_resize $theMaxWidth -text `"$myvar`" -text_offset +0 -font `"$($item.font_name)`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$($item.out_name)`" -base_color `"$($item.base_color)`" -gradient 1 -avg_color 0 -clean 1 -white_wash 1"
    }

    LaunchScripts -ScriptPaths $arr
    WriteToLogFile "MonitorProcess               : Waiting for all processes to end before continuing..."
    Start-Sleep -Seconds 3
    MonitorProcess -ProcessName "magick.exe"
    
    Move-Item -Path output -Destination year

    $myvar1 = (Get-TranslatedValue -TranslationFilePath $TranslationFilePath -EnglishValue "BEST OF" -CaseSensitivity Upper) 

    $theFont = "ComfortAa-Medium"
    $theMaxWidth = 1800
    $theMaxHeight = 1000
    $minPointSize = 100
    $maxPointSize = 200

    $arr = @()
    for ($i = 1880; $i -lt 2030; $i++) {
        $myvar = $myvar1
        $optimalFontSize = Get-OptimalPointSize -text $myvar -font $theFont -box_width $theMaxWidth -box_height $theMaxHeight -min_pointsize $minPointSize -max_pointsize $maxPointSize
        $arr += ".\create_poster.ps1 -logo `"$script_path\year\$i.jpg`" -logo_offset +0 -logo_resize 2000 -text `"$myvar`" -text_offset -400 -font `"$theFont`" -font_size $optimalFontSize -font_color `"#FFFFFF`" -border 0 -border_width 15 -border_color `"#FFFFFF`" -avg_color_image `"`" -out_name `"$i`" -base_color `"#FFFFFF`" -gradient 1 -avg_color 0 -clean 1 -white_wash 0"
    }
    LaunchScripts -ScriptPaths $arr
    Start-Sleep -Seconds 3
    MonitorProcess -ProcessName "magick.exe"
    Move-Item -Path output -Destination "$script_path\year\best"
    Move-Item -Path output-orig -Destination output

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

    $sep1 = "blue.png"
    $sep2 = "gray.png"
    $sep3 = "green.png"
    $sep4 = "orig.png"
    $sep5 = "purple.png"
    $sep6 = "red.png"
    $sep7 = "stb.png"

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
    
    $expectedChecksum_sep1 = "AB8DBC5FCE661BDFC643F9697EEC1463CD2CDE90E4594B232A6B92C272DE0561"
    $expectedChecksum_sep2 = "9570B1E86BEC71CAED6DDFD6D2F18023A7C5D408B6A6D5B50C045672D4310772"
    $expectedChecksum_sep3 = "89951DFC6338ABC64444635F6F2835472418BF779A1EB5C342078AF0B8365F80"
    $expectedChecksum_sep4 = "98E161CD70C3300D30340257D674FCC18B11FDADEE3FFF9B80D09C4AB09C1483"
    $expectedChecksum_sep5 = "3768CA736B6BD1CAD0CD02827A6BA7BDBCA2077B1A109802C57144C31B379477"
    $expectedChecksum_sep6 = "03E9026430C8F0ABD031B608225BF40CB87FD1983899C113E410A511CC5622A7"
    $expectedChecksum_sep7 = "A01695FAB8646079331811F381A38A529E76AFC31538285E7EE60600CA07ADC1"

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
    Write-Host "AudioLanguage, Awards, Based, Charts, ContentRating, Country, Decades, Franchise, Genres, Network, Playlist, Resolution, Streaming, Studio, Seasonal, Separators, SubtitleLanguages, Universe, Years, All"
    exit
}

#################################
# MAIN
#################################
Set-Location $script_path
$font_flag = $null
if (!(Test-Path "$scriptLogPath" -ErrorAction SilentlyContinue)) {
    New-Item "$scriptLogPath" -ItemType Directory | Out-Null
}
Update-LogFile -LogPath $scriptLog

WriteToLogFile "#### START ####"
WriteToLogFile "Script Path                  : $script_path"

$Stopwatch = [System.Diagnostics.Stopwatch]::new()
$Stopwatch.Start()
New-SQLCache

Get-CheckSum-Files -script_path $script_path

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

#################################
# Imagemagick version check
#################################
Test-ImageMagick
$test = $global:magick
if ($null -eq $test) {
    WriteToLogFile "Imagemagick                  : Imagemagick is NOT installed. Aborting.... Imagemagick must be installed - https://imagemagick.org/script/download.php"
    exit
}
else {
    WriteToLogFile "Imagemagick                  : Imagemagick is installed. $global:magick"
}

#################################
# Powershell version check
#################################
$tmp = $null
$tmp = $PSVersionTable.PSVersion.ToString()
WriteToLogFile "Powershell Version           : $tmp"

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "Error: This script requires PowerShell version 7 or higher."
    return
}

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

# Call the InstallFontsIfNeeded function
if (-not (InstallFontsIfNeeded)) {
    # If the function returns $false, exit the script
    exit 1
}

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
    # ShowFunctions
    CreateNetwork
    # CreateYear
    # CreateBased
    # CreateAudioLanguage
}

#######################
# Set current directory
#######################
Set-Location $script_path

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
