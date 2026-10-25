import requests
import sys
from pathlib import Path, PurePosixPath, PureWindowsPath
import logging
import os

import time
from datetime import datetime as dt
from dotenv import load_dotenv
from plexapi.server import PlexServer

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from plex_stuff_helpers import configure_logging, get_formatted_duration, prune_logs, connect_plex


def clean_up_old_logs():
    global max_log_files
    max_log_files = prune_logs(logs_directory, script_name, max_log_files)


def media_path_under(parent_directory, plex_path):
    """Map a Plex absolute path beneath a local root, dropping its drive/share."""
    remote = (
        PureWindowsPath(plex_path)
        if "\\" in plex_path or PureWindowsPath(plex_path).drive
        else PurePosixPath(plex_path)
    )
    parts = remote.parts[1:] if remote.anchor else remote.parts
    if not parts or any(part in {"..", "."} for part in parts):
        raise ValueError("Plex path must not traverse outside the media root")
    base = Path(parent_directory).resolve()
    result = base.joinpath(*parts).resolve()
    if not result.is_relative_to(base):
        raise ValueError("Plex path resolves outside the media root")
    return result


def main():
    """Run the command explicitly; importing never contacts services."""
    global max_log_files, script_name, logs_directory
    load_dotenv()

    max_log_files, script_name, logs_directory, timestamp = configure_logging()

    timeout_seconds = int(os.getenv("PLEX_TIMEOUT", 60))
    plex = connect_plex(PlexServer)

    start_time = time.time()

    libraries = plex.library.sections()

    print("Select a library to update:")

    for i, library in enumerate(libraries):
        print(f"{i + 1}. {library.title}")
        logging.info(f"{i + 1}. {library.title}")

    selected_library_index = int(input("Enter the number of the library: ")) - 1

    if selected_library_index < 0 or selected_library_index >= len(libraries):
        print("Invalid library selection. Exiting.")
        exit()

    selected_library = libraries[selected_library_index]

    print(f"selected_library: {selected_library}")

    logging.info(f"selected_library: {selected_library}")

    parent_directory = input(
        "Enter the parent directory where media items are located (don't worry, you will be prompted before any changes are applied): "
    )

    all_items = []

    print("Changes to be made:")

    for media_item in selected_library.all():
        if media_item.type == "show":
            all_items.extend([e for s in media_item.seasons() for e in s.episodes()])
        elif media_item.type == "movie":
            all_items.append(media_item)
        else:
            print(f"Unsupported media type for '{media_item.title}': {media_item.type}")
            logging.warning(f"Unsupported media type for '{media_item.title}': {media_item.type}")

    items_to_change = []

    for item in all_items:
        full_path = media_path_under(parent_directory, item.media[0].parts[0].file)

        # Check if the file exists
        if not os.path.exists(full_path):
            print(f"Error: File not found - {full_path}")
            logging.error(f"Error: File not found - {full_path}")
            continue  # Skip to the next item if the file is not found

        # Check if the parent directory exists
        if not os.path.exists(os.path.dirname(full_path)):
            print(f"Error: Parent directory not found - {os.path.dirname(full_path)}")
            logging.error(f"Error: Parent directory not found - {os.path.dirname(full_path)}")
            continue  # Skip to the next item if the parent directory is not found

        print(f"Trying to build full path for media item: {item.title}")
        print(f"Base directory: {parent_directory}")
        print(f"Relative file path from Plex: {item.media[0].parts[0].file[1:]}")
        print(f"Full path attempt: {full_path}")
        print(f"Media item: {item.title}, Full path: {full_path}")
        logging.info(f"Trying to build full path for media item: {item.title}")
        logging.info(f"Base directory: {parent_directory}")
        logging.info(f"Relative file path from Plex: {item.media[0].parts[0].file[1:]}")
        logging.info(f"Full path attempt: {full_path}")
        logging.info(f"Media item: {item.title}, Full path: {full_path}")
        modified = dt.strptime(
            dt.fromtimestamp(os.path.getmtime(full_path)).strftime("%m/%d/%Y, %H:%M:%S"), "%m/%d/%Y, %H:%M:%S"
        )
        current = dt.strptime(item.addedAt.strftime("%m/%d/%Y, %H:%M:%S"), "%m/%d/%Y, %H:%M:%S")
        if modified != current:
            items_to_change.append((item, full_path, current, modified))
            print(f"Current added_at: {current}")
            print(f"New added_at: {modified}")
            print("")
            logging.info(f"Current added_at: {current}")
            logging.info(f"New added_at: {modified}")
            logging.info("")

    user_input = input(
        f"{len(items_to_change)}/{len(all_items)} media items need to be updated. Do you want to apply the changes? (y/n): "
    )

    if user_input.lower() == "y":
        # Apply changes
        print("Applying changes...")
        logging.info("Applying changes...")
        successful_updates = 0
        for media_item, full_path, _, modified in items_to_change:
            print(f"Media item: {media_item.title}, Full path: {full_path}")
            logging.info(f"Media item: {media_item.title}, Full path: {full_path}")
            try:
                media_item.editAddedAt(modified).reload()
                current = dt.strptime(media_item.addedAt.strftime("%m/%d/%Y, %H:%M:%S"), "%m/%d/%Y, %H:%M:%S")
                if current == modified:
                    successful_updates += 1
                    print("Update successful!")
                    logging.info("Update successful!")
                else:
                    print(f"Update failed. Current: {current} Modified: {modified}")
                    logging.error(f"Update failed. Current: {current} Modified: {modified}")
            except requests.exceptions.ReadTimeout:
                timeout_value = timeout_seconds  # Convert the timeout value to a string
                print(f"Timeout occurred while updating (timeout value: {timeout_value}). Skipping this media item.")
                logging.warning(
                    f"Timeout occurred while updating (timeout value: {timeout_value}). Skipping this media item."
                )
            except Exception as e:
                print(f"Error occurred while updating: {type(e).__name__}")
                logging.error(f"Error occurred while updating: {type(e).__name__}")
        print(f"Results: {successful_updates}/{len(items_to_change)} media items were updated.")
        logging.info(f"Results: {successful_updates}/{len(items_to_change)} media items were updated.")
    else:
        print("No changes were applied.")
        logging.info("No changes were applied.")

    end_time = time.time()

    script_duration = end_time - start_time

    print("Script completed.")

    print(f"Script duration: {get_formatted_duration(script_duration)}")

    logging.info("Script completed.")

    logging.info(f"Script duration: {get_formatted_duration(script_duration)}")

    clean_up_old_logs()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Command failed ({type(error).__name__}). Check configuration and inputs.")
        raise SystemExit(1) from None
