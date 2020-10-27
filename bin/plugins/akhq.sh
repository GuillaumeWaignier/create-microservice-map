#!/bin/bash

IFS="
"

if [ -z "${AKHQ_URL}" ]
then
  exit 0
fi

echo "[AKHQ] Run akhq plugin"


function akhq_list_acl {
  echo "[AKHQ] Get all ACLs"
  AKHQ_ACL=`curl -k -s -u "${AKHQ_USER}:${AKHQ_PASS}" -H "Content-Type: application/json;charset=UTF-8" -XGET ${AKHQ_URL}/api/${AKHQ_CLUSTER}/acls`
}


function akhq_create_link_inside_file {
  #$1 = AKHQ_RIGHT_OPERATION
  #$2 = AKHQ_RIGHT_TOPIC
  #$3 = AKHQ_ACL_I_NAME
  if [ "${1=}" == "READ" ]
      then
        echo "{\"sourceType\":\"topic\",\"sourceName\":\"${2}\",\"targetType\":\"app\",\"targetName\":\"${3}\",\"linkName\":\"consume\",\"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
      elif [ "${1=}" == "WRITE" ]
      then
        echo "{\"sourceType\":\"app\",\"sourceName\":\"${3}\",\"targetType\":\"topic\",\"targetName\":\"${2}\",\"linkName\":\"produce\",\"linkProperties\":\"\"}" >> ${OUTPUT_FILE}
      fi
}


function akhq_create_prefixed_link {
  #$1 = AKHQ_RIGHT_OPERATION
  #$2 = AKHQ_RIGHT_TOPIC
  #$3 = AKHQ_ACL_I_NAME
  AKHQ_TOPICS_ALL_PREXIXED=`cat "${ENRICHED_NODES_FILE}" | grep "^topic;${2}"`

  for line in `echo "${AKHQ_TOPICS_ALL_PREXIXED}"`
  do
      NAME=`echo "${line}" | cut -d';' -f2`
      akhq_create_link_inside_file "${1}" "${NAME}" "${3}"
 done
}

function akhq_create_star_link {
  #$1 = AKHQ_RIGHT_OPERATION
  #$2 = AKHQ_RIGHT_TOPIC
  #$3 = AKHQ_ACL_I_NAME
  AKHQ_TOPICS_ALL_PREXIXED=`cat "${ENRICHED_NODES_FILE}" | grep "^topic;"`

  for line in `echo "${AKHQ_TOPICS_ALL_PREXIXED}"`
  do
      NAME=`echo "${line}" | cut -d';' -f2`
      akhq_create_link_inside_file "${1}" "${NAME}" "${3}"
 done
}


function akhq_create_link {

  AKHQ_ACL_LENGTH=`echo "${AKHQ_ACL}" | jq length`

  echo "[AKHQ] There is ${AKHQ_ACL_LENGTH} User ID"


  i=0
  while [ "$i" -lt "${AKHQ_ACL_LENGTH}" ]
  do

    echo "[AKHQ] Collect acl ${i}/${AKHQ_ACL_LENGTH}"

    AKHQ_ACL_I=`echo "${AKHQ_ACL}" | jq .[$i]`


    AKHQ_ACL_I_NAME=`echo "${AKHQ_ACL_I}" | jq -r .principal | cut -d: -f2 `

    AKHQ_ACL_I_LIST=`echo "${AKHQ_ACL_I}" | jq .acls`
    AKHQ_ACL_I_LENGTH=`echo "${AKHQ_ACL_I_LIST}" | jq length`

    j=0
    while [ "$j" -lt "${AKHQ_ACL_I_LENGTH}" ]
    do
      AKHQ_RIGHT_J=`echo "${AKHQ_ACL_I_LIST}" | jq .[$j]`
      
      AKHQ_RIGHT_RESOURCE_TYPE=`echo "${AKHQ_RIGHT_J}" | jq -r .resource.resourceType`
      AKHQ_RIGHT_PATTERN_TYPE=`echo "${AKHQ_RIGHT_J}" | jq -r .resource.patternType`
      AKHQ_RIGHT_OPERATION=`echo "${AKHQ_RIGHT_J}" | jq -r .operation.operation`
      AKHQ_RIGHT_TOPIC=`echo "${AKHQ_RIGHT_J}" | jq -r .resource.name`


      if [ "${AKHQ_RIGHT_RESOURCE_TYPE}" == "TOPIC" ] && [ "${AKHQ_RIGHT_PATTERN_TYPE}" == "LITERAL" ] && [ "${AKHQ_RIGHT_TOPIC}" == "*" ]
      then
        akhq_create_star_link "${AKHQ_RIGHT_OPERATION=}" "${AKHQ_RIGHT_TOPIC}" "${AKHQ_ACL_I_NAME}"
      elif [ "${AKHQ_RIGHT_RESOURCE_TYPE}" == "TOPIC" ] && [ "${AKHQ_RIGHT_PATTERN_TYPE}" == "LITERAL" ]
      then
        akhq_create_link_inside_file "${AKHQ_RIGHT_OPERATION=}" "${AKHQ_RIGHT_TOPIC}" "${AKHQ_ACL_I_NAME}"
      elif [ "${AKHQ_RIGHT_RESOURCE_TYPE}" == "TOPIC" ] && [ "${AKHQ_RIGHT_PATTERN_TYPE}" == "PREFIXED" ]
      then
        akhq_create_prefixed_link "${AKHQ_RIGHT_OPERATION=}" "${AKHQ_RIGHT_TOPIC}" "${AKHQ_ACL_I_NAME}"
      fi

      j=$(( j+1 ))
    done

    i=$(( i+1 ))
  done

}

function akhq_process_topic {
    echo "[AKHQ] Collect topic ${i}/${nbTopics}"

    TOPIC_NAME=`echo "${TOPIC}" | jq -r .name`

    CONFIG_TOPIC=`curl -k -s -u "${AKHQ_USER}:${AKHQ_PASS}" -H "Content-Type: application/json;charset=UTF-8" -XGET "${AKHQ_URL}/api/${AKHQ_CLUSTER}/topic/${TOPIC_NAME}/configs"`

    PARTITIONS=`echo "${TOPIC}" | jq ".partitions|length"`
    REPLICATION=`echo "${TOPIC}" | jq ".replicaCount"`
    CLEANUP=`echo "${CONFIG_TOPIC}" | jq -r "map(select(.name == \"cleanup.policy\"))[].value"`
    MIN_INSYNC_REPLICAS=`echo "${CONFIG_TOPIC}" | jq -r "map(select(.name == \"min.insync.replicas\"))[].value"`
    RETENTION_MS=`echo "${CONFIG_TOPIC}" | jq -r "map(select(.name == \"retention.ms\"))[].value"`
    RETENTION_BYTE=`echo "${CONFIG_TOPIC}" | jq -r "map(select(.name == \"retention.bytes\"))[].value"`

    LINE="topic;${TOPIC_NAME};{partition:${PARTITIONS},replication:${REPLICATION},minInsyncReplica:${MIN_INSYNC_REPLICAS},cleanup:\\\"${CLEANUP}\\\""

    if [ "${CLEANUP}" = "delete" ]
    then
      echo "${LINE},retentionMs:${RETENTION_MS},retentionBytes:${RETENTION_BYTE}}" >> ${ENRICHED_NODES_FILE}
    else
      echo "${LINE}}" >> ${ENRICHED_NODES_FILE}
    fi

}

function akhq_enriche_node {
  echo "[AKHQ] Enriche Node"

  page=1
  i=0
  LIST_TOPIC=`curl -k -s -u "${AKHQ_USER}:${AKHQ_PASS}" -H "Content-Type: application/json;charset=UTF-8" -XGET "${AKHQ_URL}/api/${AKHQ_CLUSTER}/topic?show=ALL&page=${page}"`
  nbTopics=`echo "${LIST_TOPIC}" | jq .total`

  echo "[AKHQ] There are ${nbTopics} topics"

   while [ "$i" -lt "${nbTopics}" ]
    do
      LIST_TOPIC=`curl -k -s -u "${AKHQ_USER}:${AKHQ_PASS}" -H "Content-Type: application/json;charset=UTF-8" -XGET "${AKHQ_URL}/api/${AKHQ_CLUSTER}/topic?show=ALL&page=${page}"`
      NB_TOPIC_PER_PAGE=`echo "${LIST_TOPIC}" | jq ".results | length"`
      j=0
      while [ "$j" -lt "${NB_TOPIC_PER_PAGE}" ]
      do
        TOPIC=`echo "${LIST_TOPIC}" | jq ".results[${j}]"`
        akhq_process_topic
        i=$(( i+1 ))
        j=$(( j+1 ))
      done
      page=$(( page+1 ))
  done
}


akhq_enriche_node

akhq_list_acl
akhq_create_link

