# Lightsail Debian 10.5

![](firewall.png)

# Terminal

```ruby
chmod 400 YOUR_CERTIFICATE_NAME.pem
ssh -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN -p 22
sudo su
rm -rf step1.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/develop/step1.sh" && chmod +x step1.sh && rm -rf step2.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/develop/step2.sh" && chmod +x step2.sh
./step1.sh YOUR_IP_OR_DOMAIN (предложенные установки = Y. Остальное Enter. Любой пароль для сертификата)
ssh -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN -p 22
sudo su
./step2.sh YOUR_IP_OR_DOMAIN > vpn.mobileconfig
exit
exit
scp -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN:vpn.mobileconfig ./
scp -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN:client.p12 ./
ssh -i YOUR_CERTIFICATE_NAME.pem admin@YOUR_IP_OR_DOMAIN -p 22
sudo su
rm -rf step1.sh && rm -rf step2.sh && rm -rf vpn.mobileconfig (не забудьте прибраться после скачивания)
exit
exit
```
