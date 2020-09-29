#!/bin/bash


if [ -z "${MONGODB_ATLAS_URL}" ]
then
  exit 0
fi

echo "[MongoDBAtlas] Run MongoDB Atlas plugin"

function Mongodb_atlas_list_user {
  echo "[MongoDBAtlas] Get all Users"
  MONGO_USERS=`curl -s -u "${MONGODB_ATLAS_USER}:${MONGODB_ATLAS_PASS}" --digest -XGET ${MONGODB_ATLAS_URL}/api/atlas/v1.0/groups/${MONGODB_ATLAS_PROJECT_ID}/databaseUsers?itemsPerPage=499`
}

function Mongodb_atlas_create_read_link_any {
  k=0
  while [ "$k" -lt "${MONGO_DATABASES_COUNT}" ]
  do
    NAME=`echo "${MONGO_DATABASES}" | jq -r ".results[${k}].databaseName"`
    echo "{\"sourceType\":\"mongo\",\"sourceName\":\"${NAME}\",\"targetType\":\"app\",\"targetName\":\"${1}\",\"linkName\":\"read\",\"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
    k=$(( k+1 ))
  done
}


function collect_mongo_user {

  MONGO_USER_NAME=`echo "${MONGO_USER}" | jq -r .username`
  MONGO_USER_ROLES_NUMBER=`echo "${MONGO_USER}" | jq ".roles|length"`

  j=0
  while [ "$j" -lt "${MONGO_USER_ROLES_NUMBER}" ]
  do
    MONGO_USER_ROLE=`echo "${MONGO_USER}" | jq ".roles[${j}]"`
    MONGO_USER_DB=`echo "${MONGO_USER_ROLE}" | jq -r ".databaseName"`
    MONGO_USER_RIGHT=`echo "${MONGO_USER_ROLE}" | jq -r ".roleName"`

    if [ "${MONGO_USER_RIGHT}" == "read" ]
    then
      echo "{\"sourceType\":\"mongo\",\"sourceName\":\"${MONGO_USER_DB}\",\"targetType\":\"app\",\"targetName\":\"${MONGO_USER_NAME}\",\"linkName\":\"read\",\"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
    elif [ "${MONGO_USER_RIGHT=}" == "readWrite" ]
    then
      echo "{\"sourceType\":\"mongo\",\"sourceName\":\"${MONGO_USER_DB}\",\"targetType\":\"app\",\"targetName\":\"${MONGO_USER_NAME}\",\"linkName\":\"read\",\"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
      echo "{\"sourceType\":\"app\",\"sourceName\":\"${MONGO_USER_NAME}\",\"targetType\":\"mongo\",\"targetName\":\"${MONGO_USER_DB}\",\"linkName\":\"write\",\"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
    elif [ "${MONGO_USER_RIGHT=}" == "readAnyDatabase" ]
    then
      Mongodb_atlas_create_read_link_any "${MONGO_USER_NAME}"
    else
      echo "[MongoDBAtlas] Role ${MONGO_USER_RIGHT} ignored for user ${MONGO_USER_NAME}"
    fi
    j=$(( j+1 ))
  done
}


function Mongodb_atlas_create_link {

  MONGO_USERS_NUMBER=`echo "${MONGO_USERS}" | jq ".results|length"`

  echo "[MongoDBAtlas] There is ${MONGO_USERS_NUMBER} User"

  i=0
  while [ "$i" -lt "${MONGO_USERS_NUMBER}" ]
  do

    echo "[MongoDBAtlas] Collect user ${i}/${MONGO_USERS_NUMBER}"

    MONGO_USER=`echo "${MONGO_USERS}" | jq .results[$i]`

    collect_mongo_user

    i=$(( i+1 ))
  done
}

function Mongodb_atlas_list_database {
  echo "[MongoDBAtlas] Get all Databases"
  MONGO_ALL_PROCESS=`curl -s -u "${MONGODB_ATLAS_USER}:${MONGODB_ATLAS_PASS}" --digest -XGET ${MONGODB_ATLAS_URL}/api/atlas/v1.0/groups/${MONGODB_ATLAS_PROJECT_ID}/processes`
  MONGO_PROCESS=`echo "${MONGO_ALL_PROCESS}" | jq -r ".results[0].id"`

  MONGO_DATABASES=`curl -s -u "${MONGODB_ATLAS_USER}:${MONGODB_ATLAS_PASS}" --digest -XGET ${MONGODB_ATLAS_URL}/api/atlas/v1.0/groups/${MONGODB_ATLAS_PROJECT_ID}/processes/${MONGO_PROCESS}/databases`
  MONGO_DATABASES_COUNT=`echo "${MONGO_DATABASES}" | jq ".totalCount"`
}


function Mongodb_atlas_enrich_node {

  echo "[MongoDBAtlas] There is ${MONGO_DATABASES_COUNT} databases (enriche)"

  k=0
  while [ "$k" -lt "${MONGO_DATABASES_COUNT}" ]
  do

    echo "[MongoDBAtlas] Collect databases ${k}/${MONGO_DATABASES_COUNT}"

    NAME=`echo "${MONGO_DATABASES}" | jq -r ".results[${k}].databaseName"`
    MONGO_DATABASES_INFO=`curl -s -u "${MONGODB_ATLAS_USER}:${MONGODB_ATLAS_PASS}" --digest -XGET ${MONGODB_ATLAS_URL}/api/atlas/v1.0/groups/${MONGODB_ATLAS_PROJECT_ID}/processes/${MONGO_PROCESS}/databases/${NAME}/measurements?granularity=PT5M\&period=PT10M`

    MONGO_COLLECTION_COUNT=`echo "${MONGO_DATABASES_INFO}" | jq ".measurements | map(select(.name == \"DATABASE_COLLECTION_COUNT\" ))[].dataPoints[0].value"`
    MONGO_INDEX_COUNT=`echo "${MONGO_DATABASES_INFO}" | jq ".measurements | map(select(.name == \"DATABASE_INDEX_COUNT\" ))[].dataPoints[0].value"`
    MONGO_OBJECT_COUNT=`echo "${MONGO_DATABASES_INFO}" | jq ".measurements | map(select(.name == \"DATABASE_OBJECT_COUNT\" ))[].dataPoints[0].value"`
    MONGO_INDEX_SIZE=`echo "${MONGO_DATABASES_INFO}" | jq ".measurements | map(select(.name == \"DATABASE_INDEX_SIZE\" ))[].dataPoints[0].value"`
    MONGO_DATA_SIZE=`echo "${MONGO_DATABASES_INFO}" | jq ".measurements | map(select(.name == \"DATABASE_DATA_SIZE\" ))[].dataPoints[0].value"`

    echo "mongo;${NAME};{indexCount:${MONGO_INDEX_COUNT},indexSize:${MONGO_INDEX_SIZE},docCount:${MONGO_OBJECT_COUNT},docSize:${MONGO_DATA_SIZE},collectionCount:${MONGO_COLLECTION_COUNT}}" >> ${ENRICHED_NODES_FILE}
    k=$(( k+1 ))
  done
}



Mongodb_atlas_list_database
Mongodb_atlas_list_user
Mongodb_atlas_create_link
Mongodb_atlas_enrich_node

