"""Real ffmpeg output regression tests, using bundled ffmpeg and generated media."""

import os

import pytest

pytestmark = [
    pytest.mark.video,
    pytest.mark.skipif(
        os.environ.get("PLEX_STUFF_TEST_PROFILE") != "video", reason="Run in isolated video environment"
    ),
]


def test_generated_video_extracts_expected_frame_and_releases_file(load_script, tmp_path):
    from moviepy import ColorClip
    from PIL import Image

    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "test video é.mp4"
    with ColorClip((32, 24), color=(230, 20, 40), duration=1) as clip:
        clip.write_videofile(str(source), fps=4, codec="libx264", audio=False, logger=None)
    output = tmp_path / "S01E01.jpg"
    module.take_screenshots(source, output, 0.5)
    with Image.open(output) as image:
        assert image.size == (32, 24)
        red, green, blue = image.getpixel((16, 12))
        assert red > 220 and green < 30 and blue < 50
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
