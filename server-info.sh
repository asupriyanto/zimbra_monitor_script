#!/bin/bash

# Konfigurasi Telegram
CONFIG="/opt/zimbra/scripts/telegram.conf"
if [ ! -f "$CONFIG"]; then
    echo "ERROR: Telegram config not found: $CONFIG"
    exit 1
fi

## Load Configuration
source "$CONFIG"

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
ZHOST=$(su - zimbra -c "zmhostname" 2>/dev/null)
if [ -z "$ZHOST" ]; then
    ZHOST=$(hostname -f 2>/dev/null)
fi
if [ -z "$ZHOST" ]; then
    ZHOST=$(hostname)
fi

ZVERSION=$(su - zimbra -c "zmcontrol -v" 2>/dev/null)
ZSERVICES=$(su - zimbra -c "zmprov gs ${ZHOST} zimbraServiceEnabled" 2>/dev/null)
ZSTATUS=$(su - zimbra -c "zmcontrol status" 2>/dev/null)

## Check MMR or Not
LDAP_REPLCHK=""

if echo "$ZSERVICES" | grep -qw ldap; then
    ZLDAP_SYNC=$(su - zimbra -c "/opt/zimbra/libexec/zmreplchk" 2>/dev/null)
    if [ -n "${ZLDAP_SYNC}" ]; then
        LDAP_REPLCHK="${LDAP_REPLCHK}
<b>LDAP Replication</b>
<pre>
${ZLDAP_SYNC}
</pre>  
"
    fi
fi

## Check Numbers of Account each Mailbox
MBOX_ACCOUNT=""

if echo "$ZSERVICES" | grep -qw mailbox; then
    ZCOUNT_MBOX=$(su - zimbra -c "zmprov -l gaa -s ${ZHOST} | wc -l" 2>/dev/null)
    MBOX_ACCOUNT="
<b>The Number of Accounts In This Mailbox:</b>
<pre>
${ZCOUNT_MBOX}
</pre>
"

fi

# Role-specific information
ROLE_INFO="<b>🖥️ Server Used For</b>
<pre>"

if echo "$ZSERVICES" | grep -qw ldap; then
    ROLE_INFO="${ROLE_INFO}
Server LDAP ✅
"
else
    ROLE_INFO="${ROLE_INFO}
Server LDAP ❌
"
fi

if echo "$ZSERVICES" | grep -qw mailbox; then
    ROLE_INFO="${ROLE_INFO}
Server Mailbox ✅
"
else
    ROLE_INFO="${ROLE_INFO}
Server Mailbox ❌
"
fi

if echo "$ZSERVICES" | grep -qw mta; then

    ROLE_INFO="${ROLE_INFO}
Server MTA ✅
"
else
    ROLE_INFO="${ROLE_INFO}
Server MTA ❌
"
fi

if echo "$ZSERVICES" | grep -qw proxy; then
    ROLE_INFO="${ROLE_INFO}
Server Proxy ✅
"
else
    ROLE_INFO="${ROLE_INFO}
Server Proxy ❌
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
${ROLE_INFO}
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