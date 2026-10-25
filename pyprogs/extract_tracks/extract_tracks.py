import argparse
import logging
import sys
import time
import titlecase
from dotenv import load_dotenv
from plexapi.server import PlexServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from plex_stuff_helpers import configure_logging, get_formatted_duration, prune_logs, connect_plex


class PlexTrackProcessor:
    def __init__(self, use_title_case=False, use_sentence_case=False):
        self.total_tracks = 0
        self.tracks_bad_case = 0
        self.use_title_case = use_title_case
        self.use_sentence_case = use_sentence_case

    def is_title_case(self, s):
        return s.istitle()

    def is_sentence_case(self, s):
        # Check if the string is in sentence case
        return bool(s) and s[0].isupper() and (len(s) == 1 or s[1:].islower())

    def detect_case(self, track_title):
        if self.use_title_case:
            return "Title Case"
        elif self.use_sentence_case:
            return "Sentence Case"
        else:
            return "Original Case"

    def process_title_case(self, track_title):
        return (
            titlecase.titlecase(track_title)
            if self.use_title_case
            else track_title.capitalize()
            if self.use_sentence_case
            else track_title
        )

    def process_sentence_case(self, track_title):
        return track_title.capitalize() if not self.is_sentence_case(track_title) else track_title

    def extract_tracks(self):
        # Iterate through all music libraries
        for music_library in plex.library.sections():
            if music_library.type == "artist":
                for artist in music_library.all():
                    print(f"Artist: {artist.title}")
                    logging.info(f"Artist: {artist.title}")
                    for album in artist.albums():
                        print(f"  Album: {album.title}")
                        logging.info(f"  Album: {album.title}")
                        for track in album.tracks():
                            track_title = track.title
                            self.total_tracks += 1

                            # Check if the track title needs processing based on user's choice
                            if self.use_title_case and not self.is_title_case(track_title):
                                processed_title = self.process_title_case(track_title)
                            elif self.use_sentence_case and not self.is_sentence_case(track_title):
                                processed_title = self.process_sentence_case(track_title)
                            else:
                                processed_title = track_title

                            # Log and print warnings if necessary
                            if processed_title != track_title:
                                self.tracks_bad_case += 1
                                case_info = (
                                    "Title Case"
                                    if self.use_title_case
                                    else "Sentence Case"
                                    if self.use_sentence_case
                                    else "Original Case"
                                )
                                print(f"    Warning  : Track title is not in {case_info} - {track_title}")
                                print(f"    New Title: Track title is now in {case_info} - {processed_title}")
                                logging.warning(f"Warning  : Track title is not in {case_info} - {track_title}")
                                logging.warning(f"New Title: Track title is now in {case_info} - {processed_title}")

                                # Update track title in Plex if --apply argument is provided
                                if args.apply:
                                    track.editTitle(title=processed_title)
                                    print(f"    Updated in Plex! New Title: {processed_title}")
                                    logging.info(f"    Updated in Plex! New Title: {processed_title}")

                            print(f"    Track: {track_title}")
                            logging.info(f"    Track: {track_title}")

    def log_summary(self, mode, script_duration):
        case_info = (
            "Title Case" if self.use_title_case else "Sentence Case" if self.use_sentence_case else "Original Case"
        )

        logging.info(f"Script completed in {mode} mode with chosen case: {case_info}.")
        logging.info(f"Total tracks processed: {self.total_tracks}")
        logging.info(f"Tracks with bad case: {self.tracks_bad_case}")
        logging.info(f"Script duration: {get_formatted_duration(script_duration)}")  # Use get_formatted_duration here
        print(f"Script completed in {mode} mode with chosen case: {case_info}.")
        print(f"Total tracks processed: {self.total_tracks}")
        print(f"Tracks with bad case: {self.tracks_bad_case}")
        print(f"Script duration: {get_formatted_duration(script_duration)}")


def clean_up_old_logs():
    global max_log_files
    max_log_files = prune_logs(logs_directory, script_name, max_log_files)


def main():
    """Run the command explicitly; importing never contacts services."""
    global max_log_files, script_name, logs_directory, plex, args
    parser = argparse.ArgumentParser(description="Update Plex Track Title Case to Sentence-Case or Title-Case")

    parser.add_argument("--apply", action="store_true", help="Apply changes.")

    parser.add_argument("--title-case", action="store_true", help="Use title case for track titles.")

    parser.add_argument("--sentence-case", action="store_true", help="Use sentence case for track titles.")

    args = parser.parse_args()

    load_dotenv()

    max_log_files, script_name, logs_directory, timestamp = configure_logging()

    plex = connect_plex(PlexServer)

    if args.apply and not (args.title_case or args.sentence_case):
        print("Error: When using --apply, either --title-case or --sentence-case must be specified.")
        sys.exit(1)

    if args.apply:
        confirmation = input("Applying changes! Are you sure you want to continue? (y/n): ").lower()
        if confirmation != "y":
            print("Aborted.")
            sys.exit(0)

    try:
        # Determine mode outside the conditional block
        if args.apply:
            mode = "Apply"
        else:
            mode = "Report"

        # Initialize PlexTrackProcessor with case options
        track_processor = PlexTrackProcessor(use_title_case=args.title_case, use_sentence_case=args.sentence_case)
        start_time = time.time()

        # Call the extract_tracks method
        track_processor.extract_tracks()

        end_time = time.time()
        script_duration = end_time - start_time

        # Call the log_summary method
        track_processor.log_summary(mode, script_duration)

    except Exception as e:
        # Log any unhandled exceptions
        logging.error(f"An unexpected error occurred: {type(e).__name__}")

    # Call the clean_up_old_logs function
    clean_up_old_logs()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Command failed ({type(error).__name__}). Check configuration and inputs.")
        raise SystemExit(1) from None
