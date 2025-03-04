#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh



if [ ! -z "$AZ_USER" ] && [ ! -z "$AZ_PASS" ]
then
    log "Logging to Azure using environment variables AZ_USER and AZ_PASS"
    set +e
    az logout
    set -e
    az login -u "$AZ_USER" -p "$AZ_PASS" > /dev/null 2>&1
else
    log "Logging to Azure using browser"
    az login
fi

AZURE_TENANT_NAME=${AZURE_TENANT_NAME:-$1}

if [ -z "$AZURE_TENANT_NAME" ]
then
     logerror "AZURE_TENANT_NAME is not set. Export it as environment variable or pass it as argument"
     exit 1
fi

AZURE_NAME=pg${USER}dl${GITHUB_RUN_NUMBER}${TAG}
AZURE_NAME=${AZURE_NAME//[-._]/}
AZURE_RESOURCE_GROUP=$AZURE_NAME
AZURE_DATALAKE_ACCOUNT_NAME=$AZURE_NAME
AZURE_AD_APP_NAME=$AZURE_NAME
AZURE_REGION=westeurope

set +e
az group delete --name $AZURE_RESOURCE_GROUP --yes
AZURE_DATALAKE_CLIENT_ID=$(az ad app create --display-name "$AZURE_AD_APP_NAME" --is-fallback-public-client false --sign-in-audience AzureADandPersonalMicrosoftAccount --query appId -o tsv)
az ad app delete --id $AZURE_DATALAKE_CLIENT_ID
set -e

log "Creating resource $AZURE_RESOURCE_GROUP in $AZURE_REGION"
az group create \
    --name $AZURE_RESOURCE_GROUP \
    --location $AZURE_REGION \
    --tags owner_email=$AZ_USER

log "Registering active directory App $AZURE_AD_APP_NAME"
AZURE_DATALAKE_CLIENT_ID=$(az ad app create --display-name "$AZURE_AD_APP_NAME" --is-fallback-public-client false --sign-in-audience AzureADandPersonalMicrosoftAccount --query appId -o tsv)
AZURE_DATALAKE_CLIENT_PASSWORD=$(az ad app credential reset --id $AZURE_DATALAKE_CLIENT_ID | jq -r '.password')

if [ "$AZURE_DATALAKE_CLIENT_PASSWORD" == "" ]
then
  logerror "password could not be retrieved"
  if [ -z "$GITHUB_RUN_NUMBER" ]
  then
    az ad app credential reset --id $AZURE_DATALAKE_CLIENT_ID
  fi
  exit 1
fi

log "Creating Service Principal associated to the App"
SERVICE_PRINCIPAL_ID=$(az ad sp create --id $AZURE_DATALAKE_CLIENT_ID | jq -r '.id')

AZURE_TENANT_ID=$(az account list --query "[?name=='$AZURE_TENANT_NAME']" | jq -r '.[].tenantId')
AZURE_DATALAKE_TOKEN_ENDPOINT="https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/token"

log "Creating data lake $AZURE_DATALAKE_ACCOUNT_NAME in resource $AZURE_RESOURCE_GROUP"
az dls account create --account $AZURE_DATALAKE_ACCOUNT_NAME --resource-group $AZURE_RESOURCE_GROUP

log "Giving permission to app $AZURE_AD_APP_NAME to get access to data lake $AZURE_DATALAKE_ACCOUNT_NAME"
az dls fs access set-entry --account $AZURE_DATALAKE_ACCOUNT_NAME  --acl-spec user:$SERVICE_PRINCIPAL_ID:rwx --path /

# generate data file for externalizing secrets
sed -e "s|:AZURE_DATALAKE_CLIENT_ID:|$AZURE_DATALAKE_CLIENT_ID|g" \
    -e "s|:AZURE_DATALAKE_CLIENT_PASSWORD:|$AZURE_DATALAKE_CLIENT_PASSWORD|g" \
    -e "s|:AZURE_DATALAKE_ACCOUNT_NAME:|$AZURE_DATALAKE_ACCOUNT_NAME|g" \
    -e "s|:AZURE_DATALAKE_TOKEN_ENDPOINT:|$AZURE_DATALAKE_TOKEN_ENDPOINT|g" \
    ../../connect/connect-azure-data-lake-storage-gen1-sink/data.template > ../../connect/connect-azure-data-lake-storage-gen1-sink/data


${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

log "Creating Data Lake Storage Gen1 Sink connector"
playground connector create-or-update --connector azure-datalake-gen1-sink << EOF
{
    "connector.class": "io.confluent.connect.azure.datalake.gen1.AzureDataLakeGen1StorageSinkConnector",
    "tasks.max": "1",
    "topics": "datalake_topic",
    "flush.size": "3",
    "azure.datalake.client.id": "\${file:/data:AZURE_DATALAKE_CLIENT_ID}",
    "azure.datalake.client.key": "\${file:/data:AZURE_DATALAKE_CLIENT_PASSWORD}",
    "azure.datalake.account.name": "\${file:/data:AZURE_DATALAKE_ACCOUNT_NAME}",
    "azure.datalake.token.endpoint": "\${file:/data:AZURE_DATALAKE_TOKEN_ENDPOINT}",
    "format.class": "io.confluent.connect.azure.storage.format.avro.AvroFormat",
    "confluent.license": "",
    "confluent.topic.bootstrap.servers": "broker:9092",
    "confluent.topic.replication.factor": "1"
}
EOF


playground topic produce -t datalake_topic --nb-messages 10 --forced-value '{"f1":"value%g"}' << 'EOF'
{
  "type": "record",
  "name": "myrecord",
  "fields": [
    {
      "name": "f1",
      "type": "string"
    }
  ]
}
EOF

sleep 20

log "Listing ${AZURE_DATALAKE_ACCOUNT_NAME} in Azure Data Lake"
az dls fs list --account "${AZURE_DATALAKE_ACCOUNT_NAME}" --path /topics

log "Getting one of the avro files locally and displaying content with avro-tools"
az dls fs download --account "${AZURE_DATALAKE_ACCOUNT_NAME}" --overwrite --source-path /topics/datalake_topic/partition=0/datalake_topic+0+0000000000.avro --destination-path /tmp/datalake_topic+0+0000000000.avro

docker run --rm -v /tmp:/tmp vdesabou/avro-tools tojson /tmp/datalake_topic+0+0000000000.avro

log "Deleting resource group"
az group delete --name $AZURE_RESOURCE_GROUP --yes --no-wait

log "Deleting active directory app"
az ad app delete --id $AZURE_DATALAKE_CLIENT_ID