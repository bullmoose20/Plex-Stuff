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

Remediation and validation are in progress. The baseline gate is failing; successful Python CI alone does not satisfy this task.
