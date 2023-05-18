#!/bin/sh

cd
apt update && apt upgrade
apt install strongswan iptables-persistent strongswan-pki zsh
cd /etc/ipsec.d
ipsec pki --gen --type rsa --size 4096 --outform pem > private/root.pem
ipsec pki --self --ca --lifetime 3650 --in private/root.pem \
--type rsa --digest sha256 \
--dn "CN=root" \
--outform pem > cacerts/root.pem
ipsec pki --gen --type rsa --size 4096 --outform pem > private/server.pem
ipsec pki --pub --in private/server.pem --type rsa |
ipsec pki --issue --lifetime 3650 --digest sha256 \
--cacert cacerts/root.pem --cakey private/root.pem \
--dn "CN=$1" \
--san $1 \
--flag serverAuth --outform pem > certs/server.pem
ipsec pki --gen --type rsa --size 4096 --outform pem > private/client.pem
ipsec pki --pub --in private/client.pem --type rsa |
ipsec pki --issue --lifetime 3650 --digest sha256 \
--cacert cacerts/root.pem --cakey private/root.pem \
--dn "CN=client" --san client \
--flag clientAuth \
--outform pem > certs/client.pem
rm /etc/ipsec.d/private/root.pem
> /etc/ipsec.conf
touch /etc/ipsec.conf
echo "include /var/lib/strongswan/ipsec.conf.inc" >> /etc/ipsec.conf
echo "\n" >> /etc/ipsec.conf
echo "config setup" >> /etc/ipsec.conf
echo "        uniqueids=never" >> /etc/ipsec.conf
echo "        charondebug=\"ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2,  mgr 2\"" >> /etc/ipsec.conf
echo "\n" >> /etc/ipsec.conf
echo "conn %default" >> /etc/ipsec.conf
echo "        keyexchange=ikev2" >> /etc/ipsec.conf
echo "        ike=aes128-sha2_256-ecp256!" >> /etc/ipsec.conf
echo "        esp=aes128-sha2_256-ecp256!" >> /etc/ipsec.conf
echo "        fragmentation=yes" >> /etc/ipsec.conf
echo "        rekey=no" >> /etc/ipsec.conf
echo "        compress=yes" >> /etc/ipsec.conf
echo "        dpdaction=clear" >> /etc/ipsec.conf
echo "        left=%any" >> /etc/ipsec.conf
echo "        leftauth=pubkey" >> /etc/ipsec.conf
echo "        leftsourceip=$1" >> /etc/ipsec.conf
echo "        leftid=$1" >> /etc/ipsec.conf
echo "        leftcert=server.pem" >> /etc/ipsec.conf
echo "        leftsendcert=always" >> /etc/ipsec.conf
echo "        leftsubnet=0.0.0.0/0" >> /etc/ipsec.conf
echo "        right=%any" >> /etc/ipsec.conf
echo "        rightauth=pubkey" >> /etc/ipsec.conf
echo "        rightsourceip=10.10.10.0/24" >> /etc/ipsec.conf
echo "        rightdns=8.8.8.8,8.8.4.4" >> /etc/ipsec.conf
echo "\n" >> /etc/ipsec.conf
echo "conn ikev2-pubkey" >> /etc/ipsec.conf
echo "        auto=add" >> /etc/ipsec.conf
> /etc/ipsec.secrets
touch /etc/ipsec.secrets
echo "include /var/lib/strongswan/ipsec.secrets.inc" >> /etc/ipsec.secrets
echo "\n" >> /etc/ipsec.secrets
echo ": RSA server.pem" >> /etc/ipsec.secrets
ipsec restart
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.ip_no_pmtu_disc = 1" >> /etc/sysctl.conf
sysctl -p
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F
iptables -Z
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p udp --dport  500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir in  --proto esp -s 10.10.10.0/24 -j ACCEPT
iptables -A FORWARD --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o eth0 -m policy --pol ipsec --dir out -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o eth0 -j MASQUERADE
iptables -t mangle -A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
iptables -A INPUT -j DROP
iptables -A FORWARD -j DROP
netfilter-persistent save
netfilter-persistent reload
cd
openssl pkcs12 -export -in /etc/ipsec.d/certs/client.pem -inkey /etc/ipsec.d/private/client.pem -certfile /etc/ipsec.d/cacerts/root.pem -name "client" -out $2.p12
chmod 777 $2.p12
openssl verify -CAfile /etc/ipsec.d/cacerts/root.pem /etc/ipsec.d/certs/server.pem
openssl verify -CAfile /etc/ipsec.d/cacerts/root.pem /etc/ipsec.d/certs/client.pem
reboot
