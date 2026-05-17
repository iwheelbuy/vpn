#!/bin/sh

set -eu

SERVER_ADDR="${1:?Usage: ./step1.sh <server_ip_or_fqdn> [client_p12_basename]}"

PROFILE_REGION="Turkey"
PROFILE_VERSION="v1"
CA_CN="Turkey VPN Root CA"
CLIENT_CN="Turkey VPN Client"
CLIENT_SLUG="$(printf '%s' "${PROFILE_REGION}" | tr '[:upper:]' '[:lower:]')"
CLIENT_ID="${CLIENT_SLUG}-${PROFILE_VERSION}-client"
P12_BASENAME="${2:-${CLIENT_SLUG}-${PROFILE_VERSION}-client}"
P12_PASSWORD="${P12_PASSWORD:-123}"
VPN_POOL="10.10.10.0/24"
LE_EMAIL="${LE_EMAIL:-}"
CERTBOT_BIN="/usr/local/bin/certbot"
CERTBOT_DEPLOY_HOOK="/usr/local/sbin/turkey-v1-cert-deploy.sh"
CERTBOT_RENEW_CRON="/etc/cron.d/turkey-v1-certbot-renew"
LE_LIVE_DIR="/etc/letsencrypt/live/${SERVER_ADDR}"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get -y dist-upgrade
apt-get install -y strongswan strongswan-pki iptables-persistent zsh snapd

systemctl enable --now snapd.socket || true
systemctl enable --now snapd.service || true
snap list core >/dev/null 2>&1 || snap install core
snap refresh core
snap list certbot >/dev/null 2>&1 || snap install --classic certbot
ln -sf /snap/bin/certbot "${CERTBOT_BIN}"

cd /etc/ipsec.d
ipsec pki --gen --type rsa --size 4096 --outform pem > private/root.pem
ipsec pki --self --ca --lifetime 3650 --in private/root.pem \
--type rsa --digest sha256 \
--dn "CN=${CA_CN}" \
--outform pem > cacerts/root.pem
ipsec pki --gen --type rsa --size 4096 --outform pem > private/client.pem
ipsec pki --pub --in private/client.pem --type rsa |
ipsec pki --issue --lifetime 3650 --digest sha256 \
--cacert cacerts/root.pem --cakey private/root.pem \
--dn "CN=${CLIENT_CN}" --san "${CLIENT_ID}" \
--flag clientAuth \
--outform pem > certs/client.pem
rm /etc/ipsec.d/private/root.pem

cat > "${CERTBOT_DEPLOY_HOOK}" <<EOF
#!/bin/sh
set -eu

install -m 644 "${LE_LIVE_DIR}/fullchain.pem" /etc/ipsec.d/certs/server.pem
install -m 600 "${LE_LIVE_DIR}/privkey.pem" /etc/ipsec.d/private/server.key

if [ -f /etc/ipsec.conf ] && grep -q '^conn ikev2-pubkey' /etc/ipsec.conf; then
    if systemctl list-unit-files | grep -q '^strongswan-starter'; then
        systemctl reload-or-restart strongswan-starter
    else
        ipsec restart
    fi
fi
EOF
chmod 755 "${CERTBOT_DEPLOY_HOOK}"

if printf '%s' "${SERVER_ADDR}" | grep -Eq '^[0-9]+(\.[0-9]+){3}$'; then
    CERTBOT_NAME_ARG="--ip-address"
    CERTBOT_PROFILE_ARGS="--preferred-profile shortlived"
    CERTBOT_RENEW_SCHEDULE="17 */6 * * *"
else
    CERTBOT_NAME_ARG="-d"
    CERTBOT_PROFILE_ARGS=""
    CERTBOT_RENEW_SCHEDULE="17 3,15 * * *"
fi

if [ -n "${LE_EMAIL}" ]; then
    CERTBOT_ACCOUNT_ARGS="--email ${LE_EMAIL}"
else
    CERTBOT_ACCOUNT_ARGS="--register-unsafely-without-email"
fi

if [ -n "${CERTBOT_PROFILE_ARGS}" ]; then
    "${CERTBOT_BIN}" certonly \
        --non-interactive \
        --agree-tos \
        ${CERTBOT_ACCOUNT_ARGS} \
        --standalone \
        ${CERTBOT_PROFILE_ARGS} \
        --key-type rsa \
        --rsa-key-size 2048 \
        "${CERTBOT_NAME_ARG}" "${SERVER_ADDR}" \
        --deploy-hook "${CERTBOT_DEPLOY_HOOK}"
else
    "${CERTBOT_BIN}" certonly \
        --non-interactive \
        --agree-tos \
        ${CERTBOT_ACCOUNT_ARGS} \
        --standalone \
        --key-type rsa \
        --rsa-key-size 2048 \
        "${CERTBOT_NAME_ARG}" "${SERVER_ADDR}" \
        --deploy-hook "${CERTBOT_DEPLOY_HOOK}"
fi

"${CERTBOT_DEPLOY_HOOK}"

cat > /etc/ipsec.conf <<EOF
include /var/lib/strongswan/ipsec.conf.inc

config setup
        uniqueids=never
        charondebug="ike 1, cfg 1, knl 1"

conn %default
        keyexchange=ikev2
        ike=aes256-sha256-modp2048!
        esp=aes256-sha256!
        fragmentation=yes
        rekey=no
        dpdaction=clear
        left=%any
        leftauth=pubkey
        leftid=${SERVER_ADDR}
        leftcert=server.pem
        leftsendcert=always
        leftsubnet=0.0.0.0/0
        right=%any
        rightauth=pubkey
        rightsourceip=${VPN_POOL}
        rightdns=1.1.1.1,8.8.8.8

conn ikev2-pubkey
        auto=add
EOF

cat > /etc/ipsec.secrets <<EOF
include /var/lib/strongswan/ipsec.secrets.inc

: RSA server.key
EOF

cat > /etc/sysctl.d/90-turkey-vpn.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.ip_no_pmtu_disc = 1
EOF
sysctl --system

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -Z
iptables -t nat -F
iptables -t mangle -F
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir in --proto esp -s ${VPN_POOL} -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d ${VPN_POOL} -j ACCEPT

INTERFACE=$(ip route | awk '/default/ {print $5; exit}')

iptables -t nat -A POSTROUTING -s ${VPN_POOL} -o "${INTERFACE}" -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s ${VPN_POOL} -o "${INTERFACE}" -j MASQUERADE
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s ${VPN_POOL} -o "${INTERFACE}" -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360

iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP
netfilter-persistent save
netfilter-persistent reload

cat > "${CERTBOT_RENEW_CRON}" <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

${CERTBOT_RENEW_SCHEDULE} root ${CERTBOT_BIN} renew -q
EOF
chmod 644 "${CERTBOT_RENEW_CRON}"

if systemctl list-unit-files | grep -q '^strongswan-starter'; then
    systemctl enable --now strongswan-starter
    systemctl restart strongswan-starter
else
    ipsec restart
fi

openssl pkcs12 -export \
    -in /etc/ipsec.d/certs/client.pem \
    -inkey /etc/ipsec.d/private/client.pem \
    -certfile /etc/ipsec.d/cacerts/root.pem \
    -name "${PROFILE_REGION} ${PROFILE_VERSION} Client" \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES \
    -macalg sha1 \
    -passout "pass:${P12_PASSWORD}" \
    -out "${P12_BASENAME}.p12" \
    -descert
chmod 600 "${P12_BASENAME}.p12"

openssl verify -CAfile /etc/ipsec.d/cacerts/root.pem /etc/ipsec.d/certs/client.pem
openssl x509 -in /etc/ipsec.d/certs/server.pem -noout -subject -issuer -dates

cat <<EOF

Done.
Client PKCS#12: /root/${P12_BASENAME}.p12
PKCS#12 password: ${P12_PASSWORD}
Apple profile: run ./step2.sh ${SERVER_ADDR} > ${CLIENT_SLUG}-${PROFILE_VERSION}.mobileconfig
EOF
