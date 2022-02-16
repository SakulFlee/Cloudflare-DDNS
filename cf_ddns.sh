#!/usr/bin/env bash
# Checks your CloudFlare DNS entries against your current IP address.
# If a difference is detected for any of the set domain entries, the
# entry will be updated.
#
# It is highly suggested to run this script on a regular basis OR
# if a IP change was detected.
# This is perfect for home-routers with changing public/external 
# IP addresses.
# This script is tested with cron executing it every hour and after
# a reboot.
# However, this script can also be hooked into another script 
# (e.g. ip-change) or tool; Simply execute it!
#
# Requires:
# - bash
# - jq
# - sed
# - dig (dnsutils)
# - curl
#
#    Lukas Weber <me@sakul6499.de> - Main Developer
#    Copyright (C) 2021 Lukas Weber <me@sakul6499.de>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

################################################################
# Settings
################################################################
# CloudFlare account authentification key
AUTH_KEY="<YOUR CF KEY>" # Check on CF: Account > API Key > Global API Key
# CloudFlare account email
AUTH_EMAIL="<YOUR CF EMAIL>"
# Domains to be affected (only of type 'A')
HOSTNAMES=("<FIRST DNS ENTRY TO BE UPDATED>" "<SECOND ENTRY ...>" "<LAST ENTRY>")
# Only 'A' records are supported ATM;

################################################################
# Script variables (do not change)
################################################################
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LAST_IP_FILE="$CWD/last_ip"

FORCE_DNS_UPDATE=0
UPDATE_DNS=0

################################################################
# Process CLI arguments
################################################################
if [ $# -gt 0 ]; then
    if [ "$1" == "--force" ]; then
        echo "-> Forcing dns update!"
        FORCE_DNS_UPDATE=1
    fi
fi

################################################################
# Query current IP
################################################################
CURRENT_IP=$(dig +short myip.opendns.com @resolver1.opendns.com.)
echo "Current IP: $CURRENT_IP"

################################################################
# Read last IP
################################################################
if [ -f "$LAST_IP_FILE" ]; then
    LAST_IP=$(cat "$LAST_IP_FILE")
    echo "Last IP: $LAST_IP"
    
    if [ $FORCE_DNS_UPDATE -eq 0 ] && [ "$last_ip" == "$current_ip" ]; then
        echo "IP didn't change! Use --force to force dns update ..."
        UPDATE_DNS=0
    else
        echo "Updating DNS!"
        UPDATE_DNS=1
    fi
else
    echo "Last IP file not found! [$last_ip_file]"
    echo "Assuming first run -> Updating DNS records"
    UPDATE_DNS=1
fi


################################################################
# Update DNS
################################################################
# Exit if no update is required
if [ $UPDATE_DNS -eq 0 ]; then
	exit
fi
# > After this line we know that we need/want to update the DNS records

# Store new IP
echo "$CURRENT_IP" > "$LAST_IP_FILE"

################################################################

ZONE_RESULT=$(
	curl -X GET \
	-H "X-Auth-Key:$AUTH_KEY" \
	-H "X-Auth-Email:$AUTH_EMAIL" \
	-H "Content-Type: application/json" \
	https://api.cloudflare.com/client/v4/zones
)
ZONE=$(echo "$ZONE_RESULT" | jq -r '.result[0].id')
echo "Zone ID: $ZONE"

# List DNS Records
DNS_RESULT=$(
	curl -X GET \
	-H "X-Auth-Key:$AUTH_KEY" \
	-H "X-Auth-Email:$AUTH_EMAIL" \
	-H "Content-Type: application/json" \
	https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records
)
DNS=$(echo "$DNS_RESULT" | jq '[.result[] | select (.type == "A") | .]')
ENTRIES=$(echo "$DNS" | jq length)
echo "DNS: $DNS"
echo "Entries: $ENTRIES"

for ((i=0; i<ENTRIES; i++)); do
	echo "Entry: #$i"

	ID=$(echo "$DNS" | jq ".[$i].id" | sed -e 's/^"//' -e 's/"$//')
	TYPE=$(echo "$DNS" | jq ".[$i].type" | sed -e 's/^"//' -e 's/"$//')
	NAME=$(echo "$DNS" | jq ".[$i].name" | sed -e 's/^"//' -e 's/"$//')
	PROXIED=$(echo "$DNS" | jq ".[$i].proxied" | sed -e 's/^"//' -e 's/"$//')
	echo "> $ID [$TYPE] ($NAME) {$PROXIED}"

    for hostname in $HOSTNAMES; do
        if [ "$hostname" == "$NAME" ]; then
            echo "Matched: $hostname"

            # Update entry
            UPDATE_RESULT=$(
                curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records/$ID" \
                -H "X-Auth-Key:$AUTH_KEY" \
                -H "X-Auth-Email:$AUTH_EMAIL" \
                -H "Content-Type: application/json" \
                --data "{\"type\":\"$TYPE\",\"name\":\"$NAME\",\"content\":\"$CURRENT_IP\",\"proxied\":$PROXIED}"
            )
            echo "Update Result: $UPDATE_RESULT"
        fi
    done
done
