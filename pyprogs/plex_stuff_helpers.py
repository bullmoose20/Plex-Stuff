"""Small shared helpers for the standalone scripts; importing has no side effects."""

from datetime import datetime
import glob
import logging
import os
from pathlib import Path
import sys


def log_configuration():
    return (
        int(os.getenv("MAX_LOG_FILES", 10)),
        Path(sys.argv[0]).stem,
        "logs",
        datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3],
    )


def configure_logging():
    settings = log_configuration()
    _, name, directory, timestamp = settings
    Path(directory).mkdir(exist_ok=True)
    logging.basicConfig(
        filename=Path(directory) / f"{name}_{timestamp}.log",
        level=getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper()),
        format="%(asctime)s - %(levelname)s - %(message)s",
    )
    return settings


def prune_logs(directory, name, limit):
    limit = max(1, limit)
    logs = sorted(glob.glob(os.path.join(directory, f"{glob.escape(name)}_*.log")))
    if len(logs) > limit:
        logging.info("existing_logs: %s > max_log_files: %s", len(logs), limit)
        for old_log in logs[:-limit]:
            os.remove(old_log)
    return limit


def get_formatted_duration(seconds):
    units = [("day", 86400), ("hour", 3600), ("minute", 60), ("second", 1)]
    result = []
    for name, unit_seconds in units:
        value, seconds = divmod(seconds, unit_seconds)
        if value > 0:
            suffix = "" if value == 1 else "s"
            result.append(f"{int(value):.0f} {name}{suffix}")
    if result:
        return " ".join(result)
    milliseconds = seconds * 1000
    suffix = "" if milliseconds == 1 else "s"
    return f"{milliseconds:.3f} millisecond{suffix}"


def connect_plex(server_factory):
    """Keep connection failures useful without logging credential-bearing errors."""
    from plexapi.exceptions import BadRequest
    from requests.exceptions import RequestException

    url, token = os.getenv("PLEX_URL"), os.getenv("PLEX_TOKEN")
    if url is None or token is None:
        print("Error: Plex URL or token not found in .env file.")
        raise SystemExit(1)
    try:
        return server_factory(url, token, timeout=int(os.getenv("PLEX_TIMEOUT", 60)))
    except (RequestException, BadRequest) as error:
        logging.error("Error connecting to Plex server: %s", type(error).__name__, exc_info=False)
        raise SystemExit(1) from None


def determine_image_mode(image_path):
    from PIL import Image

    with Image.open(image_path) as source:
        with source.convert("RGB") as image:
            for r, g, b in image.get_flattened_data():
                if max(abs(r - g), abs(r - b), abs(g - b)) > 30:
                    return "RGB"
    return "Grayscale"


def append_people_log(path, message):
    with open(path, "a", encoding="utf-8") as log_file:
        log_file.write(f"{datetime.now()} ~ {message}\n")
    print(f"{datetime.now()} ~ {message}")


def initialize_people_outputs(script_file):
    script = Path(script_file).resolve()
    script_log = script.with_name(f"{script.name}.log")
    download_log = script.with_name(f"{script.name}_downloads.log")
    download_dir = script.parent / "Downloads"
    if script_log.exists():
        script_log.unlink()
    append_people_log(script_log, "#### START ####")
    download_dir.mkdir(exist_ok=True)
    return str(script_log), str(download_log), str(download_dir)
