#!/bin/bash 


if [ ! -z "${GRAVITEE1_URL}" ]
then
  GRAVITEE_URL=${GRAVITEE1_URL}/management
  echo "[Gravitee] Run gravitee version 1.x plugin"
elif [ ! -z "${GRAVITEE3_URL}" ]
then
  GRAVITEE_URL=${GRAVITEE3_URL}/management/organizations/${GRAVITEE3_ORGANIZATION:-DEFAULT}/environments/${GRAVITEE3_ENVIRONMENTS:-DEFAULT}
  echo "[Gravitee] Run gravitee version 3.x plugin"
else
  exit 0
fi


function apim_login {
  APIM_TOKEN=`curl -k -s -u "${GRAVITEE_USER}:${GRAVITEE_PASS}" -H "Content-Type: application/json;charset=UTF-8" -XPOST ${GRAVITEE_URL}/user/login  -d ""`
  APIM_TOKEN=`echo ${APIM_TOKEN} | jq -r .token`

  if [[ ! -z "${APIM_TOKEN}" ]]
  then
    echo "[Gravitee] Successfully logging with APIM ${GRAVITEE1_URL}"
  else
    echo "[Gravitee] Failed to login to gravitee"
    exit 1
  fi
}


function apim_application {
  echo "[Gravitee] GET all applications"
  APIM_APPLICATION=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${GRAVITEE_URL}/applications/`
}

function apim_create_link {

  APIM_APPLICATION_LENGTH=`echo "${APIM_APPLICATION}" | jq length`
  echo "[Gravitee] There is ${APIM_APPLICATION_LENGTH} applications"

  i=0
  while [ "$i" -lt "${APIM_APPLICATION_LENGTH}" ]
  do
    echo "[Gravitee] Collect subscription ${i}/${APIM_APPLICATION_LENGTH}"

    APIM_APPLICATION_I=`echo "${APIM_APPLICATION}" | jq .[$i] `


    APIM_APPLICATION_I_NAME=`echo "${APIM_APPLICATION_I}" | jq -r .name`
    APIM_APPLICATION_I_ID=`echo "${APIM_APPLICATION_I}" | jq -r .id`

    APIM_APPLICATION_I_SUBCRIPTION_FULL=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${GRAVITEE_URL}/applications/${APIM_APPLICATION_I_ID}/subscriptions?status=ACCEPTED`
    APIM_APPLICATION_I_SUBCRIPTION=`echo "${APIM_APPLICATION_I_SUBCRIPTION_FULL}" | jq .data`

    APIM_SUBCRIPTION_LENGTH=`echo "${APIM_APPLICATION_I_SUBCRIPTION}" | jq length`
    j=0
    while [ "$j" -lt "${APIM_SUBCRIPTION_LENGTH}" ]
    do
      APIM_SUBCRIPTION_J=`echo "${APIM_APPLICATION_I_SUBCRIPTION}" | jq .[$j]`

      APIM_SUBCRIPTION_J_ID=`echo "${APIM_SUBCRIPTION_J}" | jq .api`
      APIM_SUBCRIPTION_J_NAME=`echo "${APIM_APPLICATION_I_SUBCRIPTION_FULL}" | jq -r ".metadata.${APIM_SUBCRIPTION_J_ID}.name"`
      APIM_SUBCRIPTION_J_PLAN_ID=`echo "${APIM_SUBCRIPTION_J}" | jq .plan`
      APIM_SUBCRIPTION_J_PLAN_NAME=`echo "${APIM_APPLICATION_I_SUBCRIPTION_FULL}" | jq -r ".metadata.${APIM_SUBCRIPTION_J_PLAN_ID}.name"`

      echo "{\"sourceType\":\"api\",\"sourceName\":\"${APIM_APPLICATION_I_NAME}\",\"targetType\":\"api\",\"targetName\":\"${APIM_SUBCRIPTION_J_NAME}\",\"linkName\":\"call\", \"linkProperties\":\"plan:\\\\\\\"${APIM_SUBCRIPTION_J_PLAN_NAME}\\\\\\\"\"}" >> ${OUTPUT_FILE}
      j=$(( j+1 ))
    done

    i=$(( i+1 ))
  done
}



function apim_enrichedApi {

  echo "[Gravitee] GET all APIs for enriched data (version, owner, ...)"
  APIM_APIS=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${GRAVITEE_URL}/apis/`
  APIM_APIS_LENGTH=`echo "${APIM_APIS}" | jq length`

  echo "[Gravitee] There is ${APIM_APIS_LENGTH} apis"

  i=0
  while [ "$i" -lt "${APIM_APIS_LENGTH}" ]
  do
    echo "[Gravitee] Collect apis ${i}/${APIM_APIS_LENGTH}"

    APIM_API_I=`echo "${APIM_APIS}" | jq .[$i] `
    APIM_API_I_NAME=`echo "${APIM_API_I}" | jq -r .name`
    APIM_API_I_VERSION=`echo "${APIM_API_I}" | jq -r .version`
    APIM_API_I_OWNER=`echo "${APIM_API_I}" | jq -r .owner.displayName`
    APIM_API_I_CREATED=`echo "${APIM_API_I}" | jq -r .created_at`
    APIM_API_I_UPDATED=`echo "${APIM_API_I}" | jq -r .updated_at`
    APIM_API_I_VISIBILITY=`echo "${APIM_API_I}" | jq -r .visibility`
    APIM_API_I_LIFECYCLE_STATE=`echo "${APIM_API_I}" | jq -r .lifecycle_state`
    APIM_API_I_STATE=`echo "${APIM_API_I}" | jq -r .state`

    echo "api;${APIM_API_I_NAME};{version:\\\"${APIM_API_I_VERSION}\\\",owner:\\\"${APIM_API_I_OWNER}\\\",createdAt:datetime({epochMillis:${APIM_API_I_CREATED}}),updatedAt:datetime({epochMillis:${APIM_API_I_UPDATED}}),visibility:\\\"${APIM_API_I_VISIBILITY}\\\",lifecycleState:\\\"${APIM_API_I_LIFECYCLE_STATE}\\\",state:\\\"${APIM_API_I_STATE}\\\"}" >> ${ENRICHED_NODES_FILE}
    i=$(( i+1 ))
  done
}


apim_login
apim_application
apim_create_link

apim_enrichedApi
