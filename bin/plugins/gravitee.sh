#!/bin/bash 


if [ -z "${APIM_URL}" ]
then
  exit 0
fi

echo "[Gravitee] Run gravitee plugin"


function apim_login {
  APIM_TOKEN=`curl -k -s -u "${APIM_USER}:${APIM_PASS}" -H "Content-Type: application/json;charset=UTF-8" -XPOST ${APIM_URL}/management/user/login  -d ""`
  APIM_TOKEN=`echo ${APIM_TOKEN} | jq -r .token`

  if [[ ! -z "${APIM_TOKEN}" ]]
  then
    echo "[Gravitee] Successfully logging with APIM ${APIM_URL}"
  else
    echo "[Gravitee] Failed to login to gravitee"
    exit 1
  fi
}


function apim_application {
  echo "[Gravitee] GET all applications"
  APIM_APPLICATION=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${APIM_URL}/management/applications/`
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

    APIM_APPLICATION_I_SUBCRIPTION_FULL=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${APIM_URL}/management/applications/${APIM_APPLICATION_I_ID}/subscriptions?status=ACCEPTED`
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

















