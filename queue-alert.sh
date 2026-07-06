#!/bin/bash

set -u
set -o pipefail

# Telegram Configuration
CONFIG="/opt/zimbra/scripts/telegram.conf"
if [ ! -f "$CONFIG" ]; then
    echo "ERROR: Telegram config not found: $CONFIG"
    exit 1
fi

## Load Configuration
if ! source "$CONFIG"; then
    echo "[ERROR] Failed to load configuration: $CONFIG"
    exit 1
fi

for var in URL CHAT_ID CONNECT_TIMEOUT MAX_TIME RETRY RETRY_DELAY;do
    if [ -z "${!var}" ]; then
        echo "[ERROR] $var is not defined in $CONFIG"
        exit 1
    fi
done

## MAIN CODE
ZHOST=$(hostname)
DATE=$(date '+%d+%m+%Y %H:%M:%S')

run_zmqstat() {
    /opt/zimbra/libexec/zmqstat 2>/dev/null
}

ZQSTAT=$(run_zmqstat)

MAIL_ACTIVE=$(echo "${ZQSTAT}" | awk -F= '/active/ {print $2}')
MAIL_HOLD=$(echo "${ZQSTAT}" | awk -F= '/hold/ {print $2}')
MAIL_DEFERRED=$(echo "${ZQSTAT}"| awk -F= '/deferred/ {print $2}')
MAIL_INCOMING=$(echo "${ZQSTAT}"| awk -F= '/incoming/ {print $2}')

MAIL_ACTIVE=${MAIL_ACTIVE:-0}
MAIL_HOLD=${MAIL_HOLD:-0}
MAIL_DEFERRED=${MAIL_DEFERRED:-0}
MAIL_INCOMING=${MAIL_INCOMING:-0}

SENDER_CHECK=$(
    su - zimbra -c "mailq" \
    | awk '/^[A-F0-9]/ {print $7}' \
    | sort \
    | uniq -c \
    | sort -nr \
    | head
)

MAIL_INFO=""

if [ "${MAIL_ACTIVE}" -ge 50 ]; then
    MAIL_INFO+="<pre>Active Queue : ${MAIL_ACTIVE}</pre>"
fi

if [ "${MAIL_HOLD}" -ge 50 ]; then
    MAIL_INFO+="<pre>Hold Queue : ${MAIL_HOLD}</pre>"
fi

if [ "${MAIL_DEFERRED}" -ge 50 ]; then
    MAIL_INFO+="<pre>Deferred Queue : ${MAIL_DEFERRED}</pre>"
fi

if [ "${MAIL_INCOMING}" -ge 50 ]; then
    MAIL_INFO+="<pre>Incoming Queue : ${MAIL_INCOMING}</pre>"
fi

## Message
MESSAGE="
<b>Queue ALert - ${ZHOST}</b>

<pre>
Date : ${DATE}
</pre>

${MAIL_INFO}

<pre>
Top Sender:
${SENDER_CHECK}
</pre>
"

# END MAIN CODE

if [ -n "$MAIL_INFO" ]; then
## Send Notification To Telegram
curl -s \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    --retry "$RETRY" \
    --retry-delay "$RETRY_DELAY" \
    -X POST "$URL" \
    -d "chat_id=${CHAT_ID}" \
    -d "parse_mode=HTML" \
    --data-urlencode "text=${MESSAGE}" >/dev/null
fi
