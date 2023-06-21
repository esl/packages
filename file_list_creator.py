import boto3
import re
import json
from urllib.parse import quote

def extract_info_from_filename(filename):
    # Example regular expression to extract information from the filename
    pattern =  r'(.+)_([\d\.-]+)~(.+?)~(.+?)_([\w-]+)\.(\w+)'

    match = re.match(pattern, filename)

    if match:
        path = "https://binaries2.erlang-solutions.com/" + quote(filename)
        version = match.group(2)
        os_name = match.group(3).replace('_', ' ').capitalize() + " " + match.group(4)  # Capitalize the OS name
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
                # Extraer la distribución del nombre del archivo
                distribution = os_parts[1]
                # Lógica para generar los footers según la distribución
                footer = ""
                if distribution == "centos":
                    footer = "CentOS footer"
                elif distribution == "ubuntu":
                    footer = "<h1>Installation using repository</h1>\n\n<h2>1. Adding repository entry</h2>\n\n<p>To add Erlang Solutions repository (including our public key for apt-secure) to your system, call the following commands:</p> adding the repository entry manually</h2>\n\n<p>Add one of the following lines to your /etc/apt/sources.list (according to your distribution):</p>\n\n<pre><code>deb https://packages.erlang-solutions.com/ubuntu trusty contrib\ndeb https://packages.erlang-solutions.com/ubuntu saucy contrib\ndeb https://packages.erlang-solutions.com/ubuntu precise contrib\n</code></pre>\n\n<p>To verify which distribution you are running, run \"lsb_release -c\" in console.</p>\n\n<p>Next, add the Erlang Solutions public key for \"apt-secure\" using following commands:</p>\n\n<pre><code>wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc\nsudo apt-key add erlang_solutions.asc\n</code></pre>\n\n<h2>2. Installing Erlang</h2>\n\n<p>Refresh the repository cache and install either the \"erlang\" package:</p>\n\n<pre><code>sudo apt-get update\nsudo apt-get install erlang\n</code></pre>\n\n<p>or the \"esl-erlang\" package:</p>\n\n<pre><code>sudo apt-get update\nsudo apt-get install esl-erlang\n</code></pre>\n\n<p>Please refer to the FAQ for the difference between those versions.</p>\n\n<h1>FAQ &mdash; Frequently Asked Questions</h1>\n\n<h2>1. What is the \"erlang\" package?</h2>\n\n<p>Erlang/OTP Platform is a complex system composed of many smaller applications (modules). Installing the \"erlang\" package automatically installs the entire OTP suite. Since some of the more advanced users might want to download only a specific selection of modules, Erlang/OTP has been divided into smaller packages (all with the prefix \"erlang-\") that can be installed without launching the \"erlang\" package.</p>\n\n<h2>2. What is \"esl-erlang\", how is it different from erlang? Have you removed it from repositories?</h2>\n\n<p>The \"esl-erlang\" package is a file containing the complete installation: it includes the Erlang/OTP platform and all of its applications. The \"erlang\" package is a frontend to a number of smaller packages. Currently we support both \"erlang\" and \"esl-erlang\".</p>\n\n<p>Note that the split packages have multiple advantages:</p>\n\n<ol>\n<li>seamless replacement of the available packages,</li>\n<li>other packages have dependencies on \"erlang\", not \"esl-erlang\",</li>\n<li>if your disk-space is low, you can get rid of some unused parts; \"erlang-base\" needs only ~13MB of space.</li>\n</ol>\n\n<h2>3. My operating system already provides erlang. Why should I choose yours?</h2>\n\n<p>Our packages contain the latest stable Erlang/OTP distribution. Other repositories usually lag behind. For example: when we started providing R16B02, Ubuntu 12.04 LTS Precise Pangolin still provided R14B02. Our packages are complete, easy to install and have been thoroughly tested.</p>\n\n<h2>4. How to prevent packages from the Erlang Solutions repository being replaced by other repositories?</h2>\n\n<p>It is very improbable that this would happen due to the fact that we provide the latest Erlang/OTP and the distributions are unlikely to change the provided Erlang/OTP version. The auto&ndash;update tools on Debian/Ubuntu download the newest version.</p>\n\n<p>If you are still concerned, use our \"erlang-solutions<em>1.0</em>all.deb\" package (see: \"Installation using repository\") &mdash; it automatically sets our repo to have a higher priority than others. If you would like to do that by hand, add the following lines to your \"/etc/apt/preferences\":</p>\n\n<pre><code>Package: *\nPin: release o=Erlang Solutions Ltd.\nPin-Priority: 999\n</code></pre>\n\n<h2>5. Does the \"erlang\" package install everything I need for Erlang programming?</h2>\n\n<p>No, there are three additional packages:</p>\n\n<ol>\n<li>erlang-doc &mdash; HTML/PDF documentation,</li>\n<li>erlang-manpages &mdash; manpages,</li>\n<li>erlang-mode &mdash; major editing mode for Emacs.</li>\n</ol>\n\n<h2>6. I have heard about HiPE. What is it? How to get it?</h2>\n\n<p>HiPE stands for High-Performance Erlang Project. It is a native code compiler for Erlang. In most cases, it positively affects performance. If you want to download it, call the following:</p>\n\n<pre><code>sudo apt-get install erlang-base-hipe\n</code></pre>\n\n<p>This will replace the Erlang/OTP runtime with a HiPE supported version. Other Erlang applications do not need to be reinstalled. To return to the standard runtime, call:</p>\n\n<pre><code>sudo apt-get install erlang-base\n</code></pre>\n"
                elif distribution == "debian":
                    footer = "<h1>Installation using repository</h1>\n\n<h2>1. Adding repository entry</h2>\n\n<p>To add Erlang Solutions repository (including our public key for apt-secure) to your system, call the following commands:</p> adding the repository entry manually</h2>\n\n<p>Add one of the following lines to your /etc/apt/sources.list (according to your distribution):</p>\n\n<pre><code>deb https://packages.erlang-solutions.com/ubuntu trusty contrib\ndeb https://packages.erlang-solutions.com/ubuntu saucy contrib\ndeb https://packages.erlang-solutions.com/ubuntu precise contrib\n</code></pre>\n\n<p>To verify which distribution you are running, run \"lsb_release -c\" in console.</p>\n\n<p>Next, add the Erlang Solutions public key for \"apt-secure\" using following commands:</p>\n\n<pre><code>wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc\nsudo apt-key add erlang_solutions.asc\n</code></pre>\n\n<h2>2. Installing Erlang</h2>\n\n<p>Refresh the repository cache and install either the \"erlang\" package:</p>\n\n<pre><code>sudo apt-get update\nsudo apt-get install erlang\n</code></pre>\n\n<p>or the \"esl-erlang\" package:</p>\n\n<pre><code>sudo apt-get update\nsudo apt-get install esl-erlang\n</code></pre>\n\n<p>Please refer to the FAQ for the difference between those versions.</p>\n\n<h1>FAQ &mdash; Frequently Asked Questions</h1>\n\n<h2>1. What is the \"erlang\" package?</h2>\n\n<p>Erlang/OTP Platform is a complex system composed of many smaller applications (modules). Installing the \"erlang\" package automatically installs the entire OTP suite. Since some of the more advanced users might want to download only a specific selection of modules, Erlang/OTP has been divided into smaller packages (all with the prefix \"erlang-\") that can be installed without launching the \"erlang\" package.</p>\n\n<h2>2. What is \"esl-erlang\", how is it different from erlang? Have you removed it from repositories?</h2>\n\n<p>The \"esl-erlang\" package is a file containing the complete installation: it includes the Erlang/OTP platform and all of its applications. The \"erlang\" package is a frontend to a number of smaller packages. Currently we support both \"erlang\" and \"esl-erlang\".</p>\n\n<p>Note that the split packages have multiple advantages:</p>\n\n<ol>\n<li>seamless replacement of the available packages,</li>\n<li>other packages have dependencies on \"erlang\", not \"esl-erlang\",</li>\n<li>if your disk-space is low, you can get rid of some unused parts; \"erlang-base\" needs only ~13MB of space.</li>\n</ol>\n\n<h2>3. My operating system already provides erlang. Why should I choose yours?</h2>\n\n<p>Our packages contain the latest stable Erlang/OTP distribution. Other repositories usually lag behind. For example: when we started providing R16B02, Ubuntu 12.04 LTS Precise Pangolin still provided R14B02. Our packages are complete, easy to install and have been thoroughly tested.</p>\n\n<h2>4. How to prevent packages from the Erlang Solutions repository being replaced by other repositories?</h2>\n\n<p>It is very improbable that this would happen due to the fact that we provide the latest Erlang/OTP and the distributions are unlikely to change the provided Erlang/OTP version. The auto&ndash;update tools on Debian/Ubuntu download the newest version.</p>\n\n<p>If you are still concerned, use our \"erlang-solutions<em>1.0</em>all.deb\" package (see: \"Installation using repository\") &mdash; it automatically sets our repo to have a higher priority than others. If you would like to do that by hand, add the following lines to your \"/etc/apt/preferences\":</p>\n\n<pre><code>Package: *\nPin: release o=Erlang Solutions Ltd.\nPin-Priority: 999\n</code></pre>\n\n<h2>5. Does the \"erlang\" package install everything I need for Erlang programming?</h2>\n\n<p>No, there are three additional packages:</p>\n\n<ol>\n<li>erlang-doc &mdash; HTML/PDF documentation,</li>\n<li>erlang-manpages &mdash; manpages,</li>\n<li>erlang-mode &mdash; major editing mode for Emacs.</li>\n</ol>\n\n<h2>6. I have heard about HiPE. What is it? How to get it?</h2>\n\n<p>HiPE stands for High-Performance Erlang Project. It is a native code compiler for Erlang. In most cases, it positively affects performance. If you want to download it, call the following:</p>\n\n<pre><code>sudo apt-get install erlang-base-hipe\n</code></pre>\n\n<p>This will replace the Erlang/OTP runtime with a HiPE supported version. Other Erlang applications do not need to be reinstalled. To return to the standard runtime, call:</p>\n\n<pre><code>sudo apt-get install erlang-base\n</code></pre>\n"
                # Extract the os_name and version from os_parts
                #os_name = os_parts[1].split("_")[0] + " " + os_parts[2]  # Concatenate OS name and version
                os_name = os_parts[1] 
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
                    # Después de los bloques "if json_data:"
                    # Agrega el siguiente código:

                    # Verificar si ya existe una pestaña para macOS
                    macos_tab = next((tab for tab in json_data["tabs"] if tab["name"] == "Mac OS"), None)
                    if not macos_tab:
                        json_data["tabs"].append({
                            "name": "Mac OS",
                            "caption": "Mac OS",
                            "header": "",
                            "footer": "Install on MacOS using brew install erlang or ports install erlang",
                            "flavours": [
                                {
                                    "name": "main",
                                    "packages": [],
                                    "header": "",
                                    "footer": ""
                                }
                            ]
                        })

                    # Verificar si ya existe una pestaña para Windows
                    windows_tab = next((tab for tab in json_data["tabs"] if tab["name"] == "Windows"), None)
                    if not windows_tab:
                        json_data["tabs"].append({
                            "name": "Windows",
                            "caption": "Windows",
                            "header": "",
                            "footer": "Install over Windows using OTP Installer on erlang.org",
                            "flavours": [
                                {
                                    "name": "main",
                                    "packages": [],
                                    "header": "",
                                    "footer": ""
                                }
                            ]
                        })
                    existing_tab = next((tab for tab in json_data["tabs"] if tab["name"] == os_name), None)
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
                            "name": os_name,
                            "caption": os_name.capitalize(),
                            "header": "",
                            "footer": footer,
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
