#!/bin/zsh

set -eu

SERVER_ADDR="${1:?Usage: ./step2.sh <server_ip_or_fqdn>}"

PROFILE_REGION="Turkey"
PROFILE_VERSION="v1"
PROFILE_LABEL="${PROFILE_REGION} ${PROFILE_VERSION}"
CLIENT_SLUG="$(printf '%s' "${PROFILE_REGION}" | tr '[:upper:]' '[:lower:]')"
CLIENT_ID="${CLIENT_SLUG}-${PROFILE_VERSION}-client"
PROFILE_IDENTIFIER="com.iwheelbuy.vpn.${CLIENT_SLUG}.${PROFILE_VERSION}"
TRUSTED_SSIDS=("MikroTik5GHz" "MikroTik2GHz" "MikroTik1GHz")

PAYLOAD_CERTIFICATE_UUID=$(cat /proc/sys/kernel/random/uuid)
PAYLOAD_VPN_UUID=$(cat /proc/sys/kernel/random/uuid)
PAYLOAD_CONFIGURATION_UUID=$(cat /proc/sys/kernel/random/uuid)
PKCS12_PASSWORD=$(cat /proc/sys/kernel/random/uuid)

cat << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadDisplayName</key>
    <string>${PROFILE_LABEL}</string>
    <key>PayloadIdentifier</key>
    <string>${PROFILE_IDENTIFIER}</string>
    <key>PayloadUUID</key>
    <string>${PAYLOAD_CONFIGURATION_UUID}</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadDisplayName</key>
            <string>${PROFILE_LABEL} Client Certificate</string>
            <key>PayloadDescription</key>
            <string>Install client identity for ${PROFILE_LABEL}</string>
            <key>PayloadCertificateFileName</key>
            <string>${CLIENT_ID}.p12</string>
            <key>Password</key>
            <string>${PKCS12_PASSWORD}</string>
            <key>PayloadContent</key>
            <data>
$(openssl pkcs12 -export -inkey /etc/ipsec.d/private/client.pem -in /etc/ipsec.d/certs/client.pem -name "${PROFILE_LABEL} Client" -certfile /etc/ipsec.d/cacerts/root.pem -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 -passout pass:${PKCS12_PASSWORD} | base64 -w 0)
            </data>
            <key>PayloadType</key>
            <string>com.apple.security.pkcs12</string>
            <key>PayloadIdentifier</key>
            <string>${PROFILE_IDENTIFIER}.pkcs12</string>
            <key>PayloadUUID</key>
            <string>${PAYLOAD_CERTIFICATE_UUID}</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        <dict>
            <key>PayloadDisplayName</key>
            <string>${PROFILE_LABEL}</string>
            <key>PayloadDescription</key>
            <string>Configure ${PROFILE_LABEL} IKEv2 VPN</string>
            <key>UserDefinedName</key>
            <string>${PROFILE_LABEL}</string>
            <key>VPNType</key>
            <string>IKEv2</string>
            <key>IKEv2</key>
            <dict>
                <key>RemoteAddress</key>
                <string>${SERVER_ADDR}</string>
                <key>RemoteIdentifier</key>
                <string>${SERVER_ADDR}</string>
                <key>LocalIdentifier</key>
                <string>${CLIENT_ID}</string>
                <key>AuthenticationMethod</key>
                <string>Certificate</string>
                <key>PayloadCertificateUUID</key>
                <string>${PAYLOAD_CERTIFICATE_UUID}</string>
                <key>CertificateType</key>
                <string>RSA</string>
                <key>EnablePFS</key>
                <integer>0</integer>
                <key>IKESecurityAssociationParameters</key>
                <dict>
                    <key>EncryptionAlgorithm</key>
                    <string>AES-256</string>
                    <key>IntegrityAlgorithm</key>
                    <string>SHA2-256</string>
                    <key>DiffieHellmanGroup</key>
                    <integer>14</integer>
                </dict>
                <key>ChildSecurityAssociationParameters</key>
                <dict>
                    <key>EncryptionAlgorithm</key>
                    <string>AES-256</string>
                    <key>IntegrityAlgorithm</key>
                    <string>SHA2-256</string>
                </dict>
                <key>OnDemandEnabled</key>
                <integer>1</integer>
                <key>OnDemandRules</key>
                <array>
                    <dict>
                        <key>InterfaceTypeMatch</key>
                        <string>WiFi</string>
                        <key>SSIDMatch</key>
                        <array>
`for x in ${TRUSTED_SSIDS}; echo "                            <string>$x</string>"`
                        </array>
                        <key>Action</key>
                        <string>Disconnect</string>
                    </dict>
                    <dict>
                        <key>InterfaceTypeMatch</key>
                        <string>Cellular</string>
                        <key>Action</key>
                        <string>Connect</string>
                    </dict>
                    <dict>
                        <key>Action</key>
                        <string>Connect</string>
                    </dict>
                </array>
            </dict>
            <key>PayloadType</key>
            <string>com.apple.vpn.managed</string>
            <key>PayloadIdentifier</key>
            <string>${PROFILE_IDENTIFIER}.vpn</string>
            <key>PayloadUUID</key>
            <string>${PAYLOAD_VPN_UUID}</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
    </array>
</dict>
</plist>
EOF
