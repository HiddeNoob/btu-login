#!/bin/bash

# User Credentials
USERNAME="KULLANICI_ADINIZ"
PASSWORD="SIFRENIZ"
CHECK_INTERVAL=10
COOKIE_FILE="/tmp/btu_fg_cookie.txt"

# Standard Headers
HEADERS=(
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
  -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
  -H "Accept-Language: tr-TR,tr;q=0.9,en;q=0.8"
  -H "Content-Type: application/x-www-form-urlencoded"
)

# Connectivity Check
check_internet() {
    if curl -s --head --max-time 3 https://www.google.com | grep -qE "200 OK|302 Found|301 Moved"; then
        return 0
    fi
    return 1
}

# Authentication
do_login() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [*] Session inactive, attempting login..."
    rm -f "$COOKIE_FILE"

    # Fetch captive portal redirect URL
    local INIT_RESP
    INIT_RESP=$(curl -s -m 5 "${HEADERS[@]}" http://neverssl.com)
    local REDIRECT_URL
    REDIRECT_URL=$(echo "$INIT_RESP" | grep -oP 'window\.location="\K[^"]+')

    if [ -z "$REDIRECT_URL" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [-] Failed to get redirect URL."
        return 1
    fi

    local BASE_URL HOST_HEADER MAGIC FORM_RESP TREDIR
    BASE_URL=$(echo "$REDIRECT_URL" | grep -oP 'https?://[^/]+')
    HOST_HEADER=$(echo "$BASE_URL" | sed -E 's#https?://##')

    # Get initial session cookies and token values
    FORM_RESP=$(curl -s -k -m 5 -c "$COOKIE_FILE" "${HEADERS[@]}" -H "Host: $HOST_HEADER" "$REDIRECT_URL")
    
    MAGIC=$(echo "$FORM_RESP" | grep -oP 'name="magic" value="\K[^"]+')
    TREDIR=$(echo "$FORM_RESP" | grep -oP 'name="4Tredir" value="\K[^"]+')

    [ -z "$MAGIC" ] && MAGIC=$(echo "$REDIRECT_URL" | grep -oP 'fgtauth\?\K[a-fA-F0-9]+')
    [ -z "$TREDIR" ] && TREDIR="http://neverssl.com/"

    # Submit credentials
    local POST_RESP
    POST_RESP=$(curl -s -k -i -m 10 -X POST "${BASE_URL}/" \
      -b "$COOKIE_FILE" -c "$COOKIE_FILE" \
      "${HEADERS[@]}" \
      -H "Host: $HOST_HEADER" \
      -H "Origin: $BASE_URL" \
      -H "Referer: $REDIRECT_URL" \
      --data-urlencode "4Tredir=$TREDIR" \
      --data-urlencode "magic=$MAGIC" \
      --data-urlencode "username=$USERNAME" \
      --data-urlencode "password=$PASSWORD")

    # Parse response header details
    local HTTP_STATUS LOCATION
    HTTP_STATUS=$(echo "$POST_RESP" | grep -m1 "HTTP/" | awk '{print $2}')
    LOCATION=$(echo "$POST_RESP" | grep -i "^Location:" | awk '{print $2}' | tr -d '\r')

    # Validate authentication result
    if [ "$HTTP_STATUS" = "303" ] && [[ "$LOCATION" != *"fgtauth"* ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [+] Login successful (HTTP 303)."
        sleep 2
        
        if check_internet; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') [++] Internet connectivity verified."
            return 0
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') [-] HTTP 303 received, but internet is still unreachable."
            return 1
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') [-] ERROR: Login failed (HTTP: ${HTTP_STATUS:-No Response})."
        [ -n "$LOCATION" ] && echo "    > Redirected to: $LOCATION"
        return 1
    fi
}

# Keep-alive loop
while true; do
    if ! check_internet; then
        do_login
    fi
    sleep "$CHECK_INTERVAL"
done
