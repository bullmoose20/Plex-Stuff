from __future__ import annotations
import argparse
import glob
import logging
import os
import sys
import time
from dataclasses import dataclass
from datetime import datetime as dt
from pathlib import Path

Image = None
ImageDraw = None
ImageEnhance = None
ImageFilter = None
ImageOps = None
PIL_IMPORT_ERROR = None
RESAMPLING_LANCZOS = None

SUPPORTED_FORMATS = {
    ".jpg": "JPEG",
    ".jpeg": "JPEG",
    ".png": "PNG",
    ".webp": "WEBP",
}
DEFAULT_SOURCE_NAMES = ("poster",)
POSTER_RATIO = 2 / 3
SEASON_FOLDER_PREFIX = "season "
SPECIALS_FOLDER_NAME = "specials"


@dataclass
class Stats:
    discovered: int = 0
    processed: int = 0
    created_new: int = 0
    replaced_existing: int = 0
    dry_run: int = 0
    skipped_existing: int = 0
    skipped_ratio: int = 0
    skipped_invalid: int = 0
    errors: int = 0


def initialize_pillow() -> bool:
    global Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps, PIL_IMPORT_ERROR, RESAMPLING_LANCZOS

    if Image is not None:
        return True

    try:
        from PIL import Image as PILImage
        from PIL import ImageDraw as PILImageDraw
        from PIL import ImageEnhance as PILImageEnhance
        from PIL import ImageFilter as PILImageFilter
        from PIL import ImageOps as PILImageOps

        Image = PILImage
        ImageDraw = PILImageDraw
        ImageEnhance = PILImageEnhance
        ImageFilter = PILImageFilter
        ImageOps = PILImageOps
        try:
            RESAMPLING_LANCZOS = Image.Resampling.LANCZOS
        except AttributeError:
            RESAMPLING_LANCZOS = Image.Resampling.LANCZOS
        return True
    except ImportError as exc:
        PIL_IMPORT_ERROR = exc
        return False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create Plex/Kometa-style square art from portrait posters without cropping the original poster content."
        )
    )
    parser.add_argument(
        "--input-folder",
        required=True,
        help="Root folder containing the asset directories to scan.",
    )
    parser.add_argument(
        "--source-names",
        default="poster",
        help=("Comma-separated base filenames to process, without extensions. Default: poster"),
    )
    parser.add_argument(
        "--all-images",
        action="store_true",
        help="Process any supported portrait image in movie/show root folders instead of matching source names.",
    )
    parser.add_argument(
        "--include-season-posters",
        action="store_true",
        help="Also process posters found inside season folders such as 'Season 01' or 'Specials'.",
    )
    parser.add_argument(
        "--output-name",
        default="square",
        help="Base filename to write next to the source poster. Default: square",
    )
    parser.add_argument(
        "--format",
        choices=("auto", "jpg", "png", "webp"),
        default="auto",
        help="Output format. Default: auto, which follows the source extension.",
    )
    parser.add_argument(
        "--size",
        type=int,
        default=1000,
        help="Square canvas size in pixels. Default: 1000",
    )
    parser.add_argument(
        "--ratio-tolerance",
        type=float,
        default=0.03,
        help="Allowed difference from 2:3 poster ratio before skipping. Default: 0.03",
    )
    parser.add_argument(
        "--blur-radius",
        type=float,
        default=36,
        help="Blur radius for the background fill. Default: 36",
    )
    parser.add_argument(
        "--poster-height",
        type=float,
        default=0.94,
        help="Poster height as a fraction of square size. Default: 0.94",
    )
    parser.add_argument(
        "--background-brightness",
        type=float,
        default=0.72,
        help="Brightness multiplier applied to the blurred background. Default: 0.72",
    )
    parser.add_argument(
        "--background-color",
        type=float,
        default=1.15,
        help="Color multiplier applied to the blurred background. Default: 1.15",
    )
    parser.add_argument(
        "--quality",
        type=int,
        default=95,
        help="JPEG/WEBP quality. Default: 95",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Force regeneration even when an existing square image is already 1:1.",
    )
    parser.add_argument(
        "--non-recursive",
        action="store_true",
        help="Only scan the top level of the input folder.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report the files that would be processed without writing output.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Log each processed file to the console.",
    )
    parser.add_argument(
        "--progress-every",
        type=int,
        default=25,
        help="Print a progress update every N candidates. Default: 25",
    )
    return parser.parse_args()


def configure_logging(verbose: bool) -> tuple[str, str]:
    script_name = Path(sys.argv[0]).stem
    logs_directory = "logs"
    os.makedirs(logs_directory, exist_ok=True)

    timestamp = dt.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
    log_filename = os.path.join(logs_directory, f"{script_name}_{timestamp}.log")
    log_level = logging.DEBUG if verbose else logging.INFO
    log_format = "%(asctime)s - %(levelname)s - %(message)s"

    logging.basicConfig(
        level=log_level,
        format=log_format,
        handlers=[
            logging.FileHandler(log_filename, encoding="utf-8"),
            logging.StreamHandler(sys.stdout),
        ],
    )
    return logs_directory, script_name


def clean_up_old_logs(logs_directory: str, script_name: str, max_log_files: int = 10) -> None:
    existing_logs = glob.glob(os.path.join(logs_directory, f"{script_name}_*.log"))
    if len(existing_logs) <= max_log_files:
        return

    for old_log in sorted(existing_logs)[:-max_log_files]:
        os.remove(old_log)


def parse_source_names(raw_source_names: str) -> set[str]:
    names = {name.strip().lower() for name in raw_source_names.split(",") if name.strip()}
    return names or set(DEFAULT_SOURCE_NAMES)


def discover_source_images(
    input_folder: Path,
    recursive: bool,
    source_names: set[str],
    all_images: bool,
    output_name: str,
    include_season_posters: bool,
) -> list[Path]:
    candidates: list[Path] = []
    iterator = input_folder.rglob("*") if recursive else input_folder.glob("*")

    for path in iterator:
        if not path.is_file():
            continue

        suffix = path.suffix.lower()
        stem = path.stem.lower()
        if suffix not in SUPPORTED_FORMATS:
            continue
        if stem == output_name.lower():
            continue
        if not include_season_posters and is_season_folder(path.parent):
            continue
        if not all_images and stem not in source_names:
            continue
        candidates.append(path)

    return sorted(candidates)


def is_season_folder(folder: Path) -> bool:
    folder_name = folder.name.strip().lower()
    return folder_name.startswith(SEASON_FOLDER_PREFIX) or folder_name == SPECIALS_FOLDER_NAME


def output_extension_for(source_path: Path, requested_format: str) -> str:
    if requested_format == "auto":
        suffix = source_path.suffix.lower()
        return ".jpg" if suffix == ".jpeg" else suffix
    return f".{requested_format}"


def build_output_path(source_path: Path, output_name: str, requested_format: str) -> Path:
    output_extension = output_extension_for(source_path, requested_format)
    return source_path.with_name(f"{output_name}{output_extension}")


def is_close_to_poster_ratio(width: int, height: int, tolerance: float) -> bool:
    if width <= 0 or height <= 0:
        return False
    ratio = width / height
    return abs(ratio - POSTER_RATIO) <= tolerance


def is_square_ratio(width: int, height: int) -> bool:
    return width > 0 and width == height


def existing_output_needs_regeneration(output_path: Path) -> bool:
    try:
        with Image.open(output_path) as existing_image:
            width, height = existing_image.size
            return not is_square_ratio(width, height)
    except OSError:
        logging.warning("Existing output is unreadable and will be replaced: %s", output_path)
        return True


def create_rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def add_vignette(canvas: Image.Image, size: int) -> Image.Image:
    vignette = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(vignette)
    inset = int(size * 0.03)
    draw.ellipse((inset, inset, size - inset, size - inset), fill=220)
    vignette = ImageOps.invert(vignette).filter(ImageFilter.GaussianBlur(radius=size * 0.08))

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    overlay.putalpha(vignette)
    return Image.alpha_composite(canvas.convert("RGBA"), overlay)


def build_square_composite(
    source_image: Image.Image,
    size: int,
    blur_radius: float,
    poster_height_fraction: float,
    background_brightness: float,
    background_color: float,
) -> Image.Image:
    image = ImageOps.exif_transpose(source_image).convert("RGB")

    background = ImageOps.fit(
        image,
        (size, size),
        method=RESAMPLING_LANCZOS,
        centering=(0.5, 0.3),
    )
    background = background.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    background = ImageEnhance.Brightness(background).enhance(background_brightness)
    background = ImageEnhance.Color(background).enhance(background_color)

    canvas = background.convert("RGBA")
    canvas = add_vignette(canvas, size)

    max_poster_size = (int(size * 0.96), int(size * poster_height_fraction))
    poster = ImageOps.contain(image, max_poster_size, method=RESAMPLING_LANCZOS).convert("RGBA")

    corner_radius = max(10, int(min(poster.size) * 0.035))
    poster_mask = create_rounded_mask(poster.size, corner_radius)
    poster.putalpha(poster_mask)

    shadow_padding = max(20, int(size * 0.03))
    shadow_offset = max(10, int(size * 0.012))
    shadow_size = (
        poster.width + shadow_padding * 2,
        poster.height + shadow_padding * 2,
    )
    shadow = Image.new("RGBA", shadow_size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (
            shadow_padding,
            shadow_padding + shadow_offset,
            shadow_padding + poster.width,
            shadow_padding + shadow_offset + poster.height,
        ),
        radius=corner_radius,
        fill=(0, 0, 0, 150),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=max(12, int(size * 0.025))))

    shadow_x = (size - shadow.width) // 2
    shadow_y = (size - shadow.height) // 2
    canvas.alpha_composite(shadow, (shadow_x, shadow_y))

    poster_x = (size - poster.width) // 2
    poster_y = (size - poster.height) // 2
    canvas.alpha_composite(poster, (poster_x, poster_y))
    return canvas.convert("RGB")


def save_image(image: Image.Image, output_path: Path, requested_format: str, quality: int) -> None:
    output_format = SUPPORTED_FORMATS[output_extension_for(output_path, requested_format)]
    save_kwargs: dict[str, int | bool] = {}

    if output_format in {"JPEG", "WEBP"}:
        save_kwargs["quality"] = quality

    if output_format == "JPEG":
        save_kwargs["optimize"] = True

    image.save(output_path, format=output_format, **save_kwargs)


def process_image(source_path: Path, output_path: Path, args: argparse.Namespace, stats: Stats) -> None:
    stats.discovered += 1

    if output_path == source_path:
        logging.error(
            "Output path resolves to the source file for %s. Use a different --output-name or --format.",
            source_path,
        )
        stats.errors += 1
        return

    replacing_existing = False
    if output_path.exists():
        if args.overwrite:
            logging.info("Overwriting existing output due to --overwrite: %s", output_path)
            replacing_existing = True
        elif not existing_output_needs_regeneration(output_path):
            logging.info("Skipping existing square output with 1:1 ratio: %s", output_path)
            stats.skipped_existing += 1
            return
        else:
            logging.info("Replacing existing output because it is not 1:1: %s", output_path)
            replacing_existing = True

    try:
        with Image.open(source_path) as source_image:
            width, height = source_image.size
            if not is_close_to_poster_ratio(width, height, args.ratio_tolerance):
                logging.info(
                    "Skipping non-poster ratio %s (%sx%s)",
                    source_path,
                    width,
                    height,
                )
                stats.skipped_ratio += 1
                return

            if args.dry_run:
                logging.info("Dry run: would create %s from %s", output_path, source_path)
                stats.processed += 1
                stats.dry_run += 1
                return

            square_image = build_square_composite(
                source_image=source_image,
                size=args.size,
                blur_radius=args.blur_radius,
                poster_height_fraction=args.poster_height,
                background_brightness=args.background_brightness,
                background_color=args.background_color,
            )
            save_image(square_image, output_path, args.format, args.quality)
            logging.info("Created %s from %s", output_path, source_path)
            stats.processed += 1
            if replacing_existing:
                stats.replaced_existing += 1
            else:
                stats.created_new += 1
    except OSError as exc:
        logging.error("Skipping unreadable image %s: %s", source_path, exc)
        stats.skipped_invalid += 1
    except Exception as exc:
        logging.exception("Failed to process %s: %s", source_path, exc)
        stats.errors += 1


def get_formatted_duration(seconds: float) -> str:
    units = (("day", 86400), ("hour", 3600), ("minute", 60), ("second", 1))
    parts: list[str] = []
    remaining = seconds

    for unit_name, unit_seconds in units:
        value, remaining = divmod(remaining, unit_seconds)
        if value >= 1:
            label = unit_name if value == 1 else f"{unit_name}s"
            parts.append(f"{int(value)} {label}")

    if parts:
        return " ".join(parts)
    return f"{seconds * 1000:.0f} milliseconds"


def should_emit_progress(completed: int, total: int, progress_every: int, verbose: bool) -> bool:
    if completed <= 0:
        return False
    if completed == total:
        return True
    if verbose or total <= 10:
        return True
    return progress_every > 0 and completed % progress_every == 0


def print_progress(completed: int, total: int, stats: Stats) -> None:
    percent = 100 if total == 0 else int((completed / total) * 100)
    print(
        "Progress: "
        f"{completed}/{total} ({percent}%) | "
        f"created={stats.created_new} | "
        f"replaced={stats.replaced_existing} | "
        f"dry-run={stats.dry_run} | "
        f"skipped-existing={stats.skipped_existing} | "
        f"skipped-ratio={stats.skipped_ratio} | "
        f"skipped-invalid={stats.skipped_invalid} | "
        f"errors={stats.errors}"
    )


def get_items_per_second(completed: int, elapsed_seconds: float) -> str:
    if completed <= 0 or elapsed_seconds <= 0:
        return "n/a"
    return f"{completed / elapsed_seconds:.2f}"


def main() -> int:
    global args, elapsed_seconds, input_folder, logs_directory, output_path, recursive, script_name, source_names, source_path, stats
    args = parse_args()
    logs_directory, script_name = configure_logging(args.verbose)
    started_at = dt.now()

    if not initialize_pillow():
        logging.error(
            "Pillow is required but not installed. Run 'pip install -r requirements.txt' "
            "from pyprogs\\poster_to_square before running this script."
        )
        logging.debug("Import error: %s", PIL_IMPORT_ERROR)
        clean_up_old_logs(logs_directory, script_name)
        return 1

    input_folder = Path(args.input_folder).expanduser()
    if not input_folder.exists() or not input_folder.is_dir():
        logging.error("Input folder does not exist or is not a directory: %s", input_folder)
        clean_up_old_logs(logs_directory, script_name)
        return 1

    source_names = parse_source_names(args.source_names)
    recursive = not args.non_recursive
    stats = Stats()

    logging.info("Command: %s", " ".join(["python"] + sys.argv))
    logging.info("Scanning %s", input_folder)
    print(f"Started: {started_at.strftime('%Y-%m-%d %H:%M:%S')}")

    start_time = time.time()
    source_images = discover_source_images(
        input_folder=input_folder,
        recursive=recursive,
        source_names=source_names,
        all_images=args.all_images,
        output_name=args.output_name,
        include_season_posters=args.include_season_posters,
    )

    total_candidates = len(source_images)
    print(f"Found {total_candidates} candidate poster files.")

    for index, source_path in enumerate(source_images, start=1):
        output_path = build_output_path(source_path, args.output_name, args.format)
        process_image(source_path, output_path, args, stats)
        if should_emit_progress(index, total_candidates, args.progress_every, args.verbose):
            print_progress(index, total_candidates, stats)

    finished_at = dt.now()
    elapsed_seconds = time.time() - start_time
    elapsed = get_formatted_duration(elapsed_seconds)
    avg_rate = get_items_per_second(total_candidates, elapsed_seconds)
    logging.info("Finished in %s", elapsed)
    logging.info("Candidates Found: %s", total_candidates)
    logging.info("Processed: %s", stats.processed)
    logging.info("Created New: %s", stats.created_new)
    logging.info("Replaced Existing: %s", stats.replaced_existing)
    logging.info("Dry Run: %s", stats.dry_run)
    logging.info("Skipped Existing: %s", stats.skipped_existing)
    logging.info("Skipped Ratio: %s", stats.skipped_ratio)
    logging.info("Skipped Invalid: %s", stats.skipped_invalid)
    logging.info("Errors: %s", stats.errors)
    logging.info("Started At: %s", started_at.strftime("%Y-%m-%d %H:%M:%S"))
    logging.info("Finished At: %s", finished_at.strftime("%Y-%m-%d %H:%M:%S"))
    logging.info("Average Rate: %s candidates/sec", avg_rate)

    print("Summary:")
    print(f"Candidates Found: {total_candidates}")
    print(f"Processed: {stats.processed}")
    print(f"Created New: {stats.created_new}")
    print(f"Replaced Existing: {stats.replaced_existing}")
    print(f"Dry Run: {stats.dry_run}")
    print(f"Skipped Existing: {stats.skipped_existing}")
    print(f"Skipped Ratio: {stats.skipped_ratio}")
    print(f"Skipped Invalid: {stats.skipped_invalid}")
    print(f"Errors: {stats.errors}")
    print(f"Started At: {started_at.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Finished At: {finished_at.strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Duration: {elapsed}")
    print(f"Average Rate: {avg_rate} candidates/sec")

    clean_up_old_logs(logs_directory, script_name)
    return 0 if stats.errors == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
