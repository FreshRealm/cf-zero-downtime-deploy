#!/usr/bin/env bash

APP_ID=$(base64 /dev/urandom | env tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1 )

# Setup error handling for shell script
set -e
set -o pipefail

while getopts n:d:h:s:p:t: option
do
 case "${option}"
 in
 n) APP_NAME=${OPTARG};;
 d) DOMAIN=${OPTARG};;
 h) HEALTH_CHECK_ROUTE=${OPTARG};;
 s) HEALTH_SEARCH_STRING=$OPTARG;;
 p) CF_PUSH_PARAMS=$OPTARG;;
 t) PROTOCOL=$OPTARG;;
 esac
done

# Usage
if [ -z ${APP_NAME} ] || [ -z ${DOMAIN} ]; then
  echo "Cloud Foundry Zero Downtime Deployment Script"
  echo
  echo "Usage:"
  echo "  cf-zero-downtime-deploy.sh -n appname -d domain [-s string-to-check-for-health] [-h health-check-route] [-t https(s)] [-p \"cf push params\"]"
  echo "  -n  application name already deployed to CF"
  echo "  -d  domain i.e. cf-staging.mydomain.com"
  echo "  -s  text to check for on the healh check page"
  echo "  -h  health check route; default is /"
  echo "  -t  protocol for healthcheck; default is https"
  echo "  -p  cf push params"
  echo
  echo "Example:"
  echo "  ./cf-zero-downtime-deploy.sh -n my-awesome-app -d cf-staging.mydomain.com -s \"Status: OK\" -h \"/ping\" -t https -p \"-b my-buildpack -m 256M\""
  exit 1
fi

NEW_APP_NAME="${APP_NAME}-${APP_ID}"
on_fail () {
  FAILED_APP_NAME=${APP_NAME}-${APP_ID}-failed
  echo "DEPLOY FAILED - you may need to check ${FAILED_APP_NAME} and do manual cleanup"
  cf rename ${NEW_APP_NAME} ${FAILED_APP_NAME}
}

trap on_fail ERR

# Deploy new app
cf push ${NEW_APP_NAME} -d ${DOMAIN} ${CF_PUSH_PARAMS}

# Run smoke test (optional)
if [ -n "${HEALTH_SEARCH_STRING}" ]; then
  PROTOCOL=${PROTOCOL:="https"}
  NEW_APP_URL=${NEW_APP_NAME}.${DOMAIN}
  
  CHECK_PORT="443"
  if [ "${PROTOCOL}" == "http" ]; then
    CHECK_PORT="80"
  fi
  APP_HEALTH_CHECK_URL=${NEW_APP_URL}${HEALTH_CHECK_ROUTE:="/"}
  # Address issue with wildcard DNS CNAMEs by re-using current app ip address with the new hostname
  CURRENT_IP=$(nslookup ${APP_NAME}.${DOMAIN} | awk '/^Address: / { print $2 }' | head -n 1)
  grep "${HEALTH_SEARCH_STRING}" <<< `curl -svL  ${PROTOCOL}://${APP_HEALTH_CHECK_URL} --resolve ${NEW_APP_URL}:80:${CURRENT_IP} --resolve ${NEW_APP_URL}:443:${CURRENT_IP}`
fi

# Map route to the new app
cf map-route ${NEW_APP_NAME} ${DOMAIN} -n ${APP_NAME}

# Unmap from the current production
cf unmap-route ${APP_NAME} ${DOMAIN} -n ${APP_NAME}

# Delete current app
cf delete ${APP_NAME} -f

# Rename new app to current
cf rename ${NEW_APP_NAME} ${APP_NAME}

echo "DONE"