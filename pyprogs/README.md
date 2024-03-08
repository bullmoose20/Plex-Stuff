# Python-Stuff
## Random python related stuff

## Requirements

1. A system that can run Python3
2. Python3 installed on that system
3. Preferable to also have a system that can run powershell
4. Preferable to have a system that can also run Power Automate Desktop Flows
5. System that has ImageMagick installed

## Setup

1. clone repo
2. setup python virtualenv - [I'd suggest doing this in a virtual environment. Great instructions found here - https://www.metamanager.wiki/en/nightly/pmm/install/guides/local/#setting-up-a-virtual-environment]
3. Activate that virtualenv
4. Install requirements with `pip install -r requirements.txt` into that virtualenv
5. cd to the directory that you want to run the script in
6. Copy `.env.example` to `.env` 
7. Edit `.env` to suit

All these PYTHON scripts use the same `.env` and requirements. The Unraid bash scripts, Windows powershell or Windows cmd scripts, will vary in nature. Read the related section down below for more details. 

### `.env` contents

```
PLEX_URL=https://plex.domain.tld                # URL for Plex; can be a domain or IP:PORT
PLEX_TOKEN=PLEX-TOKEN                           # https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
```

## Plex scripts:

## Scripts:
1.pyprogs

drop file into a folder
create a venv
activate the venv
install requirements
run title_card_clips

open a powershell prompt and navigate to a folder and create a directory
`cd pyprogs`
`mkdir tcc`

drop requirements and title_card_clips.py into the `tcc` folder just created

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


drop file into a folder
create a venv
activate the venv
install requirements
run fake_media_generator

open a powershell prompt and navigate to a folder and create a directory
`cd pyprogs`
`mkdir fmg`

drop requirements and fake_media_generator.py into the `fmg` folder just created

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


Name
----
collage
exif_overlay_checker
extract_tracks
fix-added_at
fmg
resizer
tcc
update_plex_artist_art