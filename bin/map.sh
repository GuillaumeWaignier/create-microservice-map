#! /bin/bash


base_dir=$(dirname $0)

IFS="
"

export OUTPUT_FILE="${base_dir}/links.cvs"
NODES_FILE="${base_dir}/nodes.txt" 
JSON_FILE="/var/www/html/graph.json"


# config for gravitee
#export APIM_USER="admin"
#export APIM_PASS="admin"
#export APIM_URL="http://localhost:8083"

# Config for kafka
#export AKHQ_URL="http://localhost:8080"
#export AKHQ_USER="admin"
#export AKHQ_PASSWORD="admin"
#export AKHQ_CLUSTER="docker-kafka-server"


function collect {
  start=`date -u +%FT%T.%3NZ`
  echo "Start collect at ${start}"
  echo "source-type_source-name,destination-type_destination-name" > ${OUTPUT_FILE}

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

  cat "${OUTPUT_FILE}" | tail -n +2 | cut -d, -f1 > ${NODES_FILE}
  cat "${OUTPUT_FILE}" | tail -n +2 | cut -d, -f2 >> ${NODES_FILE}
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
    echo "{\"name\":\"${line}\",\"width\":260,\"height\":40}" >> ${JSON_FILE}
    first=0
  done

  echo "]," >>  ${JSON_FILE}
}

function get_node_number {

   pos=`cat "${NODES_FILE}" | grep -n "^${1}$" | cut -d: -f1`

   pos=$(( pos -1 ))
   echo "$pos"
}


function create_link {

  echo "Compute links..."


  echo "\"links\":[" >>  ${JSON_FILE}

  LINKS_NUMBER=`cat ${OUTPUT_FILE} | wc -l`

  i=1
  for line in `cat "${OUTPUT_FILE}" | tail -n +2`
  do

    echo "Create link ${i}/${LINKS_NUMBER}"

    if [ "$i" -ne 1 ]
    then
      echo -n "," >> ${JSON_FILE}
    fi


    source_name=`echo "${line}" | cut -d, -f1`
    target_name=`echo "${line}" | cut -d, -f2`

    source=$(get_node_number "$source_name")
    target=$(get_node_number "$target_name")

    echo "{\"source\":${source},\"target\":${target}}" >> ${JSON_FILE}
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



collect
create_json
