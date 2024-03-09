# Python-Stuff
## Random python related stuff

## Requirements

1. A system that can run Python3
2. Python3 installed on that system

## Setup

1. clone repo

All these PYTHON scripts may use a `.env` and requirements.txt per folder.

### `.env` contents example

```
PLEX_URL=https://plex.domain.tld                # URL for Plex; can be a domain or IP:PORT
PLEX_TOKEN=PLEX-TOKEN                           # https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
```

```commandline 
D:\PLEX-STUFF\PYPROGS
├───collage
│   └───output
├───exif_overlay_checker
├───extract_tracks
├───fix_added_at
├───fmg
├───resizer
│   ├───input
│   └───output
├───tcc
└───update_plex_artist_art
```


## Scripts:
1. pyprogs\\<<folder_name>>
   1. collage [collage.py](#collage)
   2. exif_overlay_checker [exif_overlay_checker.py](#exif_overlay_checker)
   3. extract_tracks [extract_tracks.py](#extract_tracks)
   4. fix_added_at [fix_added_at.py](#fix_added_at)
   5. fmg [fake_media_generator.py](#fake_media_generator)
   6. resizer [resizer.py](#resizer)
   7. tcc [title_card_clips.py](#title_card_clips)
   8. update_plex_artist_art [update_plex_artist_art.py](#update_plex_artist_art)

## collage

The "collage.py" script generates a grid of thumbnails from a folder of images. This script utilizes the PIL (Python Imaging Library) for image processing. Users can specify parameters such as the number of columns, thumbnail size, and whether to display text under the images. The resulting image grid is saved in a folder called "output."

Example of how to call and run the script:

```
python collage.py /path/to/image/folder --num_columns 4 --thumb_width 150 --thumb_height 150 --show_text --show_image
```

Replace "/path/to/image/folder" with the actual path to the folder containing images. Adjust other parameters as needed. The script creates a timestamped log file and outputs the generated image grid both in the specified "output" folder and the original folder.

Note: Ensure you have the necessary dependencies installed, particularly PIL.

`@collage_maker.cmd` is an additional cmd file to assist in running collage.py

```batch
REM This script automates the process of creating collage posters based on an input folder and all its subfolders.
REM It utilizes PowerShell and Python scripts for collage generation, followed by the use of robocopy for image transfer.

REM Set the active code page to UTF-8 for enhanced character support
chcp 65001

REM Navigate to the directory containing the collage.py script
D:
cd D:\bullmoose20\pyprogs\collage

REM Step 1: Extract all directories and generate collages
"C:\Program Files\PowerShell\7\pwsh.exe" -Command "$filteredDirectories = Get-ChildItem -Path 'D:\defaults\' -Directory -Recurse | Where-Object { -not ($_ -match '\\\.' -or $_ -match '\\\[\\]*\\\.') }; $filteredDirectories | ForEach-Object { .\venv\Scripts\python.exe .\collage.py $_ }"

REM Step 2: Copy images using robocopy
robocopy D:\defaults\ D:\bullmoose20\Plex-Meta-Manager-Images\ /E /COPY:DAT /DCOPY:T /XO

```

Explanation:

1. **`REM This script automates...`**: Describes the purpose of the script.

2. **`REM Set the active code page...`**: Changes the code page to UTF-8 for better handling of Unicode characters in the command prompt.

3. **`D:` and `cd D:\bullmoose20\pyprogs\collage`**: Navigates to the directory where the `collage.py` script is located.

4. **Step 1 (PowerShell command)**:
   - **`"C:\Program Files\PowerShell\7\pwsh.exe" -Command ...`**: Invokes PowerShell 7 to execute the specified command.
   - **`$filteredDirectories = ...`**: Retrieves all directories under 'D:\defaults\' recursively, excluding hidden and system directories.
   - **`ForEach-Object { .\venv\Scripts\python.exe .\collage.py $_ }`**: For each filtered directory, runs the `collage.py` script using the Python interpreter within the virtual environment.

5. **Step 2 (robocopy command)**:
   - **`robocopy D:\defaults\ D:\bullmoose20\Plex-Meta-Manager-Images\ /E /COPY:DAT /DCOPY:T /XO`**: Uses robocopy to copy images from 'D:\defaults\' to 'D:\bullmoose20\Plex-Meta-Manager-Images\'.
      - `/E`: Copies subdirectories, including empty ones.
      - `/COPY:DAT`: Copies file data, attributes, and timestamps.
      - `/DCOPY:T`: Copies directory timestamps.
      - `/XO`: Excludes older files, only copying newer or non-existing files.

This script streamlines the generation of collage posters for images in the specified directory and its subfolders, providing a convenient and automated solution.

[Back to top](#scripts)

## exif_overlay_checker

The "exif_overlay_checker" script is a Python tool that scans images within a specified folder, examining their EXIF metadata. Specifically designed to identify the presence of keywords like 'overlay' or 'titlecard' in the EXIF data, the script logs its findings and provides a summary of images with or without such metadata. The tool offers a command-line interface with optional verbose logging for a detailed analysis of the image files.

open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

pick your folder for the script you want to run

```
cd exif_overlay_checker
python -m venv venv
.\venv\Scripts\activate.ps1`
python.exe -m pip install --upgrade pip
pip install -r .\requirements.txt
```

now you are ready to run it (with the venv activated)

`python exif_overlay_checker.py --input-folder /path/to/your/images --verbose`

This command initiates the script, specifying the path to the folder containing your images using the --input-folder argument. The --verbose flag enables detailed logging for a more comprehensive analysis.   

## extract_tracks

The "extract_tracks.py" script is a Python tool designed to interact with a Plex server, providing functionality to analyze and modify track titles within music libraries. Offering options to apply changes directly to Plex or generate a detailed report, users can choose between sentence case and title case for track titles. The script logs information about processed tracks, including warnings for titles requiring adjustments.

open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

pick your folder for the script you want to run

```
cd extract_tracks
python -m venv venv
.\venv\Scripts\activate.ps1`
python.exe -m pip install --upgrade pip
pip install -r .\requirements.txt
```

now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```
python extract_tracks.py --apply --title-case
```

This command applies changes to the Plex server, updating track titles to title case. Customize the arguments based on your preferences, and adjust the paths accordingly to run the script with your environment and Plex server details.

## fix_added_at

The "fix_added_at.py" script is a Python utility designed for interacting with a Plex server to update the track titles in music libraries. With customizable options, it allows users to switch between sentence case and title case for track titles. Additionally, the script provides the option to apply changes directly to the Plex server or generate a detailed report without making modifications.

open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

pick your folder for the script you want to run

```
cd fix_added_at
python -m venv venv
.\venv\Scripts\activate.ps1`
python.exe -m pip install --upgrade pip
pip install -r .\requirements.txt
```

now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```
python fix_added_at.py --apply --title-case
```

This command applies changes to the Plex server, updating track titles to title case. Modify the arguments as needed based on your preferences.

## fake_media_generator

The "fake_media_generator.py" script is a Python utility designed to simulate the creation of folder structures and sample media files for movies and TV shows using the TMDb API. By fetching details for a given TMDb ID, the script organizes these simulated media entries into appropriately named directories, incorporating IMDb IDs and season information for TV shows. The generated files include sample.avi, serving as placeholders for media content.

open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

pick your folder for the script you want to run

```
cd fmg
python -m venv venv
.\venv\Scripts\activate.ps1`
python.exe -m pip install --upgrade pip
pip install -r .\requirements.txt
```

now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```
python fake_media_generator.py --tmdbid 12345
```

Replace "12345" with the desired TMDb ID for a movie or TV show. The script prompts users to choose between available options if both movie and TV show details are found. Once a choice is made, the script creates a folder structure and sample media files in the specified directories based on the selected media type. Adjust the TMDb ID and paths as needed for your use case.

folder is created within the script subfolder called `movies` or `shows` depending on the tmdbid

## resizer

Description for "resizer.py":

The "resizer.py" script is a Python tool for resizing images within a specified input folder, and it saves the resized images into a designated output folder. Leveraging the PIL (Python Imaging Library), the script ensures that the aspect ratio of the images is maintained during resizing. The resizing process aims for a target aspect ratio of 1:1.5, avoiding skewing or adding black borders. The resulting images are saved in JPEG format.

open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

pick your folder for the script you want to run

```
cd resizer
python -m venv venv
.\venv\Scripts\activate.ps1`
python.exe -m pip install --upgrade pip
pip install -r .\requirements.txt
```

now you are ready to run it (with the venv activated)

Example of how to call and run the script:
```
python resizer.py /path/to/input/folder
```

Replace "/path/to/input/folder" with the path to the folder containing the images you want to resize. If the script is executed without a command-line argument, it prompts the user to enter the input folder location interactively. The resized images are then stored in the "output" folder within the script's directory. Adjust the input and output folder paths as needed for your use case.

## title_card_clips

The "title_card_clips.py" script serves the purpose of extracting title card frames from videos, offering flexibility for both TV shows and movies. Utilizing Python libraries such as PIL (Python Imaging Library) and MoviePy, the script extracts frames from specified video files and creates title card images. It provides logging functionality for tracking frame extraction operations.

open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

pick your folder for the script you want to run

```
cd title_card_clips
python -m venv venv
.\venv\Scripts\activate.ps1`
python.exe -m pip install --upgrade pip
pip install -r .\requirements.txt
```

now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```
python title_card_clips.py --path /path/to/videos --time 45
```

Replace "/path/to/videos" with the root directory containing the video files you want to process. The optional "--time" argument allows you to set the frame extraction time in seconds (default: 45). The script logs essential information, including the input path and frame extraction time. After execution, the title card frames are generated and saved in the "output" directory within the script's location. Adjust the input path and optional parameters as needed for your use case.

## update_plex_artist_art

The "update_plex_artist_art.py" script automates the process of updating artist thumbnails in a Plex media server. It connects to the Plex server specified in the environment variables, identifies artists with missing thumbnails, and attempts to update them based on the latest album's art. The script supports both reporting changes and applying them to Plex.

open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

pick your folder for the script you want to run

```
cd update_plex_artist_art
python -m venv venv
.\venv\Scripts\activate.ps1`
python.exe -m pip install --upgrade pip
pip install -r .\requirements.txt
```

now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```
python update_plex_artist_art.py --apply
```

Replace "--apply" with "--report" to generate a report without making changes. The script logs essential information, creates a timestamped log file, and allows configuration through environment variables such as PLEX_URL, PLEX_TOKEN, PLEX_TIMEOUT, and MAX_LOG_FILES. After execution, the script provides a summary of processed artists, artists with missing art, and the duration of the script. Ensure your environment variables are correctly set before running the script.