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


function rename_node_label() {

  echo "[neo4J] Rename node label (need neo4j apoc plugin)"
  RESULT=`curl -XPOST -s -u "${NEO4J_USER}:${NEO4J_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/${NEO4J_DB:-neo4j}/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (n:api) WHERE n.label IS NOT NULL WITH DISTINCT n.label AS label RETURN label\"}]}"`

  LABELS_TO_RENAME=`echo "${RESULT}" | jq .results[0].data[0].row`
  LABELS_TO_RENAME_COUNT=`echo "${LABELS_TO_RENAME}" | jq length`

  i=0
  while [ "$i" -lt "${LABELS_TO_RENAME_COUNT}" ]
  do
    LABEL_TO_RENAME=`echo "${LABELS_TO_RENAME}" | jq -r .[$i]`
    echo "[neo4J] Rename label ${LABEL_TO_RENAME} : ${i}/${LABELS_TO_RENAME_COUNT}"

    RESULT=`curl -XPOST -s -u "${NEO4J_USER}:${NEO4J_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/${NEO4J_DB:-neo4j}/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (n:api{label:'${LABEL_TO_RENAME}'}) WITH COLLECT(n) AS nodes CALL apoc.refactor.rename.label('api','${LABEL_TO_RENAME}',nodes) yield errorMessages AS eMessages RETURN eMessages\"}]}"`
    i=$(( i+1 ))
  done

}


clear_neo4j
create_node
create_link
enriche_node
rename_node_label

echo "[neo4J] Graph create successfully. Open ${NEO4J_URL}"