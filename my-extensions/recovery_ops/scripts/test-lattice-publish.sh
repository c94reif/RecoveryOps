#!/usr/bin/env bash

read -p "Sandbox Token (Bearer): " SANDBOX_TOKEN
read -p "Environment Token (Bearer): " ENV_TOKEN
read -p "Base URL (e.g. lattice-1qt68c.env.sandboxes.developer.anduril.com): " BASE_URL

if [[ ! "$BASE_URL" =~ ^https?:// ]]; then
  BASE_URL="https://${BASE_URL}"
fi
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
EXPIRY=$(date -u -d "+1 day" +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -v+1d +"%Y-%m-%dT%H:%M:%S.000Z")

curl -v -X PUT "${BASE_URL}/api/v1/entities" \
  -H 'Content-Type: application/json' \
  -H "anduril-sandbox-authorization: Bearer ${SANDBOX_TOKEN}" \
  -H "Authorization: Bearer ${ENV_TOKEN}" \
  -d "{
    \"entityId\": \"test-curl-$(date +%s)\",
    \"aliases\": {\"name\": \"CURL-TEST - Tow Bar Recovery\"},
    \"createdTime\": \"${NOW}\",
    \"expiryTime\": \"${EXPIRY}\",
    \"milView\": {\"disposition\": \"DISPOSITION_FRIENDLY\"},
    \"location\": {\"position\": {\"latitudeDegrees\": 37.4219983, \"longitudeDegrees\": -122.084}},
    \"ontology\": {\"template\": \"TEMPLATE_ASSET\"},
    \"provenance\": {\"integrationName\": \"recovery_ops\", \"dataType\": \"RECOVERY_REQUEST\", \"sourceUpdateTime\": \"${NOW}\"},
    \"navigatorLocation\": null,
    \"routeGeometry\": null,
    \"isLive\": true
  }"
