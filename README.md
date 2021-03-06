# create-microservice-map

![Build](https://github.com/GuillaumeWaignier/create-microservice-map/workflows/Build/badge.svg)


Create a graph between all related elements, such as API, Kafka topic, by introspecting middleware configuration.

## Usage (docker)

Create a docker compose file (*docker-compose.yml*) like this following:

```yaml
version: "3.7"
services:
  create-microservice-map:
    image: "ianitrix/create-microservice-map:latest"
    hostname: create-microservice-map
    environment:
      # neo4j backend
      - NEO4J_URL=http://neo4j:7474
      - NEO4J_DB=test
      - NEO4J_USER=neo4j
      - NEO4J_PASSWORD=passwordSecure
      - NEO4J_POST_ACTION_FILE=/post-action-neo4j.txt
      # orientdb backend
      - ORIENTDB_URL=http://orientdb:2480
      - ORIENTDB_DB=test
      - ORIENTDB_USER=root
      - ORIENTDB_PASSWORD=root
      - ORIENTDB_POST_ACTION_FILE=/post-action-orientdb.txt
      # Gravitee Configuration
      - GRAVITEE1_URL=http://management_api:8083
      - GRAVITEE_USER=admin
      - GRAVITEE_PASS=admin
      # AKHQ Configuration
      - AKHQ_URL=http://akhq:8080
      - AKHQ_USER=admin
      - AKHQ_PASS=admin
      - AKHQ_CLUSTER=docker-kafka-server
      # AKHQ Configuration for kafka connect
      - AKHQ_CONNECT_CLUSTER=default
      # MongoDB Atlas Configuration
      - MONGODB_ATLAS_URL=https://cloud.mongodb.com
      - MONGODB_ATLAS_USER=xxxxx
      - MONGODB_ATLAS_PASS=xxxxxx-xxxx-xxxxx-xxxx-xxxxxxxxxxxx
      - MONGODB_ATLAS_PROJECT_ID=xxxxxxxxxxxxxxxx
    restart: on-failure
    ports:
      - 8080:80
    networks:
      - net

  neo4j:
    image: "neo4j:4.1.1"
    hostname: neo4j
    restart: on-failure
    environment:
      # - NEO4J_AUTH=none
      - NEO4J_AUTH=neo4j/passwordSecure
      - NEO4J_dbms_default__database=test
      - NEO4J_apoc_export_file_enabled=true
      - NEO4J_apoc_import_file_enabled=true
      - NEO4J_apoc_import_file_use__neo4j__config=true
      - NEO4JLABS_PLUGINS=["apoc"]
    ports:
      - 7474:7474
      - 7687:7687
    networks:
      - net

  orientdb:
    image: "orientdb:3.1.7"
    hostname: orientdb
    restart: on-failure
    environment:
      - ORIENTDB_ROOT_PASSWORD=root
    ports:
      - 2480:2480
      - 2424:2424
    networks:
      - net

networks:
  net:
    name: net    
```

Then open the following URL [http://localhost:7474](http://localhost:7474) for the [Neo4J](https://neo4j.com) graph.
Or open [http://localhost:2480](http://localhost:2480) for the [orientdb](https://www.orientdb.org) graph.



## Configuration

All configurations are done with environment variables.

> Each plugin is enable only if the URL is set

* Storage [Neo4J](https://neo4j.com)

| Configuration      | Default value | Comment  |
| ------------------ |:-------------:| -----:|
|  NEO4J_URL         |               | Neo4J URL (enable only if the URL is set)|
|  NEO4J_DB          |  neo4j        | Database   |
|  NEO4J_USER        |               | User login (optional)   |
|  NEO4J_PASSWORD    |               | User password (optional)   |
|  NEO4J_POST_ACTION_FILE|           | list of neo4j query executed at the end, such as tagging node as 'user' (optional)   |

* Storage [orientdb](https://www.orientdb.org)

| Configuration      | Default value | Comment  |
| ------------------ |:-------------:| -----:|
|  ORIENTDB_URL         |               | Orientdb URL (enable only if the URL is set)|
|  ORIENTDB_DB          |               | Database   |
|  ORIENTDB_USER        |               | User login (optional)   |
|  ORIENTDB_PASSWORD    |               | User password (optional)   |
|  ORIENTDB_POST_ACTION_FILE|           | list of orientdb query executed at the end, such as tagging node as 'user' (optional)   |

* API Management [Gravitee V1.x](https://www.gravitee.io/)

| Configuration      | Default value | Comment  |
| ------------------ |:-------------:| -----:|
|  GRAVITEE1_URL     |               | URL for Gravitee Management Api |
|  GRAVITEE_USER     |               | User login   |
|  GRAVITEE_PASS     |               | Password |

* API Management [Gravitee V3.x](https://www.gravitee.io/)

| Configuration      | Default value | Comment  |
| ------------------ |:-------------:| -----:|
|  GRAVITEE3_URL     |               | URL for Gravitee Management Api |
|  GRAVITEE_USER     |               | User login   |
|  GRAVITEE_PASS     |               | Password |
|  GRAVITEE3_ORGANIZATION    | DEFAULT       | Organization |
|  GRAVITEE3_ENVIRONMENTS    | DEFAULT       | Environment |

* Kafka IHM [Akhq](https://akhq.io/) (version 0.14 min)

| Configuration | Default value | Comment  |
| ------------- |:-------------:| -----:|
|  AKHQ_URL     |               | URL for AKHQ Api |
|  AKHQ_CLUSTER |               | Cluster name in AKHQ config |
|  AKHQ_USER    |               | User login   |
|  AKHQ_PASS    |               | Password |
|  AKHQ_CONNECT_CLUSTER    |               | Optional: used to collect kafka connect plugins |

The needed permissions is *acls/read* and optionally *connect/read* to collect kafka connect info.

* [MongoDB Atlas](https://cloud.mongodb.com)

| Configuration | Default value | Comment  |
| ------------- |:-------------:| -----:|
|  MONGODB_ATLAS_URL     |               | URL for mongoDB atlas (https://cloud.mongodb.com) |
|  MONGODB_ATLAS_PROJECT_ID |               | Project Id |
|  MONGODB_ATLAS_USER    |               | Public API key   |
|  MONGODB_ATLAS_PASS    |               | Private API key |

See [https://docs.atlas.mongodb.com/configure-api-access/](https://docs.atlas.mongodb.com/configure-api-access/) to create API key.
The needed permissions is *Project Read Only*

## How it's work

The tool calls the REST API of the various tools (Gravitee, AkHQ, Elastic, ...) in order to retrieve the ACLs configuration.
Given this ACLs (read, write), a data graph is created.
A [Neo4J](https://neo4j.com) graph database is populated.

## Test

If you want to test, there are several docker-compose files used to simulate an e-commerce SI.

First, clone the repo and start the docker network

```bash
# Clone the repo
git clone https://github.com/GuillaumeWaignier/create-microservice-map.git

# Start the docker netwok
cd test
docker-compose up -d
```

Then, create the Gravitee API Management

```bash
# Start Gravitee and all its dependencies (MongoDB, Elastic)
cd test/gravitee
docker-compose up -d
```

You can use the Gravitee UI to see the APIs and subscriptions at [http://localhost:8084](http://localhost:8084).
Login and password are *admin*/*admin*

You can create Kafka topic with
```bash
# Start AKHQ and all its dependencies (Zookeeper, Kafka)
cd test/kafka
docker-compose up -d
```

You can use the AKHQ to see the kafka topic and the associated ACLs at [http://localhost:8080](http://localhost:8080).

You can create the graph with

```bash
# Create the graph
docker-compose up -d
```

Then open the neo4j graph at [http://localhost:7474](http://localhost:7474).

# Neo4j

When the [Neo4J](https://neo4j.com) URL is set, the tool populate the base.

![Graphe](./neo4j.png)

You can then do some query:

* Node connected to *api-cart* with depth of 2

```bash
MATCH (a:api { Name: 'api-cart' })-[*0..2]->(b) RETURN a,b
```

![cart](./api-cart.png)

* Topic with *delete* policy

```bash
MATCH (n:topic) WHERE n.cleanup="delete" RETURN n
```

![topics](./topics.png)

* Mongo db read or write by loaders

```bash
MATCH (n)-[*0..1]-(b) WHERE n.Name STARTS WITH "loader-" RETURN n,b
```

![loader](./loader.png)

* Number of sub dependancy links (topic, mongo, other apis) for all api

```bash
MATCH (a:api)-[r:consume|produce*1..1]-(b) RETURN a.Name, COUNT(r) ORDER BY COUNT(r) DESC
```



