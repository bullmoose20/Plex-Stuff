from io import BytesIO
from types import SimpleNamespace
from unittest.mock import Mock

from PIL import Image
import pytest
import requests


def test_track_title_report_does_not_edit_and_apply_does(load_script, monkeypatch):
    module = load_script("extract_tracks/extract_tracks.py")
    track = Mock(title="a song about love")
    album = Mock()
    album.tracks.return_value = [track]
    artist = Mock(title="Artist")
    artist.albums.return_value = [album]
    library = Mock(type="artist")
    library.all.return_value = [artist]
    module.plex = Mock()
    module.plex.library.sections.return_value = [library]
    module.args = SimpleNamespace(apply=False)
    processor = module.PlexTrackProcessor(use_title_case=True)
    processor.extract_tracks()
    assert processor.total_tracks == 1
    assert processor.tracks_bad_case == 1
    track.editTitle.assert_not_called()
    module.args.apply = True
    processor.extract_tracks()
    track.editTitle.assert_called_once_with(title="A Song About Love")


@pytest.mark.parametrize("locked", [True, False])
def test_selected_label_removed_and_original_lock_preserved(load_script, monkeypatch, locked):
    module = load_script("label_remover/label_remover.py")
    item = Mock(title="Example")
    field = SimpleNamespace(name="label", locked=locked)
    item.fields = [field]
    item.labels = [SimpleNamespace(tag="Custom Label"), SimpleNamespace(tag="Overlay")]

    def remove(label):
        item.labels = [value for value in item.labels if value.tag != label]

    item.removeLabel.side_effect = remove
    monkeypatch.setattr("builtins.input", lambda prompt: "1")
    module.manage_labels(item, "show")
    item.removeLabel.assert_called_once_with("Custom Label")
    assert [label.tag for label in item.labels] == ["Overlay"]
    assert item.editField.call_count == (2 if locked else 0)


def test_plex_connection_timeout_and_secret_safe_errors(load_script, monkeypatch, caplog, capsys):
    module = load_script("label_remover/label_remover.py")
    module.PLEX_URL = "http://plex.invalid"
    module.PLEX_TOKEN = "mock-token-never-real"
    constructor = Mock(return_value=Mock())
    monkeypatch.setattr(module, "PlexServer", constructor)
    assert module.connect_to_plex() is constructor.return_value
    constructor.assert_called_once_with(module.PLEX_URL, module.PLEX_TOKEN, timeout=60)
    constructor.side_effect = requests.RequestException("http://plex.invalid?X-Plex-Token=MOCK_SECRET_SENTINEL")
    with pytest.raises(requests.RequestException):
        module.connect_to_plex()
    assert "MOCK_SECRET_SENTINEL" not in caplog.text + capsys.readouterr().out
    assert "RequestException" in caplog.text


def test_mocked_movie_art_creates_valid_portrait_and_skips_cached(load_script, tmp_path, monkeypatch):
    module = load_script("ltp/landscape_to_portrait.py")
    module.OUTPUT_FOLDER = str(tmp_path / "posters")
    module.PLEX_URL = "http://plex.invalid"
    module.PLEX_TOKEN = "mock-token"
    buffer = BytesIO()
    Image.new("RGB", (320, 180), "red").save(buffer, format="PNG")
    response = Mock(content=buffer.getvalue())
    get = Mock(return_value=response)
    monkeypatch.setattr(module.SESSION, "get", get)
    movie = {"title": "Movie", "type": "movie", "locations": [r"D:\Media\Movie\movie.mkv"], "art": "/library/art"}
    stats = {"processed": 0, "skipped": 0, "errors": 0}
    cache = set()
    module.process_movie(movie, "Movies", stats, cache)
    with Image.open(tmp_path / "posters/Movies/Movie/poster.jpg") as image:
        assert image.size == (1000, 1500)
        assert image.getpixel((500, 750))[0] > 240
    assert stats == {"processed": 1, "skipped": 0, "errors": 0}
    assert "mock-token" not in get.call_args.args[0]
    assert get.call_args.kwargs["headers"] == {"X-Plex-Token": "mock-token"}
    module.process_movie(movie, "Movies", stats, cache)
    assert stats["skipped"] == 1
    get.assert_called_once()


def test_tmdb_lookup_encodes_query_and_handles_response(load_script, monkeypatch):
    module = load_script("find-imdb-person.py")
    module.api_key = "mock-key"
    get = Mock(
        side_effect=[
            Mock(json=lambda: {"total_results": 1, "results": [{"id": 42, "name": "A & B"}]}),
            Mock(json=lambda: {"imdb_id": "nm0000042"}),
        ]
    )
    monkeypatch.setattr(module.requests, "get", get)
    assert "nm0000042" in module.find_person_by_name("A & B")
    assert get.call_args.kwargs["timeout"] == 60
