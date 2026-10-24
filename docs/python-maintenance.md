# Python support and dependency maintenance

Active scripts support CPython **3.12, 3.13 and 3.14**. CI runs the full offline
suite on Linux for each version and on Windows with 3.14. Use a separate virtual
environment for this repository; old environments with MoviePy installed conflict
with the supported Pillow version.

## Local checks and VS Code

From the repository root, on Windows:

```powershell
py -3.14 -m venv .venv
.venv\Scripts\python -m pip install --upgrade pip
.venv\Scripts\python -m pip install -r requirements.txt -r requirements-dev.txt
.venv\Scripts\python -m pip check
.venv\Scripts\python -m ruff check pyprogs tests tools
.venv\Scripts\python -m pytest -q
.venv\Scripts\python -m pip_audit --progress-spinner off
```

On Linux/macOS use `python3.14 -m venv .venv` and `.venv/bin/python` in the
remaining commands. Repeat with 3.12 and 3.13 when changing dependencies. macOS
is not currently part of the automated platform matrix.

In VS Code open this repository folder, select `.venv` through **Python: Select
Interpreter**, then enable pytest in **Python: Configure Tests** and select
`tests`. The same pytest configuration is used locally and in CI. No VS Code
extensions or personal settings need to be committed.

`requirements.txt` aggregates all active scripts. To install only one tool use
its own `pyprogs/<tool>/requirements.txt`; scripts directly under `pyprogs/` use
`pyprogs/requirements.txt`. `strip_columns` uses only the standard library.
Every direct third-party import must appear in the appropriate manifest,
even when another installed package happens to provide it transitively.

## Supported dependency choices

| Dependency | Decision |
| --- | --- |
| NumPy | 2.x APIs and current binary wheels; image/template/metrics tests cover usage |
| Pillow | Public resampling, pixel and EXIF APIs; >=13 required by current security advisories |
| MoviePy | Removed: 2.2.1 requires Pillow <12, conflicting with current security fixes |
| imageio-ffmpeg | Direct frame decoder replaces the only MoviePy use; generated video verifies timestamps, dimensions, RGB output and file release |
| SQLAlchemy | Removed: no consumers; retired cleaner uses sqlite3 and stays unsupported |
| PlexAPI | Current 4.x API; mocked report/apply, label locks, art, metadata and timeout checks |
| OpenCV | Headless package: no GUI usage; NumPy 2 binary integration tested with generated templates |
| Selenium | Dependency/import checks and browser-call blocking; real Adobe/Chrome workflow needs manual testing |
| qbittorrent-api | Explicit dependency; public pause/resume methods with `torrent_hashes` support current server routing |
| argparse / setuptools | Removed from application manifests; standard library / build tooling respectively |

Minimum versions are maintained security/compatibility floors, not a lockfile.
New environments resolve current compatible releases. Major-version updates stay
separate in Dependabot so their behavior changes can receive focused review.
Do not use `--no-deps`, ignored advisories or an EOL Python to force a solution.
The Pillow 12 restriction is intentional; do not restore it to satisfy MoviePy.

## Automated test boundaries

Tests generate tiny RGB/grayscale/EXIF/PNG images, random template fixtures, UTF-8
text and a short two-color video. They check dimensions, pixel colors, timestamp
selection, output format, preservation of originals, existing-output behavior,
metadata detection, Windows/UNC/Unicode paths, traversal rejection and process
arguments. Each active script is imported under an unrelated host argument list.

pytest-socket blocks sockets; the test fixture additionally rejects unmocked
Requests calls, browser construction and interactive input. .env loading is
disabled and service variables are removed. Use fake `.invalid` hosts and mock
tokens only. Never enable a live-service exception in the default suite.

Installing packages and `pip-audit` advisory retrieval require internet. pytest
does not: FFmpeg is supplied by the installed wheel, with no runtime downloads.
pip-audit checks Python distribution advisories, not every codec bundled in the
FFmpeg executable. Review upstream imageio-ffmpeg/FFmpeg security releases when
updating video dependencies.

## Dependabot review

Weekly Monday updates target `main` for pip manifests at `/`, `/pyprogs` and
`/pyprogs/*`, plus GitHub Actions. Each ecosystem allows five open PRs; minor
and patch updates are grouped and major updates stay individual. Automatic
merging is not enabled. Normal `pull_request` CI runs without secrets, including
for Dependabot PRs. Workflow permissions are `contents: read`; checkout does not
persist credentials. Manual dispatch and pushes to `main` also run checks.

For an update, use the failure's named step: installation means resolver/wheel
support, pip check means inconsistent metadata, Ruff means code/API problems,
pytest means an import or behavioral regression, and pip-audit means a known
advisory (or advisory-service connectivity). Fix the relevant code or dependency
and rerun the affected regression before rerunning the full matrix. Do not merge
on green installation alone. Consider making the matrix checks required through
repository branch protection when adopting this workflow.

Regenerate the API inventory with:

```powershell
python -X utf8 tools/audit_python.py
```

## Intentional changes and remaining manual verification

* Importing modules performs no CLI work. Run the same script paths as before.
  Optional .env loading happens at command startup. Reports and existing apply
  confirmations remain; an out-of-range video timestamp now fails explicitly
  instead of silently reporting a created title card.
* Image cropping fixes remove off-by-one crop asymmetry and black padding from
  small/non-16:9 artwork. Collage uses Pillow's bundled default font if Arial is
  absent; text appearance can differ on machines without Arial.
* `fix_added_at` maps a Plex path beneath the chosen local root, dropping the
  POSIX root, Windows drive or UNC share. For example `/Movies/A/movie.mkv` and
  `D:\Movies\A\movie.mkv` map to `<chosen-root>/Movies/A/movie.mkv`. Paths escaping
  that root are rejected, including resolved symlinks. Confirm the mapping in
  the existing preview before applying timestamp changes.
* Orchestrator executes a venv's interpreter directly and preserves arguments
  with spaces/metacharacters. PowerShell tasks still require installed PowerShell;
  service behavior, process suspension and server maintenance windows require a
  controlled manual smoke test. Use disposable tasks and test server libraries.
* Verify representative real photos/posters visually and compare a real local
  video screenshot at a known timestamp, including rotated/variable-frame-rate
  media, before a bulk run. Codec pixel rounding can differ across platforms.
* Adobe browser automation remains sensitive to website/Chrome changes, existing
  browser profiles and download timing. Test on copied source images; its
  established original/archive moves and overwrite behavior are preserved.
* The local Selenium `.env` is now ignored and untracked, with a sanitized
  `.env.example`. Keep personal profiles, tokens, API keys and paths out of PRs.
  No repository-history rewrite or real-service verification was performed.

These manual checks do not require credentials in CI and are not substitutes
for the automated matrix. The archived database cleaner and shell wrappers have
no new Python compatibility guarantee.
