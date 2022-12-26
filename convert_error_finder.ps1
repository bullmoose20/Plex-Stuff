$myDir = "C:\users\bullmoose\Downloads\metalogs"
Set-Location $myDir
Get-ChildItem $myDir -I met*.txt, met*.log met*.log.* -R | Select-String "Convert Error: No TVDb ID Found for IMDb ID:", 
"Convert Error: No IMDb ID Found for TVDb ID:", 
"Convert Error: No TMDb ID Found for TVDb ID:", 
"Convert Error: No IMDb ID Found for TMDb ID:",
"Convert Error: AniDB ID not found for MyAnimeList ID:",
"Convert Error: AniDB ID not found for AniList ID:",
"Convert Error: No TVDb ID or IMDb ID found for AniDB ID:",
"Convert Error: No TVDb ID Found for TMDb ID:",
"Convert Error: No TMDb ID Found for IMDb ID:" | Out-File .\big.log

$myBigLog = Join-Path $myDir "big.log"
$myBigLogConvert = Join-Path $myDir "biglog-convert.log"
$myBigLogTmp = Join-Path $myDir "biglog-convert2.log"
$mySearch = "Convert Error: "
Get-Content "$myBigLog" | Select-String $mySearch | Sort-Object -Unique | Out-File -FilePath "$myBigLogConvert" -width 3000
(Get-Content "$myBigLogConvert") | Where-Object { $_.trim() -ne "" } | Out-File -FilePath "$myBigLogConvert"

if (Test-Path "$myBigLogTmp") {
    Remove-Item -Path "$myBigLogTmp" -Force | Out-Null
}

foreach ($line in [System.IO.File]::ReadLines("$myBigLogConvert")) {
    $arr = $line.Split("|")
    # $arr2 = $arr[1].Split(":")
    "|"+$arr[1].trim() | Out-File -FilePath "$myBigLogTmp" -Append
}
(Get-Content "$myBigLogTmp") | Sort-Object -Unique | Out-File -FilePath "$myBigLogTmp"
Remove-Item -Path "$myBigLog"
Remove-Item -Path "$myBigLogConvert"
Move-Item -Path "$myBigLogTmp" -Destination "$myBigLogConvert"
