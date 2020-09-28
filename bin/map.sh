#! /bin/bash


base_dir=$(dirname $0)

IFS="
"

export OUTPUT_FILE="${base_dir}/links.json"
export NODES_FILE="${base_dir}/nodes.json"
export JSON_FILE="/var/www/html/graph.json"
export ENRICHED_NODES_FILE="/var/www/html/enrichedNodes.csv"


function collect {
  start=`date -u +%FT%T.%3NZ`
  echo "Start collect at ${start}"
  touch ${OUTPUT_FILE}

  for plugin in `ls "${base_dir}/plugins"`
  do
    echo "Try to run plugin ${plugin}"
    {
      ./plugins/${plugin}
    } 2>&1
  done

  end=`date -u +%FT%T.%3NZ`
  echo "End collect at ${end}"
}

function create_node {

  echo "Compute nodes ..."

  for line in `cat "${OUTPUT_FILE}"`
  do
    SOURCE_NAME=`echo "${line}" | jq -r .sourceName`
    SOURCE_TYPE=`echo "${line}" | jq -r .sourceType`
    TARGET_NAME=`echo "${line}" | jq -r .targetName`
    TARGET_TYPE=`echo "${line}" | jq -r .targetType`

    echo "{\"type\":\"${SOURCE_TYPE}\",\"name\":\"${SOURCE_NAME}\"}" >> ${NODES_FILE}
    echo "{\"type\":\"${TARGET_TYPE}\",\"name\":\"${TARGET_NAME}\"}" >> ${NODES_FILE}
  done

  cat "${NODES_FILE}" | sort | uniq > ${NODES_FILE}.uniq
  mv ${NODES_FILE}.uniq ${NODES_FILE}

  echo "There are `cat ${NODES_FILE} | wc -l` nodes"

  echo "Create JSON nodes"
  echo "{\"nodes\":[" >  ${JSON_FILE}

  first=1
  for line in `cat "${NODES_FILE}"`
  do
    if [ "$first" -ne 1 ]
    then
      echo -n "," >> ${JSON_FILE}
    fi

    TYPE=`echo "${line}" | jq -r .type`
    NAME=`echo "${line}" | jq -r .name`

    echo "{\"name\":\"${NAME}\",\"width\":260,\"height\":40, \"type\":\"${TYPE}\" }" >> ${JSON_FILE}
    first=0
  done

  echo "]," >>  ${JSON_FILE}
}

function get_node_number {

   pos=`cat "${NODES_FILE}" | grep -n "^{\"type\":\"${1}\",\"name\":\"${2}\"}$" | cut -d: -f1`

   pos=$(( pos -1 ))
   echo "$pos"
}


function create_link {

  echo "Compute links..."


  echo "\"links\":[" >>  ${JSON_FILE}

  LINKS_NUMBER=`cat ${OUTPUT_FILE} | wc -l`

  echo "There are ${LINKS_NUMBER} links"

  i=1
  for line in `cat "${OUTPUT_FILE}"`
  do

    echo "Create link ${i}/${LINKS_NUMBER}"

    if [ "$i" -ne 1 ]
    then
      echo -n "," >> ${JSON_FILE}
    fi


    SOURCE_NAME=`echo "${line}" | jq -r .sourceName`
    SOURCE_TYPE=`echo "${line}" | jq -r .sourceType`
    TARGET_NAME=`echo "${line}" | jq -r .targetName`
    TARGET_TYPE=`echo "${line}" | jq -r .targetType`
    LINK_NAME=`echo "${line}" | jq -r .linkName`

    source=$(get_node_number "${SOURCE_TYPE}" "${SOURCE_NAME}")
    target=$(get_node_number "${TARGET_TYPE}" "${TARGET_NAME}")

    echo "{\"source\":${source},\"target\":${target}, \"sourceName\":\"${SOURCE_NAME}\", \"sourceType\":\"${SOURCE_TYPE}\", \"targetName\":\"${TARGET_NAME}\", \"targetType\":\"${TARGET_TYPE}\", \"linkName\": \"${LINK_NAME}\"}" >> ${JSON_FILE}
    i=$(( i + 1 ))
  done

  echo "]}" >> ${JSON_FILE}

}

function create_json {
  echo "Create json"

  create_node
  create_link

  echo "End create json"
}

function check_neo4j {
  echo "[neo4J] Check neo4j"

  result=`curl -s -o /dev/null -w "%{http_code}" -u ${NEO4J_USER}:${NEO4J_PASSWORD} -H "Content-Type:application/json;charset=UTF-8" ${NEO4J_URL}/db/${NEO4J_DB:-neo4j}/tx/commit -d "{\"statements\":[{\"statement\":\"MATCH (a) LIMIT 1 RETURN a\"}]}"`

  if [ ${result}  = 200 ]
  then
    echo "[neo4J] Neo4j is up at ${NEO4J_URL}"
  else
    echo "[neo4J] Failed to contact neo4j at ${NEO4J_URL}. Error code is ${result}"
    exit 1
  fi
}

function create_neo4j_graph {
  {
    ./create-neo4j-graph.sh
  } 2>&1
}

if [ ! -z "${NEO4J_URL}" ]
then
  check_neo4j
fi

collect
create_json
create_neo4j_graph

