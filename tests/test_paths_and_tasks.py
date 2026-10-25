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


def make_file_link(link, target):
    try:
        link.symlink_to(target)
    except OSError as error:
        if os.name == "nt" and error.winerror == 1314:
            pytest.skip("Windows account lacks permission to create symbolic links")
        raise


@pytest.mark.parametrize("side", ["input", "output"])
def test_strip_columns_rejects_links_escaping_selected_directory(load_script, tmp_path, side):
    module = load_script("strip_columns/strip_columns.py")
    selected = tmp_path / "selected"
    selected.mkdir()
    outside = tmp_path / "outside.txt"
    outside.write_text("outside content", encoding="utf-8")
    source = selected / "input.txt"
    output = selected / "output.txt"
    if side == "input":
        make_file_link(source, outside)
    else:
        source.write_text("xxsafe", encoding="utf-8")
        make_file_link(output, outside)
    with pytest.raises(ValueError, match="outside"):
        module.strip_characters(source, 2, output)
    assert outside.read_text(encoding="utf-8") == "outside content"


def test_strip_columns_supports_deliberate_paths_outside_working_directory(load_script, tmp_path, monkeypatch):
    module = load_script("strip_columns/strip_columns.py")
    selected = tmp_path / "selected"
    selected.mkdir()
    work = tmp_path / "work"
    work.mkdir()
    source = selected / "input.txt"
    source.write_text("xxsafe\n", encoding="utf-8")
    monkeypatch.chdir(work)
    module.strip_characters("../selected/input.txt", 2, selected / "custom.txt")
    assert (selected / "custom.txt").read_text(encoding="utf-8") == "safe\n"


def test_metalog_reader_filters_files_and_preserves_unicode(load_script, tmp_path):
    module = load_script("get_missing_people.py")
    (tmp_path / "meta-é.log").write_text("海报", encoding="utf-8")
    (tmp_path / "ignore.log").write_text("ignored", encoding="utf-8")
    (tmp_path / "meta-directory").mkdir()
    assert list(module.read_metalogs(tmp_path)) == [("meta-é.log", "海报")]


def test_metalog_reader_rejects_link_outside_log_directory(load_script, tmp_path):
    module = load_script("get_missing_people.py")
    root = tmp_path / "logs"
    root.mkdir()
    outside = tmp_path / "outside.log"
    outside.write_text("not a selected log", encoding="utf-8")
    make_file_link(root / "meta.log", outside)
    with pytest.raises(ValueError, match="outside"):
        list(module.read_metalogs(root))


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


@pytest.mark.parametrize("service,version", [("sonarr", "v3"), ("radarr", "v3"), ("lidarr", "v1")])
@pytest.mark.parametrize("enabled", [True, False])
def test_arr_client_state_changes_preserve_payload_and_skip_unchanged(
    load_script, monkeypatch, capsys, service, version, enabled
):
    module = load_script("orchestrator/orchestrator.py")
    monkeypatch.setattr(module, service.upper() + "_URL", "http://service.invalid")
    monkeypatch.setattr(module, service.upper() + "_API_KEY", "mock-service-key")
    changed = {"id": 1, "name": "Changed", "enable": not enabled, "fields": [{"name": "host", "value": "local"}]}
    unchanged = {"id": 2, "name": "Unchanged", "enable": enabled}
    get = Mock(return_value=Mock(status_code=200, json=lambda: [changed, unchanged]))
    put = Mock(return_value=Mock(status_code=202))
    monkeypatch.setattr(module.requests, "get", get)
    monkeypatch.setattr(module.requests, "put", put)
    action = "enable" if enabled else "disable"
    getattr(module, f"{action}_{service}_download_clients")()
    url = f"http://service.invalid/api/{version}/downloadclient"
    get.assert_called_once_with(url, headers={"X-Api-Key": "mock-service-key"}, timeout=60)
    put.assert_called_once_with(
        url + "/1", json={**changed, "enable": enabled}, headers={"X-Api-Key": "mock-service-key"}, timeout=60
    )
    assert changed["enable"] is not enabled
    assert "mock-service-key" not in capsys.readouterr().out


def test_arr_failed_list_request_does_not_modify_clients(load_script, monkeypatch):
    module = load_script("orchestrator/orchestrator.py")
    monkeypatch.setattr(module.requests, "get", Mock(return_value=Mock(status_code=503)))
    put = Mock()
    monkeypatch.setattr(module.requests, "put", put)
    module.disable_lidarr_download_clients()
    put.assert_not_called()


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
