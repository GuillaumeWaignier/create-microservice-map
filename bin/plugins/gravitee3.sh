#!/bin/bash 


if [ -z "${GRAVITEE3_URL}" ]
then
  exit 0
fi

echo "[Gravitee-3] Run gravitee version 3.x plugin"

function apim_login {
  APIM_TOKEN=`curl -k -s -u "${GRAVITEE3_USER}:${GRAVITEE3_PASS}" -H "Content-Type: application/json;charset=UTF-8" -XPOST ${GRAVITEE3_URL}/management/organizations/${GRAVITEE3_ORGANIZATION:-DEFAULT}/environments/${GRAVITEE3_ENVIRONMENTS:-DEFAULT}/user/login  -d ""`
  APIM_TOKEN=`echo ${APIM_TOKEN} | jq -r .token`

  if [[ ! -z "${APIM_TOKEN}" ]]
  then
    echo "[Gravitee-3] Successfully logging with APIM ${GRAVITEE3_URL}"
  else
    echo "[Gravitee-3] Failed to login to gravitee"
    exit 1
  fi
}


function apim_application {
  echo "[Gravitee-3] GET all applications"
  APIM_APPLICATION=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${GRAVITEE3_URL}/management/organizations/${GRAVITEE3_ORGANIZATION:-DEFAULT}/environments/${GRAVITEE3_ENVIRONMENTS:-DEFAULT}/applications/`
}

function apim_create_link {

  APIM_APPLICATION_LENGTH=`echo "${APIM_APPLICATION}" | jq length`
  echo "[Gravitee-3] There is ${APIM_APPLICATION_LENGTH} applications"

  i=0
  while [ "$i" -lt "${APIM_APPLICATION_LENGTH}" ]
  do
    echo "[Gravitee-3] Collect subscription ${i}/${APIM_APPLICATION_LENGTH}"

    APIM_APPLICATION_I=`echo "${APIM_APPLICATION}" | jq .[$i] `


    APIM_APPLICATION_I_NAME=`echo "${APIM_APPLICATION_I}" | jq -r .name`
    APIM_APPLICATION_I_ID=`echo "${APIM_APPLICATION_I}" | jq -r .id`

    APIM_APPLICATION_I_SUBCRIPTION_FULL=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${GRAVITEE3_URL}/management/organizations/${GRAVITEE3_ORGANIZATION:-DEFAULT}/environments/${GRAVITEE3_ENVIRONMENTS:-DEFAULT}/applications/${APIM_APPLICATION_I_ID}/subscriptions?status=ACCEPTED`
    APIM_APPLICATION_I_SUBCRIPTION=`echo "${APIM_APPLICATION_I_SUBCRIPTION_FULL}" | jq .data`

    APIM_SUBCRIPTION_LENGTH=`echo "${APIM_APPLICATION_I_SUBCRIPTION}" | jq length`
    j=0
    while [ "$j" -lt "${APIM_SUBCRIPTION_LENGTH}" ]
    do
      APIM_SUBCRIPTION_J=`echo "${APIM_APPLICATION_I_SUBCRIPTION}" | jq .[$j]`

      APIM_SUBCRIPTION_J_ID=`echo "${APIM_SUBCRIPTION_J}" | jq .api`
      APIM_SUBCRIPTION_J_NAME=`echo "${APIM_APPLICATION_I_SUBCRIPTION_FULL}" | jq -r ".metadata.${APIM_SUBCRIPTION_J_ID}.name"`

      echo "{\"sourceType\":\"api\",\"sourceName\":\"${APIM_APPLICATION_I_NAME}\",\"targetType\":\"api\",\"targetName\":\"${APIM_SUBCRIPTION_J_NAME}\",\"linkName\":\"call\"}" >> ${OUTPUT_FILE}
      j=$(( j+1 ))
    done

    i=$(( i+1 ))
  done
}


apim_login
apim_application
apim_create_link
