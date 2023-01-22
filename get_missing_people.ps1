####################################################
# get_missing_people.ps1
# v1.2
# author: bullmoose20
#
# DESCRIPTION: 
# In a powershell window this will go through all your meta*.log files created by PMM to find all missing people posters.
# It will create 1 .cmd file per meta.log file and run it to download the images locally
#
# REQUIREMENTS:
# $metalog_location=is the path to the logs directory for PMM
# Powershell security settings: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2
#
# PARAMETERS:
# -metalog_location          (specify the logs folder location for PMM)
# 
# EXAMPLE:
# .\get_missing_people.ps1 -metalog_location \\NZWHS01\appdata\Plex-Meta-Manager\logs
####################################################

param ($metalog_location)

#################################
# $metalog_location checks
#################################
if ($metalog_location -eq "" -or $null -eq $metalog_location) {
  write-host "Logs location >$metalog_location< not found. Exiting now..." -ForegroundColor Red -BackgroundColor White
  exit
}

if (-not(Test-Path -Path $metalog_location)) {
  WriteToLogFile "Logs location >$metalog_location< not found. Exiting now..."
  exit
}

#################################
# collect paths
#################################
$script_path = $PSScriptRoot
$scriptName = $MyInvocation.MyCommand.Name
$scriptLog = Join-Path $script_path -ChildPath "$scriptName.log"
$download_dir = Join-Path -Path $script_path -ChildPath "Downloads"
$step_del = Join-Path $metalog_location -ChildPath "*"
$outputfile = Join-Path $metalog_location -ChildPath "step1_download_"
$dds = Join-Path $download_dir ''
$mls = Join-Path $metalog_location ''

#################################
# WriteToLogFile function
#################################
Function WriteToLogFile ($message) {
  Add-content $scriptLog -value ((Get-Date).ToString() + " ~ " + $message)
  Write-Host ((Get-Date).ToString() + " ~ " + $message)
}

if (Test-Path $scriptLog) {
  Remove-Item $scriptLog -Force | Out-Null
}

WriteToLogFile "#### START ####"

# Create dirs
New-Item -ItemType Directory -Force -Path $download_dir | Out-Null

# Remove step*.cmd from previous runs
Remove-Item $step_del -Include step*.cmd

# Gather all the meta* files
$inputFile = Get-ChildItem -Path $metalog_location -Name 'meta*' -File
ForEach ($item in $inputfile) {
  WriteToLogFile "Found: $item"
}

# Define search pattern and newvalue
$theString = $null
$theOutput = $null
$find = $null
$item_path = $null
$pattern = $null
$newvalue = $null
$chcp = $null
$files_to_process = $null

$pattern = '\[\d\d\d\d-\d\d-\d\d .*\[.*\] *\| Detail: tmdb_person updated poster to \[URL\] (https.*)(\..*g) *\|\n.*\n.*\n.*Finished (.*) Collection'
$newvalue = "`n`n" + "powershell -command " + [char]34 + "Invoke-WebRequest " + '$1$2' + " -Outfile " + [char]39 + "$dds" + '$3$2' + [char]39 + [char]34 + "`n`n"


###################################################
# 1 - Find files in meta.log and download to download_dir
###################################################
ForEach ($item in $inputfile) {
  $item_path = Join-Path $metalog_location -ChildPath "$item"
  if (Test-Path -Path $item_path -PathType Leaf) {
    $theOutput = $item.replace("$mls", "")
    WriteToLogFile "Working on: $theOutput"
    WriteToLogFile "Working on: $outputfile$theOutput.cmd"
    Set-Content -Path $outputfile$theOutput.cmd -Value (((Get-Content $item_path -Raw) -replace "`r`n?", "`n") -replace $pattern, $newvalue)
    $find = 'Invoke-WebRequest '
    $theString = Get-Content $outputfile$theOutput.cmd | Select-String -Pattern $find -CaseSensitive -SimpleMatch
    if ($theString -eq "" -or $null -eq $theString) {
      Remove-Item $outputfile$theOutput.cmd
      WriteToLogFile "0 items found..."  
    }
    else {
      $theString > tmp.txt
      $theString = Get-Content tmp.txt
      $theString = $theString.replace(' (Director).', '.')
      $theString = $theString.replace(' (Producer).', '.')
      $theString = $theString.replace(' (Writer).', '.')
      $theString = $theString | Sort-Object -Unique
      $chcp = "chcp 65001>nul"
      Set-Content -Path $outputfile$theOutput.cmd -Value $chcp
      Add-Content -Path $outputfile$theOutput.cmd -Value $theString
      $files_to_process = $theString.Count - 1
      WriteToLogFile "$files_to_process items found..."  
      Start-Process -FilePath $outputfile$theOutput.cmd -Wait
    }
  }
}
###################################################
# CLEANUP
###################################################
if (Test-Path tmp.txt) {
  Remove-Item -Path tmp.txt -Force | Out-Null
}

WriteToLogFile "#### END ####"
