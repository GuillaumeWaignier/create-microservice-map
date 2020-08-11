#!/bin/bash


if [ -z "${AKHQ_URL}" ]
then
  exit 0
fi

echo "Run akhq plugin"


function akhq_list_acl {
  AKHQ_ACL=`curl -s -u "${AKHQ_LOGIN}:${AKHQ:PASS}" -H "Content-Type: application/json;charset=UTF-8" -XGET ${AKHQ_URL}/api/${AKHQ_CLUSTER}/acls`
}

function akhq_create_link {

  AKHQ_ACL_LENGTH=`echo "${AKHQ_ACL}" | jq length`

  i=0
  while [ "$i" -lt "${AKHQ_ACL_LENGTH}" ]
  do
    AKHQ_ACL_I=`echo "${AKHQ_ACL}" | jq .[$i]`


    AKHQ_ACL_I_NAME=`echo "${AKHQ_ACL_I}" | jq -r .principal | cut -d: -f2 `

    AKHQ_ACL_I_LIST=`echo "${AKHQ_ACL_I}" | jq .acls`
    AKHQ_ACL_I_LENGTH=`echo "${AKHQ_ACL_I_LIST}" | jq length`

    j=0
    while [ "$j" -lt "${AKHQ_ACL_I_LENGTH}" ]
    do
      AKHQ_RIGHT_J=`echo "${AKHQ_ACL_I_LIST}" | jq .[$j]`
      
      AKHQ_RIGHT_RESOURCE_TYPE=`echo "${AKHQ_RIGHT_J}" | jq -r .resource.resourceType`
      AKHQ_RIGHT_OPERATION=`echo "${AKHQ_RIGHT_J}" | jq -r .operation.operation`

      if [ "${AKHQ_RIGHT_RESOURCE_TYPE}" == "TOPIC" ]
      then
        AKHQ_RIGHT_TOPIC=`echo "${AKHQ_RIGHT_J}" | jq -r .resource.name`
        if [ "${AKHQ_RIGHT_OPERATION=}" == "READ" ]
        then
          echo "topic_${AKHQ_RIGHT_TOPIC},api_${AKHQ_ACL_I_NAME}" >> ${OUTPUT_FILE}
        elif [ "${AKHQ_RIGHT_OPERATION=}" == "WRITE" ]
        then
          echo "api_${AKHQ_ACL_I_NAME},topic_${AKHQ_RIGHT_TOPIC}" >> ${OUTPUT_FILE}
        fi
      fi
      j=$(( j+1 ))
    done

    i=$(( i+1 ))
  done

}


akhq_list_acl
echo "$AKHQ_ACL"

akhq_create_link
