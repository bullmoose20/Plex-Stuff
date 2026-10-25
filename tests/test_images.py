from argparse import Namespace

import numpy as np
from PIL import Image, PngImagePlugin
import pytest


def sample(path, size=(120, 180), color=(220, 30, 50), mode="RGB"):
    Image.new(mode, size, color).save(path)
    return path


@pytest.mark.parametrize(
    "size,min_width,max_width,expected",
    [
        ((121, 90), 60, 120, (60, 90)),
        ((60, 181), 60, 120, (60, 90)),
        ((40, 60), 60, 120, (60, 90)),
        ((240, 360), 60, 120, (120, 180)),
    ],
)
def test_resizer_dimensions_pixels_and_source_preservation(load_script, tmp_path, size, min_width, max_width, expected):
    module = load_script("resizer/resizer.py")
    source = sample(tmp_path / "portrait é.png", size)
    original = source.read_bytes()
    output = tmp_path / "result"
    output.mkdir()
    module.resize_image(str(source), str(output), min_width, max_width)
    with Image.open(output / "portrait é.jpg") as result:
        assert result.size == expected
        assert result.mode == "RGB"
        assert np.max(np.abs(np.array(result.getpixel((0, 0))) - (220, 30, 50))) <= 3
    assert source.read_bytes() == original


def test_collage_unicode_paths_font_fallback_and_jpeg(load_script, tmp_path):
    module = load_script("collage/collage.py")
    folder = tmp_path / "café 海报"
    folder.mkdir()
    sample(folder / "first.JPG", (20, 30))
    sample(folder / "second.png", (20, 30), (0, 0, 255))
    sample(folder / "!_existing.png")
    module.__file__ = str(tmp_path / "collage.py")
    image = module.create_image_grid(folder, 2, (40, 40), True, False, True, "JPG", 95)
    assert image.size == (80, 80)
    assert image.getpixel((20, 40))[0] > 200
    result_path = folder / "!_café 海报_grid.jpg"
    with Image.open(result_path) as result:
        assert result.format == "JPEG"
        assert result.size == image.size
    assert len(module.get_image_files(folder)) == 2


def test_collage_missing_truetype_font_uses_sized_pillow_fallback(load_script, tmp_path, monkeypatch):
    module = load_script("collage/collage.py")
    sample(tmp_path / "poster.png", (20, 30))
    fallback = module.ImageFont.load_default(12)
    calls = []

    def unavailable(*args, **kwargs):
        raise OSError("Test font is unavailable")

    def load_default(size):
        calls.append(size)
        return fallback

    monkeypatch.setattr(module.ImageFont, "truetype", unavailable)
    monkeypatch.setattr(module.ImageFont, "load_default", load_default)
    image = module.create_image_grid(tmp_path, 1, (40, 40), True, False, False, "PNG", 95)
    assert calls == [12]
    assert image.size == (40, 80)
    assert image.getpixel((20, 40))[0] > 200


@pytest.mark.parametrize("extension", ["jpg", "png", "webp"])
def test_square_regression_and_skip_existing(load_script, tmp_path, extension):
    module = load_script("poster_to_square/poster_to_square.py")
    assert module.initialize_pillow()
    source = sample(tmp_path / ("poster." + extension))
    output = tmp_path / ("square." + extension)
    args = Namespace(
        overwrite=False,
        ratio_tolerance=0.1,
        dry_run=False,
        size=200,
        blur_radius=8,
        poster_height=0.9,
        background_brightness=0.6,
        background_color=0.8,
        format="auto",
        quality=95,
    )
    stats = module.Stats()
    module.process_image(source, output, args, stats)
    with Image.open(output) as image:
        assert image.size == (200, 200)
        assert image.getpixel((100, 100))[0] > 200
    first_bytes = output.read_bytes()
    module.process_image(source, output, args, stats)
    assert output.read_bytes() == first_bytes
    assert stats.skipped_existing == 1
    sample(output, (30, 50))
    module.process_image(source, output, args, stats)
    assert stats.replaced_existing == 1


def test_square_dry_run_and_bad_input(load_script, tmp_path):
    module = load_script("poster_to_square/poster_to_square.py")
    module.initialize_pillow()
    source = sample(tmp_path / "poster.png")
    args = Namespace(overwrite=False, ratio_tolerance=0.1, dry_run=True)
    stats = module.Stats()
    module.process_image(source, tmp_path / "square.png", args, stats)
    assert stats.dry_run == 1
    assert not (tmp_path / "square.png").exists()
    source.write_bytes(b"invalid image")
    module.process_image(source, tmp_path / "square.png", args, stats)
    assert stats.skipped_invalid == 1


@pytest.mark.parametrize("size", [(1920, 1080), (320, 180), (100, 200)])
def test_landscape_crop_uses_actual_image_size(load_script, size):
    module = load_script("ltp/landscape_to_portrait.py")
    image = Image.new("RGB", size, (230, 40, 20))
    result = module.resize_and_crop(image, 60, 90)
    assert result.size == (60, 90)
    assert result.getpixel((0, 0)) == (230, 40, 20)


@pytest.mark.parametrize(
    "filename,color,expected", [("gray.png", (80, 80, 80), "Grayscale"), ("color.png", (255, 0, 0), "RGB")]
)
@pytest.mark.parametrize("script", ["get_missing_people.py", "get_missing_people_dir.py"])
def test_grayscale_classification(load_script, tmp_path, filename, color, expected, script):
    module = load_script(script)
    assert module.determine_image_mode(sample(tmp_path / filename, color=color)) == expected


@pytest.mark.parametrize("extension", ["png", "jpg"])
def test_overlay_metadata_public_pillow_api(load_script, tmp_path, extension):
    checker = load_script("exif_overlay_checker/exif_overlay_checker.py")
    detector = load_script("pmm-detect-overlays.py")
    path = tmp_path / ("tagged." + extension)
    image = Image.new("RGB", (20, 30), "red")
    if extension == "png":
        metadata = PngImagePlugin.PngInfo()
        metadata.add_text("Description", "Kometa Overlay")
        image.save(path, pnginfo=metadata)
    else:
        exif = Image.Exif()
        exif[270] = "Kometa Overlay"
        image.save(path, exif=exif)
    assert checker.check_overlay_in_exif(path)[0] is True
    assert detector.detect_overlay_in_exif(path) is True
    sample(path)
    assert checker.check_overlay_in_exif(path)[0] is False
    assert detector.detect_overlay_in_exif(path) is False


def test_numpy_opencv_template_matching_with_unicode_paths(load_script, tmp_path):
    module = load_script("pmm-detect-overlays.py")
    random = np.random.default_rng(42)
    tile = random.integers(0, 255, (12, 12), dtype=np.uint8)
    target = random.integers(0, 255, (50, 60), dtype=np.uint8)
    target[20:32, 10:22] = tile
    source_path, target_path = tmp_path / "小.png", tmp_path / "大.png"
    Image.fromarray(tile).save(source_path)
    Image.fromarray(target).save(target_path)
    matched, score = module.detect_embedded_images(str(source_path), str(target_path))
    assert matched and score > 0.99
    assert module.detect_embedded_images(str(target_path), str(source_path)) == (False, 0)
