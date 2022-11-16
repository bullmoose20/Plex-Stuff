####################################################################
# REQUIREMENTS
####################################################################
# PlexAPI
# python-dotenv
# SQLAlchemy

__version__ = "1.3.5"
from xmlrpc.client import Boolean
from operator import itemgetter, attrgetter
from plexapi.server import PlexServer
from pathlib import Path
import os, sys, sqlite3, glob, time, logging, platform, logging.handlers, shutil
import urllib.request
import json
import requests
from os import walk
from urllib.parse import urlparse
from dotenv import load_dotenv

PLEX_DB_NAME = "com.plexapp.plugins.library.db"
LOG_FILENAME = "logs/plex-bloat-fix.log"
HEADER_WIDTH = 20
SUMMARY_HEADER_WIDTH = 45
LINE_WIDTH = 71
SEP_CHAR = '#'
color_g = "00ff00"
color_y = "FFFF00"
color_r = "FF0000"

env_is_here = os.path.isfile('.env')

if not env_is_here:
    print('Configuration file [.env] is not here.  Exiting.')
    exit()

load_dotenv()

####################################################################
# Set up a specific logger with our desired output level
####################################################################
my_logger = logging.getLogger("MyLogger")
my_logger.setLevel(logging.DEBUG)

####################################################################
# Check if log exists and should therefore be rolled
####################################################################
needRoll = os.path.isfile(LOG_FILENAME)

####################################################################
# Add the log message handler to the logger
####################################################################
handler = logging.handlers.RotatingFileHandler(LOG_FILENAME, backupCount=9)

my_logger.addHandler(handler)

####################################################################
# This is a stale log, so roll it
####################################################################
if needRoll:
    # Roll over on application start
    my_logger.handlers[0].doRollover()

logging.basicConfig(
    filename=LOG_FILENAME,
    filemode="w",
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)
logging.getLogger().addHandler(logging.StreamHandler())

####################################################################
# FUNCTIONS
####################################################################
def send_notifiarr (msg_type, color, text_msg, f1_title, f1_msg, f2_title, f2_msg, f3_title, f3_msg):
  if NOTIFIARR_ENABLED != 1:
    return
  base_url = "https://notifiarr.com/api/v1/"
  dev_url = "https://dev.notifiarr.com/api/v1/"
  notifiarr_channel = "notification/passthrough/"
  notifiarr_key = NOTIFIARR_KEY
  discord_channel = DISCORD_CHANNEL
  url = base_url+notifiarr_channel+notifiarr_key
  inline1 = bool(1)
  inline2 = bool(1)
  inline3 = bool(0)
  #print(url)
  logo = "https://raw.githubusercontent.com/bullmoose20/Plex-Stuff/master/pbf.png"

  json_string = {
      'notification': {
          'name': 'PBF: '+msg_type,
          'event': '0'
      },
      'discord': {
          'color': color,
          'images': {
              'thumbnail': logo,
              'image': ''
          },
          'text': {
              'title': '',
              'content': '',
              'description': text_msg,
              'fields': [
                  {
                      'title': f1_title,
                      'text': f1_msg,
                      'inline': inline1
                  },
                  {
                      'title': f2_title,
                      'text': f2_msg,
                      'inline': inline2
                  },
                  {
                      'title': f3_title,
                      'text': f3_msg,
                      'inline': inline3
                  }
              ],
              'footer': ''
          },
          'ids': {
              'channel': discord_channel
          }
      }
  }


  # Serializing json
  json_object = json.dumps(json_string, indent=2)
  # print(json_object)

  r = requests.post(url, json_object)
  if r.status_code != 200:
    log_error(f"Status Code: {r.status_code}, Response: {r.json()}")

def chk_ver():
    url = "https://raw.githubusercontent.com/bullmoose20/Plex-Stuff/master/version.txt"
    file = urllib.request.urlopen(url)

    for line in file:
        remote_ver = line.decode("utf-8")

    if __version__ != remote_ver:
        log_line("# UPGRADE",f"Current Ver:{__version__} New Ver:{remote_ver} ")
        send_notifiarr("WARNING", color_y, "PBF Upgrade Recommended", "Current Ver:", f"{__version__}", "New Ver:", f"{remote_ver}", "WARNING", "Maybe consider updating your version of plex-bloat-fix")

def log_line(header, msg):
    logging.info(f'{header : <{HEADER_WIDTH}}{msg}')

def log_file(header, msg):
    if LOG_FILE_ACTIONS:
        log_line(header, msg)

def log_error(msg):
    log_line("ERROR:", msg)

def log_error_and_exit(msg):
    log_error(msg)
    exit()

def drawLine():
    logging.info(f'{"":{SEP_CHAR}<{LINE_WIDTH}}')

def summary_line(heading, msg):
    logging.info(f'{heading : <{SUMMARY_HEADER_WIDTH}}{msg}')

def undo_rename():
    log_line("STATUS","UNDO starting and this will take time....")
    start = time.time()
    for DIR_PATH in DIR_PATH_ARR:
        files = glob.glob(f"{DIR_PATH}/**/*.jpg", recursive=True)
        log_line(f"Working on:",f"{DIR_PATH}")
        for f in files:
            tempTuple = os.path.splitext(f)
            log_file("RENAME:",f"{f} --> {tempTuple[0]}")
            os.rename(f, tempTuple[0])

    log_line("STATUS","UNDO Complete")
    end = time.time()
    stopwatch = end - start
    log_line(f"UNDO time:",f"{stopwatch:.2f} seconds")

    sys.exit()

def clear_tmp():
    log_line("STATUS:",f"Deleting all files in PLEX DB download directory: {TMP_DIR}")
    files = glob.glob(f"{TMP_DIR}/*")
    for f in files:
        os.remove(f)

def format_bytes(size):
    # 2**10 = 1024
    power = 2**10
    n = 0
    power_labels = {0: "", 1: "kilo", 2: "mega", 3: "giga", 4: "tera"}
    while size > power:
        size /= power
        n += 1
    return f"{size:.2f} {power_labels[n]}bytes"

def handle_file(f):
    if DELETE:
        log_file("DELETE----->", f )
        f.unlink()
    elif RENAME:
        log_file("RENAME----->", f )
        f.rename(f.with_suffix(".jpg"))
    else:
        log_file("SAFE MODE----->", f )

def report_summary(s_data):

    SECTION = s_data['name']
    ACTION = "# Ver: "+__version__+" SUMMARY" if s_data["meta_size_total"] or s_data["tc_size_delete"] else "# NO FILES FOUND IN"
    drawLine()
    logging.info(f"{ACTION}: {SECTION}")
    drawLine()
    if TC_DEL:
        tc_del_txt  = "deleted"
    else:
        tc_del_txt  = "to delete"
    if DELETE:
        del_txt  = "deleted"
    else:
        del_txt  = "to delete"
    if s_data["meta_size_total"] or s_data["tc_size_delete"] > 0:
        summary_line(f"{SECTION} elapsed time:", f"{s_data['stopwatch']:.2f} seconds")
        summary_line(f"{SECTION} Metadata {del_txt}:", f"{format_bytes(s_data['meta_size_delete'])}")
        summary_line(f"{SECTION} Metadata files {del_txt}:", f"{s_data['meta_ct_delete']}")
        summary_line(f"{SECTION} Metadata size:", f"{format_bytes(s_data['meta_size_total'])}")
        summary_line(f"{SECTION} Metadata files:", f"{s_data['meta_ct_total']}")
        send_notifiarr("INFO", color_g, "PBF Summary", "Results:", f"{SECTION} elapsed time: "+f"{s_data['stopwatch']:.2f} seconds", f"{SECTION} Metadata size: "+f"{format_bytes(s_data['meta_size_total'])}", f"{SECTION} Metadata {del_txt}: "+f"{format_bytes(s_data['meta_size_delete'])}", f"{SECTION} Metadata files: "+f"{s_data['meta_ct_total']}", f"{SECTION} Metadata files {del_txt}: "+f"{s_data['meta_ct_delete']}")
        if s_data["name"] == "PhotoTranscoder":
            summary_line(f"PhotoTranscoder data {tc_del_txt}:", f"{format_bytes(s_data['tc_size_delete'])}")
            summary_line(f"PhotoTranscoder files {tc_del_txt}:", f"{s_data['tc_ct_delete']}")
            send_notifiarr("INFO", color_g, "PBF Summary", "Results:", f"{SECTION} elapsed time: "+f"{s_data['stopwatch']:.2f} seconds", "SIZE:", f"PhotoTranscoder data {tc_del_txt}:"+f"{format_bytes(s_data['tc_size_delete'])}", "FILES:", f"PhotoTranscoder files {tc_del_txt}: "+f"{s_data['tc_ct_delete']}")
        if s_data["grand_total"]:
            summary_line(f"Overall PhotoTranscoder data {tc_del_txt}:", f"{format_bytes(s_data['tc_size_delete'])}")
            summary_line(f"Overall PhotoTranscoder files {tc_del_txt}:", f"{s_data['tc_ct_delete']}")
            summary_line(f"{SECTION} data {del_txt}:", f"{format_bytes(s_data['tc_size_delete'] + s_data['meta_size_delete'])}")
            summary_line(f"{SECTION} files {del_txt}:", f"{s_data['meta_ct_delete'] + s_data['tc_ct_delete']}")
            send_notifiarr("INFO", color_g, "PBF Overall Summary", "Results:", f"{SECTION} elapsed time: "+f"{s_data['stopwatch']:.2f} seconds.\n"+f"{SECTION} Plex bloat factor: "+"{:.2%}".format(s_data['pct_bloat']), f"Overall PhotoTranscoder data {tc_del_txt}: "+f"{format_bytes(s_data['tc_size_delete'])}", f"Overall PhotoTranscoder files {tc_del_txt}: "+f"{s_data['tc_ct_delete']}", f"{SECTION} data {del_txt}: "+f"{format_bytes(s_data['tc_size_delete'] + s_data['meta_size_delete'])}", f"{SECTION} files {del_txt}: "+f"{s_data['meta_ct_delete'] + s_data['tc_ct_delete']}")
        summary_line(f"{SECTION} Plex bloat factor:", "{:.2%}".format(s_data['pct_bloat']))
        drawLine()
    else:
        send_notifiarr("INFO", color_g, "PBF Summary", "Results:", f"NO FILES FOUND IN: {SECTION}", "SIZE:", "N/A", "FILES:", "N/A")

if sys.version_info.major != 3:
    print('This script requires Python 3.  Exiting.')
    exit()

drawLine()
log_line("# BEGIN",f"Ver:{__version__} ")
drawLine()

####################################################################
# VARS
####################################################################

try:
    NOTIFIARR_ENABLED = Boolean(int(os.getenv("NOTIFIARR_ENABLED")))
except:
    NOTIFIARR_ENABLED = False

NOTIFIARR_KEY = os.getenv("NOTIFIARR_KEY")
if NOTIFIARR_ENABLED and NOTIFIARR_KEY is None:
    log_error_and_exit("NOTIFIARR_KEY is not defined.")

DISCORD_CHANNEL = os.getenv("DISCORD_CHANNEL")
if NOTIFIARR_ENABLED and DISCORD_CHANNEL is None:
    log_error_and_exit("DISCORD_CHANNEL is not defined.")

try:
    TC_DEL = Boolean(int(os.getenv("TC_DEL")))
except:
    TC_DEL = False

try:
    UNDO = Boolean(int(os.getenv("UNDO")))
except:
    UNDO = False

try:
    RENAME = Boolean(int(os.getenv("RENAME")))
except:
    RENAME = False

try:
    DELETE = Boolean(int(os.getenv("DELETE")))
except:
    DELETE = False

try:
    EMPTY_TRASH = Boolean(int(os.getenv("EMPTY_TRASH")))
except:
    EMPTY_TRASH = False

try:
    CLEAN_BUNDLES = Boolean(int(os.getenv("CLEAN_BUNDLES")))
except:
    CLEAN_BUNDLES = False

try:
    OPTIMIZE_DB = Boolean(int(os.getenv("OPTIMIZE_DB")))
except:
    OPTIMIZE_DB = False

try:
    LOG_FILE_ACTIONS = Boolean(int(os.getenv("LOG_FILE_ACTIONS")))
except:
    LOG_FILE_ACTIONS = True

try:
    SLEEP = int(os.getenv("SLEEP"))
except:
    SLEEP = 60

send_notifiarr("INFO", color_g, "PBF started", "N/A", "N/A", "N/A", "N/A", "INFO", "PBF Plex Bloat Fix has started")
chk_ver()
drawLine()
log_line(f"Log file:",f"{LOG_FILENAME} created...")

DB_PATH = os.getenv("DB_PATH")
local_run = os.path.isdir(DB_PATH)

if local_run:
    log_line("DB_PATH VALID:","This is a local run which will COPY the database")
else:
    log_line("DB_PATH INVALID:","This is a remote run which will DOWNLOAD the database")

TC_PATH = os.getenv("TC_PATH")
if "PhotoTranscoder" not in TC_PATH and TC_DEL:
    send_notifiarr("ERROR", color_r, "PBF PhotoTranscoder path issue", "Issue:", "PhotoTranscoder not found in path", "Detail:", TC_PATH, "ERROR", "TC_PATH is not a standard PhotoTranscoder directory.")
    log_error_and_exit("TC_PATH is not a standard PhotoTranscoder directory.")
if not Path(TC_PATH).is_dir():
    send_notifiarr("ERROR", color_r, "PBF PhotoTranscoder path issue", "Issue:", "TC_PATH is not a directory", "Detail:", TC_PATH, "ERROR", "TC_PATH is not a directory. Update the .env file with a proper directory")
    log_error_and_exit(f"TC_PATH is not a directory: {TC_PATH}")

DIR_PATH = os.getenv("DIR_PATH")
if not Path(DIR_PATH).is_dir():
    send_notifiarr("ERROR", color_r, "PBF Metadata path issue", "Issue:", "DIR_PATH is not a directory", "Detail:", DIR_PATH, "ERROR", "DIR_PATH is not a directory. Update the .env file with a proper directory")
    log_error_and_exit(f"DIR_PATH is not a directory: {DIR_PATH}")

TMP_DIR = os.getenv("TMP_DIR")
# go ahead and create the temp dir if it doesn't already exist
Path(TMP_DIR).mkdir(parents=True, exist_ok=True)

if not Path(TMP_DIR).is_dir():
    send_notifiarr("ERROR", color_r, "PBF temp directory path issue", "Issue:", "TMP_DIR is not a directory", "Detail:", TMP_DIR, "ERROR", "TMP_DIR is not a directory. Update the .env file with a proper directory")
    log_error_and_exit(f"TMP_DIR is not a directory: {TMP_DIR}")

if len(os.listdir(TMP_DIR)) > 0:
    send_notifiarr("ERROR", color_r, "PBF temp directory not empty", "Issue:", "TMP_DIR is not empty", "Detail:", TMP_DIR, "ERROR", "TMP_DIR is not empty. Navigate to this directory and ensure it is empty")
    log_error_and_exit(f"TMP_DIR is not empty:       {TMP_DIR}")

PLEX_URL = os.getenv("PLEX_URL")
if PLEX_URL is None:
    send_notifiarr("ERROR", color_r, "PBF plex url is missing", "Issue:", "PLEX_URL is not defined", "N/A", "N/A", "ERROR", "PLEX_URL is missing. You will need to update the .env with a url to PLEX")
    log_error_and_exit("PLEX_URL is not defined.")

PLEX_TOKEN = os.getenv("PLEX_TOKEN")
if PLEX_TOKEN is None:
    send_notifiarr("ERROR", color_r, "PBF plex token is missing", "Issue:", "PLEX_TOKEN is not defined", "N/A", "N/A", "ERROR", "PLEX_TOKEN is missing. You will need to update the .env with the token for PLEX")
    log_error_and_exit("PLEX_TOKEN is not defined.")

dbpath = ""
file_size_tot = 0
file_size_del = 0
file_size_sub = 0
file_sub = 0
file_size_sub_del = 0
file_sub_del = 0

####################################################################
# MAIN
####################################################################
SQLCMD1 = (
    "SELECT user_thumb_url FROM metadata_items WHERE user_thumb_url like 'upload://%';"
)
SQLCMD2 = (
    "SELECT user_art_url FROM metadata_items WHERE user_art_url like 'upload://%';"
)

LIBS = ["Movies", "TV Shows", "Playlists", "Collections", "Artists", "Albums"]

DIR_PATH_ARR = []
for lib in LIBS:
    DIR_PATH_ARR.append(os.path.join(DIR_PATH, lib))

log_line(f"UNDO:",f"{UNDO}")
log_line(f"RENAME:",f"{RENAME}")
log_line(f"DELETE:",f"{DELETE}")
log_line(f"TC_DEL:",f"{TC_DEL}")
log_line(f"LOG_FILE_ACTIONS:",f"{LOG_FILE_ACTIONS}")
log_line(f"SLEEP:",f"{SLEEP}")
log_line(f"EMPTY_TRASH:",f"{EMPTY_TRASH}")
log_line(f"CLEAN_BUNDLES:",f"{CLEAN_BUNDLES}")
log_line(f"OPTIMIZE_DB:",f"{OPTIMIZE_DB}")

for p in DIR_PATH_ARR:
    log_line(f"LIB:",f"{p}")

log_line(f"TMP_DIR:",f"{TMP_DIR}")
log_line(f"DIR_PATH:",f"{DIR_PATH}")
log_line(f"TC_PATH:",f"{TC_PATH}")
log_line(f"DB_PATH:",f"{DB_PATH}")

if RENAME and DELETE:
    send_notifiarr("ERROR", color_r, "PBF config is ambiguous", "Issue:", "RENAME and DELETE are both set; this config is ambiguous, please choose one or the other.", "N/A", "N/A", "ERROR", "PLEX_TOKEN is missing. You will need to update the .env with the token for PLEX")
    log_error_and_exit(f"RENAME and DELETE are both set; this config is ambiguous, please choose one or the other.")
elif DELETE:
    log_line(f"DELETE:","PBF will delete files within the Metadata directories WITHOUT UNDO.")
elif RENAME:
    log_line(f"RENAME:","PBF will rename files within the Metadata directories and CAN BE UNDONE.")
else:
    log_line(f"REPORTONLY:","PBF will report files to be deleted without doing so.")

drawLine()

####################################################################
# UNDO RENAME
####################################################################
if UNDO:
    undo_rename()

# Start time
start_all = time.time()
try:
    ####################################################################
    # Clean PhotoTranscoder Folder
    ####################################################################
    tot_tc_file_size = 0
    tot_tc_files = 0
    sub_start = time.time()
    log_line("Working on:", TC_PATH)
    log_line("STATUS:","Processing PhotoTranscoder files. This will take some time...")
    files = glob.glob(f"{TC_PATH}/**/*.*", recursive=True)
    for f in files:
        p = Path(TC_PATH) / f
        tot_tc_file_size += p.stat().st_size
        tot_tc_files += 1
        if TC_DEL:
            log_file("DELETE----->", p )
            os.remove(f)
        else:
            log_file("SAFE MODE----->", p)
    if TC_DEL:
        sub_folders_list = glob.glob(f"{TC_PATH}/*", recursive=True)
        for sub_folder in sub_folders_list:
          shutil.rmtree(sub_folder)

    sub_end = time.time()

    s_data = {}
    s_data["name"] = "PhotoTranscoder"
    s_data["stopwatch"] = sub_end - sub_start
    s_data["pct_bloat"] = 0 if tot_tc_file_size == 0 else 1
    s_data["meta_size_total"] = 0
    s_data["meta_ct_total"] = 0
    s_data["meta_size_delete"] = 0
    s_data["meta_ct_delete"] = 0
    s_data["tc_size_delete"] = tot_tc_file_size
    s_data["tc_ct_delete"] = tot_tc_files
    s_data["grand_total"] = False

    report_summary(s_data)

    ####################################################################
    # Connect to Plexserver
    ####################################################################
    ps = PlexServer(PLEX_URL, PLEX_TOKEN, timeout=600)

    ####################################################################
    # clear the download target dir
    ####################################################################
    clear_tmp()

    ####################################################################
    # Download DB
    ####################################################################
    start = time.time()

    if not local_run:
        logging.info(f"STATUS:             Sending command to download PLEX DB. This will take some time...\n\
                    To see progress, log into PLEX and goto Settings | Manage | Console and filter on Database\n\
                    You can also look at the PLEX Dashboard to see the progress of the Database backup...\n\
                    Hit CTRL-C now if unsure...")

        dbpath = ps.downloadDatabases(savepath=TMP_DIR, unpack=True)
        # dbpath now contains the name of the zip file, if that's useful
        log_line(f"STATUS:",f"dbpath= {dbpath}")
    else:
        # copy database to tmp_dir
        log_line(f"STATUS:",f"Copying database...")
        import shutil

        shutil.copyfile(f"{DB_PATH}/{PLEX_DB_NAME}", f"{TMP_DIR}/{PLEX_DB_NAME}")
        log_line(f"STATUS:",f"dbpath= {TMP_DIR}/{PLEX_DB_NAME}")

    end = time.time()
    stopwatch = end - start
    if not local_run:
        send_notifiarr("INFO", color_g, "PBF Plex DB transfer", "Info:", f"Download completed: "+f"{stopwatch:.2f} seconds", "N/A", "N/A", "N/A", "N/A")
        log_line(f"Download completed:",f"{stopwatch:.2f} seconds")
    else:
        send_notifiarr("INFO", color_g, "PBF Plex DB transfer", "Info:", f"Copy completed: "+f"{stopwatch:.2f} seconds", "N/A", "N/A", "N/A", "N/A")
        log_line(f"Copy completed:",f"{stopwatch:.2f} seconds")

    ####################################################################
    # Find the downloaded PLEX DB
    ####################################################################
    db_file = ""
    for count, f in enumerate(os.listdir(TMP_DIR)):
        split_tup = os.path.splitext(f)
        if split_tup[1] != ".zip":
            db_file = f"{f}"

    ####################################################################
    # connect to db
    ####################################################################
    if db_file:
        db_path = Path(TMP_DIR) / db_file
        log_line(f"Opening database:",f"{db_path}")
        if db_path.exists():
            conn = sqlite3.connect(f"{db_path}")
            log_line(f"STATUS:",f"Opened database successfully")
        else:
            send_notifiarr("ERROR", color_r, "PBF Plex DB issue", "Issue:", "Database cannot be found", "N/A", "N/A", "N/A", "N/A")
            log_error_and_exit(f"ERROR:",f"Database cannot be found")

        log_line(f"STATUS:",f"Executing {SQLCMD1}")
        cursor1 = conn.execute(SQLCMD1)
        log_line(f"STATUS:",f"Executing {SQLCMD2}")
        cursor2 = conn.execute(SQLCMD2)
        BLOAT_RUN = True
    else:
        send_notifiarr("ERROR", color_r, "PBF Plex DB issue", "Issue:", f"No extracted database found in: {TMP_DIR}. Try to download manually in PLEX and look at logs for any errors. If the downloaded file is a 22kb zip file, there maybe PLEX db issue to address. PBF will continue, though nothing will be deleted from the Metadata subdirectories.", "N/A", "N/A", "N/A", "N/A")
        log_error(f"No extracted database found in: {TMP_DIR}")
        log_line("",f"Try to download manually in PLEX and look at logs for any errors")
        log_line("",f"If the downloaded file is a 22kb zip file, there maybe PLEX db issue to address.")
        log_line("",f"PBF will continue, though nothing will be deleted from the Metadata subdirectories.")
        BLOAT_RUN = False

    ####################################################################
    # Building list of selected uploaded posters
    ####################################################################
    if BLOAT_RUN:
        log_line(f"STATUS:",f"Building list of selected uploaded posters")
        res_sql = []
        for row in cursor1:
            p = urlparse(row[0])
            tmp = p.path.rsplit("/", 1).pop()
            # print("ID = ", tmp)
            res_sql.append(tmp)
        for row in cursor2:
            p = urlparse(row[0])
            tmp = p.path.rsplit("/", 1).pop()
            # print("ID = ", tmp)
            res_sql.append(tmp)

        log_line(f"STATUS:",f"Pulled {len(res_sql)} upload items from the database")

        conn.close()
        clear_tmp()

        ####################################################################
        # Building list of files to compare
        ####################################################################
        log_line(f"STATUS:",f"Building list of files to compare")

        res = []
        file_tot = 0
        file_del = 0
        file_sub_del = 0
        file_sub = 0
        file_size_tot = 0
        file_size_del = 0
        file_size_sub_del = 0
        file_size_sub = 0

        for DIR_PATH in DIR_PATH_ARR:
            sub_start = time.time()
            p = Path(DIR_PATH)
            log_line(f"Working on:",f"{DIR_PATH}")
            for (DIR_PATH, dir_names, file_names) in walk(DIR_PATH):
                for file in file_names:
                    file_size = 0
                    q = Path(DIR_PATH) / file
                    if not q.is_symlink():
                        file_size = q.stat().st_size
                        file_size_tot += file_size
                        file_size_sub += file_size
                        file_tot += 1
                        file_sub += 1
                    if ("." not in file and file not in res_sql) or ".jpg" in file:
                        file_size_del += file_size
                        file_size_sub_del += file_size
                        file_del += 1
                        file_sub_del += 1
                        handle_file(q)

            sub_end = time.time()
            stopwatch_sub = sub_end - sub_start
            pct_bloat = (
                0 if file_size_sub == 0 else ((file_size_sub_del) / (file_size_sub))
            )


            s_data = {}
            s_data["name"] = p.name
            s_data["stopwatch"] = sub_end - sub_start
            s_data["pct_bloat"] = 0 if file_size_sub == 0 else ((file_size_sub_del) / (file_size_sub))
            s_data["meta_size_total"] = file_size_sub
            s_data["meta_ct_total"] = file_sub
            s_data["meta_size_delete"] = file_size_sub_del
            s_data["meta_ct_delete"] = file_sub_del
            s_data["tc_size_delete"] = tot_tc_file_size
            s_data["tc_ct_delete"] = tot_tc_files
            s_data["grand_total"] = False

            report_summary(s_data)

            file_size_sub_del = 0
            file_size_sub = 0
            file_sub_del = 0
            file_sub = 0

    clear_tmp()
    if EMPTY_TRASH:
        et = ps.library.emptyTrash()
        drawLine()
        log_line(f"# EMPTY_TRASH",f"{EMPTY_TRASH}")
        drawLine()
        log_line(f"EMPTY TRASH:",f"{et}")
        log_line(f"STATUS:",f"sleeping for {SLEEP}")
        time.sleep(SLEEP)

    if CLEAN_BUNDLES:
        drawLine()
        log_line(f"# CLEAN_BUNDLES",f"{CLEAN_BUNDLES}")
        drawLine()
        cb = ps.library.cleanBundles()
        log_line(f"CLEAN BUNDLES:",f"{cb}")
        log_line(f"STATUS:",f"sleeping for {SLEEP}")
        time.sleep(SLEEP)

    if OPTIMIZE_DB:
        drawLine()
        log_line(f"# OPTIMIZE_DB",f"{OPTIMIZE_DB}")
        drawLine()
        op = ps.library.optimize()
        log_line(f"OPTIMIZE DB:",f"{op}")
        log_line(f"STATUS:",f"sleeping for {SLEEP}")
        time.sleep(SLEEP)

    end_all = time.time()


    ####################################################################
    # OVERALL SUMMARY
    ####################################################################

    s_data = {}
    s_data["name"] = "Overall"
    s_data["stopwatch"] = end_all - start_all
    s_data["pct_bloat"] = 0 if file_size_tot + tot_tc_file_size == 0 else ((file_size_del + tot_tc_file_size) / (file_size_tot + tot_tc_file_size))
    s_data["meta_size_total"] = file_size_tot
    s_data["meta_ct_total"] = file_tot
    s_data["meta_size_delete"] = file_size_del
    s_data["meta_ct_delete"] = file_del
    s_data["tc_size_delete"] = tot_tc_file_size
    s_data["tc_ct_delete"] = tot_tc_files
    s_data["grand_total"] = True

    report_summary(s_data)
    send_notifiarr("INFO", color_g, "PBF complete", "N/A", "N/A", "N/A", "N/A", "INFO", "PBF Plex Bloat Fix has completed")

except:
    logging.exception(f"Exception raised")
    raise

sys.exit()
