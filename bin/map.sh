#! /bin/bash


base_dir=$(dirname $0)

IFS="
"

export OUTPUT_FILE="${base_dir}/links.json"
export NODES_FILE="${base_dir}/nodes.json"
export ENRICHED_NODES_FILE="${base_dir}/enrichedNodes.csv"

function clean {
  echo -n "" > ${OUTPUT_FILE}
  echo -n "" > ${NODES_FILE}
  echo -n "" > ${ENRICHED_NODES_FILE}
}

function collect {
  start=`date -u +%FT%T.%3NZ`
  echo "Start collect at ${start}"

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
}

function get_node_number {

   pos=`cat "${NODES_FILE}" | grep -n "^{\"type\":\"${1}\",\"name\":\"${2}\"}$" | cut -d: -f1`

   pos=$(( pos -1 ))
   echo "$pos"
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


clean
collect
create_node
create_neo4j_graph

