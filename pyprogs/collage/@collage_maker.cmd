REM This script automates the process of creating collage posters based on an input folder and all its subfolders.
REM It utilizes PowerShell and Python scripts for collage generation, followed by the use of robocopy for image transfer.

REM Set the active code page to UTF-8 for enhanced character support
chcp 65001

REM Navigate to the directory containing the collage.py script
D:
cd D:\Plex-Stuff\pyprogs\collage

REM Step 1: Extract all directories and generate collages. Replace D:\defaults with your desired folder of images
"C:\Program Files\PowerShell\7\pwsh.exe" -Command "$filteredDirectories = Get-ChildItem -Path 'D:\defaults\' -Directory -Recurse | Where-Object { -not ($_ -match '\\\.' -or $_ -match '\\\[\\]*\\\.') }; $filteredDirectories | ForEach-Object { .\venv\Scripts\python.exe .\collage.py $_ }"

REM Step 2: Copy images using robocopy
robocopy D:\defaults\ D:\bullmoose20\Plex-Meta-Manager-Images\ /E /COPY:DAT /DCOPY:T /XO
