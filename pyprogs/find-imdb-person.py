import os
from dotenv import load_dotenv
import requests

load_dotenv()
api_key = os.getenv("TMDB_KEY")

# Check if API key is valid
def check_api_key():
    url = f"https://api.themoviedb.org/3/configuration?api_key={api_key}"
    try:
        response = requests.get(url)
        if response.status_code != 200:
            return False
        else:
            return True
    except requests.exceptions.RequestException as e:
        print("Error:", e)
        return False

def find_person_by_name(name):
    try:
        url = f"https://api.themoviedb.org/3/search/person?api_key={api_key}&query={name}"
        response = requests.get(url)
        data = response.json()
        if data["total_results"] == 0:
            return "No results found"
        else:
            result_string = ""
            count = 0
            for i, person in enumerate(data["results"]):
                person_id = person["id"]
                external_ids_url = f"https://api.themoviedb.org/3/person/{person_id}/external_ids?api_key={api_key}"
                external_ids_response = requests.get(external_ids_url)
                external_ids_data = external_ids_response.json()
                if "imdb_id" in external_ids_data:
                    result_string += f"{i+1}. {person['name']} - IMDb ID: {external_ids_data['imdb_id']}\n"
                    count += 1
            if count == 0:
                return "No results found with IMDb ID"
            else:
                return f"{count} results found:\n{result_string}"
    except requests.exceptions.RequestException as e:
        print("Error:", e)
        return "An error occurred"

if check_api_key():
    while True:
        name = input("Enter a person's name (or hit enter to exit): ")
        if name == "":
            break
        else:
            result = find_person_by_name(name)
            print(result)
else:
    print("Invalid API key. Please check your .env file.")
