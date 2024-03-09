# Python-Stuff
## Random python related stuff

## Requirements

1. A system that can run Python3
2. Python3 installed on that system

## Setup

1. clone repo
2. setup python virtualenv - [I'd suggest doing this in a virtual environment. Great instructions found here - https://www.metamanager.wiki/en/nightly/pmm/install/guides/local/#setting-up-a-virtual-environment]
3. Activate that virtualenv
4. Install requirements with `pip install -r requirements.txt` into that virtualenv
5. cd to the directory that you want to run the script in
6. Copy `.env.example` to `.env` 
7. Edit `.env` to suit
8. drop file into a folder
9. create a venv
10. activate the venv
11. install requirements
12. run title_card_clips

All these PYTHON scripts may use a `.env` and requirements.txt per folder.

### `.env` contents example

```
PLEX_URL=https://plex.domain.tld                # URL for Plex; can be a domain or IP:PORT
PLEX_TOKEN=PLEX-TOKEN                           # https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
```

## Plex scripts:

## Scripts:
1. pyprogs\<<folder_name>>
   2. collage
   3. exif_overlay_checker
   4. extract_tracks
   5. fix-added_at
   6. fmg
   7. resizer
   8. tcc
   9. update_plex_artist_art




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
