from plexapi.server import PlexServer
from dotenv import load_dotenv
from datetime import datetime
import os
import requests

# Load environment variables from .env file
load_dotenv()

# Retrieve the Plex server URL and authentication token from environment variables
PLEX_URL = os.getenv("PLEX_URL")
PLEX_TOKEN = os.getenv("PLEX_TOKEN")

# Retrieve the timeout value from the .env file (default to 30 seconds if not specified)
PLEX_TIMEOUT = int(os.getenv("PLEX_TIMEOUT", 30))

# Debug: Print the PLEX_TIMEOUT to check the actual value being used
print(f"Using PLEX_TIMEOUT: {PLEX_TIMEOUT}")

# Create a custom session with the specified timeout
session = requests.Session()
session.timeout = PLEX_TIMEOUT

# Connect to the Plex server using the custom session
plex = PlexServer(PLEX_URL, PLEX_TOKEN, session=session)

# Get a list of libraries and prompt the user to select one
libraries = plex.library.sections()
print("Select a library to update:")
for i, library in enumerate(libraries):
    print(f"{i + 1}. {library.title}")

selected_library_index = int(input("Enter the number of the library: ")) - 1
if selected_library_index < 0 or selected_library_index >= len(libraries):
    print("Invalid library selection. Exiting.")
    exit()

selected_library = libraries[selected_library_index]

# Ask user to specify the parent directory for building the full path
parent_directory = input("Enter the parent directory where media items are located: ")

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

items_to_change = []
for item in all_items:
    full_path = os.path.join(parent_directory, os.path.normpath(item.media[0].parts[0].file[1:]))
    print(f"Media item: {item.title}, Full path: {full_path}")
    modified = datetime.strptime(datetime.fromtimestamp(os.path.getmtime(full_path)).strftime("%m/%d/%Y, %H:%M:%S"), "%m/%d/%Y, %H:%M:%S")
    current = datetime.strptime(item.addedAt.strftime("%m/%d/%Y, %H:%M:%S"), "%m/%d/%Y, %H:%M:%S")
    if modified != current:
        items_to_change.append((item, full_path, current, modified))
        print(f"Current added_at: {current}")
        print(f"New added_at: {modified}")
        print("")

# Ask user to confirm before applying changes
user_input = input(f"{len(items_to_change)}/{len(all_items)} media items need to be updated. Do you want to apply the changes? (y/n): ")
if user_input.lower() == 'y':
    # Apply changes
    print("Applying changes...")
    successful_updates = 0
    for media_item, full_path, _, modified in items_to_change:
        print(f"Media item: {media_item.title}, Full path: {full_path}")
        try:
            media_item.editAddedAt(modified).reload()
            current = datetime.strptime(media_item.addedAt.strftime("%m/%d/%Y, %H:%M:%S"), "%m/%d/%Y, %H:%M:%S")
            if current == modified:
                successful_updates += 1
                print("Update successful!")
            else:
                print(f"Update failed. Current: {current} Modified: {modified}")
        except requests.exceptions.ReadTimeout as e:
            timeout_value = str(e.args[0])  # Convert the timeout value to a string
            print(f"Timeout occurred while updating (timeout value: {timeout_value}). Skipping this media item.")
        except Exception as e:
            print(f"Error occurred while updating: {e}")
    print(f"Results: {successful_updates}/{len(items_to_change)} media items were updated.")
else:
    print("No changes were applied.")
