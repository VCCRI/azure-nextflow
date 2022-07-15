import os
import requests
import re
import subprocess
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

def curl(uri, fileName=""):
    if fileName == "":
        fileName = uri.split("/")[-1]

    response = requests.get(uri)
    if response.status_code == 200:
        f = open(fileName, "w")
        f.write(response.text)
        f.close()
        print(fileName)
    else:
        print(f"Error {response.status_code} downloading: {uri}")

def findFirstInLine(fileName, pattern):
    list = []    
    f = open(fileName, "r")
    for line in f:
        match = re.findall(pattern, line)
        if match:
            list.append(match[0])
    return list

def findSecrets(fileName):
    list = []
    matches = findFirstInLine(fileName, "secrets.[a-z,A-Z,_]*")
    for item in matches:
        item = item.split(".")[1]
        if item not in list:
            list.append(item.replace("_","-"))
    return list

def findParams(fileName):
    list = []
    matches = findFirstInLine(fileName, "exParams.[a-z,A-Z,_]*")
    for item in matches:
        item = item.split(".")[1]
        if item not in list:
            list.append(item)
    return list

curl("https://raw.githubusercontent.com/axgonz/azure-nextflow/main/nextflow/pipelines/nextflow.config")
curl("https://raw.githubusercontent.com/axgonz/azure-nextflow/main/nextflow/pipelines/helloWorld/pipeline.nf")
curl("https://raw.githubusercontent.com/axgonz/azure-nextflow/main/nextflow/pipelines/helloWorld/parameters.json")

secrets = findSecrets("nextflow.config")
params = findParams("nextflow.config")

keyVaultName = os.environ["AZ_KEY_VAULT_NAME"]
KVUri = f"https://{keyVaultName}.vault.azure.net"

credential = DefaultAzureCredential()
client = SecretClient(vault_url=KVUri, credential=credential)

for secret in secrets:
    print(f"Importing secret '{secret}' to nextflow")
    azSecret = client.get_secret(secret.replace("_","-"))
    subprocess.run(["./nextflow", "secrets", "put", "-n", secret.replace("-","_"), "-v", azSecret.value])

for param in params:
    azSecret = client.get_secret(param.replace("_","-"))
    print(f"{param}: {azSecret.value}")
    # ToDo replace exParam with value in nextflow.config

subprocess.run(["./nextflow", "config"])
subprocess.run(["./nextflow", "run pipeline.nf", "-params-file", "parameters.json", "-w", "az://batch/work", "-with-timeline", "-with-dag"])

