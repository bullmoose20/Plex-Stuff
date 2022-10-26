# Plex-Stuff
## Random plex related stuff

## Requirements

1. A system that can run Python3
1. Python3 installed on that system

## Setup

1. clone repo
2. setup python virtualenv - [I'd suggest doing this in a virtual environment. Great instructions found here - https://metamanager.wiki/en/nightly/home/guides/local.html?highlight=virtualenv#setting-up-a-virtual-environment]
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
NOTIFIARR_ENABLED=0                             # Set to 1 to enable notifiarr
NOTIFIARR_KEY=NOTIFIARR_KEY                     # Add notifiarr key as per the PASSTHOUGH integration on notifiarr.com
DISCORD_CHANNEL=DISCORD_CHANNEL                 # Add the discord channel number associated to the channel that you want to send messages to
DELETE=0                                        # DELETE=1 will perform the delete. This is PERMANENT. UNDO will NOT restore. 0 is safemode
RENAME=0                                        # RENAME=1 will perform a rename of the files that would be deleted to append ".jpg". Can be undone by setting UNDO=1
UNDO=0                                          # UNDO=1 will rename all the files that are named with ".jpg" back to no file extension
TMP_DIR=path\to\tmp_dir\                        # Temporary directory (SHOULD BE AN EMPTY FOLDER) where the plex DB will be downloaded to perform query
DIR_PATH=path\to\Metadata\                      # path to the Metadata directory in PLEX where the Movies and TV Shows subfolders are found. Local for best perf but can be mounted
TC_PATH=path\to\PhotoTranscoder\                # path to the PhotoTranscoder folder where client thumbnails are stored and rarely if ever get deleted
DB_PATH=path\to\Plex\Plug-in Support\Databases\ # path to the PLEX db folder
TC_DEL=0                                        # set TC_DEL=1 and the script will delete files found in the Cache\PhotoTranscoder directory. UNDO will not undo this action. 
SLEEP=60                                        # set SLEEP=60 to add a 60 second delay between the EMPTY_TRASH, CLEAN_BUNDLES, and OPTIMIZE PLEX operations
EMPTY_TRASH=0                                   # set EMPTY_TRASH=1 and the script will run the EMPTY TRASH operation in PLEX
CLEAN_BUNDLES=0                                 # set CLEAN_BUNDLES=1 and the script will run the CLEAN BUNDLES operation in PLEX
OPTIMIZE_DB=0                                   # set OPTIMIZE_DB=1 and the script will run the OPTIMIZE DB operation in PLEX
LOG_FILE_ACTIONS=1                              # set LOG_FILE_ACTIONS=1 for VERBOSE output
```

### Note on paths:
```
TMP_DIR=path\to\tmp_dir\
DIR_PATH=path\to\Metadata\
TC_PATH=path\to\PhotoTranscoder\
DB_PATH=path\to\Plex\Plug-in Support\Databases\
```

These paths are all local to the machine where the script is running.  If your Plex server is a different machine from the one running the script, you will need to mount the relevant folders from the Plex server to this machine, then these paths will get set to the local mount location.

For example, your Plex server is running on a Linux box somewhere.  On your Plex server, the three directories of interest are
```
DIR_PATH=/opt/plex/Library/Application Support/Plex Media Server/Metadata
DB_PATH=/opt/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases
TC_PATH=/opt/plex/Library/Application Support/Plex Media Server/Cache/PhotoTranscoder
```
If you run `plex-bloat-fix.py` on that machine, those are correct.

If you want to run `plex-bloat-fix.py` on your Windows machine, you need to map those three directories to local locations, then use *those paths* in the env:
```
DIR_PATH=j:
DB_PATH=k:
TC_PATH=l:
```
Or however you've mounted those directories.

## Plex scripts:

## Scripts:
1. [plex-bloat-fix.py](#plex-bloat-fix) - removes unneeded image files (Posters/Title Cards) from plex
2. [plexdance.sh](#plexdance) - Unraid script to automate the full plexdance
3. [process-tcards.cmd](#process-tcards) - Windows script to create properly sized PLEX titlecards to use with TCM or for other purposes
4. [pumpanddump.sh](#pumpanddump) - Unraid script to automate the plex db repair when using hotio plex container
5. [chk-video-codec.sh](#chk-video-codec) - Unraid script to find and sort files that have been converted to HEVC/H265 and those that have not been
6. [create_poster.ps1](#create_poster) - Powershell script to create posters/images for PMM/PLEX/EMBY/JELLYFIN/OTHER

## plex-bloat-fix

Your PLEX folders are growing out of control. You use overlays from PMM or upload lots of custom art that you no longer want to use or need to eliminate. You don't want to perform the plex dance if you can avoid it. This script will free up gigs of space....It can also perform some PLEX operations like "empty trash", "clean bundles", and "optimize db". PBF also supports the use of PASSTHROUGH alerts to discord with notifiarr.com

### Usage
1. setup as above
2. Run with `python plex-bloat-fix.py` - sometimes (usually when you have not setup the virtualenv for python as recommended above), you need to specify the version of python in the command like `python3.9 plex-bloat-fix.py`
3. Make sure that you are NOT actively updating posters or title cards with PMM or TCM while running this script. Schedule this after the last run happens. So TCM, Plex Scheduled Tasks, PMM, THEN schedule or run plex-bloat-fix.py. Example: TCM @ 00:00, PLEX @ 02:00-05:00, and PMM @ 05:00

The script will loop through all the folders as defined in your `.env` and then clean it up if you want it to.

In this case, the script found ~ 434 gigabytes it could free up out of ~ 524 gigabytes found and hence 82.78% bloat!
```
#######################################################################
# BEGIN             Ver:#.#.# 
#######################################################################
Log file:           plex-bloat-fix.log created...
DB_PATH VALID:      This is a local run which will COPY the database
UNDO:               False
RENAME:             False
DELETE:             False
TC_DEL:             False
LOG_FILE_ACTIONS:   False
SLEEP:              60
EMPTY_TRASH:        False
CLEAN_BUNDLES:      False
OPTIMIZE_DB:        False
LIB:                /mnt/user/appdata/plex/Metadata/Movies
LIB:                /mnt/user/appdata/plex/Metadata/TV Shows
LIB:                /mnt/user/appdata/plex/Metadata/Playlists
LIB:                /mnt/user/appdata/plex/Metadata/Collections
LIB:                /mnt/user/appdata/plex/Metadata/Artists
LIB:                /mnt/user/appdata/plex/Metadata/Albums
TMP_DIR:            /mnt/user/data/scripts/plex-scripts/plex-bloat-fix/plex_db/
DIR_PATH:           /mnt/user/appdata/plex/Metadata/
TC_PATH:            /mnt/user/appdata/plex/Cache/PhotoTranscoder/
DB_PATH:            /mnt/user/appdata/plex/Plug-in Support/Databases/
REPORTONLY:         PBF will report files to be deleted without doing so.
#######################################################################

#######################################################################
# SUMMARY: Overall
#######################################################################
Overall elapsed time:                        403.66 seconds
Overall Metadata to delete:                  206.94 gigabytes
Overall Metadata files to delete:            131726
Overall Metadata size:                       297.28 gigabytes
Overall Metadata files:                      190296
PhotoTranscoder data to delete:              227.25 gigabytes
PhotoTranscoder files to delete:             1197607
Overall data to delete:                      434.19 gigabytes
Overall files to delete:                     1387903
Overall Plex bloat factor:                   82.78%
#######################################################################
```
So what are the recommended settings for when I actually let the script run and do its thing?
```
DELETE:                 False
TC_DEL:                 False
```
Flip these to true in `.env` by setting them to 1

DELETE will delete this stuff:
```
Overall Metadata to delete:                  206.94 gigabytes
Overall Metadata files to delete:            131726
```
TC DELETE will delete this stuff:
```
PhotoTranscoder data to delete:              227.25 gigabytes
PhotoTranscoder files to delete:             1197607
```

If you want to dry run and examine files:
```
RENAME:                 False
```
Setting ONLY RENAME to true (=1 in `.env`) will just rename these files so you can look at them
```
Overall Metadata to delete:                  206.94 gigabytes
Overall Metadata files to delete:            131726
```
If DB_PATH is pointing to a valid directory:
```
DB_PATH="/opt/plex/Library/Application Support/Plex Media Server/Plug-in Support/Databases"
```
The script will *copy* the database file rather than downloading it through the Plex API.  The assumption here is that you are running PBF on the same machine as plex.  This is useful in cases where the DB is too large to download.

IMPORTANT: the script currently does not verify that Plex is idle before doing this.  MAKE SURE that Plex is idle before running the script to avoid any database problems that may be caused by copying the DB out from under Plex while it's being optimized or the like.  ONLY use this if you have a backup.

If LOG_FILE_ACTIONS is set to 0:
```
LOG_FILE_ACTIONS=0
```
The script will NOT log any individual file actions.  That list can be quite long, and you may not want to scroll through it to get to the size information you seek.


### NOTES/TIPS
1. If you run PMM, make sure this script runs AFTER PMM run completes. Never during the run. 
2. Do not make changes to posters while this script is running. Same reason as #1 above
3. Ensure you have proper permissions to delete/rename or the script will fail
4. For performance purposes, its always recommended to run locally so that accessing the files is not done over a network share
5. If you are running on UNRAID, use nerdpack to install the latest python package and I suggest the same virtualenv install as explained above.(`/mnt/user/data/scripts/plex-scripts/plex-bloat-fix`) where the venv is found in `/mnt/user/data/scripts/venv`). You can then navigate to the location of the `plex-bloat-fix.py` folder in a terminal and then run `../../venv/bin/python plex-bloat-fix.py`
6. If you are using a PLEX container in UNRAID or other, use the hotio plex container... It ROCKS! https://hotio.dev/containers/plex/

## plexdance

So your plex is hosed... and your DB and metadata is in a real mess... time for the plexdance. https://forums.plex.tv/t/the-plex-dance/197064 Quote: "The purpose of this is to remove all cached metadata and xml data for an item that Plex usually keeps. This helps when you want to “start from scratch” for particular item" My version will do a FULL plexdance on ALL of your libraries

### Usage
1. setup as above
2. edit the bash script so that the proper paths are used. I picked a very common structure, but this will depend on your setup
3. edit/comment the docker start and stop lines as needed
4. cp the bash script to a location accessible in Unraid terminal
5. Open Unraid terminal and navigate to the folder that contains the bash script
6. `chown 755 plexdance.sh` to ensure that you can run the script
7. Run with `./plexdance.sh`
8. follow prompts closely

## process-tcards

This script will use Imagemagick to produce title cards based on a folder that contains the episode titlecards stored as jpg. The end results will be in the `results` subfolder along with the `grayscale` subfolder

### Usage
1. Install latest windows version of Imagemagick (https://imagemagick.org/script/download.php#windows) 
2. Create a folder with the jpg files you want to process and place process-tcards.cmd in that same directory
3. Run `process-tcards.cmd`
4. Original files will not be touched and results are stored in `results` subfolder and the `grayscale` subfolder

## pumpanddump

This script will dump your plex db to a file and reimport it which usually repairs your db when you are seeing corruption and unable to download the db via the ui or the plexapi. This script is currently setup to work with the hotio plex container...... It ROCKS! https://hotio.dev/containers/plex/

### Usage
1. Copy the script into `/mnt/user/data/scripts/plex-scripts/pumpanddump` folder (or any other unraid scripts folder you use) 
2. Review the paths in the file like the `sqlplex=` variable (around line 5) and the `docker cp` line (around line 40)
3. Open a terminal session and navigate to that folder with the script and run: `chmod 755 pumpanddump.sh` to make it executable
4. Run `./pumpanddump.sh plex` where `plex` is the name of your container

## chk-video-codec

This script will go through the current directory and 10 levels down (if needed) to determine which files have been converted to HEVC/H265 and those that have not been.

### Usage
1. Copy the script into `/mnt/user/data/scripts/plex-scripts/chk-video-codec` folder (or any other unraid scripts folder you use) 
2. Review the paths in the file like the `ffprobe_path=` variable and ensure that you specify the full path to ffprobe which is part of the ffmpeg(http://www.ffmpeg.org/download.html) suite. Consider running the tdarr_node container in Unraid as the path I used is from that container.
3. Open a terminal session and navigate to that folder with the script and run: `chmod 755 chk-video-codec.sh` to make it executable
4. Goto the media folder that you want to scan and run `/mnt/user/data/scripts/plex-scripts/chk-video-codec/chk-video-codec.sh`
5. 3 log files will be created. Review them to see the results

## create_poster

This Powershell script will create posters/images for PMM/PLEX/EMBY/JELLYFIN/OTHER

### DESCRIPTION

In a powershell window and with ImageMagick installed, this will 
1. create a 2000x3000 colored poster based on $base_color parameter otherwise a random color for base is used and creates base_$base_color.jpg
2. it will add the gradient in the second line to create a file called gradient_$base_color.jpg
3. takes the $logo specified and sizes it 1800px (or whatever desired logo_size specified) wide leaving 100 on each side as a buffer of space
4. if a border is specified, both color and size of border will be applied
5. if text is desired it will be added to the final result with desired size, color and font
6. if white-wash is enabled, the colored logo with be made to 100% white
7. final results are a logo centered and merged to create a 2000x3000 poster with the $base_color color and gradient fade applied and saved as a jpg file (with an optional border of specified width and color and logo offset, as well as text, font, font_color, and font_size )
 
### REQUIREMENTS
Imagemagick must be installed - https://imagemagick.org/script/download.php

font must be installed on system and visible by Imagemagick. Make sure that you install the ttf font for ALL users as an admin so ImageMagick has access to the font when running (r-click on font Install for ALL Users in Windows)

Powershell security settings: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.2

### PARAMETERS
`-logo`          (specify the logo/image png file that you want to have centered and resized)

`-logo_offset`   (+100 will push logo down 100 px from the center. -100 will move the logo up 100px from the center. Value is between -1500 and 1500. DEFAULT=0 or centered. -750 is the midpoint between the center and the top)

`-logo_resize`   (1000 will resize the log to fit in the poster.DEFAULT=1800.)

`-base_color`    (hex color code for the base background. If omitted a random color will be picked using the "#xxxxxx" format)

`-text`          (text that you want to show on the resulting image. use \n to perform a carriage return and enclose text in double quotes.)

`-text_offset`   (+100 will push text down 100 px from the center. -100 will move the text up 100px from the center. Value is between -1500 and 1500. DEFAULT=0 or centered. +750 is the midpoint between the center and the bottom)

`-font`          (font name that you want to use. magick identify -list font magick -list font)

`-font_color`    (hex color code for the font. If omitted, white or #FFFFFF will be used)

`-font_size`     (default is 250. pick a font size between 10-500.)

`-border`        (default is 0 or $false - boolean value and when set to 1 or $true, it will add the border)

`-border_width`  (width in pixels between 1 and 100. DEFAULT=15)

`-border_color`  (hex color code for the border color using the "#xxxxxx" format. DEFAULT=#FFFFFF)

`-white_wash`    (default is 0 or $false - boolean value and when set to 1 or $true, it will take the logo and make it white)

`-clean`         (default is 0 or $false - boolean value and when set to 1 or $true, it will delete the temporary files that are created as part of the script)


### EXAMPLES
Create a poster with the Spotify.png logo and random background color with a black border that is 50 px wide. Temp files are deleted because "-clean 1"

`.\create_poster.ps1 -logo .\logos\Spotify.png -clean 1 -border_width 50 -border_color "#000000" -border 1`

Create a poster with the Spotify.png logo and random background color with a white border that is 15 px wide. Temp files are deleted because "-clean 1". Defaults of WHITE and Border width 15 are used

`.\create_poster.ps1 -logo .\logos\Spotify.png -clean 1 -border 1`

Create a poster with the Spotify.png logo and a black background color. Temp files are deleted because "-clean 1".

`.\create_poster.ps1 -logo .\logos\Spotify.png -base "#000000" -clean 1`

Create a poster with the Spotify.png and random background color. Temp files are deleted because "-clean 1".

`.\create_poster.ps1 -logo .\logos\Spotify.png -clean 1`

Create a poster with the Spotify.png and specified background color of "#FB19B9". Temp files are deleted because "-clean 1". border is enabled and width of 20px. Logo is moved up from the center by -750px.

`.\create_poster.ps1 -logo .\logos\Spotify.png -clean 1 -base "#FB19B9" -offset -750 -border_width 20 -border 1`

![](images/create_poster-example1.png)
![](images/create_poster-example2.png)