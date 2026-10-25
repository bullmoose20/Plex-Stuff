import requests
import argparse
import datetime
import logging
import os
import plexapi
import re
import sys
import time
import urllib.parse
from dotenv import load_dotenv
from plexapi.server import PlexServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from plex_stuff_helpers import configure_logging, get_formatted_duration, prune_logs, connect_plex


def clean_up_old_logs():
    global max_log_files
    max_log_files = prune_logs(logs_directory, script_name, max_log_files)


def main():
    """Run the command explicitly; importing never contacts services."""
    global max_log_files, script_name, logs_directory
    parser = argparse.ArgumentParser(description="Update Plex artist art.")

    group = parser.add_mutually_exclusive_group(required=True)

    group.add_argument("--apply", action="store_true", help="Apply changes.")

    group.add_argument("--report", action="store_true", help="Report changes without applying them.")

    args = parser.parse_args()

    load_dotenv()

    max_log_files, script_name, logs_directory, timestamp = configure_logging()

    plex = connect_plex(PlexServer)
    plex_url, plex_token = os.getenv("PLEX_URL"), os.getenv("PLEX_TOKEN")

    subfolder = "output"

    if not os.path.exists(subfolder):
        os.makedirs(subfolder)

    libraries = plex.library.sections()

    total_artists = 0

    artists_with_missing_art = 0

    start_time = time.time()

    mode = "Report" if args.report else "Apply"

    timestamp = time.strftime("%Y%m%d_%H%M%S")

    log_filename = f"update_plex_artist_art_{timestamp}.log"

    log_format = "%(asctime)s - %(levelname)s - %(message)s"

    logging.basicConfig(filename=log_filename, level=logging.DEBUG, format=log_format)

    try:
        # Loop through all libraries
        for library in libraries:
            logging.info(f"{mode} - Processing library: {library.title}")

            # Check if it's a music library
            if library.type == "artist":
                # Process artists in the music library
                for artist in library.all():
                    total_artists += 1

                    # Check if artist has no art
                    if not artist.thumb:
                        artists_with_missing_art += 1
                        # Find the latest album
                        if artist.albums():
                            latest_album = max(
                                artist.albums(),
                                key=lambda x: (
                                    x.originallyAvailableAt
                                    if isinstance(x.originallyAvailableAt, datetime.datetime)
                                    else datetime.datetime.min
                                ),
                            )
                        else:
                            logging.warning(f"Warning - Artist: {artist.title} has no albums. Skipping update.")
                            continue  # Skip to the next artist if there are no albums

                        # Log the information without making changes
                        logging.info(
                            f"{mode.capitalize()} - Would update artist: {artist.title}, Album: {latest_album.title}"
                        )

                        # Check if the latest album has a poster
                        if not latest_album.thumb:
                            logging.warning(
                                f"Warning - Artist: {artist.title}, Latest Album: {latest_album.title} has no poster. Skipping update."
                            )
                        else:
                            # Retrieve album art URL (relative path)
                            album_art_relative_path = latest_album.thumb

                            # Build the complete album art URL using Plex server's base URL
                            album_art_url = urllib.parse.urljoin(plex_url, album_art_relative_path)

                            # Download the album art with Plex Token in headers
                            headers = {"X-Plex-Token": plex_token}
                            response = requests.get(album_art_url, headers=headers, timeout=60)

                            if response.status_code == 200 and len(response.content) > 0:
                                # Sanitize the filename before saving
                                sanitized_artist_title = re.sub(r"[^\w\s.-]", "_", artist.title)
                                sanitized_album_title = re.sub(r"[^\w\s.-]", "_", latest_album.title)

                                # Update the local_file_path to include the subfolder
                                local_file_path = os.path.join(
                                    subfolder, f"{sanitized_artist_title}_{sanitized_album_title}_art.jpg"
                                )

                                # Save the downloaded image locally in the subfolder
                                with open(local_file_path, "wb") as image_file:
                                    image_file.write(response.content)

                                if args.apply:
                                    try:
                                        # Update the artist's thumbnail with the downloaded image
                                        logging.info(
                                            f"Apply - Updated artist: {artist.title}, Album: {latest_album.title}"
                                        )
                                        artist.uploadPoster(None, local_file_path)
                                    except plexapi.exceptions.BadRequest as e:
                                        logging.error(
                                            f"Error applying changes to artist {artist.title}: {type(e).__name__}"
                                        )
                                        logging.error(f"Details: {type(e).__name__}")
                                    except Exception as e:
                                        logging.error(f"An unexpected error occurred: {type(e).__name__}")
                            else:
                                logging.error(
                                    f"Failed to download album art for {artist.title}: HTTP status {response.status_code}"
                                )

        # Record script end time
        end_time = time.time()

        # Calculate script duration
        script_duration = end_time - start_time

        # Log summary
        print(f"Script completed in {mode} mode.")
        print(f"Total artists processed: {total_artists}")
        print(f"Artists with missing art: {artists_with_missing_art}")
        print(f"Script duration: {get_formatted_duration(script_duration)}")
        logging.info(f"Script completed in {mode} mode.")
        logging.info(f"Total artists processed: {total_artists}")
        logging.info(f"Artists with missing art: {artists_with_missing_art}")
        logging.info(f"Script duration: {get_formatted_duration(script_duration)}")

    except Exception as e:
        # Log any unhandled exceptions
        logging.error(f"An unexpected error occurred: {type(e).__name__}")

    print(f"DONE! Check log for more information: {log_filename}")

    clean_up_old_logs()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Command failed ({type(error).__name__}). Check configuration and inputs.")
        raise SystemExit(1) from None
