#!/bin/bash

GRAPH=`cat "${JSON_FILE}"`

NODES=`echo "${GRAPH}" | jq ".nodes"`
NODES_LENGTH=`echo "${NODES}" | jq length`

i=0
while [ "$i" -lt "${NODES_LENGTH}" ]
do

  echo "[neo4J] Create node ${i}/${NODES_LENGTH}"

  NODE=`echo "${NODES}" | jq ".[$i]"`
  NAME=`echo "${NODE}" | jq -r .name`
  TYPE=`echo "${NAME}" | cut -d_ -f1`
  NAME=`echo "${NAME}" | cut -d_ -f2`

  curl -XPOST -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/neo4j/tx/commit -d "{\"statements\":[{\"statement\":\"CREATE (:${TYPE} { Name : \\\"${NAME}\\\", Id: $i })\"}]}"

  i=$(( i+1 ))
done


LINKS=`echo "${GRAPH}" | jq ".links"`
LINKS_LENGTH=`echo "${LINKS}" | jq length`

i=0
while [ "$i" -lt "${LINKS_LENGTH}" ]
do

  echo "[neo4J] Create link ${i}/${LINKS_LENGTH}"

  LINK=`echo "${LINKS}" | jq ".[$i]"`
  SOURCE=`echo "${LINK}" | jq -r .source`
  TARGET=`echo "${LINK}" | jq -r .target`
  SOURCE_TYPE=`echo "${LINK}" | jq -r .sourceType`
  TARGET_TYPE=`echo "${LINK}" | jq -r .targetType`

  curl -XPOST -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/neo4j/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (a:${SOURCE_TYPE}),(b:${TARGET_TYPE}) WHERE a.Id = ${SOURCE} AND b.Id = ${TARGET} CREATE (a)-[r:RELTYPE]->(b) RETURN type(r)\"}]}"

  i=$(( i+1 ))
done

echo "[neo4J] Graph create successfully. Open ${NEO4J_URL}"
