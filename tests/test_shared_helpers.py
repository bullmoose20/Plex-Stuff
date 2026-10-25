from pathlib import Path
from unittest.mock import Mock

import pytest
import requests

import plex_stuff_helpers as helpers


@pytest.mark.parametrize(
    "seconds,expected",
    [
        (0, "0.000 milliseconds"),
        (0.001, "1.000 millisecond"),
        (61, "1 minute 1 second"),
        (90061.5, "1 day 1 hour 1 minute 1 second"),
    ],
)
def test_duration_output_is_preserved(seconds, expected):
    assert helpers.get_formatted_duration(seconds) == expected


def test_log_retention_limits_only_the_selected_script(tmp_path):
    for name in ("tool_001.log", "tool_002.log", "tool_003.log", "other_001.log"):
        (tmp_path / name).touch()
    assert helpers.prune_logs(tmp_path, "tool", 2) == 2
    assert sorted(p.name for p in tmp_path.iterdir()) == ["other_001.log", "tool_002.log", "tool_003.log"]
    assert helpers.prune_logs(tmp_path, "tool", 0) == 1
    assert (tmp_path / "tool_003.log").exists()


def test_log_retention_treats_script_name_as_literal(tmp_path):
    for name in ("tool[1]_001.log", "tool[1]_002.log", "tool1_001.log"):
        (tmp_path / name).touch()
    helpers.prune_logs(tmp_path, "tool[1]", 1)
    assert sorted(p.name for p in tmp_path.iterdir()) == ["tool1_001.log", "tool[1]_002.log"]


def test_logging_uses_current_environment_and_existing_output_layout(monkeypatch):
    monkeypatch.setenv("MAX_LOG_FILES", "7")
    monkeypatch.setenv("LOG_LEVEL", "WARNING")
    monkeypatch.setattr("sys.argv", ["/somewhere/a tool.py"])
    configure = Mock()
    monkeypatch.setattr(helpers.logging, "basicConfig", configure)
    limit, name, directory, timestamp = helpers.configure_logging()
    assert (limit, name, directory) == (7, "a tool", "logs")
    assert len(timestamp) == 19
    assert Path(directory).is_dir()
    assert configure.call_args.kwargs["filename"] == Path("logs") / f"a tool_{timestamp}.log"
    assert configure.call_args.kwargs["level"] == helpers.logging.WARNING


def test_shared_plex_connection_keeps_timeout_and_redacts_errors(monkeypatch, caplog, capsys):
    monkeypatch.setenv("PLEX_URL", "http://plex.invalid")
    monkeypatch.setenv("PLEX_TOKEN", "mock-token")
    monkeypatch.setenv("PLEX_TIMEOUT", "17")
    factory = Mock(return_value=object())
    assert helpers.connect_plex(factory) is factory.return_value
    factory.assert_called_once_with("http://plex.invalid", "mock-token", timeout=17)
    factory.side_effect = requests.RequestException("MOCK_SECRET_SENTINEL")
    with pytest.raises(SystemExit) as error:
        helpers.connect_plex(factory)
    assert error.value.code == 1
    assert "RequestException" in caplog.text
    assert "MOCK_SECRET_SENTINEL" not in caplog.text + capsys.readouterr().out


def test_people_log_paths_and_append_behavior(tmp_path):
    script = tmp_path / "people.py"
    stale_log = tmp_path / "people.py.log"
    stale_log.write_text("previous run", encoding="utf-8")
    script_log, download_log, download_dir = helpers.initialize_people_outputs(script)
    helpers.append_people_log(script_log, "café")
    content = Path(script_log).read_text(encoding="utf-8")
    assert "previous run" not in content
    assert "#### START ####" in content
    assert "café" in content
    assert Path(download_log) == tmp_path / "people.py_downloads.log"
    assert Path(download_dir) == tmp_path / "Downloads"
    assert Path(download_dir).is_dir()
