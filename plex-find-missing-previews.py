#!/usr/bin/env python3

import os
import array

from dotenv import load_dotenv
from plexapi.server import PlexServer

env_is_here = os.path.isfile('.env')

if not env_is_here:
    print('Configuration file [.env] is not here.  Exiting.')
    exit()

load_dotenv()

def process_item(plex_connection, item_key):
    data = plex_connection.query('{}/tree'.format(item_key))
    for media_part in data.findall('.//MediaPart'):
        if 'hash' in media_part.attrib:
            bundle_hash = media_part.attrib['hash']
            bundle_file = '{}/{}{}'.format(bundle_hash[0], bundle_hash[1::1], '.bundle')
            bundle_path = os.path.join(os.getenv('PREVIEWS_PATH'), bundle_file)
            indexes_path = os.path.join(bundle_path, 'Contents', 'Indexes')
            index_bif = os.path.join(indexes_path, 'index-sd.bif')
            if (not os.path.isfile(index_bif)):
                print('%s has no preview thumbnail' % media_part.attrib['file'])


plex = PlexServer(os.getenv("PLEX_URL"), os.getenv("PLEX_TOKEN"), timeout=600)

print('Getting Movies from Plex')
movies = [m.key for m in plex.library.search(libtype='movie')]
print('Got %s Movies from Plex' % len(movies))

for movie in movies:
    process_item(plex, movie)

print('Done processing movies')

print('Getting Episodes from Plex')
episodes = [m.key for m in plex.library.search(libtype='episode')]
print('Got %s Episodes from Plex' % len(episodes))

for episode in episodes:
    process_item(plex, episode)

print('Done processing TV Shows')
