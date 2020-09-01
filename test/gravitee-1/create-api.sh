#! /bin/bash

apt-get update
apt-get install -y curl jq

export APIM_URL="http://management_api:8083"
export APIM_USER="admin"
export APIM_PASS="admin"


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

function create_api {
  RESPONSE=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XPOST ${APIM_URL}/management/apis/import -d "{\"proxy\":{\"endpoints\":[{\"name\":\"default\",\"target\":\"localhost:7070/$1\",\"inherit\":true}],\"context_path\":\"/$1\"},\"pages\":[],\"plans\":[{\"characteristics\":[],\"name\":\"default\",\"description\":\"default\",\"security\":\"API_KEY\",\"validation\":\"AUTO\",\"paths\":{\"/\":[]},\"status\":\"PUBLISHED\"}],\"tags\":[],\"name\":\"api-$1\",\"version\":\"1.0.0\",\"description\":\"$1\",\"lifecycle_state\":\"PUBLISHED\"}"`

  API_ID=`echo "${RESPONSE}" | jq -r .id`
  if [[ ! -z "${API_ID}" ]]
  then
    echo "[Gravitee] Successfully create API $1"
  else
    echo "[Gravitee] Failed to create API $1"
    exit 1
  fi

  curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XPOST ${APIM_URL}/management/apis/${API_ID}/deploy -d ''
  curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XPOST ${APIM_URL}/management/apis/${API_ID}?action=START -d ''

}

function create_application {
  RESPONSE=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XPOST ${APIM_URL}/management/applications -d "{\"name\":\"api-$1\",\"description\":\"$1\"}"`
  APPLICATION_ID=`echo "${RESPONSE}" | jq -r .id`
  if [[ ! -z "${APPLICATION_ID}" ]]
  then
    echo "[Gravitee] Successfully create application $1"
  else
    echo "[Gravitee] Failed to create application $1"
    exit 1
  fi
}

function subscribe {

  RESPONSE=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${APIM_URL}/management/applications`
  APPLICATION_ID=`echo "${RESPONSE}" | jq -r "map(select(.name == \"api-$1\"))[].id"`
  if [[ -z "${APPLICATION_ID}" ]]
  then
    echo "[Gravitee] Application $1 not found"
    exit 1
  fi

  RESPONSE=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${APIM_URL}/management/apis`
  API_ID=`echo "${RESPONSE}" | jq -r "map(select(.name == \"api-$2\"))[].id"`
  if [[ -z "${API_ID}" ]]
  then
    echo "[Gravitee] API $2 not found"
    exit 1
  fi

  RESPONSE=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XGET ${APIM_URL}/management/apis/${API_ID}/plans?status=published&security=api_key`
  PLAN_ID=`echo "${RESPONSE}" | jq -r ".[0].id"`
  if [[ -z "${PLAN_ID}" ]]
  then
    echo "[Gravitee] No plan found for API $2"
    exit 1
  fi


  RESPONSE=`curl -k -s -H "Authorization: Bearer ${APIM_TOKEN}"  -H "Content-Type: application/json;charset=UTF-8" -XPOST "${APIM_URL}/management/apis/${API_ID}/subscriptions?plan=${PLAN_ID}&application=${APPLICATION_ID}"`
  SUBSCRIPTION_ID=`echo "${RESPONSE}" | jq -r ".id"`
  if [[ ! -z "${SUBSCRIPTION_ID}" ]]
  then
    echo "[Gravitee] Successfully subscription for application $1 to api $2"
  else
    echo "[Gravitee] Failed subscription for application $1 to api $2"
    exit 1
  fi

}


apim_login

create_api catalog
create_api site
create_api cart
create_api stock
create_api order
create_api client
create_api sms
create_api mail
create_api delivery

create_application catalog
create_application site
create_application cart
create_application stock
create_application order
create_application client
create_application sms
create_application mail
create_application delivery

subscribe cart catalog
subscribe cart stock
subscribe cart order
subscribe cart client

sleep 50000

