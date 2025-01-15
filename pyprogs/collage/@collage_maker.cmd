REM This script automates the process of creating collage posters based on an input folder and all its subfolders.
REM It utilizes PowerShell and Python scripts for collage generation, followed by the use of robocopy for image transfer.

REM Set the active code page to UTF-8 for enhanced character support
chcp 65001

REM Navigate to the directory containing the collage.py script
D:
cd D:\Plex-Stuff\pyprogs\collage

REM Step 1: Extract all directories and log them to a file
REM Replace D:\defaults with your desired folder of images
"C:\Program Files\PowerShell\7\pwsh.exe" -Command "$filteredDirectories = Get-ChildItem -Path 'D:\defaults\' -Directory -Recurse | Where-Object { -not ($_ -match '\\\.' -or $_ -match '\\\[\\]*\\\.') }; $filteredDirectories | ForEach-Object { $_.FullName } | Set-Content D:\directories.log"

REM Step 2: Display the logged directories in the console
type D:\directories.log

REM Step 3: Process each directory in the log
"C:\Program Files\PowerShell\7\pwsh.exe" -Command "$filteredDirectories = Get-ChildItem -Path 'D:\defaults\' -Directory -Recurse | Where-Object { -not ($_ -match '\\\.' -or $_ -match '\\\[\\]*\\\.') }; $filteredDirectories | ForEach-Object { .\venv\Scripts\python.exe .\collage.py --output_format=WEBP --thumb_width=400 --thumb_height=400 --save_original_folder=true $_ }"

REM Step 4: Copy images using robocopy
robocopy D:\defaults\ D:\bullmoose20\Default-Images\ /E /COPY:DAT /DCOPY:T /XO
