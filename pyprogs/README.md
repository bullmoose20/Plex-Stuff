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
   2. collage [collage.py](#collage)
   3. exif_overlay_checker [exif_overlay_checker.py](#exif_overlay_checker)
   4. extract_tracks [extract_tracks.py](#extract_tracks)
   5. fix_added_at [exif_overlay_checker.py](#exif_overlay_checker)
   6. fmg [fake_media_generator.py](#fake_media_generator)
   7. resizer [resizer.py](#resizer)
   8. tcc [title_card_clips.py](#title_card_clips)
   9. update_plex_artist_art [update_plex_artist_art.py](#update_plex_artist_art)

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


open a powershell prompt and navigate to a `pyprogs` folder
`cd pyprogs`

pick your folder for the script you want to run

`cd fmg`
`python -m venv venv`
`.\venv\Scripts\activate.ps1`
`python.exe -m pip install --upgrade pip`
`pip install -r .\requirements.txt`

now you are ready to run it (with the venv activated)
`usage: fake_media_generator [-h] --tmdbid ####

`python .\fake_media_generator.py --tmdbid 54155
`python .\fake_media_generator.py --tmdbid 123123

folder is created within the script subfolder called `movies` or `shows` depending on the tmdbid
