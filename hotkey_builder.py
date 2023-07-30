import requests


url = "https://raw.githubusercontent.com/beyond-all-reason/Beyond-All-Reason/master/language/en/units.json"





# string matching params. 
# this default example will keep any description with substring "Con" and filter out any description with substring "Tech 2" when constructing the string Not_IdMatches_%s
names_to_match = {}
descriptions_to_match = {'Con'}
names_to_avoid = {}
descriptions_to_avoid = {'Tech 2'}



def load_json_from_url(url):
    response = requests.get(url)
    if response.status_code == 200:
        return response.json()
    else:
        raise Exception("Failed to fetch JSON data from the URL")



def find_matching_names(json_data):
    matching_names = []
    units_data = json_data.get("units", {})
    names_data = units_data.get("names", {})
    descriptions_data = units_data.get("descriptions", {})

    for name_key in names_data.keys():
        name_value = names_data[name_key]

        if all(match in name_value for match in names_to_match) and not any(avoid in name_value for avoid in names_to_avoid):
            description = descriptions_data.get(name_key)
            if description and all(match in description for match in descriptions_to_match) and not any(avoid in description for avoid in descriptions_to_avoid):
                matching_names.append(name_key)
    return matching_names


if __name__ == "__main__":
    try:
        json_data = load_json_from_url(url)
        matching_names = find_matching_names(json_data)
        if not len(matching_names):
            print("couldn't find matches")
        else:
            print('_'.join(['Not_IdMatches_' + i for i in matching_names]))
    except Exception as e:
        print(f"Error: {e}")


