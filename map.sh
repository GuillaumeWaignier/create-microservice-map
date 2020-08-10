#! /bin/bash


start=`date -u +%FT%T.%3NZ`
echo "Start collect at ${start}"


base_dir=$(dirname $0)


# config for gravitee
#export APIM_USER="admin"
#export APIM_PASS="admin"
#export APIM_URL="http://localhost:8083"

# Config for kafka
export AKHQ_URL="http://localhost:8080"
export AKHQ_USER="admin"
export AKHQ_PASSWORD="admin"
export AKHQ_CLUSTER="docker-kafka-server"


export OUTPUT_FILE="${base_dir}/map.txt"



echo "source-type,source-name,destination-type,destination-name" > ${OUTPUT_FILE}


for plugin in `ls plugins`
do
  echo "Try to run plugin ${plugin}"
  echo `./plugins/${plugin}`
done

end=`date -u +%FT%T.%3NZ`
echo "End collect at ${end}"
