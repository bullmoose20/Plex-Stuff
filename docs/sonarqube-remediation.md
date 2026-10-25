# SonarQube Cloud remediation for PR #28

Baseline: `685d81788921806f06baf476c9d106bd7f4f65ba`. Findings retrieved from the public SonarCloud API on 2026-10-25 (UTC). No gate settings or issue resolutions were changed.

Gate: reliability E, security C, maintainability A, new-code duplication 14.7% (maximum 3%), security hotspots reviewed 100%.

## Retrieved issue inventory

The API returned 45 issues: 44 open and one already fixed by analysis (`githubactions:S8541`). Locations refer to the baseline commit.

| Rule | Severity | Type | File:line | Status | Message |
|---|---|---|---|---|---|
| python:S3776 | CRITICAL | CODE_SMELL | pyprogs/tcc/title_card_clips.py:100 | OPEN | Refactor this function to reduce its Cognitive Complexity from 20 to the 15 allowed. |
| python:S3358 | MAJOR | CODE_SMELL | pyprogs/tcc/title_card_clips.py:120 | OPEN | Extract this nested conditional expression into an independent statement. |
| githubactions:S8541 | MAJOR | VULNERABILITY | .github/workflows/python-dependencies.yml:61 | CLOSED | Omitting "--only-binary :all:" can lead to the execution of setup scripts. Make sure it is safe here. |
| githubactions:S8544 | MAJOR | VULNERABILITY | .github/workflows/python-dependencies.yml:61 | OPEN | Using dependencies without locking resolved versions is security-sensitive. |
| python:S3776 | CRITICAL | CODE_SMELL | tools/audit_python.py:10 | OPEN | Refactor this function to reduce its Cognitive Complexity from 18 to the 15 allowed. |
| python:S9073 | MAJOR | CODE_SMELL | tests/test_video.py:47 | OPEN | Split this composite assertion into separate assertions. |
| python:S3776 | CRITICAL | CODE_SMELL | pyprogs/collage/collage.py:108 | OPEN | Refactor this function to reduce its Cognitive Complexity from 37 to the 15 allowed. |
| python:S930 | BLOCKER | BUG | pyprogs/collage/collage.py:149 | OPEN | Remove this unexpected named argument 'size'. |
| python:S3358 | MAJOR | CODE_SMELL | pyprogs/extract_tracks/extract_tracks.py:41 | OPEN | Extract this nested conditional expression into an independent statement. |
| python:S3358 | MAJOR | CODE_SMELL | pyprogs/extract_tracks/extract_tracks.py:77 | OPEN | Extract this nested conditional expression into an independent statement. |
| python:S3358 | MAJOR | CODE_SMELL | pyprogs/extract_tracks/extract_tracks.py:97 | OPEN | Extract this nested conditional expression into an independent statement. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/extract_tracks/extract_tracks.py:195 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/extract_tracks/extract_tracks.py:198 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/extract_tracks/extract_tracks.py:199 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/extract_tracks/extract_tracks.py:235 | OPEN | Use "logging.exception()" instead. |
| python:S3776 | CRITICAL | CODE_SMELL | pyprogs/fix_added_at/fix_added_at.py:65 | OPEN | Refactor this function to reduce its Cognitive Complexity from 34 to the 15 allowed. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/fix_added_at/fix_added_at.py:110 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/fix_added_at/fix_added_at.py:113 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/fix_added_at/fix_added_at.py:114 | OPEN | Use "logging.exception()" instead. |
| python:S1192 | CRITICAL | CODE_SMELL | pyprogs/fix_added_at/fix_added_at.py:185 | OPEN | Define a constant instead of duplicating this literal "%m/%d/%Y, %H:%M:%S" 6 times. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/fix_added_at/fix_added_at.py:227 | OPEN | Use "logging.exception()" instead. |
| pythonsecurity:S8707 | MAJOR | VULNERABILITY | pyprogs/get_missing_people.py:189 | OPEN | Path Traversal via faulty LLM-supplied CLI arguments |
| python:S8786 | MAJOR | CODE_SMELL | pyprogs/get_missing_people.py:192 | OPEN | Simplify this regular expression to reduce its runtime, as it has super-linear performance due to backtracking. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/orchestrator/orchestrator.py:665 | OPEN | Use "logging.exception()" instead. |
| python:S112 | MAJOR | CODE_SMELL | pyprogs/orchestrator/orchestrator.py:698 | OPEN | Replace this generic exception class with a more specific one. |
| python:S112 | MAJOR | CODE_SMELL | pyprogs/orchestrator/orchestrator.py:706 | OPEN | Replace this generic exception class with a more specific one. |
| python:S112 | MAJOR | CODE_SMELL | pyprogs/orchestrator/orchestrator.py:716 | OPEN | Replace this generic exception class with a more specific one. |
| python:S112 | MAJOR | CODE_SMELL | pyprogs/orchestrator/orchestrator.py:726 | OPEN | Replace this generic exception class with a more specific one. |
| python:S3776 | CRITICAL | CODE_SMELL | pyprogs/orchestrator/orchestrator.py:729 | OPEN | Refactor this function to reduce its Cognitive Complexity from 18 to the 15 allowed. |
| python:S7498 | MINOR | CODE_SMELL | pyprogs/orchestrator/visualize_task_stats.py:209 | OPEN | Replace this constructor call with a literal. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/resizer/resizer.py:311 | OPEN | Use "logging.exception()" instead. |
| pythonsecurity:S8707 | MAJOR | VULNERABILITY | pyprogs/strip_columns/strip_columns.py:14 | OPEN | Path Traversal via faulty LLM-supplied CLI arguments in strip_columns.strip_characters() |
| pythonsecurity:S8707 | MAJOR | VULNERABILITY | pyprogs/strip_columns/strip_columns.py:26 | OPEN | Path Traversal via faulty LLM-supplied CLI arguments in strip_columns.strip_characters() |
| python:S1192 | CRITICAL | CODE_SMELL | pyprogs/tcc/title_card_clips.py:205 | OPEN | Define a constant instead of duplicating this literal r"Season\s\d+" 3 times. |
| python:S3776 | CRITICAL | CODE_SMELL | pyprogs/update_plex_artist_art/update_plex_artist_art.py:50 | OPEN | Refactor this function to reduce its Cognitive Complexity from 67 to the 15 allowed. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/update_plex_artist_art/update_plex_artist_art.py:104 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/update_plex_artist_art/update_plex_artist_art.py:107 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/update_plex_artist_art/update_plex_artist_art.py:108 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/update_plex_artist_art/update_plex_artist_art.py:206 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/update_plex_artist_art/update_plex_artist_art.py:209 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/update_plex_artist_art/update_plex_artist_art.py:211 | OPEN | Use "logging.exception()" instead. |
| python:S8572 | MAJOR | CODE_SMELL | pyprogs/update_plex_artist_art/update_plex_artist_art.py:235 | OPEN | Use "logging.exception()" instead. |
| python:S9073 | MAJOR | CODE_SMELL | tests/test_images.py:149 | OPEN | Split this composite assertion into separate assertions. |
| python:S5727 | CRITICAL | CODE_SMELL | pyprogs/exif_overlay_checker/exif_overlay_checker.py:138 | OPEN | Remove this identity check; it will always be True. |
| python:S1481 | MINOR | CODE_SMELL | pyprogs/get-info.py:31 | OPEN | Replace the unused loop index "i" with "_". |

## Duplicated blocks

Ranges below come directly from `/api/duplications/show` for PR 28. Overlapping groups are preserved; identical groups returned for multiple files are listed once.

- `pyprogs/collage/collage.py:13-83`; `pyprogs/exif_overlay_checker/exif_overlay_checker.py:13-83`; `pyprogs/tcc/title_card_clips.py:18-88`
- `pyprogs/collage/collage.py:31-48`; `pyprogs/exif_overlay_checker/exif_overlay_checker.py:31-48`; `pyprogs/fmg/fake_media_generator.py:33-50`; `pyprogs/resizer/resizer.py:67-84`; `pyprogs/tcc/title_card_clips.py:36-53`
- `pyprogs/collage/collage.py:53-83`; `pyprogs/exif_overlay_checker/exif_overlay_checker.py:53-83`; `pyprogs/extract_tracks/extract_tracks.py:110-140`; `pyprogs/fix_added_at/fix_added_at.py:15-45`; `pyprogs/fmg/fake_media_generator.py:62-92`; `pyprogs/resizer/resizer.py:111-141`; `pyprogs/tcc/title_card_clips.py:58-88`; `pyprogs/update_plex_artist_art/update_plex_artist_art.py:17-47`
- `pyprogs/extract_tracks/extract_tracks.py:110-144`; `pyprogs/update_plex_artist_art/update_plex_artist_art.py:17-51`
- `pyprogs/extract_tracks/extract_tracks.py:154-189`; `pyprogs/update_plex_artist_art/update_plex_artist_art.py:61-96`
- `pyprogs/extract_tracks/extract_tracks.py:156-189`; `pyprogs/fix_added_at/fix_added_at.py:68-101`; `pyprogs/update_plex_artist_art/update_plex_artist_art.py:63-96`
- `pyprogs/fmg/fake_media_generator.py:7-25`; `pyprogs/tcc/title_card_clips.py:12-30`
- `pyprogs/fmg/fake_media_generator.py:33-52`; `pyprogs/resizer/resizer.py:67-86`
- `pyprogs/fix_added_at/fix_added_at.py:12-45`; `pyprogs/update_plex_artist_art/update_plex_artist_art.py:14-47`
- `pyprogs/fix_added_at/fix_added_at.py:68-111`; `pyprogs/update_plex_artist_art/update_plex_artist_art.py:63-105`
- `pyprogs/get_missing_people.py:4-17`; `pyprogs/get_missing_people_dir.py:3-16`
- `pyprogs/get_missing_people.py:40-59`; `pyprogs/get_missing_people_dir.py:24-43`
- `pyprogs/get_missing_people.py:163-176`; `pyprogs/get_missing_people_dir.py:81-94`
- `pyprogs/orchestrator/orchestrator.py:445-470`; `pyprogs/orchestrator/orchestrator.py:516-541`; `pyprogs/orchestrator/orchestrator.py:587-612`
- `pyprogs/orchestrator/orchestrator.py:479-504`; `pyprogs/orchestrator/orchestrator.py:550-575`; `pyprogs/orchestrator/orchestrator.py:621-646`

## Change plan

1. Verify the collage font signature against the installed supported Pillow API and force its fallback in a regression test.
2. Validate paths at filesystem boundaries, including symlink escapes, while preserving deliberate local CLI file selection. Add offline regressions before altering behavior.
3. Make CI dependency installation reproducible with hashes and binary wheels, retaining weekly Dependabot maintenance and all supported interpreters.
4. Share only the duplicated logging/duration, image classification, Plex connection, and service polling behavior identified above. Preserve standalone entry points and script-specific settings.
5. Run the complete local and CI checks, push focused commits to PR 28, and retrieve the final Sonar gate and issue state.

## Results

The actual SonarQube Cloud gate passed on refactor commit `b4aaea7` and again on
workflow-correction commit `a54aea4` (check run `121048203435`). The API reported:

| Condition | Baseline | Verified result | Requirement |
|---|---|---|---|
| New-code reliability | E | A; zero bugs | A |
| New-code security | C | A; zero vulnerabilities | A |
| New-code duplication | 14.7% | 0.0% | At most 3% |
| New-code maintainability | A | A | A |
| Security hotspots reviewed | 100% | 100% | 100% |

No quality-gate settings, analysis scopes, exclusions, issue acceptance statuses
or rule suppressions were changed. `ignoredConditions` is false. Findings closed
through subsequent analysis of the fixes. Baseline findings above remain an
audit record, rather than a claim that they are all still open.

### Fixes and regression coverage

- `python:S930`: the supported Pillow 13 API accepts a font size, but Sonar's
  signature model expected zero arguments. Use `load_default()` followed by
  the public FreeType `font_variant(size=12)` API. A forced missing-Arial
  regression verifies the actual drawn font size, pixels and output dimensions.
  The bitmap fallback remains available if FreeType is unavailable.
- `pythonsecurity:S8707`: canonicalize explicitly selected paths, require
  regular files, and check containment before reading logs or opening text
  outputs. Reject links escaping the named directory. Preserve deliberate
  absolute paths, relative parent paths, custom outputs, and the selected
  filename for allowed in-directory links. These are local CLI tools, not HTTP
  services; selecting another directory intentionally remains supported.
- `githubactions:S8544`: install exact transitive versions from
  `requirements-ci.txt` with SHA-256 verification. Require wheels, with the
  documented hash-verified `titlecase` source-distribution exception. Test lock
  completeness and compatibility with every active manifest. Keep the lock
  discoverable by Dependabot alongside the original supported-version ranges.
- Extract only the reported common behavior: logging setup/retention, duration
  formatting, credential-safe Plex connection handling, People image mode
  classification/logging, and Arr download-client state changes. Preserve the
  six existing service entry points, API versions, headers, timeouts, skipped
  clients, payload fields and success handling. Tests mock every service call.
- Preserve the Selenium retirement and the PyAV decoder. Title-card timestamp,
  generated-frame, layout, filename, dimension, rotation, skip and cleanup
  regressions continue to run. Shared CLI logging is the only title-card change.

### Exact validation evidence

[CI run 40152896982](https://github.com/bullmoose20/Plex-Stuff/actions/runs/40152896982)
on `a54aea4` completed all four jobs successfully:

| Environment | Job | pytest result |
|---|---|---|
| Linux Python 3.12 | 121047962775 | 149 passed in 3.53s |
| Linux Python 3.13 | 121047962881 | 149 passed in 2.67s |
| Linux Python 3.14 | 121047962830 | 149 passed in 2.72s |
| Windows Python 3.14 | 121047962931 | 149 passed in 5.85s |

All four installed the hash-verified lock, passed `pip check` and reported no
known vulnerabilities in `pip-audit`. The designated Linux 3.14 Ruff job passed.
All symlink security tests ran successfully on both CI platforms.

One subsequent regression preserves the chosen filename for an allowed
in-directory link, bringing the final suite to **150 tests**, including all
123 original tests. Local Windows validation of that suite passed on
CPython 3.12.15, 3.13.17 and 3.14.9: **146 passed, four skipped** on each.
The four skips require symlink creation, which this local account cannot do.
Local `pip check` passed on all three; `pip-audit` found zero vulnerabilities
across 56, 55 and 55 distributions respectively. Ruff passed.

The final pushed-head CI and Sonar checks are linked in
[PR #28](https://github.com/bullmoose20/Plex-Stuff/pull/28), which remains open
and unmerged. The inventory generator now distinguishes the 21 entry points
from their one shared module and does not mislabel local imports as packages.
There are 17 active dependency manifests, including the new CI lock.

### Remaining limitations

Sonar still reports maintainability suggestions; its maintainability grade is
A. A passing gate does not mean the repository has zero code smells. Sonar's
automatic analysis does not ingest pytest coverage, so its coverage display
does not measure this suite. No coverage gate was disabled or changed.

The `titlecase` publisher does not provide a wheel; its pinned, hash-verified
source build uses build tooling. Dependency advisories do not audit every
bundled FFmpeg codec. Keep the established real-Plex report/apply, representative
media/visual-output and controlled orchestration manual checks. Tests never
contact live services or require credentials. No secrets were introduced, no
history was rewritten, and no PR was merged or closed.
