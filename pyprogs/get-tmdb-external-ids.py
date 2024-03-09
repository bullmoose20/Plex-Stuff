import os
from dotenv import load_dotenv
load_dotenv()
import requests
import csv
from tqdm import tqdm

def test_api_key(api_key):
    url = f'https://api.themoviedb.org/3/configuration?api_key={api_key}'
    response = requests.get(url)
    if response.status_code == 200:
        print("API key is valid.")
    else:
        print("API key is invalid. Please check your API key and try again.")

# API key for themoviedb.org
api_key = os.getenv("TMDB_KEY")
test_api_key(api_key)

# Initialize variables
page = 1
results_per_page = 1000
max_pages = 1000 # set the maximum number of pages you want to retrieve

# Create a new CSV file and write the headers
with open('tv_shows.csv', 'w', newline='', encoding="utf-8") as csvfile:
    fieldnames = ['TV Show', 'TMDB ID','IMDb ID', 'TVDb ID']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    
    # Iterate through the pages
    for page in tqdm(range(1, max_pages+1), unit='page', desc='Processing Pages', leave=False, unit_scale=True, dynamic_ncols=True):
        # API endpoint for getting all TV shows
        url = f'https://api.themoviedb.org/3/discover/tv?api_key={api_key}&with_networks=213&sort_by=name.asc&page={page}'
        response = requests.get(url)
        if response.status_code != 200:
            print(f'Error: {response.status_code} - {response.reason}')
        else:
            data = response.json()
            for show in data['results']:
                url = f'https://api.themoviedb.org/3/tv/{show["id"]}/external_ids?api_key={api_key}'
                response = requests.get(url)
                external_ids = response.json()
                imdb_id = external_ids.get('imdb_id', '')
                tvdb_id = external_ids.get('tvdb_id', '')
                writer.writerow({'TV Show': show['name'], 'TMDB ID': show['id'], 'IMDb ID': imdb_id, 'TVDb ID': tvdb_id})
                print(f"{show['name']} added to CSV.")
    print("All TV shows added to CSV.")
