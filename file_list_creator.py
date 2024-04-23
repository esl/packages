import boto3
import re
import json
from urllib.parse import quote

def extract_info_from_filename(filename):
    pattern_debian_ubuntu = r'(.+)_([\d\.-]+)~(.+?)~(.+?)_([\w-]+)\.(\w+)'
    pattern_centos = r'(.+)_([\d\.-]+_[\d-]+)~(.+?)~(.+?)_([\w-]+)\.(\w+)'

    match = re.match(pattern_debian_ubuntu, filename)
    if not match:
        match = re.match(pattern_centos, filename)

    if match:
        path = "https://binaries2.erlang-solutions.com/" + quote(filename)
        version = match.group(2).replace("_", ".")
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


# Dictionary to store the final JSON structure for esl-erlang
erlang_json_data = {
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
                    footer = "<h1>FAQ &mdash; Frequently Asked Questions</h1>\n\n <p> Following the launch of our new binaries platform, Erlang Solutions invites you to explore our FAQ section, dedicated to our updated packages.  Here you’ll find answers to common queries, troubleshooting and your other popular questions about our user-friendly platform. To support the continued growth and development of the Erlang ecosystem, we want to make it as easy as possible for you to download, install and deploy systems and third-party applications implemented in Erlang and Elixir.</p><p>This page will be regularly updated to reflect any changes.</p>\n\n<h2>1. What can I use the Binary packages for? </h2>\n\n<p>Binary packages provide pre-compiled versions of software, such as esl-Erlang and Elixir, which can be easily installed and used on compatible systems without the need for manual compilation. You can use these binary packages to set up and deploy Erlang and Elixir applications quickly. Whether you are an individual developer or part of a team, binary packages offer a convenient way to kickstart your development environment. By using pre-compiled versions, you can avoid the complexities of compilation and focus on coding and testing. Our binary packages undergo rigorous testing to ensure stability and reliability.</p>\n\n<h2>2. What architectures do you support?</h2>\n\n<p>We currently support two architectures in our binary packages: amd64 and arm64. These architectures cover a wide range of modern hardware, including both 64-bit x86 (amd64) and ARM-based systems (arm64).</p><p>Note: While our primary focus is on 64-bit architectures due to their widespread use and performance advantages, we understand that there is a lot of interest in 32-bit architectures, especially for embedded systems where power efficiency is crucial. While we don't officially provide pre-built packages for 32-bit architectures at the moment, we are open to considering them based on demand. If you require support for 32-bit architectures or have specific needs for embedded systems, please reach out to us, and we'll be happy to discuss customised solutions that may involve additional costs.</p><p>We always strive to provide the best experience for our users, and your feedback and requirements are essential in shaping our future offerings. Feel free to contact us if you have any questions or special requirements.</p>\n\n <h2>3. Can I request packages for architectures you currently do not support?</h2>\n\n<p>Yes. We can provide packages for currently non-supported 32 and 64-bit architectures or suggest alternative solutions. The binary packages we provide can be proprietary and built for your own needs, or they can be made available through our platform for the wider community. Fill out the contact form, and our engineers will be able to provide more information on our capabilities and sponsorship packages.</p>\n\n<h2>4. What test cases do you run?</h2>\n\n<p>We do functional testing and hardening test for each package:</p> <p>1. Release Tests: The build process runs the release tests for Erlang/OTP. These tests ensure the correctness and functionality of the release build by performing various checks on the Erlang/OTP and Elixir installation.</p><p>2. Smoke Tests: As part of the release tests, smoke tests are executed to verify the basic functionality of Erlang/OTP and Elixir. These tests ensure that critical components and features are working as expected.</p>\n\n<h2>5. How do you certify the binary packages?</h2>\n\n<p>Our binary packages undergo a meticulous certification process to ensure their integrity and authenticity. We achieve this through digital signatures, assuring the packages' origin and preventing tampering during transit. Additionally, cryptographic hashes act as unique fingerprints to verify their integrity after download. Rigorous automated testing and compatibility verification guarantee that the packages meet our high-quality standards and perform optimally on supported architectures. Continuous monitoring and user feedback further reinforce the reliability and security of our certified binary packages, allowing you to confidently deploy and develop Erlang and Elixir applications with peace of mind.</p>\n\n<h2>6. Why should I use yours, and not build my own?</h2>\n\n<p>Using pre-compiled binary packages can save you time, effort and money when compared to building the software from source code.</p><p>The binary packages are already compiled and optimised for the supported architectures, making the installation process faster and more convenient. Additionally, using official binary packages ensures that you are using a trusted and supported version of the software which has been tested.</p>\n\n<h2>7. Can I buy support for Erlang/OTP and the BEAM? </h2>\n\n<p>Yes. It is possible to purchase commercial support for Erlang/OTP and the BEAM. </p><p>Erlang Solutions has an exclusive contract with Ericsson and is able to offer commercial support packages, which can include technical assistance, bug fixes, and other benefits. They include an SLA, patches and workarounds where the bug is reproducible and a guarantee that the bug will be fixed in the next open-source release. You can explore the options provided by contacting us using the contact form. </p>\n\n<h2>8. Where can I find any additional information about Erlang and Elixir upgrades?</h2>\n\n<p>Any additional information about support packages and upgrades can be found here:</p><p>https://www.erlang.org/downloads#prebuilt</p><p>https://www.erlang.org/downloads/26</p> \n\n"
                elif distribution == "ubuntu":
                    footer = "<h1>Installation using repository</h1>\n\n<h2>1. Adding repository entry</h2>\n\n<p>To add Erlang Solutions repository (including our public key for apt-secure) to your system, call the following commands:</p> adding the repository entry manually</h2>\n\n<p>Add one of the following lines to your /etc/apt/sources.list (according to your distribution):</p>\n\n<pre><code>deb http://binaries2.erlang-solutions.com/ubuntu/ jammy-esl-erlang-25 contrib\ndeb http://binaries2.erlang-solutions.com/debian/ bullseye-elixir-1.15 contrib\ndeb http://binaries2.erlang-solutions.com/ubuntu/ bionic-mongooseim-6 contrib\n</code></pre>\n\n<p>To verify which distribution you are running, run \"lsb_release -c\" in console.</p>\n\n<p>Next, add the Erlang Solutions public key for \"apt-secure\" using following commands:</p>\n\n<pre><code>wget https://binaries2.erlang-solutions.com/GPG-KEY-pmanager.asc\nsudo apt-key add GPG-KEY-pmanager.asc\n</code></pre>\n\n<h2>2. Installing Erlang</h2>\n\n<p>Refresh the repository cache and install either the \"erlang\" package:</p>\n\n<pre><code>sudo apt-get update\nsudo apt-get install erlang\n</code></pre>\n\n<p>or the \"esl-erlang\" package:</p>\n\n<pre><code>sudo apt-get update\nsudo apt-get install esl-erlang\n</code></pre>\n\n<p>Please refer to the FAQ for the difference between those versions.</p>\n\n<h1>FAQ &mdash; Frequently Asked Questions</h1>\n\n <p> Following the launch of our new binaries platform, Erlang Solutions invites you to explore our FAQ section, dedicated to our updated packages.  Here you’ll find answers to common queries, troubleshooting and your other popular questions about our user-friendly platform. To support the continued growth and development of the Erlang ecosystem, we want to make it as easy as possible for you to download, install and deploy systems and third-party applications implemented in Erlang and Elixir.</p><p>This page will be regularly updated to reflect any changes.</p>\n\n<h2>1. What can I use the Binary packages for? </h2>\n\n<p>Binary packages provide pre-compiled versions of software, such as esl-Erlang and Elixir, which can be easily installed and used on compatible systems without the need for manual compilation. You can use these binary packages to set up and deploy Erlang and Elixir applications quickly. Whether you are an individual developer or part of a team, binary packages offer a convenient way to kickstart your development environment. By using pre-compiled versions, you can avoid the complexities of compilation and focus on coding and testing. Our binary packages undergo rigorous testing to ensure stability and reliability.</p>\n\n<h2>2. What architectures do you support?</h2>\n\n<p>We currently support two architectures in our binary packages: amd64 and arm64. These architectures cover a wide range of modern hardware, including both 64-bit x86 (amd64) and ARM-based systems (arm64).</p><p>Note: While our primary focus is on 64-bit architectures due to their widespread use and performance advantages, we understand that there is a lot of interest in 32-bit architectures, especially for embedded systems where power efficiency is crucial. While we don't officially provide pre-built packages for 32-bit architectures at the moment, we are open to considering them based on demand. If you require support for 32-bit architectures or have specific needs for embedded systems, please reach out to us, and we'll be happy to discuss customised solutions that may involve additional costs.</p><p>We always strive to provide the best experience for our users, and your feedback and requirements are essential in shaping our future offerings. Feel free to contact us if you have any questions or special requirements.</p>\n\n <h2>3. Can I request packages for architectures you currently do not support?</h2>\n\n<p>Yes. We can provide packages for currently non-supported 32 and 64-bit architectures or suggest alternative solutions. The binary packages we provide can be proprietary and built for your own needs, or they can be made available through our platform for the wider community. Fill out the contact form, and our engineers will be able to provide more information on our capabilities and sponsorship packages.</p>\n\n<h2>4. What test cases do you run?</h2>\n\n<p>We do functional testing and hardening test for each package:</p> <p>1. Release Tests: The build process runs the release tests for Erlang/OTP. These tests ensure the correctness and functionality of the release build by performing various checks on the Erlang/OTP and Elixir installation.</p><p>2. Smoke Tests: As part of the release tests, smoke tests are executed to verify the basic functionality of Erlang/OTP and Elixir. These tests ensure that critical components and features are working as expected.</p>\n\n<h2>5. How do you certify the binary packages?</h2>\n\n<p>Our binary packages undergo a meticulous certification process to ensure their integrity and authenticity. We achieve this through digital signatures, assuring the packages' origin and preventing tampering during transit. Additionally, cryptographic hashes act as unique fingerprints to verify their integrity after download. Rigorous automated testing and compatibility verification guarantee that the packages meet our high-quality standards and perform optimally on supported architectures. Continuous monitoring and user feedback further reinforce the reliability and security of our certified binary packages, allowing you to confidently deploy and develop Erlang and Elixir applications with peace of mind.</p>\n\n<h2>6. Why should I use yours, and not build my own?</h2>\n\n<p>Using pre-compiled binary packages can save you time, effort and money when compared to building the software from source code.</p><p>The binary packages are already compiled and optimised for the supported architectures, making the installation process faster and more convenient. Additionally, using official binary packages ensures that you are using a trusted and supported version of the software which has been tested.</p>\n\n<h2>7. Can I buy support for Erlang/OTP and the BEAM? </h2>\n\n<p>Yes. It is possible to purchase commercial support for Erlang/OTP and the BEAM. </p><p>Erlang Solutions has an exclusive contract with Ericsson and is able to offer commercial support packages, which can include technical assistance, bug fixes, and other benefits. They include an SLA, patches and workarounds where the bug is reproducible and a guarantee that the bug will be fixed in the next open-source release. You can explore the options provided by contacting us using the contact form.</p>\n\n<h2>8. Where can I find any additional information about Erlang and Elixir upgrades?</h2>\n\n<p>Any additional information about support packages and upgrades can be found here:</p><p>https://www.erlang.org/downloads#prebuilt</p><p>https://www.erlang.org/downloads/26</p> \n\n"
                elif distribution == "debian":
                    footer = "<h1>Installation using repository</h1>\n\n<h2>1. Adding repository entry</h2>\n\n<p>To add Erlang Solutions repository (including our public key for apt-secure) to your system, call the following commands:</p> adding the repository entry manually</h2>\n\n<p>Add one of the following lines to your /etc/apt/sources.list (according to your distribution):</p>\n\n<pre><code>deb http://binaries2.erlang-solutions.com/ubuntu/ jammy-esl-erlang-25 contrib\ndeb http://binaries2.erlang-solutions.com/debian/ bullseye-elixir-1.15 contrib\ndeb http://binaries2.erlang-solutions.com/ubuntu/ bionic-mongooseim-6 contrib\n</code></pre>\n\n<p>To verify which distribution you are running, run \"lsb_release -c\" in console.</p>\n\n<p>Next, add the Erlang Solutions public key for \"apt-secure\" using following commands:</p>\n\n<pre><code>wget https://binaries2.erlang-solutions.com/GPG-KEY-pmanager.asc\nsudo apt-key add GPG-KEY-pmanager.asc\n</code></pre>\n\n<h2>2. Installing Erlang</h2>\n\n<p>Refresh the repository cache and install either the \"erlang\" package:</p>\n\n<pre><code>sudo apt-get update\nsudo apt-get install erlang\n</code></pre>\n\n<p>or the \"esl-erlang\" package:</p>\n\n<pre><code>sudo apt-get update\nsudo apt-get install esl-erlang\n</code></pre>\n\n<p>Please refer to the FAQ for the difference between those versions.</p>\n\n<h1>FAQ &mdash; Frequently Asked Questions</h1>\n\n <p> Following the launch of our new binaries platform, Erlang Solutions invites you to explore our FAQ section, dedicated to our updated packages.  Here you’ll find answers to common queries, troubleshooting and your other popular questions about our user-friendly platform. To support the continued growth and development of the Erlang ecosystem, we want to make it as easy as possible for you to download, install and deploy systems and third-party applications implemented in Erlang and Elixir.</p><p>This page will be regularly updated to reflect any changes.</p>\n\n<h2>1. What can I use the Binary packages for? </h2>\n\n<p>Binary packages provide pre-compiled versions of software, such as esl-Erlang and Elixir, which can be easily installed and used on compatible systems without the need for manual compilation. You can use these binary packages to set up and deploy Erlang and Elixir applications quickly. Whether you are an individual developer or part of a team, binary packages offer a convenient way to kickstart your development environment. By using pre-compiled versions, you can avoid the complexities of compilation and focus on coding and testing. Our binary packages undergo rigorous testing to ensure stability and reliability.</p>\n\n<h2>2. What architectures do you support?</h2>\n\n<p>We currently support two architectures in our binary packages: amd64 and arm64. These architectures cover a wide range of modern hardware, including both 64-bit x86 (amd64) and ARM-based systems (arm64).</p><p>Note: While our primary focus is on 64-bit architectures due to their widespread use and performance advantages, we understand that there is a lot of interest in 32-bit architectures, especially for embedded systems where power efficiency is crucial. While we don't officially provide pre-built packages for 32-bit architectures at the moment, we are open to considering them based on demand. If you require support for 32-bit architectures or have specific needs for embedded systems, please reach out to us, and we'll be happy to discuss customised solutions that may involve additional costs.</p><p>We always strive to provide the best experience for our users, and your feedback and requirements are essential in shaping our future offerings. Feel free to contact us if you have any questions or special requirements.</p>\n\n <h2>3. Can I request packages for architectures you currently do not support?</h2>\n\n<p>Yes. We can provide packages for currently non-supported 32 and 64-bit architectures or suggest alternative solutions. The binary packages we provide can be proprietary and built for your own needs, or they can be made available through our platform for the wider community. Fill out the contact form, and our engineers will be able to provide more information on our capabilities and sponsorship packages.</p>\n\n<h2>4. What test cases do you run?</h2>\n\n<p>We do functional testing and hardening test for each package:</p> <p>1. Release Tests: The build process runs the release tests for Erlang/OTP. These tests ensure the correctness and functionality of the release build by performing various checks on the Erlang/OTP and Elixir installation.</p><p>2. Smoke Tests: As part of the release tests, smoke tests are executed to verify the basic functionality of Erlang/OTP and Elixir. These tests ensure that critical components and features are working as expected.</p>\n\n<h2>5. How do you certify the binary packages?</h2>\n\n<p>Our binary packages undergo a meticulous certification process to ensure their integrity and authenticity. We achieve this through digital signatures, assuring the packages' origin and preventing tampering during transit. Additionally, cryptographic hashes act as unique fingerprints to verify their integrity after download. Rigorous automated testing and compatibility verification guarantee that the packages meet our high-quality standards and perform optimally on supported architectures. Continuous monitoring and user feedback further reinforce the reliability and security of our certified binary packages, allowing you to confidently deploy and develop Erlang and Elixir applications with peace of mind.</p>\n\n<h2>6. Why should I use yours, and not build my own?</h2>\n\n<p>Using pre-compiled binary packages can save you time, effort and money when compared to building the software from source code.</p><p>The binary packages are already compiled and optimised for the supported architectures, making the installation process faster and more convenient. Additionally, using official binary packages ensures that you are using a trusted and supported version of the software which has been tested.</p>\n\n<h2>7. Can I buy support for Erlang/OTP and the BEAM? </h2>\n\n<p>Yes. It is possible to purchase commercial support for Erlang/OTP and the BEAM. </p><p>Erlang Solutions has an exclusive contract with Ericsson and is able to offer commercial support packages, which can include technical assistance, bug fixes, and other benefits. They include an SLA, patches and workarounds where the bug is reproducible and a guarantee that the bug will be fixed in the next open-source release. You can explore the options provided by contacting us using the contact form.</p>\n\n<h2>8. Where can I find any additional information about Erlang and Elixir upgrades?</h2>\n\n<p>Any additional information about support packages and upgrades can be found here:</p><p>https://www.erlang.org/downloads#prebuilt</p><p>https://www.erlang.org/downloads/26</p> \n\n"
                # Extract the os_name and version from os_parts
                #os_name = os_parts[1].split("_")[0] + " " + os_parts[2]  # Concatenate OS name and version
                os_name = os_parts[1] 
                # Find the appropriate JSON data dictionary based on the tab name
                json_data = None

                if "esl-erlang" in filename:
                    json_data = erlang_json_data


                if json_data:
                    # Check if a tab with the OS name already exists

                    macos_tab = next((tab for tab in json_data["tabs"] if tab["name"] == "Mac OS"), None)
                    if not macos_tab:
                        json_data["tabs"].append({
                            "name": "Mac OS",
                            "caption": "Mac OS",
                            "header": "",
                            "footer": "<h1>Installation instructions for Mac OS X</h1>\n\n<h2>Installation using brew </h2>\n\n<code> sudo brew install erlang </code>\n<h2>Installation using Macports </h2>\n\n<code> sudo port install erlang </code>",
                            "flavours": [
                                {
                                    "name": "main",
                                    "packages_stable": [],
                                    "packages_testing": [],
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
                            "footer": "<h1>Installation instruction for Windows</h1>\n\n<h2>Please use OTP Installer on http://erlang.org/download",
                            "flavours": [
                                {
                                    "name": "main",
                                    "packages_stable": [],
                                    "packages_testing": [],
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
                                "packages_stable": [],
                                "packages_testing": [],
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
                                    "packages_stable": [],
                                    "packages_testing": [],
                                    "packages": [file_info],
                                    "header": "",
                                    "footer": ""
                                }
                            ]
                        })

# Write separate JSON file for esl-erlang

with open('erlang_packages.json', 'w') as json_file:
    json_file.write("jsonCallback(" + json.dumps(erlang_json_data, indent=4) + ")")


