#!/bin/bash

set -u
set -o pipefail

# Konfigurasi Telegram
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

for var in URL CHAT_ID CONNECT_TIMEOUT MAX_TIME RETRY RETRY_DELAY; do
    if [ -z "${!var}" ]; then
        echo "[ERROR] $var is not defined in $CONFIG"
        exit 1
    fi
done

# System Information
OS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
UPTIME=$(uptime -p)
DATE=$(date '+%d-%m-%Y %H:%M:%S %Z')
IP=$(hostname -I)
DISK_INFO=$(df -h -x tmpfs -x devtmpfs -x squashfs --output=source,size,used,avail,pcent,target)
MEM_INFO=$(free -h | awk '
/^Mem:/ {
    printf "Total : %s\nUsed  : %s\nFree  : %s\nCache : %s\n",$2,$3,$4,$6
}
/^Swap:/ {
    printf "Swap  : %s/%s\n",$3,$2
}')

# Zimbra
run_zimbra() {
    su - zimbra -c "$1" 2>/dev/null
}

ZHOST=$(run_zimbra "zmhostname")
if [ -z "$ZHOST" ]; then
    ZHOST=$(hostname -f 2>/dev/null)
fi
if [ -z "$ZHOST" ]; then
    ZHOST=$(hostname)
fi

ZVERSION=$(run_zimbra "zmcontrol -v")
ZSERVICES=$(run_zimbra "zmprov gs ${ZHOST} zimbraServiceEnabled")
if [ -z "$ZSERVICES" ]; then
    echo "[ERROR] Unable to get zimbraServiceEnabled for host: $ZHOST"
    exit 1
fi

ZSTATUS=$(run_zimbra "zmcontrol status")

has_service() {
    grep -qw "$1" <<<"$ZSERVICES"
}

## Check MMR or Not
LDAP_REPLCHK=""

if has_service ldap; then
    ZLDAP_SYNC=$(run_zimbra "/opt/zimbra/libexec/zmreplchk")
    if [ -n "${ZLDAP_SYNC}" ]; then
        LDAP_REPLCHK="${LDAP_REPLCHK}
<b>🔄 LDAP Replication</b>
<pre>${ZLDAP_SYNC}</pre>
"
    fi
fi

## Check Numbers of Account each Mailbox
MBOX_ACCOUNT=""

if has_service mailbox; then
    ZCOUNT_MBOX=$(run_zimbra "zmprov -l gaa -s ${ZHOST} | wc -l")
    MBOX_ACCOUNT="
<b>👥 The Number of Accounts In This Mailbox:</b>
<pre>${ZCOUNT_MBOX}</pre>
"
fi

# Role-specific information
ROLE_INFO="<b>🖥️ Server Used For</b>
<pre>"

if has_service ldap; then
    ROLE_INFO="${ROLE_INFO}
Server LDAP ✅
"
fi

if has_service mailbox; then
    ROLE_INFO="${ROLE_INFO}
Server Mailbox ✅
"
fi

if has_service mta; then
    ROLE_INFO="${ROLE_INFO}
Server MTA ✅
"
fi

if has_service proxy; then
    ROLE_INFO="${ROLE_INFO}
Server Proxy ✅
"
fi
ROLE_INFO="${ROLE_INFO}
</pre>"

# Message
MESSAGE="
<b>🖥️ Server Information</b>
<pre>
Hostname : ${ZHOST}
OS       : ${OS}
Uptime   : ${UPTIME}
IP       : ${IP}
Date     : ${DATE}
</pre>

<b>💾 Disk Information</b>
<pre>${DISK_INFO}</pre>

${ROLE_INFO}

<b>🧠 Memory Information</b>
<pre>${MEM_INFO}</pre>

<b>📧 Zimbra Version</b>
<pre>${ZVERSION}</pre>

<b>🔧 Zimbra Services</b>
<pre>${ZSERVICES}</pre>

<b>✅ Zimbra Status</b>
<pre>${ZSTATUS}</pre>

${LDAP_REPLCHK}
${MBOX_ACCOUNT}
"

curl -s \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    --retry "$RETRY" \
    --retry-delay "$RETRY_DELAY" \
    -X POST "$URL" \
    -d "chat_id=${CHAT_ID}" \
    -d "parse_mode=HTML" \
    --data-urlencode "text=${MESSAGE}" >/dev/null
