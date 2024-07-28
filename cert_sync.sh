#!/bin/bash

DEBUG=false
DOMAIN="tekdebt.com"
WILDCARD_CERT_LOCATION="/etc/ssl/certs/wildcard.${DOMAIN}.crt"
WILDCARD_KEY_LOCATION="/etc/ssl/private/wildcard.${DOMAIN}.key"
OLD_SSL_MD5="$(cat ${WILDCARD_CERT_LOCATION} | openssl md5)"
TRAEFIK_PODNAME="$(kubectl get pods -n traefik --no-headers | awk '{ print $1 }')"
NEW_SSL_MD5="$(kubectl exec "$TRAEFIK_PODNAME" -- cat /data/acme.json | jq -r '.cloudflare.Certificates[] | select (.domain.main=="${DOMAIN}")' | jq -r .certificate | base64 -d | openssl md5)"

function run_sync() {
  kubectl exec "$TRAEFIK_PODNAME" -- cat /data/acme.json | jq -r ".cloudflare.Certificates[] | select (.domain.main==\"${DOMAIN}\")" | jq -r .certificate | base64 -d > $WILDCARD_CERT_LOCATION
  kubectl exec "$TRAEFIK_PODNAME" -- cat /data/acme.json | jq -r ".cloudflare.Certificates[] | select (.domain.main==\"${DOMAIN}\")" | jq -r .key | base64 -d > $WILDCARD_KEY_LOCATION
}

if ! test -f $WILDCARD_CERT_LOCATION
then
  [ "$DEBUG" = true ] && echo "No file found, running sync"
  run_sync
fi

if ! test -s $WILDCARD_CERT_LOCATION
then
  [ "$DEBUG" = true ] && echo "Empty cert found, running sync"
  run_sync
fi

if [ "$NEW_SSL_MD5" == "$OLD_SSL_MD5" ]
then
  [ "$DEBUG" = true ] && echo "Certs up-to-date!"
  exit 0
else
  run_sync
fi
