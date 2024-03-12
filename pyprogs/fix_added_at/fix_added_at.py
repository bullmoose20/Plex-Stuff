import glob
import logging
import os
import requests
import sys
import time
from datetime import datetime as dt
from dotenv import load_dotenv, find_dotenv
from plexapi.server import PlexServer

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

# Log the command along with its arguments
logging.info(f"Command: {' '.join(sys.argv)}")
logging.info(f"Arguments: {sys.argv}")

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


def get_formatted_duration(seconds):
    units = [('day', 86400), ('hour', 3600), ('minute', 60), ('second', 1)]
    result = []

    for unit_name, unit_seconds in units:
        value, seconds = divmod(seconds, unit_seconds)
        if value > 0:
            unit_name = unit_name if value == 1 else unit_name + 's'
            result.append(f"{int(value):.0f} {unit_name}")

    if not result:
        milliseconds = seconds * 1000
        return "{:.3f} millisecond".format(milliseconds) if milliseconds == 1 else "{:.3f} milliseconds".format(milliseconds)

    return ' '.join(result)


# Record script start time
start_time = time.time()

# Get a list of libraries and prompt the user to select one
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

# Ask user to specify the parent directory for building the full path
parent_directory = input("Enter the parent directory where media items are located (don't worry, you will be prompted before any changes are applied): ")

# Initialize counters
all_items = []
print("Changes to be made:")
for media_item in selected_library.all():
    if media_item.type == 'show':
        all_items.extend([e for s in media_item.seasons() for e in s.episodes()])
    elif media_item.type == 'movie':
        all_items.append(media_item)
    else:
        print(f"Unsupported media type for '{media_item.title}': {media_item.type}")
        logging.warning(f"Unsupported media type for '{media_item.title}': {media_item.type}")

items_to_change = []
for item in all_items:
    relative_path = os.path.normpath(item.media[0].parts[0].file[1:])
    full_path = os.path.join(parent_directory, relative_path)

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
    modified = dt.strptime(dt.fromtimestamp(os.path.getmtime(full_path)).strftime("%m/%d/%Y, %H:%M:%S"), "%m/%d/%Y, %H:%M:%S")
    current = dt.strptime(item.addedAt.strftime("%m/%d/%Y, %H:%M:%S"), "%m/%d/%Y, %H:%M:%S")
    if modified != current:
        items_to_change.append((item, full_path, current, modified))
        print(f"Current added_at: {current}")
        print(f"New added_at: {modified}")
        print("")
        logging.info(f"Current added_at: {current}")
        logging.info(f"New added_at: {modified}")
        logging.info("")

# Ask user to confirm before applying changes
user_input = input(f"{len(items_to_change)}/{len(all_items)} media items need to be updated. Do you want to apply the changes? (y/n): ")
if user_input.lower() == 'y':
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
        except requests.exceptions.ReadTimeout as e:
            timeout_value = str(e.args[0])  # Convert the timeout value to a string
            print(f"Timeout occurred while updating (timeout value: {timeout_value}). Skipping this media item.")
            logging.warning(f"Timeout occurred while updating (timeout value: {timeout_value}). Skipping this media item.")
        except Exception as e:
            print(f"Error occurred while updating: {e}")
            logging.error(f"Error occurred while updating: {e}")
    print(f"Results: {successful_updates}/{len(items_to_change)} media items were updated.")
    logging.info(f"Results: {successful_updates}/{len(items_to_change)} media items were updated.")
else:
    print("No changes were applied.")
    logging.info("No changes were applied.")


# Record script end time
end_time = time.time()

# Calculate script duration
script_duration = end_time - start_time

# Log summary
print(f"Script completed.")
print(f"Script duration: {get_formatted_duration(script_duration)}")
logging.info(f"Script completed.")
logging.info(f"Script duration: {get_formatted_duration(script_duration)}")

# Call the clean_up_old_logs function
clean_up_old_logs()
