#!/bin/bash

if [ -z "${ORIENTDB_URL}" ]
then
  echo "[orientdb] Skip because no ORIENTDB_URL"
  exit 0
fi

IFS="
"




function displayOrientdbResult {

  SUCCESS=`echo "$1" | grep "\"errors\": \[.+\]"`
  if [ -z "${SUCCESS}" ]
  then
    echo "[orientdb] Error is : $1 / json is $2"
  fi
}

function clear_orientdb {
  echo "[orientdb] Drop orientdb database ${ORIENTDB_DB}"
  RES=`curl -s -XDELETE -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" ${ORIENTDB_URL}/database/${ORIENTDB_DB}`
  displayOrientdbResult "${RES}" "${JSON}"

  echo "[orientdb] Create orientdb database ${ORIENTDB_DB}"
  RES=`curl -s -XPOST -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" ${ORIENTDB_URL}/database/${ORIENTDB_DB}/plocal`
  displayOrientdbResult "${RES}" "${JSON}"
}

function create_class {

  for class in "api" "mongo" "topic" "app" "kconnect" "user"
  do
    echo "[orientdb] Create vertex class ${class}"
    JSON="{\"command\":\"CREATE CLASS ${class} EXTENDS V\"}"
    RES=`curl -s -XPOST -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`
    displayOrientdbResult "${RES}" "${JSON}"
  done

  for class in "call" "read" "write" "consume" "produce"
  do
    echo "[orientdb] Create edge class ${class}"
    JSON="{\"command\":\"CREATE CLASS ${class} EXTENDS E\"}"
    RES=`curl -s -XPOST -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`
    displayOrientdbResult "${RES}" "${JSON}"
  done
}

function config_studio_ui {
  echo "[orientdb] Config studio"

  # Create class for studio
  JSON="{\"command\":\"CREATE CLASS _studio\"}"
  RES=`curl -s -XPOST -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`
  displayOrientdbResult "${RES}" "${JSON}"

  # Get user admin
  JSON="{\"command\":\"SELECT FROM OUser WHERE name=\\\"admin\\\"\"}"
  RESULT=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`
  ID_USER=`echo "${RESULT}" | jq -r '.result[]."@rid"'`

  STUDIO_CONF='{"width":1602.011364,"height":500,"classes":{"call":{"stroke":"#b28254"},"consume":{"stroke":"#1e701e"},"write":{"stroke":"#623c34"},"api":{"fill":"#ff8339","stroke":"#798ba2","iconCss":null,"icon":null,"display":"Name"},"app":{"fill":"#fe4444","stroke":"#b25809","iconCss":null,"icon":null,"display":"Name"},"topic":{"fill":"#d786d3","stroke":"#897b95","iconCss":null,"icon":null,"display":"Name"},"mongo":{"fill":"#63c8ff","stroke":"#951b1c","iconCss":null,"icon":null,"display":"Name"},"produce":{"stroke":"#b26a69"},"kconnect":{"fill":"#98df8a","stroke":"#6a9c60","iconCss":null,"icon":null,"display":"Name"},"user":{"fill":"#8c564b","stroke":"#623c34","iconCss":null,"icon":null,"display":"Name"}},"node":{"r":30},"linkDistance":200,"charge":-1000,"friction":0.9,"gravity":0.1}'

  JSON="{\"@class\":\"_studio\",\"@type\":\"d\",\"@version\":3,\"type\":\"GraphConfig\",\"config\":${STUDIO_CONF},\"user\":${ID_USER}}"
  RES=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/document/${ORIENTDB_DB} -d "${JSON}"`
  displayOrientdbResult "${RES}" "${JSON}"
}

function create_node {

  NODES_LENGTH=`cat ${NODES_FILE} | wc -l`

  i=0
  for NODE in `cat "${NODES_FILE}"`
  do
    echo "[orientdb] Create node ${i}/${NODES_LENGTH}"

    NAME=`echo "${NODE}" | jq -r .name`
    TYPE=`echo "${NODE}" | jq -r .type`

    # enrich
    LINE=`cat "${ENRICHED_NODES_FILE}" | grep "^${TYPE};${NAME};"`
    PROPERTIES=`echo "${LINE}" | cut -d';' -f3`

    echo "$PROPERTIES"

    JSON="{\"command\":\"CREATE VERTEX ${TYPE}"

    if [   -z "${PROPERTIES}" ]
    then
      JSON="${JSON} CONTENT {Name:\\\"${NAME}\\\"}\"}"
    else
      JSON=`echo "${JSON} CONTENT ${PROPERTIES}" | sed "s/}$/,Name:\\\\\\\\\"${NAME}\\\\\\\\\"}\"}/" | sed "s/datetime({epochMillis:\([0-9]*\)})/date\(\1\)/g"`
    fi

    RES=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`
    displayOrientdbResult "${RES}" "${JSON}"

    i=$(( i+1 ))
  done
}

function create_link {

  LINKS_LENGTH=`cat ${OUTPUT_FILE} | wc -l`

  i=0
  for LINK in `cat "${OUTPUT_FILE}"`
  do
    echo "[orientdb] Create link ${i}/${LINKS_LENGTH}"

    SOURCE_NAME=`echo "${LINK}" | jq -r .sourceName`
    TARGET_NAME=`echo "${LINK}" | jq -r .targetName`
    SOURCE_TYPE=`echo "${LINK}" | jq -r .sourceType`
    TARGET_TYPE=`echo "${LINK}" | jq -r .targetType`
    LINK_NAME=`echo "${LINK}" | jq -r .linkName`
    LINK_PROPERTIES=`echo "${LINK}" | jq -r .linkProperties`

    JSON="{\"command\":\"CREATE EDGE ${LINK_NAME} FROM (SELECT FROM ${SOURCE_TYPE} WHERE Name=\\\"${SOURCE_NAME}\\\") TO (SELECT FROM ${TARGET_TYPE} WHERE Name=\\\"${TARGET_NAME}\\\")\"}"
    RES=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`
    displayOrientdbResult "${RES}" "${JSON}"

    i=$(( i+1 ))
  done
}


function rename_node_label() {

  echo "[orientdb] Rename node label"
  JSON="{\"command\":\"SELECT DISTINCT label FROM app WHERE label IS NOT NULL\"}"
  RESULT=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`

  LABELS_TO_RENAME=`echo "${RESULT}" | jq -r ".result[].label"`
  LABELS_TO_RENAME_COUNT=`echo "${LABELS_TO_RENAME}" | wc -l`

  i=0
  for LABEL_TO_RENAME in ${LABELS_TO_RENAME}
  do
    echo "[orientdb] Rename label ${LABEL_TO_RENAME} : ${i}/${LABELS_TO_RENAME_COUNT}"

    JSON="{\"command\":\"MOVE VERTEX (SELECT FROM app WHERE label=\\\"${LABEL_TO_RENAME}\\\") TO CLASS:${LABEL_TO_RENAME}\"}"
    RES=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`
    displayOrientdbResult "${RES}" "${JSON}"

    i=$(( i+1 ))
  done

}

function execute_post_action {
  echo "[orientdb] Execute post action file ${ORIENTDB_POST_ACTION_FILE}"

  COUNT=`cat "${ORIENTDB_POST_ACTION_FILE}" | wc -l`
  i=1

  for line in `cat "${ORIENTDB_POST_ACTION_FILE}"`
  do
    echo "[orientdb] Execute post action ${i}/${COUNT}"
    JSON="{\"command\":\"${line}\"}"
    RES=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/command/${ORIENTDB_DB}/sql -d "${JSON}"`
    displayOrientdbResult "${RES}" "${JSON}"
    i=$(( i+1 ))
  done

}


echo "Create orientdb graph"

clear_orientdb
create_class
config_studio_ui
create_node
create_link
rename_node_label
if [ ! -z "${ORIENTDB_POST_ACTION_FILE}" ]
then
  execute_post_action
fi


echo "[orientdb] Graph create successfully. Open ${ORIENTDB_URL}"
