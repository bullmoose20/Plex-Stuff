####################################################################
# REQUIREMENTS
####################################################################
# PlexAPI
# python-dotenv
# SQLAlchemy

__version__ = "1.2.2"
from xmlrpc.client import Boolean
from operator import itemgetter, attrgetter
from plexapi.server import PlexServer
import os, sys, sqlite3, glob, time, logging, platform, logging.handlers
from os import walk
from urllib.parse import urlparse
from dotenv import load_dotenv

####################################################################
# FUNCTIONS
####################################################################


def undo_rename():
    logging.info("UNDO starting and this will take time....")
    start = time.time()
    for DIR_PATH in DIR_PATH_ARR:
        files = glob.glob(f"{DIR_PATH}/**/*.jpg", recursive=True)
        logging.info(f"Working on: {DIR_PATH}")
        for f in files:
            tempTuple = os.path.splitext(f)
            logging.info(f"{f} --> {tempTuple[0]}")
            os.rename(f, tempTuple[0])

    logging.info("UNDO Complete")
    end = time.time()
    stopwatch = end - start
    logging.info(f"UNDO time: {str(stopwatch)} seconds")

    sys.exit()


def format_bytes(size):
    # 2**10 = 1024
    power = 2**10
    n = 0
    power_labels = {0: "", 1: "kilo", 2: "mega", 3: "giga", 4: "tera"}
    while size > power:
        size /= power
        n += 1
    return size, power_labels[n] + "bytes"


load_dotenv()

LOG_FILENAME = "plex-bloat-fix.log"

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
# Clear screen
####################################################################
os.system("cls||clear")

logging.info(f"#######################################################################")
logging.info(f"# Starting plex-bloat-fix.py Ver:{__version__} ")
logging.info(f"#######################################################################")
logging.info(f"Log file:           {LOG_FILENAME} created...")

####################################################################
# VARS
####################################################################
TC_DEL = Boolean(int(0))
TC_DEL = Boolean(int(os.getenv("TC_DEL")))
UNDO = Boolean(int(0))
UNDO = Boolean(int(os.getenv("UNDO")))
RENAME = Boolean(int(0))
RENAME = Boolean(int(os.getenv("RENAME")))
DELETE = Boolean(int(0))
DELETE = Boolean(int(os.getenv("DELETE")))
EMPTY_TRASH = Boolean(int(0))
EMPTY_TRASH = Boolean(int(os.getenv("EMPTY_TRASH")))
CLEAN_BUNDLES = Boolean(int(0))
CLEAN_BUNDLES = Boolean(int(os.getenv("CLEAN_BUNDLES")))
OPTIMIZE_DB = Boolean(int(0))
OPTIMIZE_DB = Boolean(int(os.getenv("OPTIMIZE_DB")))
SLEEP = 60
SLEEP = int(os.getenv("SLEEP"))
TC_PATH = os.getenv("TC_PATH")
DIR_PATH = os.getenv("DIR_PATH")
TMP_DIR = os.getenv("TMP_DIR")
PLEX_URL = os.getenv("PLEX_URL")
PLEX_TOKEN = os.getenv("PLEX_TOKEN")
dbpath = ""
file_size_tot = 0
file_size_del = 0
####################################################################
# MAIN
####################################################################
SQLCMD = (
    "SELECT user_thumb_url FROM metadata_items WHERE user_thumb_url like 'upload://%';"
)
LIBS = ["Movies", "TV Shows", "Playlists", "Collections", "Artists", "Albums"]

TMP_DIR = os.path.join(TMP_DIR, "")
DIR_PATH = os.path.join(DIR_PATH, "")

DIR_PATH_ARR = []
for lib in LIBS:
    DIR_PATH_ARR.append(os.path.join(DIR_PATH, lib))

if PLEX_URL is None:
    logging.info("Your .env file is incomplete or missing: PLEX_URL is empty")
    exit()

if "PhotoTranscoder" not in TC_PATH and TC_DEL:
    logging.info(
        "Your .env file is incomplete or missing: TC_DIR is missing a critical folder"
    )
    exit()

logging.info(f"UNDO is:            {UNDO}")
logging.info(f"RENAME is:          {RENAME}")
logging.info(f"DELETE is:          {DELETE}")
logging.info(f"DIR_PATH is:        {DIR_PATH}")
logging.info(f"TC_PATH is:         {TC_PATH}")
logging.info(f"TC_DEL is:          {TC_DEL}")
logging.info(f"SLEEP is:           {SLEEP}")
logging.info(f"EMPTY_TRASH is:     {EMPTY_TRASH}")
logging.info(f"CLEAN_BUNDLES is:   {CLEAN_BUNDLES}")
logging.info(f"OPTIMIZE_DB is:     {OPTIMIZE_DB}")

for p in DIR_PATH_ARR:
    logging.info(f"LIB is:             {p}")
logging.info(f"TMP_DIR is:         {TMP_DIR}")

if RENAME and DELETE:
    logging.info(
        f"RENAME and DELETE:  This will skip the rename and just delete the files within the Metadata directories. UNDO is NOT possible. I hope you know what you are doing!"
    )
elif DELETE:
    logging.info(
        f"DELETE:             This will skip the rename and just delete the files within the Metadata directories. UNDO is NOT possible. I hope you know what you are doing!"
    )
elif RENAME:
    logging.info(
        f"RENAME:             This will rename the files within the Metadata directories to .jpg files to simulate a delete and allows you to UNDO if needed"
    )
else:
    logging.info(
        f"REPORTONLY:         This will report only the files that would be renamed or deleted within the Metadata directories"
    )

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
    if TC_DEL:
        logging.info(f"Working on: {TC_PATH}")
        logging.info(f"Deleting PhotoTranscoder jpg files. This will take some time...")
        files = glob.glob(f"{TC_PATH}/**/*.jpg", recursive=True)
        files2 = glob.glob(f"{TC_PATH}/**/*.ppm", recursive=True)
        for f in files:
            logging.info(f"DELETE-----> {os.path.join(TC_PATH, f)}")
            file_size = os.path.getsize(os.path.join(TC_PATH, f))
            tot_tc_file_size += file_size
            os.remove(f)
        for f in files2:
            logging.info(f"DELETE-----> {os.path.join(TC_PATH, f)}")
            file_size = os.path.getsize(os.path.join(TC_PATH, f))
            tot_tc_file_size += file_size
            os.remove(f)
    else:
        logging.info(f"Working on: {TC_PATH}")
        logging.info(
            f"Verifying PhotoTranscoder jpg files. This will take some time..."
        )
        files = glob.glob(f"{TC_PATH}/**/*.jpg", recursive=True)
        files2 = glob.glob(f"{TC_PATH}/**/*.ppm", recursive=True)
        for f in files:
            logging.info(f"SAFEMODE-----> {os.path.join(TC_PATH, f)}")
            file_size = os.path.getsize(os.path.join(TC_PATH, f))
            tot_tc_file_size += file_size
        for f in files2:
            logging.info(f"SAFEMODE-----> {os.path.join(TC_PATH, f)}")
            file_size = os.path.getsize(os.path.join(TC_PATH, f))
            tot_tc_file_size += file_size

    logging.info(f"Total TC Size: {format_bytes(tot_tc_file_size)}")

    ####################################################################
    # Connect to Plexserver
    ####################################################################
    ps = PlexServer(PLEX_URL, PLEX_TOKEN, timeout=600)

    ####################################################################
    # clear the download target dir
    ####################################################################
    logging.info(f"Deleting all files in PLEX DB download directory: {TMP_DIR}...")
    files = glob.glob(f"{TMP_DIR}*")
    for f in files:
        os.remove(f)

    ####################################################################
    # Download DB
    ####################################################################
    start = time.time()

    logging.info(f"Sending command to download PLEX DB. This will take some time...")
    logging.info(
        f"To see progress, log into PLEX and goto Settings | Manage | Console and filter on Database"
    )
    logging.info(
        f"You can also look at the PLEX Dashboard to see the progress of the Database backup..."
    )
    logging.info(f"Hit CTRL-C now if unsure...")

    dbpath = ps.downloadDatabases(savepath=TMP_DIR, unpack=True)
    # dbpath now contains the name of the zip file, if that's useful
    logging.info(f"dbpath= {dbpath}")

    end = time.time()
    stopwatch = end - start
    logging.info(f"Download completed in: {str(stopwatch)} seconds")

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
        logging.info(f"Opening database: {TMP_DIR + db_file}")
        conn = sqlite3.connect(f"{TMP_DIR + db_file}")
        logging.info(f"Opened database successfully")
        logging.info(f"Executing {SQLCMD}")
        cursor = conn.execute(SQLCMD)
        BLOAT_RUN = True
    else:
        logging.info(
            f"ERROR with Extraction of database in this directory: {TMP_DIR} not found"
        )
        logging.info(
            f"Try to download manually in PLEX and look at logs for any errors"
        )
        logging.info(
            f"If the file downloaded is a zip file 22kb in size this indicates a PLEX db issue that needs to be resolved. The script will continue, however nothing will be deleted in the Metadata subdirectories...  "
        )
        BLOAT_RUN = False
        # sys.exit()

    ####################################################################
    # Building list of selected uploaded posters
    ####################################################################
    if BLOAT_RUN:
        logging.info(f"Building list of selected uploaded posters")
        res_sql = []
        for row in cursor:
            p = urlparse(row[0])
            tmp = p.path.rsplit("/", 1).pop()
            # print("ID = ", tmp)
            res_sql.append(tmp)

        logging.info(f"Operation done successfully")

        conn.close()

        ####################################################################
        # Building list of files to compare
        ####################################################################
        logging.info(f"Building list of files to compare")

        res = []
        file_size_tot = 0
        file_size_del = 0
        file_size_sub_del = 0
        file_size_sub = 0

        for DIR_PATH in DIR_PATH_ARR:
            sub_start = time.time()
            working_on = DIR_PATH
            logging.info(f"Working on: {DIR_PATH}")
            for (DIR_PATH, dir_names, file_names) in walk(DIR_PATH):
                for file in file_names:
                    if "." not in file:
                        file_size = os.path.getsize(os.path.join(DIR_PATH, file))
                        file_size_tot += file_size
                        file_size_sub += file_size
                        if file not in res_sql:
                            file_size_del += file_size
                            file_size_sub_del += file_size
                            if RENAME and DELETE:
                                logging.info(
                                    f"DELETE-----> {os.path.join(DIR_PATH, file)}"
                                )
                                os.remove(os.path.join(DIR_PATH, file))
                            elif DELETE:
                                logging.info(
                                    f"DELETE-----> {os.path.join(DIR_PATH, file)}"
                                )
                                os.remove(os.path.join(DIR_PATH, file))
                            elif RENAME:
                                logging.info(
                                    f"RENAME-----> {os.path.join(DIR_PATH, file)}"
                                )
                                os.rename(
                                    os.path.join(DIR_PATH, file),
                                    os.path.join(DIR_PATH, file) + ".jpg",
                                )
                            else:
                                logging.info(
                                    f"SAFEMODE-----> {os.path.join(DIR_PATH, file)}"
                                )
                    elif ".jpg" in file:
                        file_size = os.path.getsize(os.path.join(DIR_PATH, file))
                        file_size_tot += file_size
                        file_size_sub += file_size
                        file_size_del += file_size
                        file_size_sub_del += file_size
                        if RENAME and DELETE:
                            logging.info(f"DELETE-----> {os.path.join(DIR_PATH, file)}")
                            os.remove(os.path.join(DIR_PATH, file))
                        elif DELETE:
                            logging.info(f"DELETE-----> {os.path.join(DIR_PATH, file)}")
                            os.remove(os.path.join(DIR_PATH, file))
                        elif RENAME:
                            logging.info(f"RENAME-----> {os.path.join(DIR_PATH, file)}")
                        else:
                            logging.info(
                                f"SAFEMODE-----> {os.path.join(DIR_PATH, file)}"
                            )

            sub_end = time.time()
            stopwatch_sub = sub_end - sub_start
            pct_bloat = (
                0 if file_size_sub == 0 else ((file_size_sub_del) / (file_size_sub))
            )
            if file_size_sub > 0:
                logging.info(
                    f"#######################################################################"
                )
                logging.info(f"# SUBTOTAL SUMMARY: {working_on}")
                logging.info(
                    f"#######################################################################"
                )
            else:
                logging.info(
                    f"#######################################################################"
                )
                logging.info(f"# NO ACTION TAKEN ON {working_on}")
                logging.info(
                    f"#######################################################################"
                )

            logging.info(f"plex-bloat-fix subtotal time: {str(stopwatch_sub)} seconds")
            logging.info(f"UNDO Mode:                    {UNDO}")
            logging.info(f"RENAME Mode:                  {RENAME}")
            logging.info(f"DELETE Mode:                  {DELETE}")
            logging.info(f"TC DELETE Mode:               {TC_DEL}")
            logging.info(
                f"Total TC Size Found:          {format_bytes(tot_tc_file_size)}"
            )
            logging.info(
                f"SubTotal Meta File Size Found:{format_bytes(file_size_sub_del)}"
            )
            logging.info(f"SubTotal Meta File Size:      {format_bytes(file_size_sub)}")
            logging.info(f"Pct Plex Bloat:               " + "{:.2%}".format(pct_bloat))
            logging.info(
                f"#######################################################################"
            )
            file_size_sub_del = 0
            file_size_sub = 0

    if EMPTY_TRASH:
        et = ps.library.emptyTrash()
        logging.info(
            f"###################################################################"
        )
        logging.info(f"# EMPTY_TRASH = {EMPTY_TRASH}")
        logging.info(
            f"###################################################################"
        )
        logging.info(f"et= {et}")
        logging.info(f"sleeping for {SLEEP}")
        time.sleep(SLEEP)

    if CLEAN_BUNDLES:
        logging.info(
            f"###################################################################"
        )
        logging.info(f"# CLEAN_BUNDLES = {CLEAN_BUNDLES}")
        logging.info(
            f"###################################################################"
        )
        cb = ps.library.cleanBundles()
        logging.info(f"cb= {cb}")
        logging.info(f"sleeping for {SLEEP}")
        time.sleep(SLEEP)

    if OPTIMIZE_DB:
        logging.info(
            f"###################################################################"
        )
        logging.info(f"# OPTIMIZE_DB = {OPTIMIZE_DB}")
        logging.info(
            f"###################################################################"
        )
        op = ps.library.optimize()
        logging.info(f"op= {op}")
        logging.info(f"sleeping for {SLEEP}")
        time.sleep(SLEEP)

    end_all = time.time()
    stopwatch = end_all - start_all
    pct_bloat = (
        0
        if file_size_tot + tot_tc_file_size == 0
        else ((file_size_del + tot_tc_file_size) / (file_size_tot + tot_tc_file_size))
    )
    ####################################################################
    # OVERALL SUMMARY
    ####################################################################

    logging.info(
        f"#######################################################################"
    )
    logging.info(
        f"# OVERALL SUMMARY:                                                    #"
    )
    logging.info(
        f"#######################################################################"
    )
    logging.info(f"plex-bloat-fix overall time: {str(stopwatch)} seconds")
    logging.info(f"UNDO Mode:                   {UNDO}")
    logging.info(f"RENAME Mode:                 {RENAME}")
    logging.info(f"DELETE Mode:                 {DELETE}")
    logging.info(f"TC DELETE Mode:              {TC_DEL}")
    logging.info(f"Total TC Size Found:         {format_bytes(tot_tc_file_size)}")
    logging.info(f"Total Meta File Size Found:  {format_bytes(file_size_del)}")
    logging.info(f"Total Meta File Size:        {format_bytes(file_size_tot)}")
    logging.info(
        f"Grand Total File Size Found: {format_bytes((file_size_del + tot_tc_file_size))}"
    )
    logging.info(
        f"Grand Total File Size:       {format_bytes((file_size_tot + tot_tc_file_size))}"
    )
    logging.info(f"Total Pct Plex Bloat:        " + "{:.2%}".format(pct_bloat))
    logging.info(
        f"Total space savings:         {format_bytes((file_size_del + tot_tc_file_size))}"
    )
    logging.info(
        f"#######################################################################"
    )

except:
    logging.exception(f"Exception raised")
    raise

sys.exit()
