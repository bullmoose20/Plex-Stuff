import os

import pytest

from conftest import PROFILE, ROOT

SCRIPTS = sorted(p.relative_to(ROOT / "pyprogs").as_posix() for p in (ROOT / "pyprogs").rglob("*.py"))
SELECTED = [p for p in SCRIPTS if (p.startswith("tcc/")) == (PROFILE == "video")]


@pytest.mark.parametrize("relative", SELECTED)
def test_module_loading_is_offline_and_does_not_run_cli(relative, load_script, tmp_path, monkeypatch):
    monkeypatch.setattr("sys.argv", ["unrelated-host", "--not-a-script-option"])
    load_script(relative)
    for name in (
        "logs",
        "output",
        "original",
        "sel_downloads",
        "tv_shows.csv",
        "get_plex_labels.log",
        "detection_log.log",
    ):
        assert not (tmp_path / name).exists(), f"Import created {name}: {relative}"


def test_no_personal_environment_is_loaded():
    assert os.environ["PYTHON_DOTENV_DISABLED"] == "1"
