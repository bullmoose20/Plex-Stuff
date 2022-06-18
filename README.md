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

All these scripts use the same `.env` and requirements.

### `.env` contents

```
PLEX_URL=https://plex.domain.tld  # URL for Plex; can be a domain or IP:PORT
PLEX_TOKEN=PLEX-TOKEN             # https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
DELETE=0                          # DELETE=1 will perform the delete. This is PERMANENT. UNDO will NOT restore. 0 is safemode
RENAME=0                          # RENAME=1 will perform a rename of the files that would be deleted to append ".jpg". Can be undone by setting UNDO=1
UNDO=0                            # UNDO=1 will rename all the files that are named with ".jpg" back to no file extension
TMP_DIR =path\to\fldr\            # Temporary directory (SHOULD BE AN EMPTY FOLDER) where the plex DB will be downloaded to perform query
DIR_PATH=path\to\Metadata\        # path to the Metadata directory in PLEX where the Movies and TV Shows subfolders are found. Local for best perf but can be mounted
TC_PATH=path\to\PhotoTranscoder\  # path to the PhotoTranscoder folder where client thumbnails are stored and rarely if ever get deleted
TC_DEL=0                          # set TC_DEL=1 and the script with delete files found in the Cache\PhotoTranscoder directory. UNDO will not undo this action. 
```

## Plex scripts:

## Scripts:
1. [plex-bloat-fix.py](#plex-bloat-fix) - removes unneeded image files (Posters/Title Cards) from plex

## plex-bloat-fix

Your PLEX folders are growing out of control. You use overlays from PMM or upload lots of custom art that you no longer want to use or need to eliminate. You don't want to perform the plex dance if you can avoid it. This script will free up gigs of space....

### Usage
1. setup as above
2. Run with `python plex-bloat-fix.py`

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
#######################################################################
```


