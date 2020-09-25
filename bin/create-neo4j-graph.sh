#!/bin/bash

if [ -z "${NEO4J_URL}" ]
then
  exit 0
fi

IFS="
"


echo "Create neo4J graph"


function clear_neo4j {
  echo "[neo4J] Clear neo4j"
  curl -s -XPOST -u "${NEO4J_USER}:${NEO4J_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/${NEO4J_DB:-neo4j}/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (n) OPTIONAL MATCH (n)-[r]-() DELETE n,r\"}]}"
}


function create_node {

  NODES_LENGTH=`cat ${NODES_FILE} | wc -l`

  i=0
  for NODE in `cat "${NODES_FILE}"`
  do
    echo "[neo4J] Create node ${i}/${NODES_LENGTH}"

    NAME=`echo "${NODE}" | jq -r .name`
    TYPE=`echo "${NODE}" | jq -r .type`

    curl -XPOST -s -u "${NEO4J_USER}:${NEO4J_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/${NEO4J_DB:-neo4j}/tx/commit -d "{\"statements\":[{\"statement\":\"CREATE (:${TYPE} { Name:\\\"${NAME}\\\",Id:$i})\"}]}"

    i=$(( i+1 ))
  done
}

function create_link {

  LINKS_LENGTH=`cat ${OUTPUT_FILE} | wc -l`

  i=0
  for LINK in `cat "${OUTPUT_FILE}"`
  do
    echo "[neo4J] Create link ${i}/${LINKS_LENGTH}"

    SOURCE_NAME=`echo "${LINK}" | jq -r .sourceName`
    TARGET_NAME=`echo "${LINK}" | jq -r .targetName`
    SOURCE_TYPE=`echo "${LINK}" | jq -r .sourceType`
    TARGET_TYPE=`echo "${LINK}" | jq -r .targetType`
    LINK_NAME=`echo "${LINK}" | jq -r .linkName`
    LINK_PROPERTIES=`echo "${LINK}" | jq -r .linkProperties`

    curl -XPOST -s -u "${NEO4J_USER}:${NEO4J_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/${NEO4J_DB:-neo4j}/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (a:${SOURCE_TYPE}),(b:${TARGET_TYPE}) WHERE a.Name = \\\"${SOURCE_NAME}\\\" AND b.Name = \\\"${TARGET_NAME}\\\" CREATE (a)-[r:${LINK_NAME}{${LINK_PROPERTIES}}]->(b) RETURN type(r)\"}]}"

    i=$(( i+1 ))
  done
}

function enriche_node() {

  COUNT=`cat "${ENRICHED_NODES_FILE}" | wc -l`
  i=1

  for line in `cat "${ENRICHED_NODES_FILE}"`
  do
      echo "[neo4J] Enriche node ${i}/${COUNT}"

      TYPE=`echo "${line}" | cut -d';' -f1`
      NAME=`echo "${line}" | cut -d';' -f2`
      PROPERTIES=`echo "${line}" | cut -d';' -f3`

      curl -XPOST -s -u "${NEO4J_USER}:${NEO4J_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/${NEO4J_DB:-neo4j}/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (a:${TYPE} { Name: \\\"${NAME}\\\" }) SET a+= ${PROPERTIES}\"}]}"
      i=$(( i+1 ))
  done

}

clear_neo4j
create_node
create_link
enriche_node

echo "[neo4J] Graph create successfully. Open ${NEO4J_URL}"