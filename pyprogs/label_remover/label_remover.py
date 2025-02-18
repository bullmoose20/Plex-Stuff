import os
import logging
import plexapi
import glob
from logging.handlers import RotatingFileHandler
from plexapi.server import PlexServer
from dotenv import load_dotenv
import time

# Load environment variables
load_dotenv()

PLEX_URL = os.getenv("PLEX_URL")
PLEX_TOKEN = os.getenv("PLEX_TOKEN")
PLEX_TIMEOUT = int(os.getenv("PLEX_TIMEOUT", 60))
MAX_LOG_FILES = int(os.getenv("MAX_LOG_FILES", 10))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

# Setup Logging
script_name = os.path.splitext(os.path.basename(__file__))[0]
logs_directory = "logs"
os.makedirs(logs_directory, exist_ok=True)

timestamp = time.strftime("%Y%m%d_%H%M%S")
log_filename = os.path.join(logs_directory, f"{script_name}_{timestamp}.log")
log_format = '%(asctime)s - %(levelname)s - %(message)s'

logging.basicConfig(level=LOG_LEVEL, format=log_format)
file_handler = RotatingFileHandler(log_filename, maxBytes=5 * 1024 * 1024, backupCount=MAX_LOG_FILES)
file_handler.setFormatter(logging.Formatter(log_format))
logging.getLogger().addHandler(file_handler)

logger = logging.getLogger()


def connect_to_plex():
    """Connect to the Plex server."""
    try:
        logger.info("Connecting to Plex server...")
        plex = PlexServer(PLEX_URL, PLEX_TOKEN, timeout=PLEX_TIMEOUT)
        logger.info("Connected to Plex server successfully.")
        return plex
    except Exception as e:
        logger.critical(f"Failed to connect to Plex server: {e}")
        raise


def select_show(plex):
    """Prompt user to select a show."""
    while True:
        show_name = input("Enter the name of the show (or 0 to exit): ").strip()
        if show_name == "0":
            logger.info("User chose to exit the script from show selection.")
            return None
        
        logger.info(f"Searching for show: {show_name}")
        shows = plex.library.search(show_name, libtype='show')
        
        if not shows:
            print("No matches found. Here is a list of all available shows:")
            logger.warning("No matches found. Displaying all available shows.")
            all_shows = plex.library.search(libtype='show')
            for i, show in enumerate(all_shows, 1):
                print(f"{i}: {show.title} ({show.year if show.year else 'Unknown Year'})")
            print("0: Go back to the main menu")
            while True:
                try:
                    choice = int(input("Enter the number of the show to select (or 0 to go back): "))
                    if choice == 0:
                        logger.info("User chose to go back to the main menu.")
                        return None
                    if 1 <= choice <= len(all_shows):
                        logger.info(f"User selected show: {all_shows[choice - 1].title}")
                        return all_shows[choice - 1]
                    else:
                        print("Invalid choice! Please enter a number within the list range.")
                except ValueError:
                    print("Invalid input! Please enter a valid number.")
        else:
            if len(shows) > 1:
                print("Multiple shows found. Please select from the list:")
                for i, show in enumerate(shows, 1):
                    print(f"{i}: {show.title} ({show.year if show.year else 'Unknown Year'})")
                print("0: Go back to the main menu")
                while True:
                    try:
                        choice = int(input("Enter the number of the show (or 0 to go back): "))
                        if choice == 0:
                            logger.info("User chose to go back to the main menu.")
                            return None
                        if 1 <= choice <= len(shows):
                            logger.info(f"User selected show: {shows[choice - 1].title}")
                            return shows[choice - 1]
                        else:
                            print("Invalid choice! Please enter a number within the list range.")
                    except ValueError:
                        print("Invalid input! Please enter a valid number.")
            else:
                logger.info(f"Single match found: {shows[0].title}")
                return shows[0]


def select_season(show):
    """Prompt user to select a season."""
    seasons = show.seasons()
    if not seasons:
        print(f"No seasons found for show {show.title}.")
        logger.info(f"No seasons found for show {show.title}.")
        return None

    print(f"Seasons for {show.title}:")
    logger.info(f"Displaying seasons for show: {show.title}")
    for i, season in enumerate(seasons, 1):
        print(f"{i}: Season {season.index} - {season.title if season.title else 'No Title'}")
    print("0: Go back to the previous menu")

    while True:
        try:
            choice = int(input("Enter the number of the season (or 0 to go back): "))
            if choice == 0:
                logger.info("User chose to go back to the previous menu.")
                return None
            if 1 <= choice <= len(seasons):
                logger.info(f"User selected Season {choice}: {seasons[choice - 1].title}")
                return seasons[choice - 1]
            else:
                print("Invalid choice! Please enter a number within the list range.")
        except ValueError:
            print("Invalid input! Please enter a valid number.")


def select_episode(season):
    """Prompt user to select an episode."""
    episodes = season.episodes()
    if not episodes:
        print(f"No episodes found for Season {season.index}.")
        logger.info(f"No episodes found for Season {season.index}.")
        return None

    print(f"Episodes for Season {season.index}:")
    logger.info(f"Displaying episodes for Season {season.index} of {season.parentTitle}.")
    for i, episode in enumerate(episodes, 1):
        print(f"{i}: {episode.title} (Episode {episode.index})")
    print("0: Go back to the previous menu")

    while True:
        try:
            choice = int(input("Enter the number of the episode (or 0 to go back): "))
            if choice == 0:
                logger.info("User chose to go back to the previous menu.")
                return None
            if 1 <= choice <= len(episodes):
                selected_episode = episodes[choice - 1]
                logger.info(f"User selected Episode {choice}: {selected_episode.title}")
                return selected_episode
            else:
                print("Invalid choice! Please enter a number within the list range.")
        except ValueError:
            print("Invalid input! Please enter a valid number.")


def clean_up_old_logs():
    """Clean up old logs if they exceed the maximum allowed."""
    existing_logs = glob.glob(os.path.join(logs_directory, f"{script_name}_*.log"))
    if len(existing_logs) > MAX_LOG_FILES:
        oldest_logs = sorted(existing_logs)[:-MAX_LOG_FILES]
        for old_log in oldest_logs:
            os.remove(old_log)


def manage_labels(item, item_type):
    """Manage labels for a specific item (show, season, or episode) with retries and enhanced handling."""
    if not item.labels:
        print(f"No labels found on the {item_type} '{item.title}'.")
        logger.info(f"No labels found on the {item_type} '{item.title}'.")
        return

    print(f"Labels on the {item_type} '{item.title}':")
    logger.info(f"Displaying labels for {item_type} '{item.title}':")
    for i, label in enumerate(item.labels, 1):
        print(f"{i}: {label.tag}")
        logger.info(f"Label {i}: {label.tag}")

    try:
        choice = int(input("Enter the number of the label to delete (or 0 to cancel): "))
        if choice == 0:
            print("No labels were deleted.")
            logger.info("User chose not to delete any labels.")
            return

        if 1 <= choice <= len(item.labels):
            label_to_delete = item.labels[choice - 1].tag
            logger.info(f"User selected label '{label_to_delete}' for deletion.")

            # Retry logic for label removal
            for attempt in range(3):  # 3 attempts
                try:
                    # Unlock label field if locked
                    if "label" in item.fields and item.fields["label"].locked:
                        logger.info(f"Unlocking the label field for {item_type} '{item.title}'...")
                        item.editField("label", value="", locked=False)
                        item.reload()

                    # Pre-check for label existence
                    if label_to_delete not in [label.tag for label in item.labels]:
                        logger.info(f"Label '{label_to_delete}' no longer exists on '{item.title}'.")
                        break

                    # Attempt to remove the label
                    logger.info(f"Attempting to delete label '{label_to_delete}' from {item_type} '{item.title}'.")
                    # Remove the label (session timeout applies globally)
                    # item.removeLabel(label_to_delete)
                    item.removeLabel("Overlay")
                    item.reload()

                    # Check if the label was removed
                    if label_to_delete not in [label.tag for label in item.labels]:
                        print(f"Label '{label_to_delete}' has been deleted from the {item_type} '{item.title}'.")
                        logger.info(f"Successfully deleted label '{label_to_delete}' from {item_type} '{item.title}'.")
                        break

                except Exception as e:
                    logger.warning(f"Attempt {attempt + 1} to delete label '{label_to_delete}' failed: {e}")
                    if attempt < 2:  # Pause before retrying (if not the last attempt)
                        logger.info(f"Retrying label deletion in 5 seconds...")
                        time.sleep(5)

            else:
                logger.error(f"Failed to delete label '{label_to_delete}' after 3 attempts.")
                print(f"An error occurred while deleting the label '{label_to_delete}'.")

            # Relock label field if it was initially locked
            if "label" in item.fields and not item.fields["label"].locked:
                logger.info(f"Relocking the label field for {item_type} '{item.title}'...")
                item.editField("label", value="", locked=True)
                item.reload()

        else:
            print("Invalid choice!")
            logger.warning("User made an invalid label selection.")

    except ValueError:
        print("Invalid input! Please enter a number.")
        logger.warning("User entered invalid input for label selection.")


def main():
    try:
        # Connect to the Plex server
        plex = connect_to_plex()

        while True:
            # Prompt the user to select a show
            show = select_show(plex)
            if not show:
                logger.info("User exited the script from the main menu.")
                print("Exiting.")
                break

            logger.info(f"User selected show: {show.title}")

            while True:
                print(f"\nManage labels for '{show.title}':")
                print("1: Show level")
                print("2: Season level")
                print("3: Episode level")
                print("0: Go back to the main menu")

                try:
                    level = int(input("Enter your choice: "))
                    if level == 0:
                        logger.info("User chose to go back to the main menu.")
                        break
                    elif level == 1:
                        print(f"\nManage labels for '{show.title}':")
                        manage_labels(show, "show")
                    elif level == 2:
                        season = select_season(show)
                        if season:
                            print(f"\nManage labels for '{season.title}' in '{show.title}':")
                            manage_labels(season, "season")
                    elif level == 3:
                        season = select_season(show)
                        if season:
                            episode = select_episode(season)
                            if episode:
                                print(f"\nManage labels for episode '{episode.title}' in season '{season.title}' of '{show.title}':")
                                manage_labels(episode, "episode")
                    else:
                        print("Invalid choice! Please select 0, 1, 2, or 3.")
                        logger.warning("User made an invalid menu selection.")
                except ValueError:
                    print("Invalid input! Please enter a valid number.")
                    logger.warning("User entered invalid input in the main menu.")
    except Exception as e:
        print(f"An error occurred: {e}")
        logger.critical(f"Critical error: {e}")
    finally:
        clean_up_old_logs()
        logger.info("Script execution completed.")


if __name__ == "__main__":
    main()
