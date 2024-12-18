import os
import logging
from logging.handlers import RotatingFileHandler
from dotenv import load_dotenv, find_dotenv
from plexapi.server import PlexServer
from PIL import Image
from io import BytesIO
import requests
import time
import glob
import gc

# Load environment variables
dotenv_path = find_dotenv(raise_error_if_not_found=True)
load_dotenv(dotenv_path)

PLEX_URL = os.getenv("PLEX_URL")
PLEX_TOKEN = os.getenv("PLEX_TOKEN")
PLEX_TIMEOUT = int(os.getenv("PLEX_TIMEOUT", 60))
MAX_LOG_FILES = int(os.getenv("MAX_LOG_FILES", 10))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

# Persistent HTTP Session
SESSION = requests.Session()
SESSION.headers.update({"Accept": "application/json"})

# Logging setup
script_name = os.path.splitext(os.path.basename(__file__))[0]
logs_directory = "logs"
if not os.path.exists(logs_directory):
    os.makedirs(logs_directory)

timestamp = time.strftime("%Y%m%d_%H%M%S")
log_filename = os.path.join(logs_directory, f"{script_name}_{timestamp}.log")
log_format = '%(asctime)s - %(levelname)s - %(message)s'

logging.basicConfig(level=LOG_LEVEL, format=log_format)
file_handler = RotatingFileHandler(log_filename, maxBytes=5 * 1024 * 1024, backupCount=MAX_LOG_FILES)
file_handler.setFormatter(logging.Formatter(log_format))
logging.getLogger().addHandler(file_handler)

logger = logging.getLogger()

ASPECT_RATIO = 16 / 9  # 1.77777778
OUTPUT_FOLDER = "output"

# Ensure the output folder exists
os.makedirs(OUTPUT_FOLDER, exist_ok=True)


def clean_up_old_logs():
    """Clean up old logs if they exceed the maximum allowed."""
    existing_logs = glob.glob(os.path.join(logs_directory, f"{script_name}_*.log"))
    if len(existing_logs) > MAX_LOG_FILES:
        oldest_logs = sorted(existing_logs)[:-MAX_LOG_FILES]
        for old_log in oldest_logs:
            os.remove(old_log)


def get_media_folder(media):
    """
    Retrieve the Plex folder location for a media item.
    For movies, return the parent folder.
    For TV shows, return the show's full folder name.
    """
    try:
        if media.TYPE == "movie":
            # For movies, return the parent folder of the file
            full_path = media.locations[0]
            parent_folder = os.path.dirname(full_path)  # Parent directory
            return os.path.basename(parent_folder)     # Extract folder name
        elif media.TYPE == "show":
            # For TV episodes, get the root folder from the file path
            full_path = media.locations[0]
            return os.path.basename(full_path)     # Extract folder name
        else:
            return media.title  # Fallback for unknown types
    except Exception as e:
        logger.warning(f"Could not determine folder for media '{media.title}': {e}")
        return media.title  # Fallback to media title


def select_from_list(items, prompt, include_all=False):
    """Display a numbered list of items and allow the user to select one."""
    while True:
        try:
            if include_all:
                print("0. Process all items")
            for idx, item in enumerate(items, start=1):
                print(f"{idx}. {item.title}")
            print()
            choice = int(input(prompt))
            if 0 <= choice <= len(items) if include_all else 1 <= choice <= len(items):
                return choice
            else:
                print("Invalid choice. Please select a valid number from the list.")
        except ValueError:
            print("Invalid input. Please enter a number.")


def resize_and_crop(image, target_width, target_height):
    """Resize and crop an image to the specified dimensions."""
    width, height = image.size
    ratio = width / height

    if abs(ratio - ASPECT_RATIO) < 0.01:
        image = image.resize((1920, 1080), Image.LANCZOS)

    return image.crop((600, 0, 1320, 1080)).resize((target_width, target_height), Image.LANCZOS)


def process_movie(movie, library_name, stats):
    """Process a movie and create a poster.jpg using its background."""
    try:
        if not movie.art:
            logger.warning(f"Skipping {movie.title}: No background art available.")
            stats["skipped"] += 1
            return

        movie_folder = os.path.join(OUTPUT_FOLDER, library_name, get_media_folder(movie))
        os.makedirs(movie_folder, exist_ok=True)

        output_path = os.path.join(movie_folder, "poster.jpg")
        if os.path.exists(output_path):
            logger.info(f"File already exists, skipping: {output_path}")
            stats["skipped"] += 1
            return

        art_url = f"{PLEX_URL}{movie.art}?X-Plex-Token={PLEX_TOKEN}"
        response = SESSION.get(art_url, timeout=PLEX_TIMEOUT)
        response.raise_for_status()

        image = Image.open(BytesIO(response.content))
        resized_image = resize_and_crop(image, 1000, 1500)

        resized_image.save(output_path, format="JPEG", quality=95)
        logger.info(f"Saved: {output_path}")
        print(f"Saved: {output_path}")
        stats["processed"] += 1
    except Exception as e:
        logger.error(f"Error processing {movie.title}: {e}")
        stats["errors"] += 1


def process_episode_thumb(episode, show_output_dir, stats):
    """Download, crop, resize, and save episode thumbnails."""
    try:
        output_path = os.path.join(show_output_dir, f"S{episode.seasonNumber:02}E{episode.index:02}.jpg")
        if os.path.exists(output_path):
            logger.info(f"File already exists, skipping: {output_path}")
            stats["skipped"] += 1
            return

        thumb_url = f"{PLEX_URL}{episode.thumb}?X-Plex-Token={PLEX_TOKEN}"
        response = SESSION.get(thumb_url, timeout=PLEX_TIMEOUT)
        response.raise_for_status()

        image = Image.open(BytesIO(response.content))
        resized_image = resize_and_crop(image, 1000, 1500)

        resized_image.save(output_path, format="JPEG", quality=95)
        logger.info(f"Saved: {output_path}")
        print(f"Saved: {output_path}")
        stats["processed"] += 1
    except Exception as e:
        logger.error(f"Error processing episode '{episode.title}': {e}")
        stats["errors"] += 1


def process_tv_show(show, library_name, stats):
    """Process a TV show, create a poster for the show, and generate episode cards."""
    try:
        episodes = show.episodes()
        stats["total"] += len(episodes)

        show_folder = os.path.join(OUTPUT_FOLDER, library_name, get_media_folder(show))
        os.makedirs(show_folder, exist_ok=True)

        # Create a poster for the show
        poster_path = os.path.join(show_folder, "poster.jpg")
        if not os.path.exists(poster_path):
            try:
                if not show.art:
                    logger.warning(f"Skipping poster creation for {show.title}: No background art available.")
                    stats["skipped"] += 1  # Increment skipped for missing art
                else:
                    art_url = f"{PLEX_URL}{show.art}?X-Plex-Token={PLEX_TOKEN}"
                    response = SESSION.get(art_url, timeout=PLEX_TIMEOUT)
                    response.raise_for_status()

                    image = Image.open(BytesIO(response.content))
                    resized_image = resize_and_crop(image, 1000, 1500)

                    resized_image.save(poster_path, format="JPEG", quality=95)
                    logger.info(f"Saved: {poster_path}")
                    print(f"Saved: {poster_path}")
                    stats["processed"] += 1  # Increment processed for successful poster
            except Exception as e:
                logger.error(f"Error creating poster for show '{show.title}': {e}")
                stats["errors"] += 1  # Increment errors for poster creation failure
        else:
            logger.info(f"File already exists, skipping poster creation: {poster_path}")
            stats["skipped"] += 1  # Increment skipped for existing poster

        # Process episodes
        for episode in episodes:
            process_episode_thumb(episode, show_folder, stats)
    except Exception as e:
        logger.error(f"Error processing show '{show.title}': {e}")
        stats["errors"] += 1


def get_libraries_from_env():
    """Get library names from the .env file."""
    libraries = os.getenv("LIBRARIES", "").split(",")
    return [lib.strip() for lib in libraries if lib.strip()]  # Remove extra spaces


def process_libraries(plex, libraries_from_env):
    """
    Get the Plex libraries to process.
    If no libraries are specified in .env, all Movie and TV Show libraries are returned.
    """
    available_libraries = plex.library.sections()
    selected_libraries = []

    if not libraries_from_env:
        logger.info("No libraries specified in .env. Defaulting to Movie and TV Show libraries.")
        for lib in available_libraries:
            if lib.type in ["movie", "show"]:  # Only include movies and TV shows
                selected_libraries.append(lib)
    else:
        for library_name in libraries_from_env:
            matching_lib = next((lib for lib in available_libraries if lib.title == library_name), None)
            if matching_lib:
                selected_libraries.append(matching_lib)
            else:
                logger.warning(f"Library '{library_name}' not found in Plex. Skipping.")

    return selected_libraries


def process_library(library, stats, cache):
    """Process an entire Plex library efficiently."""
    library_name = library.title
    logger.info(f"Processing library: {library_name}")

    # Fetch all items at once
    all_items = library.all()
    stats["total"] += len(all_items)
    logger.info(f"Fetched {len(all_items)} items from library '{library_name}'.")

    for item in all_items:
        if library.type == "movie":
            process_movie_metadata(item, library_name, stats)
        elif library.type == "show":
            process_tv_show_metadata(item, library_name, stats)


def process_movie_metadata(movie, library_name, stats):
    """Efficiently process movie metadata to determine if an image is needed."""
    try:
        if not movie.art:
            logger.warning(f"Skipping {movie.title}: No background art available.")
            stats["skipped"] += 1
            return

        movie_folder = os.path.join(OUTPUT_FOLDER, library_name, get_media_folder(movie))
        os.makedirs(movie_folder, exist_ok=True)

        output_path = os.path.join(movie_folder, "poster.jpg")
        if os.path.exists(output_path):
            logger.info(f"File exists, skipping: {output_path}")
            stats["skipped"] += 1
            return

        # Fetch the image only when required
        art_url = f"{PLEX_URL}{movie.art}?X-Plex-Token={PLEX_TOKEN}"
        response = SESSION.get(art_url, timeout=PLEX_TIMEOUT)
        response.raise_for_status()

        image = Image.open(BytesIO(response.content))
        resized_image = resize_and_crop(image, 1000, 1500)

        resized_image.save(output_path, format="JPEG", quality=95)
        logger.info(f"Saved: {output_path}")
        stats["processed"] += 1
    except Exception as e:
        logger.error(f"Error processing {movie.title}: {e}")
        stats["errors"] += 1


def process_tv_show_metadata(show, library_name, stats):
    """Efficiently process a TV show and its episodes."""
    try:
        show_folder = os.path.join(OUTPUT_FOLDER, library_name, get_media_folder(show))
        os.makedirs(show_folder, exist_ok=True)

        # Create a show poster
        poster_path = os.path.join(show_folder, "poster.jpg")
        if os.path.exists(poster_path):
            logger.info(f"File exists, skipping: {poster_path}")
            stats["skipped"] += 1  # Increment skipped count
        else:
            if show.art:
                art_url = f"{PLEX_URL}{show.art}?X-Plex-Token={PLEX_TOKEN}"
                response = SESSION.get(art_url, timeout=PLEX_TIMEOUT)
                response.raise_for_status()

                image = Image.open(BytesIO(response.content))
                resized_image = resize_and_crop(image, 1000, 1500)

                resized_image.save(poster_path, format="JPEG", quality=95)
                logger.info(f"Saved: {poster_path}")
                stats["processed"] += 1
            else:
                logger.warning(f"Skipping show '{show.title}': No background art.")
                stats["skipped"] += 1

        # Process each episode
        for episode in show.episodes():
            episode_path = os.path.join(show_folder, f"S{episode.seasonNumber:02}E{episode.index:02}.jpg")
            if os.path.exists(episode_path):
                logger.info(f"File exists, skipping: {episode_path}")
                stats["skipped"] += 1
                continue

            if episode.thumb:
                thumb_url = f"{PLEX_URL}{episode.thumb}?X-Plex-Token={PLEX_TOKEN}"
                response = SESSION.get(thumb_url, timeout=PLEX_TIMEOUT)
                response.raise_for_status()

                image = Image.open(BytesIO(response.content))
                resized_image = resize_and_crop(image, 1000, 1500)

                resized_image.save(episode_path, format="JPEG", quality=95)
                logger.info(f"Saved: {episode_path}")
                stats["processed"] += 1
    except Exception as e:
        logger.error(f"Error processing show '{show.title}': {e}")
        stats["errors"] += 1

def main():
    start_time = time.time()

    # Initialize overall stats for all libraries
    overall_stats = {"total": 0, "processed": 0, "skipped": 0, "errors": 0}
    cache = {}

    try:
        logger.info("Connecting to Plex server...")
        plex = PlexServer(PLEX_URL, PLEX_TOKEN, timeout=PLEX_TIMEOUT)

        # Get libraries from .env or allow interactive mode
        libraries_from_env = get_libraries_from_env()

        # If no libraries are specified in .env, switch to interactive mode
        if not libraries_from_env:
            # Interactive mode
            logger.info("No libraries specified in .env. Switching to interactive mode.")
            # List only Movie and TV Show libraries
            libraries = plex.library.sections()
            tv_libraries = [lib for lib in libraries if lib.type == "show"]
            movie_libraries = [lib for lib in libraries if lib.type == "movie"]

            if not tv_libraries and not movie_libraries:
                print("No Movie or TV Show libraries found in Plex.")
                return

            print("\nAvailable Libraries:")
            all_libraries = tv_libraries + movie_libraries
            for idx, lib in enumerate(all_libraries, start=1):
                lib_type = "TV Shows" if lib.type == "show" else "Movies"
                print(f"{idx}. {lib.title} ({lib_type})")

            # Select a library
            selected_library_index = select_from_list(all_libraries, "Select a library to process: ")
            selected_library = all_libraries[selected_library_index - 1]
            library_name = selected_library.title
            logger.info(f"Selected library: {library_name}")

            stats = {"total": 0, "processed": 0, "skipped": 0, "errors": 0}

            if selected_library.type == "movie":
                movies = selected_library.all()
                stats["total"] = len(movies)
                choice = select_from_list(movies, "Select a movie to process (or 0 for all): ", include_all=True)

                if choice == 0:
                    for movie in movies:
                        process_movie_metadata(movie, library_name, stats)
                else:
                    selected_movie = movies[choice - 1]
                    process_movie_metadata(selected_movie, library_name, stats)

            elif selected_library.type == "show":
                shows = selected_library.all()
                choice = select_from_list(shows, "Select a TV show to process (or 0 for all): ", include_all=True)

                if choice == 0:
                    for show in shows:
                        process_tv_show_metadata(show, library_name, stats)
                else:
                    selected_show = shows[choice - 1]
                    process_tv_show_metadata(selected_show, library_name, stats)

            # Print library-specific stats
            print("\nProcessing Summary:")
            print(f"Total items: {stats['total']}")
            print(f"Processed: {stats['processed']}")
            print(f"Skipped: {stats['skipped']}")
            print(f"Errors: {stats['errors']}")
            logger.info(f"Summary: {stats}")

            # Update overall stats
            for key in overall_stats:
                overall_stats[key] += stats[key]

        else:
            # Process libraries from .env
            libraries_to_process = process_libraries(plex, libraries_from_env)
            for library in libraries_to_process:
                stats = {"total": 0, "processed": 0, "skipped": 0, "errors": 0}
                process_library(library, stats, cache)

                # Update overall stats
                for key in overall_stats:
                    overall_stats[key] += stats[key]

        # Print overall summary
        print("\nOverall Processing Summary:")
        print(f"Total items: {overall_stats['total']}")
        print(f"Processed: {overall_stats['processed']}")
        print(f"Skipped: {overall_stats['skipped']}")
        print(f"Errors: {overall_stats['errors']}")
        logger.info(f"Overall Summary: {overall_stats}")

        logger.info("Processing complete.")
        print("Processing complete.")
    except Exception as e:
        logger.critical(f"Critical error: {e}")
        print(f"Critical error: {e}")
    finally:
        end_time = time.time()
        duration = end_time - start_time
        logger.info(f"Script completed in {duration:.2f} seconds.")
        print(f"Script completed in {duration:.2f} seconds.")
        clean_up_old_logs()
        gc.collect()


if __name__ == "__main__":
    main()
