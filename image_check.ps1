####################################################
# image_check.ps1
# v1.2
# author: bullmoose20
#
# DESCRIPTION: 
# In a powershell window this will go through all your images in the images folder mentioned to scan and report anomalies
# It will create an output log that you can review and fix issues by uploading to https://www.themoviedb.org/ and ensuring that its a primary so that when it gets downloaded, the proper image can be processed by other scripts
#
# REQUIREMENTS:
# $images_location=is the path to the directory with the transparent images to verify
# Imagemagick must be installed - https://imagemagick.org/script/download.php
# Powershell security settings: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2
#
# PARAMETERS:
# -images_location          (specify the images folder location with transparent images for script to scan and report on)
# 
# EXAMPLE:
# .\image_check.ps1 -images_location c:\temp\people\transparent
####################################################

param ($images_location)

#################################
# $metalog_location checks
#################################
if ($images_location -eq "" -or $null -eq $images_location) {
  write-host "Images location >$images_location< not found. Exiting now..." -ForegroundColor Red -BackgroundColor White
  exit
}

if (-not(Test-Path -Path $images_location)) {
  write-host "Images location >$images_location< not found. Exiting now..." -ForegroundColor Red -BackgroundColor White
  exit
}

#################################
# GLOBAL VARS
#################################
$global:Counter1 = 0
$global:Counter2 = 0
$global:Counter3 = 0
$global:Counter4 = 0
$global:Counter5 = 0
$global:Counter6 = 0
$global:Counter7 = 0
$global:magick = $null

#################################
# collect paths
#################################
$tmp_local = $env:TEMP
$script_path = $PSScriptRoot
$scriptName = $MyInvocation.MyCommand.Name
$scriptLog = Join-Path $script_path -ChildPath "$scriptName.log"

$ils = Join-Path $images_location ''

#################################
# WriteToLogFile function
#################################
Function WriteToLogFile ($message) {
  Add-content $scriptLog -value ((Get-Date).ToString() + " ~ " + $message)
  Write-Host ((Get-Date).ToString() + " ~ " + $message)
}

#################################
# check ImageMagick function
#################################
function Test-ImageMagick {
  $global:magick = $global:magick
  $global:magick = magick -version | select-string "Version:"
}

#################################
# Test-Image function
#################################
Function Test-Image {

  $imageW = magick identify -format "%w" $filepre
  $imageH = magick identify -format "%h" $filepre
  $imageRatio = [math]::Round($imageW / $imageH, 4)

  # Find if image is grayscale
  $theString = magick identify -verbose $filepre | Select-String -Pattern Type: -CaseSensitive
  $found = $theString | Select-String -Pattern 'Gray' -CaseSensitive -SimpleMatch
  if ($found) {
    $global:Counter1++
    WriteToLogFile "WARNING                      : WARNING1!~$filepre~$noextension is Grayscale! Find a color image for $noextension on TMDB and re-process"
  }

  # Find if background is removed and hence has transparency
  $string = magick $filepre -format "%[opaque]" info:
  $found = $string | Select-String -Pattern 'True' -CaseSensitive -SimpleMatch
  if ($found) {
    $global:Counter2++
    WriteToLogFile "WARNING                      : WARNING2!~$filepre~$noextension is NOT Transparent and needs background removed!"
  }

  # Find if first line is transparent to determine if there is a head chop situation
  $string = magick $filepre -crop x1+0+0 +repage -alpha extract -format %[fx:mean] info:
  if ($string -gt .06) {
    $global:Counter3++
    WriteToLogFile "WARNING                      : WARNING3!~$filepre~$noextension is most likely a HEAD CHOP and should be reviewed and changed for a better headshot!~Headchop values~$string"
  }
  
  if ($baseImageRatio -eq $imageRatio) {
  }
  else {
    $global:Counter4++
    WriteToLogFile "WARNING                      : WARNING4!~$filepre~$noextension Ratio should be $baseImageRatio, however this image is >$imageRatio<"
  }

  if ($imageW - $baseImageW -gt 0) {
  }
  else {
    $global:Counter5++
    WriteToLogFile "WARNING                      : WARNING5!~$filepre~$noextension Quality of source could be a problem. Image width should be > $baseImageW, however this image is >$imageW< wide"
  }

  if ($imageH - $baseImageH -gt 0) {
  }
  else {
    $global:Counter6++
    WriteToLogFile "WARNING                      : WARNING6!~$filepre~$noextension Quality of source could be a problem. Image height should be > $baseImageH, however this image is >$imageH< high"
  }

  if ($imageW -eq 2000 -and $imageH -eq 3000) {
  }
  else {
    $global:Counter7++
    WriteToLogFile "WARNING                      : WARNING7!~$filepre~$noextension File dimensions should be 2000 x 3000, however this image is >$imageW x $imageH<"
  }

}


#################### MAIN ###########################

if (Test-Path $scriptLog) {
  Remove-Item $scriptLog
}

WriteToLogFile "#### START ####"

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

# Image-Check variables
$baseImageRatio = [math]::Round(1 / 1.5, 4)
$baseImageW = 399
$baseImageH = 599

WriteToLogFile "#######################"
WriteToLogFile "# SETTINGS"
WriteToLogFile "#######################"
WriteToLogFile "scriptName                   : $scriptName"
WriteToLogFile "images _location             : $images_location"
WriteToLogFile "tmp_local                    : $tmp_local"
WriteToLogFile "script_path                  : $script_path"
WriteToLogFile "scriptLog                    : $scriptLog"

$filespre = @(Get-ChildItem $ils*.* -Attributes !Directory)
$Counter = 1

$files_to_process = $files_to_process + $filespre.Count
foreach ($filepre in $filespre) {
  $percentComplete = $(($Counter / $filespre.Count) * 100 )
  $Progress = @{
    Activity        = "Working on: '$($filepre)'."
    Status          = "Processing $Counter of $($filespre.Count)"
    PercentComplete = $([math]::Round($percentComplete, 2))
  }
  Write-Progress @Progress -Id 1
  # Increment the counter. 
  $Counter++

  $noextension = [System.IO.Path]::GetFileNameWithoutExtension($filepre.FullName)
  WriteToLogFile "Separator                    : ###################################################"
  WriteToLogFile "Working on                   : $filepre"
  WriteToLogFile "Name                         : $noextension"
  # Validate quality of image
  WriteToLogFile "Image-Check                  : $noextension"
  Image-Check
    
}


#######################
# SUMMARY
#######################
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

$string = "WARNING1 Grayscale Total     : $global:Counter1"
WriteToLogFile $string

$string = "WARNING2 Transparent Total   : $global:Counter2"
WriteToLogFile $string

$string = "WARNING3 Head Chop Total     : $global:Counter3"
WriteToLogFile $string

$string = "WARNING4 Image Ratio Total   : $global:Counter4"
WriteToLogFile $string

$string = "WARNING5 Quality W Total     : $global:Counter5"
WriteToLogFile $string

$string = "WARNING6 Quality H Total     : $global:Counter6"
WriteToLogFile $string

$string = "WARNING7 2000x3000 Total     : $global:Counter7"
WriteToLogFile $string

$tot = $global:Counter1 + $global:Counter2 + $global:Counter3 + $global:Counter4 + $global:Counter5 + $global:Counter6 + $global:Counter7
$tot_chks = $filespre.count * 7
if ($filespre.count -gt 0) {
  $issues_pct = [math]::Round((($tot / $tot_chks) * 100), 2)
}
else {
  $issues_pct = [math]::Round(0, 2)
}
$string = "Total files                  : " + ($filespre.count).ToString()
WriteToLogFile $string 
WriteToLogFile "Total issues                 : $tot"
WriteToLogFile "Total checks                 : $tot_chks"
WriteToLogFile "Percent Issues               : $issues_pct %"

###################################################
# CLEANUP
###################################################
if (Test-Path tmp.txt) {
  Remove-Item -Path tmp.txt -Force | Out-Null
}
if (Test-Path $tls"dds.txt") {
  Remove-Item -Path $tls"dds.txt" -Force | Out-Null
}
if (Test-Path $tls"tpos.txt") {
  Remove-Item -Path $tls"tpos.txt" -Force | Out-Null
}

WriteToLogFile "#### END ####"
