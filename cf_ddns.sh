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
# Script variables (do not change)
################################################################
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source "/opt/cf_ddns/settings"
if [ $? -ne 0 ]; then
	source "$CWD/settings"
	if [ $? -ne 0 ]; then 
	    echo "A settings file at '$CWD/settings' was not found!"
	    echo "Generating a template settings file ..."
	    echo "Please change the settings as described, then restart this tool!"
	
	    cat > "$CWD/settings" << EOL
# API Key
# How to obtain:
# 1. On CloudFlare click on your user in the top right corner.
# 2. In the left side bar click on 'API Tokens'
# 3. Click on 'Create Token' under 'API Tokens'
# 4. Use the 'Edit zone DNS' template
# 5. Leave as is, but under 'Zone Resources' select your specific zone
# 6. Submit and copy the API key into here
API_KEY=""

# Zone ID
# You can find this on CloudFlare on the "Overview" page of your Zone.
# It should appear in a list on the right side.
ZONE_ID=""

# Domains to be affected (do not add commas here! Use spaces.)
# Type A    DNS entries == IPv4
# Type AAAA DNS entries == IPv6
IPv4_HOSTS=("my-subdomain.domain.tld" "my-other-subdomain.domain.tld")
IPv6_HOSTS=("my-subdomain.domain.tld" "my-other-subdomain.domain.tld")

# Path to where the last ip cache's are stored
LAST_IP_CACHE_FOLDER="$CWD/cache"
EOL
	    exit -1
	fi
fi

if [ "$API_KEY" == "" ]; then 
    echo "There is an error in your configuration file!"
    echo "The variable 'API_KEY' doesn't seem to be properly set!"
    echo "Please review your settings file [$CWD/settings] and rerun this tool!"
    
    exit -1
fi
if [ "$ZONE_ID" == "" ]; then 
    echo "There is an error in your configuration file!"
    echo "The variable 'ZONE_ID' doesn't seem to be properly set!"
    echo "Please review your settings file [$CWD/settings] and rerun this tool!"
    
    exit -1
fi
if [ "$IPv4_HOSTS" == "" ] && [ "$IPv6_HOSTS" == "" ]; then 
    echo "There is an error in your configuration file!"
    echo "The variable 'IPv4_HOSTS' and 'IPv6_HOSTS' doesn't seem to be properly set!" 
    echo "Please review your settings file [$CWD/settings] and rerun this tool!"
    echo "It's fine to disable (i.e. unset) either of them, but at least one must exist!"
    
    exit -1
fi

LAST_IPv4_FILE="$LAST_IP_CACHE_FOLDER/ipv4.last"
LAST_IPv6_FILE="$LAST_IP_CACHE_FOLDER/ipv6.last"

IPv4_HOST_COUNT=${#IPv4_HOSTS[@]}
IPv6_HOST_COUNT=${#IPv6_HOSTS[@]}

ENABLE_IPv4=1
if [ $IPv4_HOST_COUNT -eq 0 ]; then
    ENABLE_IPv4=0
fi
ENABLE_IPv6=1
if [ $IPv6_HOST_COUNT -eq 0 ]; then
    ENABLE_IPv6=0
fi

UPDATE_DNS_IPv4=0
UPDATE_DNS_IPv6=0

FAILURE_COUNT=0

################################################################
# Process CLI arguments
################################################################
if [ $# -gt 0 ]; then
    if [ "$1" == "--force" ]; then
        echo "Forcing a DNS update as the tool ahs been called with '--force'!"

        UPDATE_DNS_IPv4=1
        UPDATE_DNS_IPv6=1
    fi
fi

################################################################
# Query current IP
################################################################
if [ $ENABLE_IPv4 -ne 0 ]; then
    CURRENT_IPv4=$(curl -s -L https://ipv4.icanhazip.com/)
    if [ $? -ne 0 ]; then
        echo "Failed retrieving current IPv4! If this continues to fail you should consider listing no IPv4 entries to disable the IPv4 stack."
        
        exit -1
    fi

    echo "Found public IPv4: $CURRENT_IPv4"
fi

if [ $ENABLE_IPv6 -ne 0 ]; then
    CURRENT_IPv6=$(curl -s -L https://ipv6.icanhazip.com/)
    if [ $? -ne 0 ]; then
        echo "Failed retrieving current IPv6! If this continues to fail you should consider listing no IPv6 entries to disable the IPv6 stack."
        
        exit -1
    fi

    echo "Found public IPv6: $CURRENT_IPv6" 
fi

################################################################
# Read last IP
################################################################
# Make sure the cache directory exists
mkdir -p "$LAST_IP_CACHE_FOLDER"
if [ $? -ne 0 ]; then
    echo "Failed creating last IP cache folder at '$LAST_IP_CACHE_FOLDER'!"
    
    exit -1
fi

if [ $ENABLE_IPv4 -ne 0 ]; then
    if [ -f "$LAST_IPv4_FILE" ]; then
        LAST_IPv4=$(cat "$LAST_IPv4_FILE")

        if [ "$LAST_IPv4" == "$CURRENT_IPv4" ]; then
            echo "Last IPv4: $LAST_IPv4 (unchanged)"
        else
            echo "Last IPv4: $LAST_IPv4 (changed)"
            
            UPDATE_DNS_IPv4=1
        fi
    else
        echo "Last IPv4 file not found! [$LAST_IPv4_FILE]"
        echo "Assuming this is the first run."
        echo "Forcing DNS update."

        UPDATE_DNS_IPv4=1
    fi
fi

if [ $ENABLE_IPv6 -ne 0 ]; then
    if [ -f "$LAST_IPv6_FILE" ]; then
        LAST_IPv6=$(cat "$LAST_IPv6_FILE")
        
        if [ "$LAST_IPv6" == "$CURRENT_IPv6" ]; then
            echo "Last IPv6: $LAST_IPv6 (unchanged)"
        else
            echo "Last IPv6: $LAST_IPv6 (changed)"

            UPDATE_DNS_IPv6=1
        fi
    else
        echo "Last IPv6 file not found! [$LAST_IPv6_FILE]"
        echo "Assuming this is the first run."
        echo "Forcing DNS update."

        UPDATE_DNS_IPv6=1
    fi
fi

################################################################
# Update DNS
################################################################
# Exit if no update is required
if [ $UPDATE_DNS_IPv4 -eq 0 ] && [ $UPDATE_DNS_IPv6 -eq 0 ]; then
    echo "Neither IPv4, nor IPv6, changed!"
    echo "Call this tool with '--force' to force an update."
	exit
fi

# We now expect to have a new IP address (or are forcing an update).
# Store new IP's
echo "$CURRENT_IPv4" > "$LAST_IPv4_FILE"
echo "$CURRENT_IPv6" > "$LAST_IPv6_FILE"

################################################################
# DNS Update                                                   #
################################################################
# List DNS Records
DNS_RESULT=$(
	curl -s \
        -X GET \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records
)

# Process Type A/IPv4 entries
if [ $ENABLE_IPv4 -ne 0 ]; then
    DNS_A_ENTRIES=$(echo "$DNS_RESULT" | jq '[.result[] | select (.type == "A") | .]')
    DNS_A_ENTRIES_COUNT=$(echo "$DNS_A_ENTRIES" | jq length)

    echo "Found $DNS_A_ENTRIES_COUNT DNS Type A entries!"
    echo "DNS Type A hosts to change: ${IPv4_HOSTS[@]}"
    for ((i=0; i<DNS_A_ENTRIES_COUNT; i++)); do
        id=$(echo "$DNS_A_ENTRIES" | jq ".[$i].id" | sed -e 's/^"//' -e 's/"$//')
        type=$(echo "$DNS_A_ENTRIES" | jq ".[$i].type" | sed -e 's/^"//' -e 's/"$//')
        name=$(echo "$DNS_A_ENTRIES" | jq ".[$i].name" | sed -e 's/^"//' -e 's/"$//')
        proxied=$(echo "$DNS_A_ENTRIES" | jq ".[$i].proxied" | sed -e 's/^"//' -e 's/"$//')
        echo "> #$id: $name [Type: $type, Proxied: $proxied]"

        matched=0
        for hostname in "${IPv4_HOSTS[@]}"; do
            if [ "$hostname" == "$name" ]; then
                matched=1
                echo "Matched: $hostname!"

                # Update entry
                update_result=$(
                    curl -s \
                        -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id" \
                        -H "Authorization: Bearer $API_KEY" \
                        -H "Content-Type: application/json" \
                        --data "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$CURRENT_IPv4\",\"proxied\":$proxied}"
                )
                success=$(echo "$update_result" | jq ".success" | sed -e 's/^"//' -e 's/"$//')
                if [ "$success" == "true" ]; then
                    echo "Successfully updated!"
                else
                    FAILURE_COUNT=$((FAILURE_COUNT + 1))
                    echo "Failed to update!"

                    errors=$(echo "$update_result" | jq ".errors")
                    echo "Errors: $errors"
                fi
            fi
        done

        if [ $matched -eq 0 ]; then
            echo "No match!"
        fi
    done
fi

# Process Type AAAA/IPv6 entries
if [ $ENABLE_IPv6 -ne 0 ]; then
    DNS_AAAA_ENTRIES=$(echo "$DNS_RESULT" | jq '[.result[] | select (.type == "AAAA") | .]')
    DNS_AAAA_ENTRIES_COUNT=$(echo "$DNS_AAAA_ENTRIES" | jq length)

    echo "Found $DNS_AAAA_ENTRIES_COUNT DNS Type AAAA entries!"
    echo "DNS Type AAAA hosts to change: ${IPv6_HOSTS[@]}"
    for ((i=0; i<DNS_AAAA_ENTRIES_COUNT; i++)); do
        id=$(echo "$DNS_AAAA_ENTRIES" | jq ".[$i].id" | sed -e 's/^"//' -e 's/"$//')
        type=$(echo "$DNS_AAAA_ENTRIES" | jq ".[$i].type" | sed -e 's/^"//' -e 's/"$//')
        name=$(echo "$DNS_AAAA_ENTRIES" | jq ".[$i].name" | sed -e 's/^"//' -e 's/"$//')
        proxied=$(echo "$DNS_AAAA_ENTRIES" | jq ".[$i].proxied" | sed -e 's/^"//' -e 's/"$//')
        echo "> #$id: $name [Type: $type, Proxied: $proxied]"

        matched=0
        for hostname in "${IPv6_HOSTS[@]}"; do
            if [ "$hostname" == "$name" ]; then
                matched=1
                echo "Matched: $hostname!"

                # Update entry
                update_result=$(
                    curl -s \
                        -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$id" \
                        -H "Authorization: Bearer $API_KEY" \
                        -H "Content-Type: application/json" \
                        --data "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$CURRENT_IPv6\",\"proxied\":$proxied}"
                )
                success=$(echo "$update_result" | jq ".success" | sed -e 's/^"//' -e 's/"$//')
                if [ "$success" == "true" ]; then
                    echo "Successfully updated!"
                else
                    FAILURE_COUNT=$((FAILURE_COUNT + 1))
                    echo "Failed to update!"

                    errors=$(echo "$update_result" | jq ".errors")
                    echo "Errors: $errors"
                fi
            fi
        done

        if [ $matched -eq 0 ]; then
            echo "No match!"
        fi
    done
fi

if [ $FAILURE_COUNT -eq 0 ]; then
    echo "Successfully finished!"
else
    echo "$FAILURE_COUNT errors occurred!"
fi

exit $FAILURE_COUNT
