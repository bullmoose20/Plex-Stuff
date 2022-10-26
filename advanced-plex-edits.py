import plexapi, time, os
from plexapi.library import LibrarySection
from plexapi.server import PlexServer
from dotenv import load_dotenv

load_dotenv()

PLEX_URL = os.getenv("PLEX_URL")
if PLEX_URL is None:
    print("PLEX_URL is not defined.")

PLEX_TOKEN = os.getenv("PLEX_TOKEN")
if PLEX_TOKEN is None:
    print("PLEX_TOKEN is not defined.")
    
LIBS = ["Movies", "TV Shows", "TestMovies", "TestTV Shows", "Playlists", "Collections", "Artists", "Albums"]

for PLEX_LIBRARY in LIBS:
    server = PlexServer(PLEX_URL, PLEX_TOKEN, timeout=600)
    lib: LibrarySection = next((s for s in server.library.sections() if s.title == PLEX_LIBRARY), None)
    all_collections = lib._search(f"/library/sections/{lib.key}/all?type=18", None, 0, plexapi.X_PLEX_CONTAINER_SIZE)
    print(f"Setting {len(all_collections)} collections to default")
    i = 0
    for col in all_collections:
        i +=1
        print(f"Working on {i}/{len(all_collections)}: {col}")
        col.modeUpdate(mode="default")

    time.sleep(10)
    
    print(f"Setting {len(all_collections)} collections to hide")
    i = 0
    for col in all_collections:
        print(f"Working on: {col}")
        col.modeUpdate(mode="hide")