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

## Scripts:
1. pyprogs\<<folder_name>>
   1. collage [collage.py](#collage)
   2. exif_overlay_checker [exif_overlay_checker.py](#exif_overlay_checker)
   3. extract_tracks [extract_tracks.py](#extract_tracks)
   4. fix_added_at [fix_added_at.py](#fix_added_at)
   5. fmg [fake_media_generator.py](#fake_media_generator)
   6. resizer [resizer.py](#resizer)
   7. tcc [title_card_clips.py](#title_card_clips)
   8. update_plex_artist_art [update_plex_artist_art.py](#update_plex_artist_art)

## collage

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

open a powershell prompt and navigate to a `pyprogs` folder
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

```bash
python fake_media_generator.py --tmdbid 12345
```

Replace "12345" with the desired TMDb ID for a movie or TV show. The script prompts users to choose between available options if both movie and TV show details are found. Once a choice is made, the script creates a folder structure and sample media files in the specified directories based on the selected media type. Adjust the TMDb ID and paths as needed for your use case.

folder is created within the script subfolder called `movies` or `shows` depending on the tmdbid

## resizer

## title_card_clips

open a powershell prompt and navigate to a `pyprogs` folder
`cd pyprogs`

pick your folder for the script you want to run
`cd tcc`
`python -m venv venv`
`.\venv\Scripts\activate.ps1`
`python.exe -m pip install --upgrade pip`
`pip install -r .\requirements.txt`

now you are ready to run it (with the venv activated)
`usage: title_card_clips.py [-h] --path PATH [--time TIME]`

`python .\title_card_clips.py --path "M:\media\tv\Alex Rider [imdb-tt6964748]"` will default to clipping at 45 seconds
`python .\title_card_clips.py --path "M:\media\tv\Alex Rider [imdb-tt6964748]" --time 170` will clip at 170 seconds

folder is created within the script subfolder called `output`

max of 11 logs are rotated in the folder.

## update_plex_artist_art
