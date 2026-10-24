import json
import os
from pathlib import Path
from unittest.mock import Mock

import pytest


@pytest.mark.parametrize(
    "remote",
    [
        "/Movies/café/file.mkv",
        r"D:\Movies\café\file.mkv",
        r"\\server\share\Movies\café\file.mkv",
        "Movies/café/file.mkv",
    ],
)
def test_media_paths_map_under_local_root(load_script, tmp_path, remote):
    module = load_script("fix_added_at/fix_added_at.py")
    assert module.media_path_under(tmp_path, remote) == tmp_path / "Movies/café/file.mkv"


@pytest.mark.parametrize("remote", ["/Movies/../../outside.mkv", r"C:\..\outside.mkv", "../outside.mkv", "/"])
def test_media_path_traversal_rejected(load_script, tmp_path, remote):
    module = load_script("fix_added_at/fix_added_at.py")
    with pytest.raises(ValueError):
        module.media_path_under(tmp_path, remote)


def test_strip_columns_unicode_and_original_preserved(load_script, tmp_path):
    module = load_script("strip_columns/strip_columns.py")
    source = tmp_path / "média.txt"
    source.write_text("xxcafé\nxx海报\n", encoding="utf-8")
    module.strip_characters(source, 2)
    assert (tmp_path / "média_stripped.txt").read_text(encoding="utf-8") == "café\n海报\n"
    assert source.read_text(encoding="utf-8").startswith("xx")


def test_orchestrator_uses_direct_venv_interpreter_and_preserves_arguments(load_script, tmp_path, monkeypatch):
    module = load_script("orchestrator/orchestrator.py")
    folder = tmp_path / "script folder"
    folder.mkdir()
    script = folder / "tool.py"
    script.touch()
    venv = tmp_path / "venv with spaces"
    executable = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    executable.parent.mkdir(parents=True)
    executable.touch()
    run = Mock(return_value=(1, 0))
    monkeypatch.setattr(module, "run_task_with_pause_check", run)
    before = Path.cwd()
    assert module.run_script_with_context(str(script), ["--name", "a & b"], 1, 2, str(venv)) == (1, 0)
    assert run.call_args.args[0] == [str(executable), "tool.py", "--name", "a & b"]
    assert Path.cwd() == before


def test_orchestrator_restores_directory_on_failure(load_script, tmp_path):
    module = load_script("orchestrator/orchestrator.py")
    before = Path.cwd()
    assert module.run_script_with_context(str(tmp_path / "unsupported.txt"), [], 1, 2) == (0, 0)
    assert Path.cwd() == before


def test_qbittorrent_public_methods_have_correct_hash_parameter(load_script, monkeypatch):
    module = load_script("orchestrator/orchestrator.py")
    client = Mock()
    monkeypatch.setattr(module, "connect_to_qbittorrent", lambda: client)
    module._pause_qbittorrent_torrents()
    module._resume_qbittorrent_torrents()
    client.torrents_pause.assert_called_once_with(torrent_hashes="all")
    client.torrents_resume.assert_called_once_with(torrent_hashes="all")


def test_task_configuration_validation_and_yaml_safe_loading(load_script, tmp_path):
    module = load_script("orchestrator/orchestrator.py")
    config = tmp_path / "tasks.yml"
    config.write_text("tasks:\n  - description: Example\n    script_path: tool.py\n    args: []\n", encoding="utf-8")
    assert module.validate_and_load_config(config)["tasks"][0]["description"] == "Example"
    config.write_text("!!python/object/apply:os.system ['echo forbidden']", encoding="utf-8")
    with pytest.raises(ValueError):
        module.load_config(config)
    with pytest.raises(ValueError, match="args"):
        module.validate_tasks_config([{"description": "Test", "script_path": "a.py", "args": "invalid"}])


def test_numpy_stats_are_json_serializable(load_script, tmp_path):
    module = load_script("orchestrator/visualize_task_stats.py")
    result = module.calculate_aggregate_metrics([10, 20], [8, 16], [2, 4])
    module.save_aggregate_metrics(result)
    assert json.loads((tmp_path / "stats/aggregate_metrics.json").read_text())["average_total_time"] == 15


def test_fake_media_output_matches_sample_bytes(load_script, tmp_path, monkeypatch):
    module = load_script("fmg/fake_media_generator.py")
    # Generated stand-in; never copy personal media or a large repository AVI.
    (tmp_path / "sample.avi").write_bytes(b"generated-test-media")
    module.create_folders_and_files({"title": "Example: Movie"}, "movie", "tt0000001")
    files = list((tmp_path / "output/movies").rglob("*.avi"))
    assert len(files) == 1
    assert files[0].read_bytes() == b"generated-test-media"
    assert "Example_ Movie" in files[0].name
