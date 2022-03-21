#!/bin/sh

# Source function library.
if [ -f /etc/init.d/functions ]
then
        . /etc/init.d/functions
fi

################################################ Parse input parameters #############################################
function usage {
      echo "\n"
      echo "Usage: provision-coffeeshop-rhosak-instance.sh [args...]"
      echo "where args include:"
      echo "    -k              The name of the Kafka instance you want to use"
      echo "    -s              The name of the service account to be created."
}

#Parse the params
while getopts ":k:s:h" opt; do
  case $opt in
    k)
      KAFKA_NAME=$OPTARG
      ;;
    t)
      TOPIC_NAME=$OPTARG
      ;;
    s)
      SERVICE_ACCOUNT_NAME=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

PARAMS_NOT_OK=false

#Check params
if [ -z "$KAFKA_NAME" ]
then
        echo "No Kafka name specified!"
        PARAMS_NOT_OK=true
fi
if [ -z "$SERVICE_ACCOUNT_NAME" ]
then
        echo "No Service Account name specified!"
        PARAMS_NOT_OK=true
fi

if $PARAMS_NOT_OK
then
        usage
        exit 1
fi

# ------------------------------------------------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------------------------------------------------

CLOUD_PROVIDER=aws
CLOUD_PROVIDER_REGION=us-east-1

# ------------------------------------------------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------------------------------------------------

function createServiceAccount {
    echo "Creating Service Account with name $1"
    rhoas service-account create --overwrite --file-format=env --output-file=service_account.env --short-description=$1
    echo "Service Account details stored in 'service_account.env' file."
    source ./service_account.env
    CLIENT_ID=$RHOAS_SERVICE_ACCOUNT_CLIENT_ID
    CLIENT_SECRET=$RHOAS_SERVICE_ACCOUNT_CLIENT_SECRET
}

# ------------------------------------------------------------------------------------------------------------------------
# Create an OpenShift Streams instance.
# ------------------------------------------------------------------------------------------------------------------------

echo "Creating OpenShift Streams instance with name: $KAFKA_NAME"

rhoas kafka create --name $KAFKA_NAME --provider $CLOUD_PROVIDER --region $CLOUD_PROVIDER_REGION

if [ $? -ne 0 ]
then
    echo "Something went wrong when creating Kafka instance."
    exit 1
fi

# ------------------------------------------------------------------------------------------------------------------------
# Wait for the OpenShift Streams instance to be ready.
# ------------------------------------------------------------------------------------------------------------------------

echo "Wait for the OpenShift Streams instance to be ready."

rhosak_status=$(rhoas kafka describe | grep status | awk -F '"' '{print $4}')

while [ $rhosak_status != "ready" ]; do
    rhosak_status=$(rhoas kafka describe | grep status | awk -F '"' '{print $4}')
    echo "Waiting for OpenShift Streams instance to be ready."
    echo "Current OpenShift Streams instance status: $rhosak_status"
    echo "Waiting 20 seconds.\n"
    sleep 20
done

echo "OpenShift Streams instance ready."

# ------------------------------------------------------------------------------------------------------------------------
# Create Kafka topics
# ------------------------------------------------------------------------------------------------------------------------

echo "Creating Kafka topics."

declare -a topics=("orders-in" "orders-up" "barista-in" "kitchen-in" "web-updates" "eighty-six" "loyalty-updates")
# Loop through the topics
for i in "${topics[@]}"
do
   echo "Creating topic: $i"
   # or do whatever with individual element of the array
   rhoas kafka topic create --name $i
done

# ------------------------------------------------------------------------------------------------------------------------
# Create Service Account
# ------------------------------------------------------------------------------------------------------------------------

createServiceAccount $SERVICE_ACCOUNT_NAME
echo "Service Account client-id: $CLIENT_ID"

# ------------------------------------------------------------------------------------------------------------------------
# Set Kafka ACLs
# ------------------------------------------------------------------------------------------------------------------------

echo "Setting Kafka ACLs"

rhoas kafka acl grant-access --producer --consumer --service-account $CLIENT_ID --topic orders-in --group quarkuscoffeeshop-counter --yes
rhoas kafka acl grant-access --producer --consumer --service-account $CLIENT_ID --topic orders-up --group quarkuscoffeeshop-counter --yes
rhoas kafka acl grant-access --producer --consumer --service-account $CLIENT_ID --topic barista-in --group quarkuscoffeeshop-counter --yes
rhoas kafka acl grant-access --producer --consumer --service-account $CLIENT_ID --topic kitchen-in --group quarkuscoffeeshop-counter --yes
rhoas kafka acl grant-access --producer --consumer --service-account $CLIENT_ID --topic web-updates --group quarkuscoffeeshop-counter --yes
rhoas kafka acl grant-access --producer --consumer --service-account $CLIENT_ID --topic eighty-six --group kitchen-group --yes
rhoas kafka acl grant-access --producer --consumer --service-account $CLIENT_ID --topic loyalty-updates --group quarkuscoffeeshop-web --yes

rhoas kafka acl create --operation read --permission allow --group quarkuscoffeeshop-counter --service-account $CLIENT_ID --yes
rhoas kafka acl create --operation read --permission allow --group kitchen-group --service-account $CLIENT_ID --yes 
rhoas kafka acl create --operation read --permission allow --group quarkuscoffeeshop-web --service-account $CLIENT_ID --yes
rhoas kafka acl create --operation read --permission allow --group barista-group --service-account $CLIENT_ID --yes

echo "OpenShift Streams setup for Quarkus Coffeeshop demo complete!"