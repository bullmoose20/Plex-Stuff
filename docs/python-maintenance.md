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
| PyAV (`av`) | Direct FFmpeg library binding replaces MoviePy; current wheels support Python 3.12–3.14 without declared Pillow/NumPy version constraints. Generated videos verify timestamps, variable frame rates, stream start offsets, rotation, RGB output and file release |
| SQLAlchemy | Removed: no consumers; retired cleaner uses sqlite3 and stays unsupported |
| PlexAPI | Current 4.x API; mocked report/apply, label locks, art, metadata and timeout checks |
| OpenCV | Headless package: no GUI usage; NumPy 2 binary integration tested with generated templates |
| Selenium | Retired; no implementation, configuration example or manifest is actively maintained. Use the linked BiRefNet generation source |
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
Requests calls and interactive input. No active script imports Selenium. .env loading is
disabled and service variables are removed. Use fake `.invalid` hosts and mock
tokens only. Never enable a live-service exception in the default suite.

Installing packages and `pip-audit` advisory retrieval require internet. pytest
does not: FFmpeg libraries are supplied by the PyAV wheel, with no runtime
downloads or external FFmpeg executable. pip-audit checks Python distribution
advisories, not every bundled codec. Review upstream PyAV and FFmpeg security
releases when updating video dependencies.

PyAV was selected over imageio-ffmpeg because its
[maintainers recommend PyAV](https://github.com/imageio/imageio-ffmpeg#purpose),
and [PyAV's current metadata](https://pypi.org/pypi/av/json) provides compatible
binary wheels with no declared runtime dependency pins. This removes MoviePy's
Pillow restriction; it does not guarantee future upgrades will be compatible.
The version matrix and output regressions remain the compatibility gate.

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
  instead of silently reporting a created title card. PyAV seeks to a preceding
  keyframe and selects the first presented frame at or after the requested time,
  relative to the video stream's start. It uses presentation timestamps rather
  than assumed frame rates, including for variable-rate media.
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
* Selenium/Adobe automation in `pyprogs/sel_remove_bg` is retired. Its replacement
  is the [BiRefNet generation source](https://github.com/Kometa-Team/Defaults-Image-Creation/tree/main/create_people_posters),
  rather than the published People-Images asset repositories. See the
  [retirement notice](../pyprogs/sel_remove_bg/README.md). Follow that project's
  model/environment setup separately; no models are downloaded by this test suite.
* The local Selenium `.env` and any local browser artifacts remain untouched and
  ignored. Its former tracked configuration example is removed. Keep personal
  profiles, tokens, API keys and paths out of PRs. No repository-history rewrite
  or real-service verification was performed.

These manual checks do not require credentials in CI and are not substitutes
for the automated matrix. The archived database cleaner and shell wrappers have
no new Python compatibility guarantee.

## Historical configuration security assessment

On 2026-10-24, the complete fetched Git history was inspected for committed
`.env` and `.env*` configurations: 30 configuration-change commits and 30 unique
configuration blobs. Values were classified in memory and never included in
logs, this report or the PR description. Local personal configuration was not
read or changed.

The retired Selenium `.env`, introduced in `10e3710` and untracked in `c36ce84`,
contained 15 path/preference assignments, no credential assignments and no URL
containing authentication. Its later eight-setting example also contained no
credentials. No tracked browser profile/cookie store was found. No credential
rotation is indicated by retiring that file; personal paths in history remain
visible because history has not been rewritten.

The broader configuration scan found a placeholder identifier for the root
Plex token, placeholder API credentials, and public default qBittorrent/NZBGet
passwords in orchestrator examples. These are not evidence of a leaked private
key. **If those defaults were used in a real deployment, change those service
passwords.** No credentials were submitted to any service to test validity.
Unrelated configurations were preserved.

This was a targeted configuration-history assessment, not a claim that every
arbitrary historical text blob, GitHub secret or local browser profile has been
audited. Any real secret previously shared elsewhere still requires rotation.

## Existing Dependabot PR review

All six open Dependabot PRs were inspected on 2026-10-24. They target `main` and
change the original flat root manifest. After PR #28 is merged by a maintainer,
their existing patches will be obsolete:

| PR | Proposed update | Disposition against modernized manifests |
| --- | --- | --- |
| [#22](https://github.com/bullmoose20/Plex-Stuff/pull/22) | python-dotenv 1.2.4 | Already included in active manifests |
| [#23](https://github.com/bullmoose20/Plex-Stuff/pull/23) | requests 2.34.2 | Already included in active manifests |
| [#24](https://github.com/bullmoose20/Plex-Stuff/pull/24) | Pillow 13.0.0 | Already included in active manifests |
| [#25](https://github.com/bullmoose20/Plex-Stuff/pull/25) | NumPy 2.5.4 | Already included in active manifests |
| [#26](https://github.com/bullmoose20/Plex-Stuff/pull/26) | MoviePy 2.2.1 | Dependency removed; PyAV is the supported replacement |
| [#27](https://github.com/bullmoose20/Plex-Stuff/pull/27) | psutil 7.2.2 | Already included in active manifests |

None was closed, merged or configured for automatic merging. A maintainer should
reassess them after adopting #28; future updates should use the active per-tool
manifests. Dependabot's wildcard directory discovery finds no manifest in the
retired Selenium directory. An offline regression checks coverage of all active
manifests and prevents Selenium from returning to the aggregate requirements.
