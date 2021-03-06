#!/bin/bash


if [ -z "${AKHQ_CONNECT_CLUSTER}" ]
then
  exit 0
fi

echo "[AKHQ] Run akhq connector plugin"


function akhq_list_connector {
  echo "[AKHQ] Get all connectors"
  AKHQ_CONNECTOR=`curl -s -u "${AKHQ_USER}:${AKHQ_PASS}" -H "Content-Type: application/json;charset=UTF-8" -XGET ${AKHQ_URL}/api/${AKHQ_CLUSTER}/connect/${AKHQ_CONNECT_CLUSTER}`
}

function akhq_create_link {

  AKHQ_CONNECTOR_LENGTH=`echo "${AKHQ_CONNECTOR}" | jq length`

  echo "[AKHQ] There is ${AKHQ_CONNECTOR_LENGTH} connectors"

  i=0
  while [ "$i" -lt "${AKHQ_CONNECTOR_LENGTH}" ]
  do

    echo "[AKHQ] Collect connector ${i}/${AKHQ_CONNECTOR_LENGTH}"

    AKHQ_CONNECTOR_I=`echo "${AKHQ_CONNECTOR}" | jq .[$i]`


    AKHQ_CONNECTOR_I_NAME=`echo "${AKHQ_CONNECTOR_I}" | jq -r .name`
    AKHQ_CONNECTOR_I_CLASS=`echo "${AKHQ_CONNECTOR_I}" | jq -r '.configs["connector.class"]'`
    AKHQ_CONNECTOR_I_NAME=`echo "${AKHQ_CONNECTOR_I}" | jq -r .name`
    AKHQ_CONNECTOR_I_TOPIC=`echo "${AKHQ_CONNECTOR_I}" | jq -r .configs.topics`

    AKHQ_CONNECTOR_I_TASKMAX=`echo "${AKHQ_CONNECTOR_I}" | jq -r '.configs["tasks.max"]'`
    AKHQ_CONNECTOR_I_ERROR_TOLERANCE=`echo "${AKHQ_CONNECTOR_I}" | jq -r '.configs["errors.tolerance"]'`


    case ${AKHQ_CONNECTOR_I_CLASS} in
    "com.mongodb.kafka.connect.MongoSinkConnector")
      AKHQ_CONNECTOR_I_DATABASE=`echo "${AKHQ_CONNECTOR_I}" | jq -r .configs.database`
      echo "{\"sourceType\":\"topic\",\"sourceName\":\"${AKHQ_CONNECTOR_I_TOPIC}\",\"targetType\":\"app\",\"targetName\":\"${AKHQ_CONNECTOR_I_NAME}\",\"linkName\":\"consume\", \"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
      echo "{\"sourceType\":\"app\",\"sourceName\":\"${AKHQ_CONNECTOR_I_NAME}\",\"targetType\":\"mongo\",\"targetName\":\"${AKHQ_CONNECTOR_I_DATABASE}\",\"linkName\":\"write\", \"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
      echo "app;${AKHQ_CONNECTOR_I_NAME};{errorsTolerance:\\\"${AKHQ_CONNECTOR_I_ERROR_TOLERANCE}\\\",taskMax:${AKHQ_CONNECTOR_I_TASKMAX},class:\\\"${AKHQ_CONNECTOR_I_CLASS}\\\",label:\\\"kconnect\\\"}" >> ${ENRICHED_NODES_FILE}
      ;;

    *)
      echo "[AKHQ] Ignoring connector ${AKHQ_CONNECTOR_I_NAME} with class ${AKHQ_CONNECTOR_I_CLASS}"
      echo "app;${AKHQ_CONNECTOR_I_NAME};{errorsTolerance:\\\"${AKHQ_CONNECTOR_I_ERROR_TOLERANCE}\\\",taskMax:${AKHQ_CONNECTOR_I_TASKMAX},class:\\\"${AKHQ_CONNECTOR_I_CLASS}\\\",label:\\\"kconnect\\\"}" >> ${ENRICHED_NODES_FILE}
      ;;
    esac

    i=$(( i+1 ))
  done

}


akhq_list_connector
akhq_create_link
