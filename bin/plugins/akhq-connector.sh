#!/bin/bash


if [ -z "${AKHQ_CONNECT_CLUSTER}" ]
then
  exit 0
fi

echo "[AKHQ] Run akhq connector plugin"


function akhq_list_connector {
  echo "[AKHQ] Get all connector"
  AKHQ_CONNECTOR=`curl -s -u "${AKHQ_LOGIN}:${AKHQ:PASS}" -H "Content-Type: application/json;charset=UTF-8" -XGET ${AKHQ_URL}/api/${AKHQ_CLUSTER}/connect/${AKHQ_CONNECT_CLUSTER}`
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

    case ${AKHQ_CONNECTOR_I_CLASS} in
    "com.mongodb.kafka.connect.MongoSinkConnector")
      AKHQ_CONNECTOR_I_DATABASE=`echo "${AKHQ_CONNECTOR_I}" | jq -r .configs.database`
      echo "{\"sourceType\":\"topic\",\"sourceName\":\"${AKHQ_CONNECTOR_I_TOPIC}\",\"targetType\":\"api\",\"targetName\":\"${AKHQ_CONNECTOR_I_NAME}\",\"linkName\":\"consume\", \"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
      echo "{\"sourceType\":\"api\",\"sourceName\":\"${AKHQ_CONNECTOR_I_NAME}\",\"targetType\":\"mongo\",\"targetName\":\"${AKHQ_CONNECTOR_I_DATABASE}\",\"linkName\":\"write\", \"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
      echo "api;${AKHQ_CONNECTOR_I_NAME};{label:\\\"kconnect\\\"}" >> ${ENRICHED_NODES_FILE}
      ;;

    *)
      echo "Ignoring connector ${AKHQ_CONNECTOR_I_NAME} with class ${AKHQ_CONNECTOR_I_CLASS}"
      ;;
    esac

    i=$(( i+1 ))
  done

}


akhq_list_connector
akhq_create_link
