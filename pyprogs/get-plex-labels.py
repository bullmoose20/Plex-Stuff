import os
import argparse
import logging
from dotenv import load_dotenv
from plexapi.server import PlexServer, Unauthorized
from tqdm import tqdm


def check_plexapi_status():
    global plex
    try:
        global plex
        plex = PlexServer(PLEX_URL, PLEX_TOKEN)
    except Unauthorized:
        print("Unauthorized error. Check if PLEX_URL and PLEX_TOKEN are correct.")
        return False
    except Exception:
        print("Error connecting to the server. Please check if the PLEX_URL is correct.")
        return False
    return True


def check_library_exists(plex, libraries=None):
    all_libraries = [lib.title for lib in plex.library.sections()]
    if libraries is None:
        return True
    for library in libraries:
        if library not in all_libraries:
            print(f"Error: Library '{library}' does not exist. Available libraries: {', '.join(all_libraries)}")
            return False
    return True


def get_overlay_items(label, libraries=None, troubleshoot=False):
    overlay_items = []
    libraries = plex.library.sections() if libraries is None else [plex.library.section(title=lib) for lib in libraries]
    for library in tqdm(libraries, desc="Searching Libraries"):
        for item in tqdm(library.all(), desc="Searching " + library.title, leave=False):
            if item.type == "show":
                show = plex.library.section(library.title).get(item.title)
                seasons = show.seasons()
                for season in seasons:
                    season_labels = season.labels
                    if label in [label.tag for label in season_labels]:
                        overlay_items.append(season)
                        logging.info(
                            f"FOUND: '{show.title} - Season {season.seasonNumber}' with label '{label}' in library '{library.title}'"
                        )
                episodes = [e for s in seasons for e in s.episodes()]
                for episode in episodes:
                    episode_labels = episode.labels
                    if label in [label.tag for label in episode_labels]:
                        overlay_items.append(episode)
                        logging.info(
                            f"FOUND: '{show.title} - Season {episode.seasonNumber} Episode {episode.index}' with label '{label}' in library '{library.title}'"
                        )
            elif hasattr(item, "labels"):
                labels = item.labels
                if label in [label.tag for label in labels]:
                    overlay_items.append(item)
                    logging.info(f"FOUND: '{item.title}' with label '{label}' in library '{library.title}'")
                elif troubleshoot:
                    logging.info(
                        f'MISSING: Item "{item.title}" does not have label "{label}" (labels: {labels}) in library "{library.title}"'
                    )
                    print(
                        f'MISSING: Item "{item.title}" does not have label "{label}" (labels: {labels}) in library "{library.title}"'
                    )
            elif troubleshoot:
                logging.info(f'MISSING: Item "{item.title}" does not have any labels in library "{library.title}"')
                print(f'MISSING: Item "{item.title}" does not have any labels in library "{library.title}"')
    return overlay_items


def summary_report(overlay_items, label):
    logging.info(f"FOUND: {len(overlay_items)} items with the label '{label}'")
    print(f'FOUND: {len(overlay_items)} items with the label "{label}"')
    for item in overlay_items:
        logging.info("-" * 50)
        logging.info(f"Title: {item.title}")
        logging.info(f"Type: {item.type}")
        if item.type == "movie":
            logging.info(f"Year: {item.year}")
        elif item.type == "season":
            logging.info(f"Show: {item.show().title}")
            logging.info(f"Season: {item.seasonNumber}")
        elif item.type == "episode":
            logging.info(f"Show: {item.show().title}")
            logging.info(f"Season: {item.seasonNumber}")
            logging.info(f"Episode: {item.index}")
        logging.info("Labels: {}".format(", ".join([label.tag for label in item.labels]) if item.labels else "None"))


def main():
    """Run the command explicitly; importing never contacts services."""
    global PLEX_TOKEN, PLEX_URL, overlay_items
    load_dotenv()

    PLEX_URL = os.getenv("PLEX_URL")

    PLEX_TOKEN = os.getenv("PLEX_TOKEN")

    parser = argparse.ArgumentParser(description="Search for items in your Plex libraries with a specific label.")

    parser.add_argument("label", nargs="?", default="Overlay", help="The label to search for (default: Overlay)")

    parser.add_argument(
        "-l",
        "--libraries",
        nargs="*",
        help="List of libraries to search in (if not specified, all libraries will be searched)",
    )

    parser.add_argument(
        "-t",
        "--troubleshoot",
        action="store_true",
        help="Print out additional information for each item that does not have the label",
    )

    args = parser.parse_args()

    logging.basicConfig(
        filename="get_plex_labels.log", filemode="w", level=logging.INFO, format="%(asctime)s %(message)s"
    )

    if check_plexapi_status():
        if check_library_exists(plex, args.libraries):
            overlay_items = get_overlay_items(args.label, args.libraries, args.troubleshoot)
            summary_report(overlay_items, args.label)


if __name__ == "__main__":
    main()
