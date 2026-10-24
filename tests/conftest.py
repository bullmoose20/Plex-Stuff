"""All script tests run with isolated configuration and no service access."""

import importlib.util
import os
from pathlib import Path
import sys
from uuid import uuid4

import pytest

ROOT = Path(__file__).resolve().parents[1]
PROFILE = os.environ.get("PLEX_STUFF_TEST_PROFILE", "core")
os.environ["PYTHON_DOTENV_DISABLED"] = "1"
os.environ["MPLBACKEND"] = "Agg"


@pytest.fixture(autouse=True)
def isolated_runtime(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    for name in tuple(os.environ):
        if any(
            word in name.upper()
            for word in ("PLEX", "TMDB", "SONARR", "RADARR", "LIDARR", "SEL_", "QBITTORRENT", "SABNZBD", "NZBGET")
        ):
            monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("PYTHON_DOTENV_DISABLED", "1")
    monkeypatch.setenv("PLEXAPI_CONFIG_PATH", str(tmp_path / "nonexistent.ini"))
    monkeypatch.setenv("MPLCONFIGDIR", str(tmp_path / "matplotlib"))

    def forbidden(*args, **kwargs):
        raise AssertionError("External service, browser or interactive input attempted during offline testing")

    monkeypatch.setattr("builtins.input", forbidden)
    import requests

    monkeypatch.setattr(requests.sessions.Session, "request", forbidden)
    if PROFILE == "core":
        from selenium import webdriver

        monkeypatch.setattr(webdriver, "Chrome", forbidden)


@pytest.fixture
def load_script():
    loaded = []

    def load(relative):
        path = ROOT / "pyprogs" / relative
        name = "plex_stuff_test_" + uuid4().hex
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        loaded.append(name)
        spec.loader.exec_module(module)
        return module

    yield load
    for name in loaded:
        sys.modules.pop(name, None)
