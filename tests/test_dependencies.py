"""Prevent undeclared direct imports and incompatible manifest drift."""

import ast
from importlib.metadata import version
import sys

from packaging.requirements import Requirement
from packaging.utils import canonicalize_name
import pytest

from conftest import ROOT

IMPORT_DISTRIBUTIONS = {
    "PIL": "Pillow",
    "dotenv": "python-dotenv",
    "plexapi": "PlexAPI",
    "cv2": "opencv-python-headless",
    "exifread": "ExifRead",
    "cpuinfo": "py-cpuinfo",
    "yaml": "PyYAML",
    "qbittorrentapi": "qbittorrent-api",
}


def requirements(path):
    result = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("-r "):
            result.extend(requirements(path.parent / line[3:]))
        elif line and not line.startswith("#"):
            result.append(Requirement(line))
    return result


SCRIPTS = sorted((ROOT / "pyprogs").rglob("*.py"))


@pytest.mark.parametrize("path", SCRIPTS, ids=lambda p: p.relative_to(ROOT).as_posix())
def test_each_scripts_direct_dependencies_are_declared(path):
    tree = ast.parse(path.read_text(encoding="utf-8"))
    imports = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imports.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            imports.add((node.module or "").split(".")[0])
    declared = {canonicalize_name(req.name) for req in requirements(path.parent / "requirements.txt")}
    local_modules = {p.stem for p in (ROOT / "pyprogs").glob("*.py")}
    for name in imports - sys.stdlib_module_names - local_modules:
        distribution = canonicalize_name(IMPORT_DISTRIBUTIONS.get(name, name))
        assert distribution in declared, (
            f"{path.name}: direct import {name} missing from {path.parent.name}/requirements.txt"
        )


@pytest.mark.parametrize(
    "path",
    [ROOT / "requirements.txt", *sorted((ROOT / "pyprogs").rglob("requirements.txt"))],
    ids=lambda p: p.relative_to(ROOT).as_posix(),
)
def test_dependency_manifests_are_utf8_and_installed_versions_satisfy_them(path):
    for req in requirements(path):
        if req.marker is None or req.marker.evaluate():
            assert req.specifier.contains(version(req.name)), f"{req.name} violates {path}"


def test_no_stdlib_or_retired_dependencies_remain():
    declared = {canonicalize_name(req.name) for req in requirements(ROOT / "requirements.txt")}
    assert not declared & {"argparse", "sqlalchemy", "setuptools", "moviepy", "imageio-ffmpeg", "selenium"}


def test_aggregate_includes_all_script_manifests():
    aggregate = {canonicalize_name(req.name) for req in requirements(ROOT / "requirements.txt")}
    for path in (ROOT / "pyprogs").rglob("requirements.txt"):
        names = {canonicalize_name(req.name) for req in requirements(path)}
        assert names <= aggregate, f"Dependencies from {path.relative_to(ROOT)} missing from CI installation"


def test_dependabot_discovers_active_manifests_without_retired_tool():
    from fnmatch import fnmatchcase
    import yaml

    config = yaml.safe_load((ROOT / ".github/dependabot.yml").read_text(encoding="utf-8"))
    updates = [update for update in config["updates"] if update["package-ecosystem"] == "pip"]
    patterns = [directory for update in updates for directory in update.get("directories", [update.get("directory")])]
    manifests = [
        ROOT / "requirements.txt",
        ROOT / "requirements-dev.txt",
        ROOT / "requirements-ci.txt",
        *(ROOT / "pyprogs").rglob("requirements.txt"),
    ]
    for manifest in manifests:
        assert "sel_remove_bg" not in manifest.parts
        directory = "/" + manifest.parent.relative_to(ROOT).as_posix().strip(".")
        assert any(fnmatchcase(directory, pattern) for pattern in patterns), f"Dependabot misses {manifest}"
    assert all(update["target-branch"] == "main" for update in updates)


def test_ci_lock_pins_and_hashes_every_resolved_dependency():
    locked = set()
    text = (ROOT / "requirements-ci.txt").read_text(encoding="utf-8").replace("\\\n", " ")
    for line in text.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        specification, *hashes = line.split("--hash=")
        req = Requirement(specification.strip())
        assert hashes, f"{req.name} has no integrity hashes"
        assert all(value.strip().startswith("sha256:") for value in hashes)
        assert len(req.specifier) == 1
        assert next(iter(req.specifier)).operator == "=="
        if req.marker is None or req.marker.evaluate():
            assert req.specifier.contains(version(req.name))
            locked.add(canonicalize_name(req.name))
    for path in (ROOT / "requirements.txt", ROOT / "requirements-dev.txt"):
        assert {canonicalize_name(req.name) for req in requirements(path)} <= locked
