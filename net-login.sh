#!/usr/bin/env bash
# captive portal auto-login script for Vodafone Hotspot
# Copyright (c) 2021 Sven Grunewaldt (strayer@olle-orks.org)
# Copyright (c) 2022 Jacob Ludvigsen (jacob@strandmoa.no)
# This is free software, licensed under the GNU General Public License v3.

export LC_ALL=C
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
set -euo pipefail

trm_useragent="Mozilla/5.0 (Linux x86_64; rv:95.0) Gecko/20100101 Firefox/95.0"
trm_maxwait="5000"
trm_neededprofile="6"
trm_vodafonedns="10.175.177.132"
trm_resolve="hotspot.vodafone.de:443:10.175.177.131"
SESSIONFILE="/tmp/bayernhotspot.session"

if ping -q -c1 "${trm_vodafonedns}" &>/dev/null; then
    network_status=online
else
   network_status=offline
fi

if [ "$network_status" = "offline" ]; then
  curl -v --resolve "$trm_resolve" https://hotspot.vodafone.de/api/v4/session \
    --user-agent "${trm_useragent}" --silent \
    --connect-timeout "${trm_maxwait}" >$SESSIONFILE

  SESSION_ID=$(jq -r '.session' $SESSIONFILE)
  SESSION_PROFILE=$(jq -r '.currentLoginProfile' $SESSIONFILE)

  # fake some dns activity
  dig "@$trm_vodafonedns" google.com
  echo "Session-ID: $SESSION_ID"

  if [ "$SESSION_PROFILE" = "$trm_neededprofile" ]; then
    exit 0
  fi

  RESULT=$(curl --resolve "$trm_resolve" -H 'Content-Type: application/json' \
  --user-agent "${trm_useragent}" --connect-timeout "${trm_maxwait}" \
  --request POST --data "{\"loginProfile\": $trm_neededprofile, \"accessType\": \"termsOnly\", \"session\": \"${SESSION_ID}\"}"\
  https://hotspot.vodafone.de/api/v4/login 2>/dev/null | jq -r '.message')

  if [ "$RESULT" = "OK" ]; then
    echo success!
    exit 0
  else
    echo "$RESULT"
    exit 1
  fi
fi
