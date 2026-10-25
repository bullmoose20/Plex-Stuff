"""Real PyAV output regressions using bundled FFmpeg and generated media."""

import pytest

pytestmark = pytest.mark.video


def make_timestamped_video(path, timestamps, rotation=0):
    """Encode known presentation timestamps without relying on frame indexes."""
    import av
    from fractions import Fraction
    from PIL import Image

    with av.open(str(path), "w") as container:
        stream = container.add_stream("libx264", rate=4)
        stream.width, stream.height = 32, 24
        stream.pix_fmt = "yuv420p"
        if rotation:
            stream.set_display_rotation(rotation)
        for index, timestamp in enumerate(timestamps):
            color = (230, 20, 40) if index < 2 else (20, 30, 230)
            with Image.new("RGB", (32, 24), color) as image:
                if rotation:
                    from PIL import ImageDraw

                    ImageDraw.Draw(image).rectangle((0, 0, 7, 23), fill=(20, 230, 40))
                frame = av.VideoFrame.from_image(image)
            frame.time_base = Fraction(1, 1000)
            frame.pts = timestamp
            for packet in stream.encode(frame):
                container.mux(packet)
        for packet in stream.encode():
            container.mux(packet)


def test_generated_video_extracts_expected_frame_and_releases_file(load_script, tmp_path):
    from PIL import Image

    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "test video é.mp4"
    make_timestamped_video(source, [0, 250, 500, 750])
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


@pytest.mark.parametrize("start", [0, 5000])
def test_variable_frame_rate_and_nonzero_start_use_presentation_timestamps(load_script, tmp_path, start):
    import av
    from PIL import Image

    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "variable.mkv"
    make_timestamped_video(source, [start, start + 250, start + 1500, start + 2000])
    with av.open(str(source)) as container:
        stream = container.streams.video[0]
        assert float(stream.start_time * stream.time_base) == start / 1000
        times = [float(frame.pts * frame.time_base) for frame in container.decode(stream)]
        assert times == [start / 1000 + offset for offset in (0, 0.25, 1.5, 2)]
    early, late = tmp_path / "early.jpg", tmp_path / "late.jpg"
    module.take_screenshots(source, early, 0.25)
    module.take_screenshots(source, late, 1.25)
    with Image.open(early) as image:
        assert image.getpixel((16, 12))[0] > 220
    with Image.open(late) as image:
        assert image.getpixel((16, 12))[2] > 220


@pytest.mark.parametrize("timestamp", [-1, float("nan"), float("inf")])
def test_invalid_timestamp_never_writes_output(load_script, tmp_path, timestamp):
    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "source.mp4"
    source.touch()
    output = tmp_path / "out.jpg"
    with pytest.raises(ValueError, match="duration"):
        module.take_screenshots(source, output, timestamp)
    assert not output.exists()


def test_corrupt_video_does_not_leak_file_handle(load_script, tmp_path):
    import av

    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "corrupt.mp4"
    source.write_bytes(b"generated-invalid-video")
    output = tmp_path / "out.jpg"
    with pytest.raises(av.error.FFmpegError):
        module.take_screenshots(source, output, 0)
    assert not output.exists()
    source.rename(tmp_path / "moved.mp4")


def test_audio_only_input_is_rejected_without_output(load_script, tmp_path):
    import wave

    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "audio.wav"
    with wave.open(str(source), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(8000)
        audio.writeframes(b"\x00\x00" * 8000)
    output = tmp_path / "out.jpg"
    with pytest.raises(ValueError, match="no video"):
        module.take_screenshots(source, output, 0)
    assert not output.exists()
    source.rename(tmp_path / "moved.wav")


def test_output_write_failure_closes_video(load_script, tmp_path, monkeypatch):
    from PIL import Image

    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "source.mp4"
    make_timestamped_video(source, [0, 250, 500, 750])

    def cannot_save(*args, **kwargs):
        raise OSError("Generated write failure")

    monkeypatch.setattr(Image.Image, "save", cannot_save)
    with pytest.raises(OSError, match="write failure"):
        module.take_screenshots(source, tmp_path / "out.jpg", 0.5)
    source.rename(tmp_path / "moved.mp4")


@pytest.mark.parametrize(
    "rotation,size,green_point,red_point",
    [
        (90, (24, 32), (12, 28), (12, 8)),
        (-90, (24, 32), (12, 4), (12, 24)),
        (180, (32, 24), (28, 12), (8, 12)),
    ],
)
def test_display_rotation_preserves_orientation(load_script, tmp_path, rotation, size, green_point, red_point):
    import av
    from PIL import Image

    module = load_script("tcc/title_card_clips.py")
    source = tmp_path / "rotated.mp4"
    make_timestamped_video(source, [0, 250, 500, 750], rotation=rotation)
    with av.open(str(source)) as container:
        frame = next(container.decode(video=0))
        assert abs(frame.rotation) == abs(rotation)
    output = tmp_path / "out.jpg"
    module.take_screenshots(source, output, 0)
    with Image.open(output) as image:
        assert image.size == size
        assert image.getpixel(green_point)[1] > 220
        assert image.getpixel(red_point)[0] > 220


@pytest.mark.parametrize(
    "is_show,filename,relative_dir,expected",
    [
        (False, "Movie (2026).mp4", "Movie (2026)", "Movie (2026).jpg"),
        (True, "Show S02E03 episode.mkv", "Show/Season 02", "S02E03.jpg"),
    ],
)
def test_scan_preserves_filenames_output_layout_and_skip(
    load_script, tmp_path, monkeypatch, is_show, filename, relative_dir, expected
):
    from pathlib import Path
    from unittest.mock import Mock

    module = load_script("tcc/title_card_clips.py")
    module.__file__ = str(tmp_path / "tool.py")
    root = tmp_path / "media"
    folder = root / relative_dir
    folder.mkdir(parents=True)
    (folder / filename).touch()

    def extract(source, output, timestamp):
        assert timestamp == 45
        Path(output).write_bytes(b"generated-title-card")

    decoder = Mock(side_effect=extract)
    monkeypatch.setattr(module, "take_screenshots", decoder)
    module.scan_directory(str(root), 45)
    # Capture the established layout, including the existing duplicated base folder.
    base_name = "Show" if is_show else "Movie (2026)"
    destination = tmp_path / "output" / base_name / relative_dir / expected
    assert destination.read_bytes() == b"generated-title-card"
    assert module.format_file_name(filename, is_show) == expected
    module.scan_directory(str(root), 45)
    decoder.assert_called_once()
