# Debian 10 + Static IP

# Lightsail

![](firewall.png)

```ruby

# To be replaced: 45.155.125.94, LIGHTSAIL_ACCESS_CERT, rabisu3_cert, rabisu3_ipsec_namespace, rabisu3

chmod 400 LIGHTSAIL_ACCESS_CERT.pem
ssh -i LIGHTSAIL_ACCESS_CERT.pem admin@45.155.125.94 -p 22
sudo su
rm -rf step1.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/rabisu3/step1.sh" && chmod +x step1.sh && rm -rf step2.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/rabisu3/step2.sh" && chmod +x step2.sh
# Предложенные установки - Y, остальное - Enter. Пароль для сертификата = 123.
./step1.sh 45.155.125.94 rabisu3_cert
ssh -i LIGHTSAIL_ACCESS_CERT.pem admin@45.155.125.94 -p 22
sudo su
cp /root/rabisu3_cert.p12 /home/admin/rabisu3_cert.p12
rm /root/rabisu3_cert.p12
./step2.sh 45.155.125.94 > vpn.mobileconfig
exit
exit
scp -i LIGHTSAIL_ACCESS_CERT.pem admin@45.155.125.94:vpn.mobileconfig ./
scp -i LIGHTSAIL_ACCESS_CERT.pem admin@45.155.125.94:rabisu3_cert.p12 ./
# Не забудьте прибраться после скачивания
ssh -i LIGHTSAIL_ACCESS_CERT.pem admin@45.155.125.94 -p 22
sudo su
rm -rf step1.sh && rm -rf step2.sh && rm -rf vpn.mobileconfig && rm -rf rabisu3_cert.p12
exit
exit
```

# Other VPS providers

```ruby

# To be replaced: 45.155.125.94, rabisu3_cert, rabisu3_ipsec_namespace, rabisu3

ssh root@45.155.125.94 -p 22
rm -rf step1.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/rabisu3/step1.sh" && chmod +x step1.sh && rm -rf step2.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/rabisu3/step2.sh" && chmod +x step2.sh
# Предложенные установки - Y, остальное - Enter. Пароль для сертификата = 123.
./step1.sh 45.155.125.94 rabisu3_cert
ssh root@45.155.125.94 -p 22
./step2.sh 45.155.125.94 > vpn.mobileconfig
exit
scp root@45.155.125.94:vpn.mobileconfig ./
scp root@45.155.125.94:rabisu3_cert.p12 ./
# Не забудьте прибраться после скачивания
ssh root@45.155.125.94 -p 22
rm -rf step1.sh && rm -rf step2.sh && rm -rf vpn.mobileconfig && rm -rf rabisu3_cert.p12
exit
```

# Router OS

### Зайти на роутер через терминал macOS
```ruby
ssh admin@192.168.88.1
```

### Поднять IPsec
```ruby
/certificate import file-name=rabisu3_cert.p12 passphrase=123
/ip ipsec profile add name=rabisu3_ipsec_namespace hash-algorithm=sha256 enc-algorithm=aes-128 dh-group=ecp256
/ip ipsec proposal add name=rabisu3_ipsec_namespace auth-algorithms=sha256 enc-algorithms=aes-128-cbc pfs-group=ecp256
/ip ipsec policy group add name=rabisu3_ipsec_namespace
/ip ipsec policy add dst-address=0.0.0.0/0 group=rabisu3_ipsec_namespace proposal=rabisu3_ipsec_namespace src-address=0.0.0.0/0 template=yes
/ip ipsec mode-config add name=rabisu3_ipsec_namespace responder=no
/ip ipsec peer add address=45.155.125.94/32 exchange-mode=ike2 name=rabisu3_ipsec_namespace profile=rabisu3_ipsec_namespace
/ip ipsec identity add auth-method=digital-signature certificate=rabisu3_cert.p12_0 generate-policy=port-strict mode-config=rabisu3_ipsec_namespace peer=rabisu3_ipsec_namespace policy-template-group=rabisu3_ipsec_namespace
```
### Если по какой-то причине policy не активировалась
![](a.png)
### То стоит удалить нужного активного пира и тогда policy активируется
![](b.png)

### Tорренты через IPsec
Адрес всей локальной сети
```ruby
/ip firewall address-list add address=192.168.88.0/24 list=torrents-local
```
Регулярки для определния торрентов
```ruby
/ip firewall layer7-protocol add name=BitTorrent regexp="\13bittorrent protocol"
/ip firewall layer7-protocol add name=DHT regexp=^d1:.d2:id20:
```
Адреса новых раздач в список торрент адресов
```ruby
/ip firewall mangle add action=add-src-to-address-list address-list=torrents-seeds address-list-timeout=1w chain=forward dst-address-list=torrents-local layer7-protocol=BitTorrent src-address-list=!torrents-seeds
/ip firewall mangle add action=add-dst-to-address-list address-list=torrents-seeds address-list-timeout=1w chain=forward dst-address-list=!torrents-seeds layer7-protocol=BitTorrent src-address-list=torrents-local
/ip firewall mangle add action=add-src-to-address-list address-list=torrents-seeds address-list-timeout=1w chain=forward dst-address-list=torrents-local layer7-protocol=DHT src-address-list=!torrents-seeds
/ip firewall mangle add action=add-dst-to-address-list address-list=torrents-seeds address-list-timeout=1w chain=forward dst-address-list=!torrents-seeds layer7-protocol=DHT src-address-list=torrents-local
```
Пометка конектов к сидам
```ruby
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=rabisu3_ipsec_namespace passthrough=yes src-address-list=torrents-seeds
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=rabisu3_ipsec_namespace passthrough=yes dst-address-list=torrents-seeds
```
Обновить fasttrack и поднять выше на место старого
```ruby
/ip firewall filter add chain=forward action=fasttrack-connection connection-state=established,related connection-mark=!rabisu3_ipsec_namespace
```
Направить торренты через IPsec
```ruby
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] connection-mark=rabisu3_ipsec_namespace
```

### Пометка конектов к русским сайтам, которые не открываются из-за бугра
```ruby
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=rabisu3_ipsec_namespace passthrough=yes src-address-list=russia
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=rabisu3_ipsec_namespace passthrough=yes dst-address-list=russia
```
Список русских сайтов
```
/ip firewall address-list add address=www.pochta.ru list=russia
/ip firewall address-list add address=lk.ttk.ru list=russia
/ip firewall address-list add address=ttk.ru list=russia
/ip firewall address-list add address=whatismyipaddress.com list=russia
```

### Очистить торрент адреса
```ruby
/ip firewall address-list remove [/ip firewall address-list find list=torrents-seeds]
```

### Весь трафик. Не гибкое решение. Обновить fasttrack.
```ruby
/ip firewall address-list add address=192.168.88.0/24 list=rabisu3_ipsec_namespace-src
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] src-address-list=rabisu3_ipsec_namespace-src
/ip firewall mangle add action=mark-connection chain=forward ipsec-policy=out,ipsec new-connection-mark=ipsec
/ip firewall mangle add action=mark-connection chain=forward ipsec-policy=in,ipsec new-connection-mark=ipsec
/ip firewall filter add chain=forward action=fasttrack-connection connection-state=established,related connection-mark=!ipsec
```

### Весь трафик. Гибкое решение. Отключить fasttrack.
```ruby
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] connection-mark=rabisu3_ipsec_namespace
/ip firewall address-list add address=192.168.88.0/24 list=rabisu3_ipsec_namespace-src
/ip firewall mangle add action=mark-connection chain=prerouting src-address-list=rabisu3_ipsec_namespace-src new-connection-mark=rabisu3_ipsec_namespace passthrough=yes
```
но по-моему работает и так
```ruby
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] connection-mark=rabisu3_ipsec_namespace
/ip firewall mangle add action=mark-connection chain=prerouting new-connection-mark=rabisu3_ipsec_namespace passthrough=yes
```

### Только конкретные сайты. Гибкое решение. Отключить fasttrack.
```ruby
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] connection-mark=rabisu3_ipsec_namespace
/ip firewall mangle add action=mark-connection chain=prerouting dst-address-list=rabisu3_ipsec_namespace-dst new-connection-mark=rabisu3_ipsec_namespace passthrough=yes

# protonmail

/ip firewall address-list add address=www.protonmail.com list=rabisu3_ipsec_namespace-dst
/ip firewall address-list add address=mail.protonmail.com list=rabisu3_ipsec_namespace-dst
/ip firewall address-list add address=protonmail.com list=rabisu3_ipsec_namespace-dst
/ip firewall address-list add address=protonmail.recruitee.com list=rabisu3_ipsec_namespace-dst

# rutracker

/ip firewall address-list add address=rutracker.org list=rabisu3_ipsec_namespace-dst
```

### Установить лимит скорости на каждого клиента. Отключить fasttrack.
```ruby
/queue type add kind=pcq name=pcq-upload-custom pcq-classifier=src-address pcq-rate=2M
/queue type add kind=pcq name=pcq-download-custom pcq-classifier=dst-address pcq-rate=2M
/queue simple add name=Throttle-Each queue=pcq-upload-custom/pcq-download-custom target=192.168.1.0/24
```
