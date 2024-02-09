import os
import sys
import glob
import time
import titlecase
import argparse
import plexapi
import logging
from plexapi.server import PlexServer
from dotenv import load_dotenv
from requests.exceptions import RequestException

# Load environment variables from .env file
load_dotenv()

plex_url = os.getenv("PLEX_URL")
plex_token = os.getenv("PLEX_TOKEN")
timeout_seconds = int(os.getenv('PLEX_TIMEOUT', 60))  # Default timeout: 60 seconds
max_log_files = int(os.getenv('MAX_LOG_FILES', 10))  # Default number of logs: 10
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()  # Default logging level: INFO

# Check if Plex URL and token are defined
if plex_url is None or plex_token is None:
    print("Error: Plex URL or token not found in .env file.")
    sys.exit(1)

# Set up Plex server connection
plex = None

import argparse
import sys

# Set up command-line argument parser
parser = argparse.ArgumentParser(description='Update Plex Track Title Case to Sentence-Case or Title-Case')
parser.add_argument('--apply', action='store_true', help='Apply changes.')
parser.add_argument('--title-case', action='store_true', help='Use title case for track titles.')
parser.add_argument('--sentence-case', action='store_true', help='Use sentence case for track titles.')

# Parse command-line arguments
args = parser.parse_args()

# Validate command-line arguments
if args.apply and not (args.title_case or args.sentence_case):
    print("Error: When using --apply, either --title-case or --sentence-case must be specified.")
    sys.exit(1)

# Prompt the user for confirmation if --apply is used
if args.apply:
    confirmation = input("Applying changes! Are you sure you want to continue? (y/n): ").lower()
    if confirmation != 'y':
        print("Aborted.")
        sys.exit(0)

# Generate a unique log filename with timestamp
timestamp = time.strftime("%Y%m%d_%H%M%S")
log_filename = f"extract_tracks_{timestamp}.log"

# Set up logging with timestamps and the specified logging level
log_format = '%(asctime)s - %(levelname)s - %(message)s'
logging.basicConfig(filename=log_filename, level=getattr(logging, log_level), format=log_format)

try:
    # Set the timeout globally for all requests
    import requests
    requests.adapters.DEFAULT_TIMEOUT = timeout_seconds

    # Set up Plex server connection
    plex = PlexServer(plex_url, plex_token)

except RequestException as e:
    logging.error(f"Error connecting to Plex server: {e}")
    sys.exit(1)
except plexapi.exceptions.BadRequest as e:
    logging.error(f"Plex API Bad Request: {e}")
    logging.error(f"Details: {str(e)}")
    sys.exit(1)


class PlexTrackProcessor:
    def __init__(self, use_title_case=False, use_sentence_case=False):
        self.total_tracks = 0
        self.tracks_bad_case = 0
        self.use_title_case = use_title_case
        self.use_sentence_case = use_sentence_case

    def is_title_case(self, s):
        return s.istitle()

    def is_sentence_case(self, s):
        # Check if the string is in sentence case
        return s[0].isupper() and s[1:].islower()

    def detect_case(self, track_title):
        if self.use_title_case:
            return "Title Case"
        elif self.use_sentence_case:
            return "Sentence Case"
        else:
            return "Original Case"

    def process_title_case(self, track_title):
        return titlecase.titlecase(
            track_title) if self.use_title_case else track_title.capitalize() if self.use_sentence_case else track_title

    def process_title_case2(self, track_title):
        return track_title.title() if self.use_title_case else track_title.capitalize() if self.use_sentence_case else track_title

    def process_sentence_case(self, track_title):
        return track_title.capitalize() if not self.is_sentence_case(track_title) else track_title

    def extract_tracks(self):
        # Iterate through all music libraries
        for music_library in plex.library.sections():
            if music_library.type == "artist":
                for artist in music_library.all():
                    print(f"Artist: {artist.title}")
                    logging.info(f"Artist: {artist.title}")
                    for album in artist.albums():
                        print(f"  Album: {album.title}")
                        logging.info(f"  Album: {album.title}")
                        for track in album.tracks():
                            track_title = track.title
                            self.total_tracks += 1

                            # Check if the track title needs processing based on user's choice
                            if self.use_title_case and not self.is_title_case(track_title):
                                processed_title = self.process_title_case(track_title)
                            elif self.use_sentence_case and not self.is_sentence_case(track_title):
                                processed_title = self.process_sentence_case(track_title)
                            else:
                                processed_title = track_title

                            # Log and print warnings if necessary
                            if processed_title != track_title:
                                self.tracks_bad_case += 1
                                case_info = "Title Case" if self.use_title_case else "Sentence Case" if self.use_sentence_case else "Original Case"
                                print(f"    Warning  : Track title is not in {case_info} - {track_title}")
                                print(f"    New Title: Track title is now in {case_info} - {processed_title}")
                                logging.warning(f"Warning  : Track title is not in {case_info} - {track_title}")
                                logging.warning(f"New Title: Track title is now in {case_info} - {processed_title}")

                                # Update track title in Plex if --apply argument is provided
                                if args.apply:
                                    track.editTitle(title=processed_title)
                                    print(f"    Updated in Plex! New Title: {processed_title}")
                                    logging.info(f"    Updated in Plex! New Title: {processed_title}")

                            print(f"    Track: {track_title}")
                            logging.info(f"    Track: {track_title}")

    def log_summary(self, mode, script_duration):
        case_info = "Title Case" if self.use_title_case else "Sentence Case" if self.use_sentence_case else "Original Case"

        logging.info(f"Script completed in {mode} mode with chosen case: {case_info}.")
        logging.info(f"Total tracks processed: {self.total_tracks}")
        logging.info(f"Tracks with bad case: {self.tracks_bad_case}")
        logging.info(f"Script duration: {script_duration: .2f} seconds")
        print(f"Script completed in {mode} mode with chosen case: {case_info}.")
        print(f"Total tracks processed: {self.total_tracks}")
        print(f"Tracks with bad case: {self.tracks_bad_case}")
        print(f"Script duration: {script_duration: .2f} seconds")


def clean_up_old_logs():
    global max_log_files

    # Set max_log_files to 1 if it's 0 or negative
    if max_log_files <= 0:
        max_log_files = 1

    # Remove old log files if there are more than the allowed number
    existing_logs = glob.glob("extract_tracks_*.log")
    if len(existing_logs) > max_log_files:
        logging.info(f"existing_logs: {len(existing_logs)} > max_log_files: {max_log_files}")
        oldest_logs = sorted(existing_logs)[:-max_log_files]
        for old_log in oldest_logs:
            os.remove(old_log)


if __name__ == "__main__":
    try:
        # Determine mode outside the conditional block
        if args.apply:
            mode = 'Apply'
        else:
            mode = 'Report'

        # Initialize PlexTrackProcessor with case options
        track_processor = PlexTrackProcessor(use_title_case=args.title_case, use_sentence_case=args.sentence_case)
        start_time = time.time()

        # Call the extract_tracks method
        track_processor.extract_tracks()

        end_time = time.time()
        script_duration = end_time - start_time

        # Call the log_summary method
        track_processor.log_summary(mode, script_duration)

    except Exception as e:
        # Log any unhandled exceptions
        logging.error(f"An unexpected error occurred: {e}", exc_info=True)

    # Call the clean_up_old_logs function
    clean_up_old_logs()
