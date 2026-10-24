"""Real ffmpeg output regression tests, using bundled ffmpeg and generated media."""

import pytest

pytestmark = pytest.mark.video


def test_generated_video_extracts_expected_frame_and_releases_file(load_script, tmp_path):
    from imageio_ffmpeg import write_frames
    import numpy as np
    from PIL import Image

    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "test video é.mp4"
    writer = write_frames(str(source), (32, 24), fps=4, codec="libx264", macro_block_size=1)
    try:
        writer.send(None)
        for index in range(4):
            color = (230, 20, 40) if index < 2 else (20, 30, 230)
            writer.send(np.full((24, 32, 3), color, dtype=np.uint8))
    finally:
        writer.close()
    output = tmp_path / "S01E01.jpg"
    module.take_screenshots(source, output, 0.75)
    with Image.open(output) as image:
        assert image.size == (32, 24)
        red, green, blue = image.getpixel((16, 12))
        assert red < 30 and green < 40 and blue > 220
    early = tmp_path / "early.jpg"
    module.take_screenshots(source, early, 0)
    with Image.open(early) as image:
        assert image.getpixel((16, 12))[0] > 220
    first = output.read_bytes()
    module.take_screenshots(source, output, 0.5)
    assert output.read_bytes() == first
    with pytest.raises(ValueError, match="duration"):
        module.take_screenshots(source, tmp_path / "invalid.jpg", 10)
    source.rename(tmp_path / "renamed.mp4")


def test_video_open_failure_propagates_without_cleanup_error(load_script, tmp_path):
    module = load_script("tcc/title_card_clips.py")
    with pytest.raises((OSError, FileNotFoundError)):
        module.take_screenshots(tmp_path / "missing.mp4", tmp_path / "out.jpg", 0)
