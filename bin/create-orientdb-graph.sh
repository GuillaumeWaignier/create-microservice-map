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

  for class in "api" "mongo" "topic" "app"
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

#MOVE VERTEX (SELECT FROM `Entity`) TO CLASS:StageOneEntity

  echo "[orientdb] Rename node label"
  RESULT=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/db/${ORIENTDB_DB}/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (n:app) WHERE n.label IS NOT NULL WITH DISTINCT n.label AS label RETURN label\"}]}"`

  LABELS_TO_RENAME=`echo "${RESULT}" | jq ".results[0].data"`
  LABELS_TO_RENAME_COUNT=`echo "${LABELS_TO_RENAME}" | jq length`

  i=0
  while [ "$i" -lt "${LABELS_TO_RENAME_COUNT}" ]
  do
    LABEL_TO_RENAME=`echo "${LABELS_TO_RENAME}" | jq -r ".[$i].row[]"`
    echo "[orientdb] Rename label ${LABEL_TO_RENAME} : ${i}/${LABELS_TO_RENAME_COUNT}"

    RES=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/db/${ORIENTDB_DB}/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (n:app{label:'${LABEL_TO_RENAME}'}) WITH COLLECT(n) AS nodes CALL apoc.refactor.rename.label('app','${LABEL_TO_RENAME}',nodes) yield errorMessages AS eMessages RETURN eMessages\"}]}"`
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
    RES=`curl -XPOST -s -u "${ORIENTDB_USER}:${ORIENTDB_PASSWORD}" -H "Content-Type:application/json;charset=UTF-8" ${ORIENTDB_URL}/db/${ORIENTDB_DB}/tx/commit -d "{\"statements\":[{\"statement\":\"${line}\"}]}"`
    displayOrientdbResult "${RES}" "${JSON}"
    sleep 10
    i=$(( i+1 ))
  done

}


echo "Create orientdb graph"

clear_orientdb
create_class
create_node
create_link
#rename_node_label
#if [ ! -z "${ORIENTDB_POST_ACTION_FILE}" ]
#then
#  execute_post_action
#fi


echo "[orientdb] Graph create successfully. Open ${ORIENTDB_URL}"
