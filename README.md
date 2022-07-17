# Plex-Stuff
## Random plex related stuff

## Requirements

1. A system that can run Python3
1. Python3 installed on that system

## Setup

1. clone repo
1. Install requirements with `pip install -r requirements.txt` [I'd suggest doing this in a virtual environment]
1. cd to desired directory
1. Copy `.env.example` to `.env`
1. Edit .env to suit

All these PYTHON scripts use the same `.env` and requirements. The Unraid bash scripts, Windows powershell or Windows cmd scripts, will vary in nature. Read the related section down below for more details. 

### `.env` contents

```
PLEX_URL=https://plex.domain.tld  # URL for Plex; can be a domain or IP:PORT
PLEX_TOKEN=PLEX-TOKEN             # https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
DELETE=0                          # DELETE=1 will perform the delete. This is PERMANENT. UNDO will NOT restore. 0 is safemode
RENAME=0                          # RENAME=1 will perform a rename of the files that would be deleted to append ".jpg". Can be undone by setting UNDO=1
UNDO=0                            # UNDO=1 will rename all the files that are named with ".jpg" back to no file extension
TMP_DIR=path\to\tmp_dir\          # Temporary directory (SHOULD BE AN EMPTY FOLDER) where the plex DB will be downloaded to perform query
DIR_PATH=path\to\Metadata\        # path to the Metadata directory in PLEX where the Movies and TV Shows subfolders are found. Local for best perf but can be mounted
TC_PATH=path\to\PhotoTranscoder\  # path to the PhotoTranscoder folder where client thumbnails are stored and rarely if ever get deleted
TC_DEL=0                          # set TC_DEL=1 and the script will delete files found in the Cache\PhotoTranscoder directory. UNDO will not undo this action. 
SLEEP=60                          # set SLEEP=60 to add a 60 second delay between the EMPTY_TRASH, CLEAN_BUNDLES, and OPTIMIZE PLEX operations
EMPTY_TRASH=0                     # set EMPTY_TRASH=1 and the script will run the EMPTY TRASH operation in PLEX
CLEAN_BUNDLES=0                   # set CLEAN_BUNDLES=1 and the script will run the CLEAN BUNDLES operation in PLEX
OPTIMIZE_DB=0                     # set OPTIMIZE_DB=1 and the script will run the OPTIMIZE DB operation in PLEX
```

## Plex scripts:

## Scripts:
1. [plex-bloat-fix.py](#plex-bloat-fix) - removes unneeded image files (Posters/Title Cards) from plex
2. [plexdance.sh](#plexdance) - Unraid script to automate the full plexdance
3. [process-tcards.cmd](#process-tcards) - Windows script to create properly sized PLEX titlecards to use with TCM or for other purposes
4. [pumpanddump.sh](#pumpanddump) - Unraid script to automate the plex db repair when using hotio plex container
5. [chk-video-codec.sh](#chk-video-codec) - Unraid script to find and sort files that have been converted to HEVC/H265 and those that have not been

## plex-bloat-fix

Your PLEX folders are growing out of control. You use overlays from PMM or upload lots of custom art that you no longer want to use or need to eliminate. You don't want to perform the plex dance if you can avoid it. This script will free up gigs of space....

### Usage
1. setup as above
2. Run with `python plex-bloat-fix.py`
3. Make sure that you are NOT actively updating posters or title cards with PMM or TCM while running this script. Scheduke this after the last run happens. So TCM, Plex Scheduled Tasks, PMM, THEN schedule or run plex-bloat-fix.py. Example: TCM @ 00:00, PLEX @ 02:00-05:00, and PMM @ 05:00

The script will loop through all the folders as defined in your .env and then clean it up if you want it to.

In this case, the script found ~7.7 gigabytes it could free up out of 12.8 gigabytes found and hence 60.12% bloat!
```
#######################################################################
# OVERALL SUMMARY:                                                    #
#######################################################################
plex-bloat-fix overall time: 313.4431965351105 seconds
UNDO Mode:                   False
RENAME Mode:                 True
DELETE Mode:                 False
TC DELETE Mode:              False
Total TC Size Found:         (2.224331005476415, 'gigabytes')
Total Meta File Size Found:  (5.451784175820649, 'gigabytes')
Total Meta File Size:        (10.542983120307326, 'gigabytes')
Grand Total File Size Found: (7.676115181297064, 'gigabytes')
Grand Total File Size:       (12.767314125783741, 'gigabytes')
Total Pct Plex Bloat:        60.12%
Total space savings:         (7.676115181297064, 'gigabytes')
#######################################################################
```
### NOTES/TIPS
1. If you run PMM, make sure this script runs AFTER PMM run completes. Never during the run. 
2. Do not make changes to posters while this script is running. Same reason as #1 above
3. Ensure you have proper permissions to delete/rename or the script will fail
4. For performance purposes, its always recommended to run locally so that accessing the files is not done over a network share
5. If you are running on UNRAID, use nerdpack to install the latest python package and I suggest the same virtualenv install as explained above.(/mnt/user/data/scripts/plex-scripts/plex-bloat-fix) where the venv is found in /mnt/user/data/scripts/venv). You can then navigate to the location of the plex-bloat-fix.py folder in a terminal and then run `../../venv/bin/python plex-bloat.fix.py`
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
1. Copy the script into /mnt/user/data/scripts/plex-scripts/pumpanddump folder (or any other unraid scripts folder you use) 
2. Review the paths in the file like the `sqlplex=` variable (around line 5) and the `docker cp` line (around line 40)
3. Open a terminal session and navigate to that folder with the script and run: `chmod 755 pumpanddump.sh` to make it executable
4. Run `./pumpanddump.sh plex` where `plex` is the name of your container

## chk-video-codec

This script will go through the current directory and 10 levels down (if needed) to determine which files have been converted to HEVC/H265 and those that have not been.

### Usage
1. Copy the script into /mnt/user/data/scripts/plex-scripts/chk-video-codec folder (or any other unraid scripts folder you use) 
2. Review the paths in the file like the `ffprobe_path=` variable and ensure that you specify the full path to ffprobe which is part of the ffmpeg(http://www.ffmpeg.org/download.html) suite
3. Open a terminal session and navigate to that folder with the script and run: `chmod 755 chk-video-codec.sh` to make it executable
4. Goto the media folder that you want to scan and run `/mnt/user/data/scripts/plex-scripts/chk-video-codec/chk-video-codec.sh`
5. 3 log files will be created. Review them to see the results
