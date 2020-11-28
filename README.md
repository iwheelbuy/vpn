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

# Router OS

```ruby
/certificate import file-name=client.p12 passphrase=123
/ip ipsec profile add name=aws_profile hash-algorithm=sha256 enc-algorithm=aes-128 dh-group=ecp256 proposal-check=obey
/ip ipsec proposal add name=aws_proposal auth-algorithms=sha256 enc-algorithms=aes-128-cbc pfs-group=ecp256
/ip ipsec policy group add name=aws_policy_group
/ip ipsec policy add group=aws_policy_group proposal=aws_proposal template=yes
/ip ipsec mode-config add name=aws_mode_config responder=no
/ip ipsec peer add name=aws_peer address=YOUR_IP_OR_DOMAIN/32 exchange-mode=ike2 profile=aws_profile
/ip ipsec identity add auth-method=digital-signature certificate=client.p12_0 generate-policy=port-strict mode-config=aws_mode_config peer=aws_peer policy-template-group=aws_policy_group
```
