# Lightsail Debian 10.5 + Static IP

![](firewall.png)

# Terminal

```ruby
ssh root@62.109.4.165 -p 22
rm -rf step1.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/firstvds/step1.sh" && chmod +x step1.sh && rm -rf step2.sh && wget "https://raw.githubusercontent.com/iwheelbuy/vpn/firstvds/step2.sh" && chmod +x step2.sh
# Предложенные установки - Y, остальное - Enter. Пароль для сертификата = 123.
./step1.sh 62.109.4.165
ssh root@62.109.4.165 -p 22
./step2.sh 62.109.4.165 > vpn.mobileconfig
exit
exit
scp root@62.109.4.165:vpn.mobileconfig ./
scp root@62.109.4.165:client.p12 ./
# Не забудьте прибраться после скачивания
ssh -i YOUR_CERTIFICATE_NAME.pem root@62.109.4.165 -p 22
sudo su
rm -rf step1.sh && rm -rf step2.sh && rm -rf vpn.mobileconfig && rm -rf client.p12
exit
exit
```

# Router OS

### Зайти на роутер через терминал macOS
```ruby
ssh admin@192.168.88.1
```

### Поднять IPsec
```ruby
/certificate import file-name=client.p12 passphrase=123
/ip ipsec profile add name=firstvds hash-algorithm=sha256 enc-algorithm=aes-128 dh-group=ecp256
/ip ipsec proposal add name=firstvds auth-algorithms=sha256 enc-algorithms=aes-128-cbc pfs-group=ecp256
/ip ipsec policy group add name=firstvds
/ip ipsec policy add dst-address=0.0.0.0/0 group=firstvds proposal=firstvds src-address=0.0.0.0/0 template=yes
/ip ipsec mode-config add name=firstvds responder=no
/ip ipsec peer add address=62.109.4.165/32 exchange-mode=ike2 name=firstvds profile=firstvds
/ip ipsec identity add auth-method=digital-signature certificate=client.p12_0 generate-policy=port-strict mode-config=firstvds peer=firstvds policy-template-group=firstvds
```

### Правила для поиска торрентов
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
/ip firewall mangle add action=add-src-to-address-list address-list=torrents-seeds address-list-timeout=none-dynamic chain=forward dst-address-list=torrents-local layer7-protocol=BitTorrent src-address-list=!torrents-seeds comment="BitTorrent in"
/ip firewall mangle add action=add-dst-to-address-list address-list=torrents-seeds address-list-timeout=none-dynamic chain=forward dst-address-list=!torrents-seeds layer7-protocol=BitTorrent src-address-list=torrents-local comment="BitTorrent out"
/ip firewall mangle add action=add-src-to-address-list address-list=torrents-seeds address-list-timeout=none-dynamic chain=forward dst-address-list=torrents-local layer7-protocol=DHT src-address-list=!torrents-seeds comment="DHT in"
/ip firewall mangle add action=add-dst-to-address-list address-list=torrents-seeds address-list-timeout=none-dynamic chain=forward dst-address-list=!torrents-seeds layer7-protocol=DHT src-address-list=torrents-local comment="DHT out"
```
Пометка конектов к сидам
```ruby
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=torrents passthrough=yes src-address-list=torrents-seeds comment="Mark in connection"
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=torrents passthrough=yes dst-address-list=torrents-seeds comment="Mark out connection"
```

### Очистить торрент адреса
```ruby
/ip firewall address-list remove [/ip firewall address-list find list=torrent]
```

### Весь трафик. Не гибкое решение. Обновить fasttrack.
```ruby
/ip firewall address-list add address=192.168.88.0/24 list=firstvds-src
/ip ipsec mode-config set [ find name=firstvds ] src-address-list=firstvds-src
/ip firewall mangle add action=mark-connection chain=forward ipsec-policy=out,ipsec new-connection-mark=ipsec comment="firstvds"
/ip firewall mangle add action=mark-connection chain=forward ipsec-policy=in,ipsec new-connection-mark=ipsec comment="firstvds"
/ip firewall filter add chain=forward action=fasttrack-connection connection-state=established,related connection-mark=!ipsec comment="firstvds"
```

### Весь трафик. Гибкое решение. Отключить fasttrack.
```ruby
/ip ipsec mode-config set [ find name=firstvds ] connection-mark=firstvds
/ip firewall address-list add address=192.168.88.0/24 list=firstvds-src
/ip firewall mangle add action=mark-connection chain=prerouting src-address-list=firstvds-src new-connection-mark=firstvds passthrough=yes
```
но по-моему работает и так
```ruby
/ip ipsec mode-config set [ find name=firstvds ] connection-mark=firstvds
/ip firewall mangle add action=mark-connection chain=prerouting new-connection-mark=firstvds passthrough=yes
```

### Только конкретные сайты. Гибкое решение. Отключить fasttrack.
```ruby
/ip ipsec mode-config set [ find name=firstvds ] connection-mark=firstvds
/ip firewall mangle add action=mark-connection chain=prerouting dst-address-list=firstvds-dst new-connection-mark=firstvds passthrough=yes

# protonmail

/ip firewall address-list add address=www.protonmail.com list=firstvds-dst
/ip firewall address-list add address=mail.protonmail.com list=firstvds-dst
/ip firewall address-list add address=protonmail.com list=firstvds-dst
/ip firewall address-list add address=protonmail.recruitee.com list=firstvds-dst

# rutracker

/ip firewall address-list add address=rutracker.org list=firstvds-dst
```

### Установить лимит скорости на каждого клиента. Отключить fasttrack.
```ruby
/queue type add kind=pcq name=pcq-upload-custom pcq-classifier=src-address pcq-rate=2M
/queue type add kind=pcq name=pcq-download-custom pcq-classifier=dst-address pcq-rate=2M
/queue simple add name=Throttle-Each queue=pcq-upload-custom/pcq-download-custom target=192.168.1.0/24
```
