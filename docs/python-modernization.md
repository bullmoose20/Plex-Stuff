# Python modernization audit and plan

Audit baseline: `11bab30` (main), 2026-10-24. Scope: all 22 active Python files,
14 per-script manifests and the root manifest. The retired Python file is
archival, has no active entry point, and is outside the supported runtime.

## Findings before implementation

* Root pins retain NumPy 1.24, Pillow 9, MoviePy 1, PlexAPI 4.12 and dotenv
  0.20. These predate the requested Python versions. Syntax-only CI cannot
  detect binary incompatibility or functional regressions.
* Root is missing OpenCV, ExifRead, titlecase, matplotlib, PyYAML, Selenium and
  qbittorrent-api. Per-script manifests also omit direct requests imports in
  extract_tracks, fix_added_at and ltp, and qbittorrent-api in orchestrator.
* SQLAlchemy has no consumers, including in the retired database cleaner,
  which uses standard-library sqlite3.
  setuptools is not an application dependency; argparse is standard library.
* MoviePy 2.2.1 declares Pillow <12. Do not override package metadata or use
  --no-deps. Isolate title-card dependencies if this restriction remains.
* Several modules parse arguments, prompt, sample the machine for two minutes,
  write files or connect to Plex/TMDb during import. Others require .env even
  though defaults suffice. Move startup work behind explicit entry points.
* Requests DEFAULT_TIMEOUT assignment does not configure PlexAPI timeouts.
  Pass timeout explicitly. Error strings/response bodies can contain tokens;
  never include these in diagnostics. The tracked Selenium .env must be
  replaced by a sanitized example without reading its values into reports.
* Pillow private _getexif, hardcoded Arial, byte-path decoding in collage,
  unclosed image/video handles, broken PNG overlay metadata handling, and
  hardcoded Overlay label removal require application changes and tests.
* fix_added_at removes the first character of every Plex path, corrupting
  Windows drive paths. Orchestrator activates Windows venvs through a shell,
  breaking arguments with spaces and portability. Use direct interpreters.
* Browser automation depends on a changing Adobe website and installed Chrome.
  Shell/PowerShell wrappers and real service integrations need manual checks.
  Automated tests must never launch those integrations.

## Proposed sequence

1. Commit this report and a per-file dependency/entry-point inventory.
2. Make imports inert; preserve command-line entry points, explicit runtime
   configuration and report/apply confirmation behavior. Add offline regression
   tests before upgrading dependencies.
3. Upgrade dependency groups, fix Pillow/MoviePy/PlexAPI/NumPy call sites and
   filesystem handling; test each significant group with supported interpreters.
4. Gate changes with pip check, Ruff, pytest and pip-audit. Run a Linux matrix
   for 3.12/3.13/3.14 and one Windows job. Resolve every per-script manifest,
   including the isolated video group, and block network calls during pytest.
5. Update weekly Dependabot coverage, group minor/patch updates and leave major
   updates separate. Document local VS Code checks, exceptions, results and
   manual checks. Open a PR targeting main; do not enable automatic merging.

## Upstream references

* [MoviePy package metadata](https://pypi.org/pypi/moviepy/json)
* [MoviePy 2 migration](https://zulko.github.io/moviepy/getting_started/updating_to_v2.html)
* [Pillow deprecations](https://pillow.readthedocs.io/en/stable/deprecations.html)
* [PyAV package metadata](https://pypi.org/pypi/av/json)
* [imageio-ffmpeg recommends PyAV](https://github.com/imageio/imageio-ffmpeg#purpose)
* [setup-python releases](https://github.com/actions/setup-python/releases)
* [checkout releases](https://github.com/actions/checkout/releases)

## Implementation decisions and results

The planned MoviePy isolation was rejected after checking security advisories:
Pillow 11.3 and 12.x have known advisories fixed in later versions. MoviePy
2.2.1 still requires Pillow <12. Title-card extraction now uses PyAV's direct
FFmpeg bindings, preserves RGB JPEG output and timestamp selection, and closes
the decoder on success and failure. PyAV replaces the initial imageio-ffmpeg
implementation: that project's maintainers recommend PyAV, whose current wheels
support Python 3.12–3.14 without declared Pillow/NumPy constraints. Seeking uses
presentation timestamps, including for variable-rate videos and stream offsets.
No dependency metadata overrides,
vulnerability allowlists or EOL Python workarounds are used. Pillow >=13 is the
supported security baseline; Pillow 12 and MoviePy 1/2 are intentionally excluded.
See [MoviePy metadata](https://pypi.org/pypi/moviepy/json) and
[Pillow advisories](https://pypi.org/pypi/Pillow/11.3.0/json).

All 22 scripts load without configuration, argument parsing, service requests,
browser startup, prompts or application file creation. Runtime .env loading stays
at CLI startup; pure image tools can use defaults without a .env. PlexAPI requests
receive explicit timeouts. Command arguments and exception payloads are omitted
from service diagnostics. The local Selenium .env is preserved but untracked;
future .env files are ignored, and a sanitized example is included.

Regression fixes include Unicode collage paths and JPEG encoding, default font
fallback, exact crop coordinates, center cropping based on actual image size,
public EXIF/PNG metadata access, selected-label removal with original lock
restoration, drive/UNC-aware Plex path mapping with traversal rejection, and
shell-free Python venv execution. Requests queries encode person names correctly.
Intentional behavior changes and manual checks are in
[the maintenance guide](python-maintenance.md).

Local Windows verification passed installation, pip check and 123 offline
pytest cases on Python 3.12.15, 3.13.17 and 3.14.9. Ruff passed. The final PR and
CI runs provide the authoritative Linux/Windows results for the committed code.
Security scans use the current advisory database and must be repeated on updates.

The [baseline inventory](python-inventory.md) records every original entry point.
[Current API usage](python-api-usage.md) records current third-party call sites.
The archived cleaner was also inspected statically: it imports PlexAPI, requests
and python-dotenv, has unguarded execution and destructive database/filesystem
operations. It stays retired and is never imported by tests; use the replacement
linked from the root README. Non-Python wrappers remain platform-specific and
outside the Python support claim.

## Selenium retirement follow-up

The seven modernization commits through `b38e736` are preserved. The obsolete
Selenium tool is removed in a separate follow-up commit: implementation,
exclusive manifest and configuration example, aggregate dependency include and
Selenium-specific fixture setup. Its local `.env` remains untracked and
untouched. A retirement notice replaces executable archived code; Git preserves
the implementation history.

The verified generation source is
[Kometa-Team/Defaults-Image-Creation/create_people_posters](https://github.com/Kometa-Team/Defaults-Image-Creation/tree/main/create_people_posters),
whose README and `remove_bg_birefnet.py` identify local BiRefNet Portrait through
rembg as the default. People-Images and People-Images-transparent publish assets.
There are now **21 active scripts and 13 per-tool manifests**. The baseline
inventory above remains historical; the current API inventory excludes Selenium.

PyAV application code is unchanged from `b38e736`; MoviePy remains absent from
active dependencies, and no Pillow upper bound is restored. Additional offline
regressions capture the established movie/episode filenames, output layout and
skip behavior. CI requires a PyAV binary wheel on every Python/platform job.

The missing `origin/modernization/python-dependency-maintenance` reference was
restored with an explicit fetch and its fetch mapping retained for future pulls.
No reset, rebase, existing commit modification or history rewrite was performed.

The [configuration-history assessment and Dependabot PR review](python-maintenance.md#historical-configuration-security-assessment)
record exposure scope, rotation guidance and the six superseded dependency PRs.
Final retirement validation is recorded in the PR and the
[exact validation record](python-validation.md): 123 tests per supported Python
version in fresh local environments and all four Linux/Windows CI jobs, passing
Ruff/dependency checks and no known Python-package vulnerabilities. The record
includes exact runtime versions, binary-wheel tags, security-assessment scope
and remaining manual checks.
## SonarQube follow-up

The PR's SonarQube gate initially failed despite passing Python CI. The
[remediation report](sonarqube-remediation.md) records every retrieved rule,
severity, baseline location and duplicated block, the targeted fixes, and the
actual passing Sonar evidence. New-code duplication fell from 14.7% to 0.0%;
reliability and security improved from E/C to A/A without changing the gate or
excluding code. The final suite has 150 tests, preserving the original 123.
The 21 entry points now share one inert helper module. A hash-verified CI lock
adds one manifest to the 16 already active after Selenium retirement.

