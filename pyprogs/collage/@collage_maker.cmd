REM This will make collage posters of the PMM Images
chcp 65001

D:
cd D:\bullmoose20\pyprogs\collage

REM Step 1: Extract all directories and generate collages
"C:\Program Files\PowerShell\7\pwsh.exe" -Command "$filteredDirectories = Get-ChildItem -Path 'D:\defaults\' -Directory -Recurse | Where-Object { -not ($_ -match '\\\.' -or $_ -match '\\\[\\]*\\\.') }; $filteredDirectories | ForEach-Object { .\venv\Scripts\python.exe .\collage.py $_ }"

REM Step 2: Copy images using robocopy
robocopy D:\defaults\ D:\bullmoose20\Plex-Meta-Manager-Images\ /E /COPY:DAT /DCOPY:T /XO
