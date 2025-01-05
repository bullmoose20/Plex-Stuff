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
from concurrent.futures import ThreadPoolExecutor, as_completed

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
created_dirs = set()


def clean_up_old_logs():
    """Clean up old logs if they exceed the maximum allowed."""
    existing_logs = glob.glob(os.path.join(logs_directory, f"{script_name}_*.log"))
    if len(existing_logs) > MAX_LOG_FILES:
        oldest_logs = sorted(existing_logs)[:-MAX_LOG_FILES]
        for old_log in oldest_logs:
            os.remove(old_log)


def process_items_parallel(items, process_function, *args):
    """Process items in parallel using ThreadPoolExecutor."""
    with ThreadPoolExecutor(max_workers=20) as executor:  # Adjust the number of workers based on system resources
        futures = [executor.submit(process_function, item, *args) for item in items]
        for future in as_completed(futures):
            try:
                future.result()
            except Exception as e:
                logger.error(f"Error in parallel processing: {e}")


def build_file_cache(output_folder):
    """Build a cache of all existing files in the output directory."""
    file_cache = set()
    for root, _, files in os.walk(output_folder):
        for file in files:
            file_cache.add(os.path.join(root, file))
    return file_cache


def safe_makedirs(directory):
    if directory not in created_dirs:
        os.makedirs(directory, exist_ok=True)
        created_dirs.add(directory)


def get_media_folder(media):
    """
    Retrieve the Plex folder location for a media item.
    For movies, return the parent folder of the first location.
    For TV shows, return the root folder from locations.
    For episodes, return the show's root folder.
    """
    try:
        if media["type"] == "movie":
            # Use the parent folder of the first location for movies
            full_path = media["locations"][0]
            return os.path.basename(os.path.dirname(full_path))  # Extract folder name
        elif media["type"] == "show" or media["type"] == "episode":
            # Use the root folder for TV shows and episodes
            if "locations" in media and media["locations"]:
                return os.path.basename(media["locations"][0])  # Show folder name
        # Fallback for unknown types
        return media.get("title", "Unknown")
    except Exception as e:
        logger.warning(f"Could not determine folder for media '{media.get('title', 'Unknown')}': {e}")
        return media.get("title", "Unknown")


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


def process_library(library, stats, file_cache):
    """
    Process an entire Plex library with optimized metadata fetching.
    """
    library_name = library.title
    logger.info(f"Processing library: {library_name}")

    # Fetch all items in one request
    all_items = fetch_limited_metadata(library)
    stats["total"] += len(all_items)
    logger.info(f"Fetched {len(all_items)} items from library '{library_name}'.")

    # Use parallelism to process items
    if library.type == "movie":
        process_items_parallel(all_items, process_movie, library_name, stats, file_cache)
    elif library.type == "show":
        process_items_parallel(all_items, process_tv_show, library_name, stats, file_cache)


def fetch_limited_metadata(library):
    """
    Fetch all items from a Plex library and limit the metadata fields manually.
    """
    try:
        items = library.all()  # Fetch all items from the library
        limited_metadata = []
        for item in items:
            limited_item = {
                "title": item.title,
                "art": getattr(item, "art", None),
                "thumb": getattr(item, "thumb", None),
                "type": item.type,
                "locations": getattr(item, "locations", []),
                "plex_object": item,  # Add original PlexAPI object
            }
            limited_metadata.append(limited_item)
        return limited_metadata
    except Exception as e:
        logger.error(f"Error fetching limited metadata: {e}")
        return []


def process_movie(movie, library_name, stats, file_cache):
    """Process a movie and create a poster.jpg using its background art."""
    try:
        if not movie.get("art"):
            logger.warning(f"Skipping {movie.get('title', 'Unknown')}: No background art available.")
            stats["skipped"] += 1
            return

        movie_folder = os.path.join(OUTPUT_FOLDER, library_name, get_media_folder(movie))
        safe_makedirs(movie_folder)
        # os.makedirs(movie_folder, exist_ok=True)
        output_path = os.path.join(movie_folder, "poster.jpg")

        if output_path in file_cache:
            logger.info(f"File already exists, skipping: {output_path}")
            stats["skipped"] += 1
            return

        art_url = f"{PLEX_URL}{movie['art']}?X-Plex-Token={PLEX_TOKEN}"
        response = SESSION.get(art_url, timeout=PLEX_TIMEOUT)
        response.raise_for_status()

        image = Image.open(BytesIO(response.content))
        resized_image = resize_and_crop(image, 1000, 1500)

        resized_image.save(output_path, format="JPEG", quality=95)
        file_cache.add(output_path)
        logger.info(f"Saved: {output_path}")
        stats["processed"] += 1
    except Exception as e:
        logger.error(f"Error processing {movie.get('title', 'Unknown')}: {e}")
        stats["errors"] += 1


def process_tv_show(show, library_name, stats, file_cache):
    """Process a TV show, create a poster for the show, and generate episode cards."""
    try:
        # Create the folder for the show
        show_folder = os.path.join(OUTPUT_FOLDER, library_name, get_media_folder(show))
        safe_makedirs(show_folder)
        # os.makedirs(show_folder, exist_ok=True)

        # Process the show's poster
        poster_path = os.path.join(show_folder, "poster.jpg")
        if poster_path not in file_cache:
            try:
                if not show.get("art"):
                    logger.warning(f"Skipping poster creation for {show.get('title', 'Unknown')}: No background art.")
                    stats["skipped"] += 1
                else:
                    art_url = f"{PLEX_URL}{show['art']}?X-Plex-Token={PLEX_TOKEN}"
                    response = SESSION.get(art_url, timeout=PLEX_TIMEOUT)
                    response.raise_for_status()

                    image = Image.open(BytesIO(response.content))
                    resized_image = resize_and_crop(image, 1000, 1500)

                    resized_image.save(poster_path, format="JPEG", quality=95)
                    file_cache.add(poster_path)
                    logger.info(f"Saved: {poster_path}")
                    stats["processed"] += 1
            except Exception as e:
                logger.error(f"Error creating poster for show '{show.get('title', 'Unknown')}': {e}")
                stats["errors"] += 1
        else:
            logger.info(f"File already exists, skipping: {poster_path}")
            stats["skipped"] += 1

        # Fetch and process episodes using the PlexAPI object
        plex_show = show["plex_object"]
        episodes = plex_show.episodes()  # Fetch episodes directly
        stats["total"] += len(episodes)

        for episode in episodes:
            # Include season and episode numbers in the filename
            episode_path = os.path.join(
                show_folder,
                f"S{episode.seasonNumber:02}E{episode.index:02}.jpg"
            )
            if episode_path in file_cache:
                logger.info(f"File already exists, skipping: {episode_path}")
                stats["skipped"] += 1
                continue

            if episode.thumb:
                try:
                    thumb_url = f"{PLEX_URL}{episode.thumb}?X-Plex-Token={PLEX_TOKEN}"
                    response = SESSION.get(thumb_url, timeout=PLEX_TIMEOUT)
                    response.raise_for_status()

                    image = Image.open(BytesIO(response.content))
                    resized_image = resize_and_crop(image, 1000, 1500)

                    resized_image.save(episode_path, format="JPEG", quality=95)
                    file_cache.add(episode_path)
                    logger.info(f"Saved: {episode_path}")
                    stats["processed"] += 1
                except Exception as e:
                    logger.error(f"Error processing episode '{episode.title}': {e}")
                    stats["errors"] += 1
            else:
                logger.warning(f"Skipping episode '{episode.title}': No thumbnail available.")
                stats["skipped"] += 1
    except Exception as e:
        logger.error(f"Error processing show '{show.get('title', 'Unknown')}': {e}")
        stats["errors"] += 1


def main():
    start_time = time.time()

    # Initialize overall stats for all libraries
    overall_stats = {"total": 0, "processed": 0, "skipped": 0, "errors": 0}

    try:
        logger.info("Connecting to Plex server...")
        plex = PlexServer(PLEX_URL, PLEX_TOKEN, timeout=PLEX_TIMEOUT)

        logger.info("Building file cache...")
        file_cache = build_file_cache(OUTPUT_FOLDER)
        logger.info(f"File cache built with {len(file_cache)} files.")

        # Process libraries
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
            logger.info(f"Processing library: {library_name}")

            if selected_library.type == "movie":
                movies = selected_library.all()
                stats["total"] = len(movies)
                choice = select_from_list(movies, "Select a movie to process (or 0 for all): ", include_all=True)

                if choice == 0:
                    for movie in movies:
                        process_movie(movie, library_name, stats, file_cache)
                else:
                    selected_movie = movies[choice - 1]
                    process_movie(selected_movie, library_name, stats, file_cache)

            elif selected_library.type == "show":
                shows = selected_library.all()
                choice = select_from_list(shows, "Select a TV show to process (or 0 for all): ", include_all=True)

                if choice == 0:
                    for show in shows:
                        process_tv_show(show, library_name, stats, file_cache)
                else:
                    selected_show = shows[choice - 1]
                    process_tv_show(selected_show, library_name, stats, file_cache)

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
                process_library(library, stats, file_cache)

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
        print(f"Overall Summary: {overall_stats}")

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
