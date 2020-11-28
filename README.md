# Lightsail Debian 10.5 + Static IP

![](firewall.png)

# Terminal

```ruby
chmod 400 YOUR_CERTIFICATE_NAME.pem
ssh -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN -p 22
sudo su
rm -rf step1.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/develop/step1.sh" && chmod +x step1.sh && rm -rf step2.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/develop/step2.sh" && chmod +x step2.sh
# Предложенные установки - Y, остальное - Enter. Пароль для сертификата = 123.
./step1.sh YOUR_IP_OR_DOMAIN
ssh -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN -p 22
sudo su
./step2.sh YOUR_IP_OR_DOMAIN > vpn.mobileconfig
exit
exit
scp -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN:vpn.mobileconfig ./
scp -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN:client.p12 ./
# Не забудьте прибраться после скачивания
ssh -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN -p 22
sudo su
rm -rf step1.sh && rm -rf step2.sh && rm -rf vpn.mobileconfig && rm -rf client.p12
exit
exit
```

# Router OS (all traffic)

```ruby
/ip ipsec profile add name=NordVPN hash-algorithm=sha256 enc-algorithm=aes-128 dh-group=ecp256
/ip ipsec proposal add name=NordVPN auth-algorithms=sha256 enc-algorithms=aes-128-cbc pfs-group=ecp256
/ip ipsec policy group add name=NordVPN
/ip ipsec policy add dst-address=0.0.0.0/0 group=NordVPN proposal=NordVPN src-address=0.0.0.0/0 template=yes
/ip ipsec mode-config add name=NordVPN responder=no
/ip ipsec peer add address=18.159.120.244/32 exchange-mode=ike2 name=NordVPN profile=NordVPN
/ip ipsec identity add auth-method=digital-signature certificate=client.p12_0 generate-policy=port-strict mode-config=NordVPN peer=NordVPN policy-template-group=NordVPN
/ip firewall address-list add address=192.168.88.0/24 list=local
/ip ipsec mode-config set [ find name=NordVPN ] src-address-list=local
```
