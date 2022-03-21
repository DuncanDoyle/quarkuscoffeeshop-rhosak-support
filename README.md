# Quarkus Coffeeshop OpenShift Streams for Apache Kafka support

This repository provides support tools and scripts to setup a managed Red Hat OpenShift Streams for Apache Kafka instance to be used with the Quarkus Cofffeeshop demo.

## Setup OpenShift Streams
The `provision-coffeeshop-rhosak-instance.sh` script provides a fully automated way to setup an OpenShift Streams for Apache Kafka instance, including the reuqired Service Account, Topics and ACLs.

To use the script, make sure you have the `rhoas` CLI installed on your machine. The `rhoas` CLI can be downloaded [here](https://github.com/redhat-developer/app-services-cli/releases).

Before you can run the script, make sure you are logged in to the `rhoas` CLI using: `rhoas login`

Once logged in, provision a Kafka instance by running the `provision-coffeeshop-rhosak-instance.sh`, providing a name for the Kafka instance and a name for the Service Account to be created:

```
provision-coffeeshop-rhosak-instance.sh -k coffeeshop-kafka -s coffeeshop-sa
```

After running this script, you will have:
* An OpenShift Streams instance
* A Service Account
* Topics required for the Quarkus Coffeeshop demo created in Kafka
* ACLs for topics and consumer groups created.
* A `service_account.env` file created on your local system, containing the _CLIENT_ID and _CLIENT_SECRET_ of the created Service Account.

## OpenShift Streams Bootstrap Server
To connect your Quarkus applications to your new OpenShift Streams instance, you will need to know the _bootstrap server url_. To retrieve the this URL of your OpenShift Streams instance, you can use the following CLI command: `rhoas kafka describe`

This will provide you the Kafka instance details, including the `bootstrap_server_host`.


## Configuring your Quarkus applications

Use the following configuration in your Quarkus' `application.properties` file to connect your Quarkus application to your OpenShift Streams Kafka instance.

```
kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_URLS}
kafka.security.protocol=SASL_SSL
kafka.sasl.mechanism=PLAIN
kafka.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required \
  username="${CLIENT_ID}" \
  password="${CLIENT_SECRET}";
```

Where the `${KAFKA_BOOTSTRAP_URLS}` environment variable should point to the OpenShift Streams Kafka instance _bootstrap server url_ retrieved earlier, and where `${CLIENT_ID}` and `${CLIENT_SECRET}` contain the _CLIENT_ID_ and _CLIENT_SECRET_ of the Service Account.
