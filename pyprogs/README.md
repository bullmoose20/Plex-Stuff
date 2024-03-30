# Python-Stuff

[Back to HOME](../README.md)

## Random python related stuff for Plex

## Requirements

1. A system that can run Python3
2. Python3 installed on that system

## Setup

1. clone repo This only needs to be done once or when you want to get updates

```bat
git clone https://github.com/bullmoose20/Plex-Stuff.git
```

Some these PYTHON scripts may use a `.env` and requirements.txt per folder.

### `.env` contents example

```bat
PLEX_URL='http://192.168.2.242:32400'  # Plex URL
PLEX_TOKEN='INSERT_PLEX_TOKEN_HERE'    # PLEX TOKEN
PLEX_TIMEOUT=30                        # Default is 60
MAX_LOG_FILES=5                        # Default is 10
LOG_LEVEL=INFO                         # Default is INFO - CRITICAL, ERROR, WARNING, INFO, DEBUG
```

```bat 
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

[Back to top](#Scripts)

The "collage.py" script generates a grid of thumbnails from a folder of images. This script utilizes the PIL (Python Imaging Library) for image processing. Users can specify parameters such as the number of columns, thumbnail size, and whether to display text under the images. The resulting image grid is saved in a folder called "output."

Open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

Pick your folder for the script you want to run

```bat
cd collage
python -m venv venv
.\venv\scripts\activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt

```

Now you are ready to run it (with the venv activated)
```bat
python collage.py /path/to/image/folder
```
```bat
python collage.py /path/to/image/folder --num_columns 4 --thumb_width 150 --thumb_height 150 --show_text --show_image
```

Or how to call it to run from the venv

```bat
.\venv\scripts\python collage.py /path/to/image/folder
```
```bat
.\venv\scripts\python collage.py /path/to/image/folder --num_columns 4 --thumb_width 150 --thumb_height 150 --show_text --show_image
```

Replace "/path/to/image/folder" with the actual path to the folder containing images. Adjust other parameters as needed. The script creates a timestamped log file and outputs the generated image grid both in the specified "output" folder and the original folder.

Note: Ensure you have the necessary dependencies installed, particularly PIL.

`@collage_maker.cmd` is an additional cmd file to assist in running collage.py

```bat
REM This script automates the process of creating collage posters based on an input folder and all its subfolders.
REM It utilizes PowerShell and Python scripts for collage generation, followed by the use of robocopy for image transfer.

REM Set the active code page to UTF-8 for enhanced character support
chcp 65001

REM Navigate to the directory containing the collage.py script
D:
cd D:\Plex-Stuff\pyprogs\collage

REM Step 1: Extract all directories and generate collages. Replace D:\defaults with your desired folder of images
"C:\Program Files\PowerShell\7\pwsh.exe" -Command "$filteredDirectories = Get-ChildItem -Path 'D:\defaults\' -Directory -Recurse | Where-Object { -not ($_ -match '\\\.' -or $_ -match '\\\[\\]*\\\.') }; $filteredDirectories | ForEach-Object { .\venv\scripts\python .\collage.py $_ }"

REM Step 2: Copy images using robocopy
robocopy D:\defaults\ D:\bullmoose20\Plex-Meta-Manager-Images\ /E /COPY:DAT /DCOPY:T /XO
```

Explanation:

1. **`REM This script automates...`**: Describes the purpose of the script.

2. **`REM Set the active code page...`**: Changes the code page to UTF-8 for better handling of Unicode characters in the command prompt.

3. **`D:` and `cd D:\Plex-Stuff\pyprogs\collage`**: Navigates to the directory where the `collage.py` script is located.

4. **Step 1 (PowerShell command)**:
   - **`"C:\Program Files\PowerShell\7\pwsh.exe" -Command ...`**: Invokes PowerShell 7 to execute the specified command.
   - **`$filteredDirectories = ...`**: Retrieves all directories under 'D:\defaults\' recursively, excluding hidden and system directories.
   - **`ForEach-Object { .\venv\scripts\python .\collage.py $_ }`**: For each filtered directory, runs the `collage.py` script using the Python interpreter within the virtual environment.

5. **Step 2 (robocopy command)**:
   - **`robocopy D:\defaults\ D:\bullmoose20\Plex-Meta-Manager-Images\ /E /COPY:DAT /DCOPY:T /XO`**: Uses robocopy to copy images from 'D:\defaults\' to 'D:\bullmoose20\Plex-Meta-Manager-Images\'.
      - `/E`: Copies subdirectories, including empty ones.
      - `/COPY:DAT`: Copies file data, attributes, and timestamps.
      - `/DCOPY:T`: Copies directory timestamps.
      - `/XO`: Excludes older files, only copying newer or non-existing files.

This script streamlines the generation of collage posters for images in the specified directory and its subfolders, providing a convenient and automated solution.

[Back to top](#Scripts)

## exif_overlay_checker

[Back to top](#Scripts)

The "exif_overlay_checker" script is a Python tool that scans images within a specified folder, examining their EXIF metadata. Specifically designed to identify the presence of keywords like 'overlay' or 'titlecard' in the EXIF data, the script logs its findings and provides a summary of images with or without such metadata. The tool offers a command-line interface with optional verbose logging for a detailed analysis of the image files.

Open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

Pick your folder for the script you want to run

```bat
cd exif_overlay_checker
python -m venv venv
.\venv\scripts\activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt

```

Now you are ready to run it (with the venv activated)

```bat
python exif_overlay_checker.py --input-folder /path/to/your/images --verbose
```

Or how to call it to run from the venv

```bat
.\venv\scripts\python exif_overlay_checker.py --input-folder /path/to/your/images --verbose
```

This command initiates the script, specifying the path to the folder containing your images using the --input-folder argument. The --verbose flag enables detailed logging for a more comprehensive analysis.   

[Back to top](#Scripts)

## extract_tracks

[Back to top](#Scripts)

The "extract_tracks.py" script is a Python tool designed to interact with a Plex server, providing functionality to analyze and modify track titles within music libraries. Offering options to apply changes directly to Plex or generate a detailed report, users can choose between sentence case and title case for track titles. The script logs information about processed tracks, including warnings for titles requiring adjustments.

Open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

Pick your folder for the script you want to run

```bat
cd extract_tracks
python -m venv venv
.\venv\scripts\activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt

```

Now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```bat
python extract_tracks.py --apply --title-case
```

Or how to call it to run from the venv

```bat
.\venv\scripts\python extract_tracks.py --apply --title-case
```

This command applies changes to the Plex server, updating track titles to title case. Customize the arguments based on your preferences, and adjust the paths accordingly to run the script with your environment and Plex server details.

[Back to top](#Scripts)

## fix_added_at

[Back to top](#Scripts)

The fix_added_at.py script is designed to correct the added_at metadata for media items in a Plex library. It identifies media items whose underlying files have been modified after their original added_at timestamp. The script then prompts the user to confirm the changes before applying them. This ensures that the Plex library accurately reflects the modification time of the media files.

Open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

Pick your folder for the script you want to run

```bat
cd fix_added_at
python -m venv venv
.\venv\scripts\activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt

```

Now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```bat
python fix_added_at.py
```

Or how to call it to run from the venv

```bat
.\venv\scripts\python fix_added_at.py
```

The command updates Plex media items' "added at" timestamps to match the modification times of their associated files on disk, ensuring accurate metadata synchronization. Simply run python fix_added_at.py, follow prompts to select a library and specify the parent directory, and confirm changes to update Plex metadata accordingly.

[Back to top](#Scripts)

## fake_media_generator

[Back to top](#Scripts)

Description for "fake_media_generator.py":

The "fake_media_generator.py" script is a Python utility designed to simulate the creation of folder structures and sample media files for movies and TV shows using the TMDb API. By fetching details for a given TMDb ID, the script organizes these simulated media entries into appropriately named directories, incorporating IMDb IDs for TV shows and movies. The generated files include sample.avi, serving as placeholders for media content.

Open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

Pick your folder for the script you want to run

```bat
cd fmg
python -m venv venv
.\venv\scripts\activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt

```

Now you are ready to run it (with the venv activated)

Example of how to call and run the script: `python fake_media_generator.py --tmdbid <tmdb_id(s)> --media-type <media_type>`

```bat
python fake_media_generator.py --tmdbid 389 19404 429 12477 11216 637 346 550 568332 246 94954 87108 95557 1408 71712 4194 1409 153312 1668 --media-type movie
```

Or how to call it to run from the venv

```bat
.\venv\scripts\python fake_media_generator.py --tmdbid  389 19404 429 12477 11216 637 346 550 568332 246 94954 87108 95557 1408 71712 4194 1409 153312 1668 --media-type tv
```

Replace <tmdb_id(s)> with the TMDb ID(s) for the movie or TV show (separated by space).Use the --media-type option to specify the type of media to process. Valid values are `movie`, or `tv`. Omitting this option will default to processing both movies and TV shows.Example:python fake_media_generator.py --tmdbid 389 19404 429 --media-type tv
Output:Folders are created within the output subfolder:For movies: output/moviesFor TV shows: output/shows

[Back to top](#Scripts)

## resizer

[Back to top](#Scripts)

Description for "resizer.py":

The "resizer.py" script is a Python tool for resizing images within a specified input folder, and it saves the resized images into a designated output folder. Leveraging the PIL (Python Imaging Library), the script ensures that the aspect ratio of the images is maintained during resizing. The resizing process aims for a target aspect ratio of 1:1.5, avoiding skewing or adding black borders. The resulting images are saved in JPEG format.

Open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

Pick your folder for the script you want to run

```bat
cd resizer
python -m venv venv
.\venv\scripts\activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt

```

Now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```bat
python resizer.py --input-folder path/to/images --output-folder /path/to/output
```
```bat
python resizer.py --input-folder input --output-folder output
```
```bat
python resizer.py --input-folder path/to/images --output-folder path/to/output --min-width 1000 --max-width 2000
```

Or how to call it to run from the venv

```bat
.\venv\scripts\python resizer.py --input-folder path/to/images --output-folder /path/to/output
```
```bat
.\venv\scripts\python resizer.py --input-folder input --output-folder output
```
```bat
.\venv\scripts\python resizer.py --input-folder path/to/images --output-folder path/to/output --min-width 1000 --max-width 2000
```

Replace "/path/to/input/folder" with the path to the folder containing the images you want to resize. The resized images are then stored in the "output" folder within the script's directory. Adjust the input and output folder paths as needed for your use case.

[Back to top](#Scripts)

## title_card_clips

[Back to top](#Scripts)

The "title_card_clips.py" script serves the purpose of extracting title card frames from videos, offering flexibility for both TV shows and movies. Utilizing Python libraries such as PIL (Python Imaging Library) and MoviePy, the script extracts frames from specified video files and creates title card images. It provides logging functionality for tracking frame extraction operations.

Open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

Pick your folder for the script you want to run

```bat
cd tcc
python -m venv venv
.\venv\scripts\activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt

```

Now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```bat
python title_card_clips.py --path /path/to/videos --time 45
```

Or how to call it to run from the venv

```bat
.\venv\scripts\python title_card_clips.py --path /path/to/videos --time 45
```

Replace "/path/to/videos" with the root directory containing the video files you want to process. The optional "--time" argument allows you to set the frame extraction time in seconds (default: 45). The script logs essential information, including the input path and frame extraction time. After execution, the title card frames are generated and saved in the "output" directory within the script's location. Adjust the input path and optional parameters as needed for your use case.

[Back to top](#Scripts)

## update_plex_artist_art

[Back to top](#Scripts)

The "update_plex_artist_art.py" script automates the process of updating artist thumbnails in a Plex media server. It connects to the Plex server specified in the environment variables, identifies artists with missing thumbnails, and attempts to update them based on the latest album's art. The script supports both reporting changes and applying them to Plex.

Open a powershell prompt and navigate to `pyprogs` folder

`cd pyprogs`

Pick your folder for the script you want to run

```bat
cd update_plex_artist_art
python -m venv venv
.\venv\scripts\activate.ps1
python -m pip install --upgrade pip
pip install -r .\requirements.txt

```

Now you are ready to run it (with the venv activated)

Example of how to call and run the script:

```bat
python update_plex_artist_art.py --apply
```

Or how to call it to run from the venv

```bat
.\venv\scripts\update_plex_artist_art.py --apply
```

Replace "--apply" with "--report" to generate a report without making changes. The script logs essential information, creates a timestamped log file, and allows configuration through environment variables such as PLEX_URL, PLEX_TOKEN, PLEX_TIMEOUT, and MAX_LOG_FILES. After execution, the script provides a summary of processed artists, artists with missing art, and the duration of the script. Ensure your environment variables are correctly set before running the script.

[Back to top](#Scripts)
