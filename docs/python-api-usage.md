# Current third-party API usage

Generated with `python tools/audit_python.py`. Active standalone entry points all use a `__main__` guard.

| Script | External imports | Direct external calls |
| --- | --- | --- |
| `pyprogs/collage/collage.py` | PIL.Image, PIL.ImageDraw, PIL.ImageFont, dotenv.load_dotenv | PIL.Image.new, PIL.Image.open, PIL.ImageDraw.Draw, PIL.ImageFont.load_default, PIL.ImageFont.truetype, dotenv.load_dotenv |
| `pyprogs/exif_overlay_checker/exif_overlay_checker.py` | PIL.ExifTags.TAGS, PIL.Image, dotenv.load_dotenv | PIL.ExifTags.TAGS.get, PIL.Image.open, dotenv.load_dotenv |
| `pyprogs/extract_tracks/extract_tracks.py` | dotenv.load_dotenv, plexapi, plexapi.server.PlexServer, requests.exceptions.RequestException, titlecase | dotenv.load_dotenv, plexapi.server.PlexServer, titlecase.titlecase |
| `pyprogs/find-imdb-person.py` | dotenv.load_dotenv, requests | dotenv.load_dotenv, requests.get |
| `pyprogs/fix_added_at/fix_added_at.py` | dotenv.load_dotenv, plexapi.exceptions.BadRequest, plexapi.server.PlexServer, requests, requests.exceptions.RequestException | dotenv.load_dotenv, plexapi.server.PlexServer |
| `pyprogs/fmg/fake_media_generator.py` | dotenv.load_dotenv, requests | dotenv.load_dotenv, requests.get |
| `pyprogs/get-info.py` | cpuinfo, psutil | cpuinfo.get_cpu_info, psutil.cpu_count, psutil.cpu_percent, psutil.disk_usage, psutil.getloadavg, psutil.net_io_counters, psutil.virtual_memory |
| `pyprogs/get-plex-labels.py` | dotenv.load_dotenv, plexapi.server.PlexServer, plexapi.server.Unauthorized, tqdm.tqdm | dotenv.load_dotenv, plexapi.server.PlexServer, tqdm.tqdm |
| `pyprogs/get-tmdb-external-ids.py` | dotenv.load_dotenv, requests, tqdm.tqdm | dotenv.load_dotenv, requests.get, tqdm.tqdm |
| `pyprogs/get_missing_people.py` | PIL.Image, requests | PIL.Image.open, requests.get |
| `pyprogs/get_missing_people_dir.py` | PIL.Image | PIL.Image.open |
| `pyprogs/label_remover/label_remover.py` | dotenv.load_dotenv, plexapi.server.PlexServer | dotenv.load_dotenv, plexapi.server.PlexServer |
| `pyprogs/ltp/landscape_to_portrait.py` | PIL.Image, PIL.ImageOps, dotenv.load_dotenv, plexapi.server.PlexServer, requests | PIL.Image.open, PIL.ImageOps.fit, dotenv.load_dotenv, plexapi.server.PlexServer, requests.Session |
| `pyprogs/orchestrator/orchestrator.py` | dotenv.load_dotenv, plexapi.server.PlexServer, psutil, qbittorrentapi.APIConnectionError, qbittorrentapi.Client, qbittorrentapi.LoginFailed, requests, yaml | dotenv.load_dotenv, plexapi.server.PlexServer, psutil.Process, qbittorrentapi.Client, requests.get, requests.put, yaml.safe_load |
| `pyprogs/orchestrator/visualize_task_stats.py` | dotenv.load_dotenv, matplotlib.pyplot, numpy | dotenv.load_dotenv, matplotlib.pyplot.axvline, matplotlib.pyplot.bar, matplotlib.pyplot.figure, matplotlib.pyplot.gcf, matplotlib.pyplot.gcf().text, matplotlib.pyplot.grid, matplotlib.pyplot.legend, matplotlib.pyplot.plot, matplotlib.pyplot.savefig, matplotlib.pyplot.show, matplotlib.pyplot.tight_layout, matplotlib.pyplot.title, matplotlib.pyplot.xlabel, matplotlib.pyplot.xticks, matplotlib.pyplot.ylabel, numpy.arange, numpy.mean, numpy.std |
| `pyprogs/pmm-detect-overlays.py` | PIL.Image, cv2, exifread, numpy, tqdm.tqdm | PIL.Image.open, cv2.imdecode, cv2.matchTemplate, exifread.process_file, numpy.fromfile, numpy.where, tqdm.tqdm |
| `pyprogs/poster_to_square/poster_to_square.py` | PIL.Image, PIL.ImageDraw, PIL.ImageEnhance, PIL.ImageFilter, PIL.ImageOps | none |
| `pyprogs/resizer/resizer.py` | PIL.Image, dotenv.load_dotenv | PIL.Image.open, dotenv.load_dotenv |
| `pyprogs/strip_columns/strip_columns.py` | stdlib only | none |
| `pyprogs/tcc/title_card_clips.py` | av, dotenv.load_dotenv | av.open, dotenv.load_dotenv |
| `pyprogs/update_plex_artist_art/update_plex_artist_art.py` | dotenv.load_dotenv, plexapi, plexapi.server.PlexServer, requests, requests.exceptions.RequestException | dotenv.load_dotenv, plexapi.server.PlexServer, requests.get |
