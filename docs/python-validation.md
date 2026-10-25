# Selenium retirement validation

Validated 2026-10-24 (America/Toronto), after preserving the seven modernization
commits through `b38e736`. Retirement implementation: **`17d8b8c`**. The later
validation-record commit changes documentation only.

## Local Windows: fresh active-only environments

Each environment was newly created, then installed with
`pip install --only-binary=av -r requirements.txt -r requirements-dev.txt`.
Neither Selenium nor MoviePy is installed. Existing environments and personal
configuration were preserved.

| CPython | pytest | pip check | pip-audit distributions | Known Python-package vulnerabilities |
| --- | --- | --- | --- | --- |
| 3.12.15 | 123 passed, 0 skipped/errors/failures | Passed | 56 | 0 |
| 3.13.17 | 123 passed, 0 skipped/errors/failures | Passed | 55 | 0 |
| 3.14.9 | 123 passed, 0 skipped/errors/failures | Passed | 55 | 0 |

Ruff check and formatting checks passed for `pyprogs`, `tests` and `tools`.
No live services, credentials, personal media or network-enabled pytest fixtures
were used. The raw local JUnit and audit JSON files remain ignored.

## GitHub Actions: retirement implementation

[Run 40146369778](https://github.com/bullmoose20/Plex-Stuff/actions/runs/40146369778)
tested `17d8b8c3c86bfbfe8aa721936ac20eed049bac06` and completed successfully.

| Job | Actual CPython | pytest result | pip check / pip-audit |
| --- | --- | --- | --- |
| [Linux 3.12](https://github.com/bullmoose20/Plex-Stuff/actions/runs/40146369778/job/121028468687) | 3.12.15 | 123 passed in 1.67s | Passed / no known vulnerabilities |
| [Linux 3.13](https://github.com/bullmoose20/Plex-Stuff/actions/runs/40146369778/job/121028468748) | 3.13.16 | 123 passed in 2.62s | Passed / no known vulnerabilities |
| [Linux 3.14](https://github.com/bullmoose20/Plex-Stuff/actions/runs/40146369778/job/121028468788) | 3.14.8 | 123 passed in 2.92s | Passed / no known vulnerabilities |
| [Windows 3.14](https://github.com/bullmoose20/Plex-Stuff/actions/runs/40146369778/job/121028468584) | 3.14.9 | 123 passed in 5.83s | Passed / no known vulnerabilities |

Dependency installation passed in every job. Ruff passed in its designated Linux
3.14 job. The patch versions above reflect the action's selected runtimes; the
local installations additionally exercised newer 3.13/3.14 patch releases.
PR #28's checks show the run for the latest documentation head as well.

## PyAV / FFmpeg evidence

The title-card implementation and its dependency manifest are byte-for-byte
unchanged from `b38e736`. PyAV **19.0.2** installed binary wheels in every tested
environment:

* Windows: `av-19.0.2-cp312-abi3-win_amd64.whl`, including CPython 3.13 and 3.14.
* Linux: `av-19.0.2-cp312-abi3-manylinux_2_28_x86_64.whl` on all three versions.

The `cp312-abi3` tag is compatible with the tested newer CPython interpreters;
CI's `--only-binary=av` prevents an unnoticed source-build fallback. The Windows
runtime reports libavcodec/libavformat **63.1.102** and libavutil **61.1.102**.
No external FFmpeg executable is invoked by the title-card implementation.

Generated-media tests verify presentation timestamps, variable frame rates,
nonzero stream starts, rotations, RGB output, dimensions, corrupt/audio-only
inputs, invalid timestamps, cleanup after errors, and existing-output skipping.
Additional scan regressions verify the established movie/episode filenames and
output layout, including its existing duplicated base-folder component. That
layout was intentionally preserved rather than redesigned.

No active manifest contains MoviePy, imageio-ffmpeg, Selenium or a Pillow upper
bound. The current Pillow security floor remains >=13. The new active-manifest
coverage regression and the existing direct-import/aggregate-manifest checks
passed. Dependabot discovers **16 active manifests**: root application/development,
standalone `pyprogs`, and 13 per-tool manifests. The retired directory has only a
tracked retirement notice, with no executable code or dependency manifest.

## Security, PR review and remaining manual checks

The [configuration-history assessment](python-maintenance.md#historical-configuration-security-assessment)
found no credentials in the historical Selenium configuration and does not
indicate rotation for that file. Public default service passwords in unrelated
examples must be changed if used in a deployment. The assessment inspected 30
configuration blobs across 30 configuration-change commits without printing
values; it is not a comprehensive secret scan of every historical text file.
No Git history rewrite was performed.

[Dependabot PRs #22–#27](python-maintenance.md#existing-dependabot-pr-review)
remain open and untouched: five proposed versions are already present in the
modernized manifests; #26 updates the now-removed MoviePy dependency.

Remaining manual verification is limited to real Plex report/apply behavior in
disposable libraries, representative local media/codec and visual checks, and
controlled orchestration/process/service tests. BiRefNet model/inference setup
belongs to the linked generation project. No Selenium browser smoke test is
required for this retired tool. pip-audit covers Python distribution advisories,
not every bundled FFmpeg codec; review upstream security releases separately.

PR #28 remains unmerged and automatic merging remains disabled.
## SonarQube remediation validation

Final implementation `e5d1268` passed the actual SonarQube Cloud gate (check
`121048990771`): reliability A, security A, maintainability A, zero bugs, zero
vulnerabilities and 0.0% duplication on new code. No gate conditions were
ignored or weakened. [CI run 40153153472](https://github.com/bullmoose20/Plex-Stuff/actions/runs/40153153472)
passed all four supported platform/interpreter jobs with **150 tests each,
zero skipped**, hash-verified dependency installation, `pip check`, and zero
known dependency vulnerabilities. Ruff passed in the designated Linux 3.14 job.
All 123 pre-existing tests remain included. See the
[findings, exact job results and limitations](sonarqube-remediation.md).
The final documentation follow-up is independently checked on
[PR #28](https://github.com/bullmoose20/Plex-Stuff/pull/28).

