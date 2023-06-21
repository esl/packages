import boto3
import re
import json
from urllib.parse import quote

def extract_info_from_filename(filename):
    # Example regular expression to extract information from the filename
    pattern1 = r'(.+)_([\d.]+)_\d+_otp_\d+\.\d+~(.+)~(.+)_(\w+)\.(\w+)'
    pattern2 = r'(.+)_([\d.-]+)~(.+)~(.+)_(\w+)\.(\w+)'
    pattern3 = r'(.+)_([\d.-]+)~(.+)\.(\w+)'
    pattern4 = r'(.+)_([\d.]+)_\d+_otp_\d+\.\d+~(.+)~(.+)\.(\w+)'
    pattern5 = r'(.+)_([\d.-]+)~(.+)~(.+)\.(\w+)'

    match = re.match(pattern1, filename) or re.match(pattern2, filename) or re.match(pattern3, filename) or re.match(pattern4, filename) or re.match(pattern5, filename)

    if match:
        path = "https://binaries2.erlang-solutions.com/" + quote(filename)
        version = match.group(2)
        os_parts = match.group(3).split("_")
        os_name = " ".join(os_parts).capitalize()  # Capitalize the OS name
        arch = match.group(5)

        return {
            "path": path,
            "version": version,
            "os": os_name,
            "arch": arch,
            "tests": "",
            "checksum": ""
        }
    else:
        return None

# Configure S3 client
s3_client = boto3.client('s3')

# S3 bucket name
bucket_name = 'binaries2.erlang-solutions.com'

# Dictionary to store the final JSON structure for Elixir
elixir_json_data = {
    "tabs": [],
    "flavours_captions": {
        "main": "Standard"
    }
}

# Dictionary to store the final JSON structure for esl-erlang
erlang_json_data = {
    "tabs": [],
    "flavours_captions": {
        "main": "Standard"
    }
}

# Dictionary to store the final JSON structure for MongooseIM
mongooseim_json_data = {
    "tabs": [],
    "flavours_captions": {
        "main": "Standard"
    }
}

# Paginate over the objects in the bucket
paginator = s3_client.get_paginator('list_objects')
page_iterator = paginator.paginate(Bucket=bucket_name)

for page in page_iterator:
    if 'Contents' in page:
        for obj in page['Contents']:
            filename = obj['Key']

            # Extract information from the filename
            file_info = extract_info_from_filename(filename)

            if file_info:
                tab_name, full_os_name = filename.split("/")[-2:]

                # Split the full_os_name into its parts
                os_parts = full_os_name.split("~")

                # Extract the os_name and version from os_parts
                os_name_file = os_parts[1].split("_")[0]  # Extract the OS name for the file
                os_version = os_parts[2]  # Extract the OS version
                os_name_with_version = os_name_file + " " + os_version  # Concatenate OS name and version

                # Find the appropriate JSON data dictionary based on the tab name
                json_data = None
                if "elixir" in filename:
                    json_data = elixir_json_data
                elif "esl-erlang" in filename:
                    json_data = erlang_json_data
                elif "mongooseim" in filename:
                    json_data = mongooseim_json_data

                if json_data:
                    # Check if a tab with the OS name already exists
                    existing_tab = next((tab for tab in json_data["tabs"] if tab["name"] == os_name_with_version), None)
                    if existing_tab:
                        existing_flavour = next((flavour for flavour in existing_tab["flavours"] if flavour["name"] == "main"), None)
                        if existing_flavour:
                            existing_flavour["packages"].append(file_info)
                        else:
                            existing_tab["flavours"].append({
                                "name": "main",
                                "packages": [file_info],
                                "header": "",
                                "footer": ""
                            })
                    else:
                        json_data["tabs"].append({
                            "name": os_name_with_version,
                            "caption": os_name_with_version.capitalize(),
                            "header": "",
                            "footer": "",
                            "flavours": [
                                {
                                    "name": "main",
                                    "packages": [file_info],
                                    "header": "",
                                    "footer": ""
                                }
                            ]
                        })

# Write separate JSON files for Elixir, esl-erlang, and MongooseIM
with open('elixir_packages.json', 'w') as json_file:
    json_file.write("jsonCallback(" + json.dumps(elixir_json_data, indent=4) + ")")

with open('erlang_packages.json', 'w') as json_file:
    json_file.write("jsonCallback(" + json.dumps(erlang_json_data, indent=4) + ")")

with open('mongooseim_packages.json', 'w') as json_file:
    json_file.write("jsonCallback(" + json.dumps(mongooseim_json_data, indent=4) + ")")
