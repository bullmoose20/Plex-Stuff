"""Prevent undeclared direct imports and incompatible manifest drift."""

import ast
from importlib.metadata import version
import sys

from packaging.requirements import Requirement
from packaging.utils import canonicalize_name
import pytest

from conftest import ROOT

IMPORT_DISTRIBUTIONS = {
    "imageio_ffmpeg": "imageio-ffmpeg",
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
    for name in imports - sys.stdlib_module_names:
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
    assert not declared & {"argparse", "sqlalchemy", "setuptools", "moviepy"}


def test_aggregate_includes_all_script_manifests():
    aggregate = {canonicalize_name(req.name) for req in requirements(ROOT / "requirements.txt")}
    for path in (ROOT / "pyprogs").rglob("requirements.txt"):
        names = {canonicalize_name(req.name) for req in requirements(path)}
        assert names <= aggregate, f"Dependencies from {path.relative_to(ROOT)} missing from CI installation"
