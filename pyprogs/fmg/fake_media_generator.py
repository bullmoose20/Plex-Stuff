import argparse
import glob
import logging
import os
import requests
import shutil
import sys
from datetime import datetime as dt
from dotenv import load_dotenv, find_dotenv

try:
    # Find the .env file
    dotenv_path = find_dotenv(raise_error_if_not_found=True)

    # Load environment variables from .env file
    load_dotenv(dotenv_path)
except OSError:
    print("Error: The .env file was not found. Please make sure it exists in the script's directory.")
    exit(1)

# Retrieve Plex server details from environment variables
# plex_url = os.getenv('PLEX_URL')
# plex_token = os.getenv('PLEX_TOKEN')
# timeout_seconds = int(os.getenv('PLEX_TIMEOUT', 60))  # Default timeout: 60 seconds
max_log_files = int(os.getenv('MAX_LOG_FILES', 10))  # Default number of logs: 10
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()  # Default logging level: INFO

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

# Retrieve TMDB API key from environment variable
TMDB_API_KEY = os.getenv("TMDB_API_KEY")

# Check if TMDB API key is present and not empty
if not TMDB_API_KEY:
    print("TMDB_API_KEY is missing or empty in the .env file. Please provide a valid API key.")
    logging.error("TMDB_API_KEY is missing or empty in the .env file. Please provide a valid API key.")
    exit()


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


def fetch_movie_details(tmdb_id):
    url = f"https://api.themoviedb.org/3/movie/{tmdb_id}?api_key={TMDB_API_KEY}&language=en-US"
    response = requests.get(url)

    # Check for a 404 status code
    if response.status_code == 404:
        print(f"Failed to retrieve <movie> details for TMDb ID {tmdb_id}. Resource not found.")
        logging.warning(f"Failed to retrieve <movie> details for TMDb ID {tmdb_id}. Resource not found.")
        return {}

    data = response.json()

    # Fetch IMDb ID separately
    imdb_id = fetch_imdb_id(tmdb_id, 'movie')

    # Include IMDb ID in the details
    data["imdb_id"] = imdb_id
    return data


def fetch_tv_details(tmdb_id):
    url = f"https://api.themoviedb.org/3/tv/{tmdb_id}?api_key={TMDB_API_KEY}&language=en-US"
    response = requests.get(url)

    # Check for a 404 status code
    if response.status_code == 404:
        print(f"Failed to retrieve <tv> details for TMDb ID {tmdb_id}. Resource not found.")
        logging.warning(f"Failed to retrieve <tv> details for TMDb ID {tmdb_id}. Resource not found.")
        return {}

    data = response.json()

    # Fetch IMDb ID separately
    imdb_id = fetch_imdb_id(tmdb_id, 'tv')

    # Include IMDb ID in the details
    data["imdb_id"] = imdb_id
    return data


def fetch_imdb_id(tmdb_id, media_type):
    if media_type == 'tv':
        url = f"https://api.themoviedb.org/3/tv/{tmdb_id}/external_ids?api_key={TMDB_API_KEY}"
    else:
        # For movies, use a different technique to get IMDb ID
        url = f"https://api.themoviedb.org/3/movie/{tmdb_id}?api_key={TMDB_API_KEY}"

    response = requests.get(url)

    # Check for a 404 status code
    if response.status_code == 404:
        print(f"Failed to retrieve {media_type} information for TMDb ID {tmdb_id}. Resource not found.")
        logging.warning(f"Failed to retrieve {media_type} information for TMDb ID {tmdb_id}. Resource not found.")
        return {}

    data = response.json()

    # Extract IMDb ID from the response
    imdb_id = data.get('imdb_id', '')

    return imdb_id


def create_folders_and_files(details, media_type, imdb_id, season_data=None):
    base_directory = 'movies' if media_type == 'movie' else 'shows'

    # Create folder path
    title = details["title"] if media_type == 'movie' else details["name"]
    folder_path = f"{title} [imdb-{imdb_id}]"
    base_folder_path = os.path.join(base_directory, folder_path)
    os.makedirs(base_folder_path, exist_ok=True)

    if media_type == 'tv':
        for season in season_data:
            season_number = season["season_number"]
            episodes = season["episode_count"]

            for episode_number in range(1, episodes + 1):
                episode_name = f"{title} - S{season_number:02}E{episode_number:02} [WEBDL-1080p][HDR][10bit][h265][EAC3 Atmos 5.1]-FLUX.avi"

                # Create season folder path
                season_folder_path = os.path.join(base_folder_path, f"Season {season_number:02}")
                os.makedirs(season_folder_path, exist_ok=True)

                # Create file path and copy sample.avi
                filepath = os.path.join(season_folder_path, episode_name.replace('.mkv', '.avi'))
                shutil.copy('sample.avi', filepath)
    else:
        # For movies, create file path and copy sample.avi
        filepath = os.path.join(base_folder_path, f"{title} [WEBDL-1080p][HDR][10bit][h265][EAC3 Atmos 5.1]-FLUX.avi")
        shutil.copy('sample.avi', filepath)


def display_options(options):
    print("Multiple entries found. Please choose one:")
    for index, entry in enumerate(options, 1):
        media_type = 'Movie' if 'title' in entry else 'TV Show'
        title = entry.get('title') if 'title' in entry else entry.get('name', 'Unknown Title')
        print(f"{index}. {title} ({media_type} - ID: {entry['id']})")
        logging.info(f"{index}. {title} ({media_type} - ID: {entry['id']})")


def main():
    parser = argparse.ArgumentParser(
        description="Fetch and organize details about movies or TV shows using the TMDb API.")

    # Add the --tmdbid argument
    parser.add_argument("--tmdbid", type=int, help="TMDb ID for the movie or TV show")

    args = parser.parse_args()

    # Use the provided TMDb ID or prompt the user if not provided
    tmdb_id = args.tmdbid or input("Enter TMDb ID: ")

    # Log the command along with its arguments
    logging.info(f"Command: {' '.join(['python'] + os.sys.argv)}")
    logging.info(f"Arguments: {args}")

    movie_details = fetch_movie_details(tmdb_id)
    tv_details = fetch_tv_details(tmdb_id)

    if not movie_details and not tv_details:
        print("Invalid TMDb ID. Make sure the TMDb ID is correct.")
        logging.error("Invalid TMDb ID. Make sure the TMDb ID is correct.")
        return

    if movie_details and tv_details:
        # Display titles and prompt the user to choose
        options = [movie_details, tv_details]
        display_options(options)
        choice = input("Enter the number corresponding to your choice: ")

        try:
            chosen_option = options[int(choice) - 1]
        except (ValueError, IndexError):
            print("Invalid choice. Exiting.")
            return
    elif movie_details:
        chosen_option = movie_details
    else:
        chosen_option = tv_details

    media_type = 'movie' if 'title' in chosen_option else 'tv'
    imdb_id = chosen_option.get("imdb_id", "")
    season_data = tv_details.get("seasons", []) if media_type == 'tv' else None

    print(f"IMDb ID for {media_type}: {imdb_id}")
    logging.info(f"IMDb ID for {media_type}: {imdb_id}")

    # Continue with the rest of your script
    create_folders_and_files(chosen_option, media_type, imdb_id, season_data)
    print(
        f"Folders and files created successfully for <{media_type}> {chosen_option['title'] if media_type == 'movie' else chosen_option['name']}.")
    logging.info(
        f"Folders and files created successfully for <{media_type}> {chosen_option['title'] if media_type == 'movie' else chosen_option['name']}.")


if __name__ == "__main__":
    main()

    # Call the clean_up_old_logs function
    clean_up_old_logs()

