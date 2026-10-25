# Retired: Selenium background removal

The `sel_remove_bg` tool is retired. Its Adobe Express browser automation,
dependency manifest and configuration example have been removed from active
maintenance. The implementation remains available in Git history; no executable
archive is maintained here.

Use the People-Images generation tooling in
[Kometa-Team/Defaults-Image-Creation — create_people_posters](https://github.com/Kometa-Team/Defaults-Image-Creation/tree/main/create_people_posters).
Its [BiRefNet setup instructions](https://github.com/Kometa-Team/Defaults-Image-Creation/blob/main/create_people_posters/README.md#local-background-removal-birefnet)
and [local background-removal implementation](https://github.com/Kometa-Team/Defaults-Image-Creation/blob/main/create_people_posters/remove_bg_birefnet.py)
identify BiRefNet Portrait as the default local background remover through rembg.
Those source files were verified on 2026-10-24.

`Kometa-Team/People-Images` and `Kometa-Team/People-Images-transparent` primarily
publish generated image assets; they are not the generation-source repositories.
Follow the generation project's own environment and model setup instructions.

The previous local `.env` and any browser/download artifacts are left untouched
and ignored. Do not add browser profiles, cookies, credentials or personal
configuration to Git. The historical Selenium `.env` contained preferences and
paths, with no detected credential assignments or credential-bearing URL;
retiring it alone does not require credential rotation. See the
[security assessment](../../docs/python-maintenance.md#historical-configuration-security-assessment)
for scope and limitations. No history was rewritten.
