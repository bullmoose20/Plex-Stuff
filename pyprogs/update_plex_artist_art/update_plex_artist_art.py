import argparse
import datetime
import glob
import logging
import os
import plexapi
import re
import sys
import time
import urllib.parse
from datetime import datetime as dt
from dotenv import load_dotenv, find_dotenv
from plexapi.server import PlexServer
from requests.exceptions import RequestException

try:
    # Find the .env file
    dotenv_path = find_dotenv(raise_error_if_not_found=True)

    # Load environment variables from .env file
    load_dotenv(dotenv_path)
except OSError:
    print("Error: The .env file was not found. Please make sure it exists in the script's directory.")
    exit(1)

# Retrieve Plex server details from environment variables
plex_url = os.getenv('PLEX_URL')
plex_token = os.getenv('PLEX_TOKEN')
timeout_seconds = int(os.getenv('PLEX_TIMEOUT', 60))  # Default timeout: 60 seconds
max_log_files = int(os.getenv('MAX_LOG_FILES', 10))  # Default number of logs: 10
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()  # Default logging level: INFO

# Check if Plex URL and token are defined
if plex_url is None or plex_token is None:
    print("Error: Plex URL or token not found in .env file.")
    sys.exit(1)

# Extract the script name without the '.py' extension
script_name = os.path.splitext(os.path.basename(sys.argv[0]))[0]

# Define the logs directory
logs_directory = "logs"

# Ensure the "logs" directory exists
if not os.path.exists(logs_directory):
    os.makedirs(logs_directory)

# Generate a unique log filename with timestamp and script name
timestamp = dt.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
log_filename = os.path.join(logs_directory, f"{script_name}_{timestamp}.log")

# Set up logging with timestamps and the specified logging level
log_format = '%(asctime)s - %(levelname)s - %(message)s'
logging.basicConfig(filename=log_filename, level=getattr(logging, log_level), format=log_format)

# Set up Plex server connection
plex = None

try:
    # Set the timeout globally for all requests
    import requests
    requests.adapters.DEFAULT_TIMEOUT = timeout_seconds

    # Set up Plex server connection
    plex = PlexServer(plex_url, plex_token)

# Inside the except block
except RequestException as e:
    logging.error(f"Error connecting to Plex server: {e}")
    sys.exit(1)
except plexapi.exceptions.BadRequest as e:
    logging.error(f"Plex API Bad Request: {e}")
    logging.error(f"Details: {str(e)}")

    sys.exit(1)

# Set the name of the subfolder
subfolder = "artist_thumbnails"

# Ensure the subfolder exists, create it if necessary
if not os.path.exists(subfolder):
    os.makedirs(subfolder)

# Set up command-line argument parser
parser = argparse.ArgumentParser(description='Update Plex artist art.')
group = parser.add_mutually_exclusive_group(required=True)
group.add_argument('--apply', action='store_true', help='Apply changes.')
group.add_argument('--report', action='store_true', help='Report changes without applying them.')
args = parser.parse_args()

# Log the command along with its arguments
logging.info(f"Command: {' '.join(['python'] + sys.argv)}")
logging.info(f"Arguments: {args}")

# Get all libraries/sections
libraries = plex.library.sections()

# Initialize counters
total_artists = 0
artists_with_missing_art = 0

# Record script start time
start_time = time.time()

# Determine mode
mode = 'Report' if args.report else 'Apply'

# Generate a unique log filename with timestamp
timestamp = time.strftime("%Y%m%d_%H%M%S")
log_filename = f"update_plex_artist_art_{timestamp}.log"

# Set up logging with timestamps
log_format = '%(asctime)s - %(levelname)s - %(message)s'
logging.basicConfig(filename=log_filename, level=logging.DEBUG, format=log_format)

try:
    # Loop through all libraries
    for library in libraries:
        logging.info(f"{mode} - Processing library: {library.title}")

        # Check if it's a music library
        if library.type == 'artist':
            # Process artists in the music library
            for artist in library.all():
                total_artists += 1

                # Check if artist has no art
                if not artist.thumb:
                    artists_with_missing_art += 1
                    # Find the latest album
                    if artist.albums():
                        latest_album = max(artist.albums(),
                                           key=lambda x: x.originallyAvailableAt if isinstance(x.originallyAvailableAt,
                                                                                               datetime.datetime) else datetime.datetime.min)
                    else:
                        logging.warning(f"Warning - Artist: {artist.title} has no albums. Skipping update.")
                        continue  # Skip to the next artist if there are no albums

                    # Log the information without making changes
                    logging.info(f"{mode.capitalize()} - Would update artist: {artist.title}, Album: {latest_album.title}")

                    # Check if the latest album has a poster
                    if not latest_album.thumb:
                        logging.warning(f"Warning - Artist: {artist.title}, Latest Album: {latest_album.title} has no poster. Skipping update.")
                    else:
                        # Retrieve album art URL (relative path)
                        album_art_relative_path = latest_album.thumb

                        # Build the complete album art URL using Plex server's base URL
                        album_art_url = urllib.parse.urljoin(plex_url, album_art_relative_path)

                        # Download the album art with Plex Token in headers
                        headers = {'X-Plex-Token': plex_token}
                        response = requests.get(album_art_url, headers=headers)

                        if response.status_code == 200 and len(response.content) > 0:
                            # Sanitize the filename before saving
                            sanitized_artist_title = re.sub(r'[^\w\s.-]', '_', artist.title)
                            sanitized_album_title = re.sub(r'[^\w\s.-]', '_', latest_album.title)

                            # Update the local_file_path to include the subfolder
                            local_file_path = os.path.join(subfolder, f"{sanitized_artist_title}_{sanitized_album_title}_art.jpg")

                            # Save the downloaded image locally in the subfolder
                            with open(local_file_path, 'wb') as image_file:
                                image_file.write(response.content)

                            if args.apply:
                                try:
                                    # Update the artist's thumbnail with the downloaded image
                                    logging.info(f"Apply - Updated artist: {artist.title}, Album: {latest_album.title}")
                                    artist.uploadPoster(None, local_file_path)
                                except plexapi.exceptions.BadRequest as e:
                                    logging.error(f"Error applying changes to artist {artist.title}: {e}")
                                    logging.error(f"Details: {str(e)}")
                                except Exception as e:
                                    logging.error(f"An unexpected error occurred: {e}")
                        else:
                            logging.error(
                                f"Failed to download album art for {artist.title}: HTTP status {response.status_code}")

    # Record script end time
    end_time = time.time()

    # Calculate script duration
    script_duration = end_time - start_time

    # Log summary
    logging.info(f"Script completed in {mode} mode.")
    logging.info(f"Total artists processed: {total_artists}")
    logging.info(f"Artists with missing art: {artists_with_missing_art}")
    logging.info(f"Script duration: {script_duration: .2f} seconds")

except Exception as e:
    # Log any unhandled exceptions
    logging.error(f"An unexpected error occurred: {e}", exc_info=True)


print(f"DONE! Check log for more information: {log_filename}")


def clean_up_old_logs():
    global max_log_files

    # Set max_log_files to 1 if it's 0 or negative
    if max_log_files <= 0:
        max_log_files = 1

    # Remove old log files from the 'logs' subdirectory if there are more than the allowed number
    existing_logs = glob.glob(os.path.join(logs_directory, f"{script_name}_*.log"))
    if len(existing_logs) > max_log_files:
        logging.info(f"existing_logs: {len(existing_logs)} > max_log_files: {max_log_files}")
        oldest_logs = sorted(existing_logs)[:-max_log_files]
        for old_log in oldest_logs:
            os.remove(old_log)


# Call the clean_up_old_logs function
clean_up_old_logs()
