# Python modernization audit and plan

Audit baseline: `11bab30` (main), 2026-10-24. Scope: all 23 active Python files,
14 per-script manifests and the root manifest. The retired Python file is
archival, has no active entry point, and is outside the supported runtime.

## Findings before implementation

* Root pins retain NumPy 1.24, Pillow 9, MoviePy 1, PlexAPI 4.12 and dotenv
  0.20. These predate the requested Python versions. Syntax-only CI cannot
  detect binary incompatibility or functional regressions.
* Root is missing OpenCV, ExifRead, titlecase, matplotlib, PyYAML, Selenium and
  qbittorrent-api. Per-script manifests also omit direct requests imports in
  extract_tracks, fix_added_at and ltp, and qbittorrent-api in orchestrator.
* SQLAlchemy has no active consumers (only the retired database cleaner).
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
* [setup-python releases](https://github.com/actions/setup-python/releases)
* [checkout releases](https://github.com/actions/checkout/releases)

Implementation results and remaining verification will be recorded below.
