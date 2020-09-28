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


Mongodb_atlas_list_user
Mongodb_atlas_create_link

