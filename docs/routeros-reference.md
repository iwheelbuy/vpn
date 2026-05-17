# RouterOS Reference

Этот файл сохраняет RouterOS-команды как operational reference для рабочего baseline. Здесь не обещается, что каждая команда нужна в каждом сценарии, но все они относятся к реальной схеме, которая использовалась на практике.

## Подключение к роутеру

```sh
ssh admin@192.168.88.1
```

## Базовый IPsec для MikroTik, Turkey v1

```sh
/certificate import file-name=turkey-v1-client.p12 passphrase=123
/ip ipsec profile add name=turkey-v1 hash-algorithm=sha256 enc-algorithm=aes-256 dh-group=modp2048
/ip ipsec proposal add name=turkey-v1 auth-algorithms=sha256 enc-algorithms=aes-256-cbc pfs-group=none
/ip ipsec policy group add name=turkey-v1
/ip ipsec policy add dst-address=0.0.0.0/0 group=turkey-v1 proposal=turkey-v1 src-address=0.0.0.0/0 template=yes
/ip ipsec mode-config add name=turkey-v1 responder=no
/ip ipsec peer add address=185.255.93.244/32 exchange-mode=ike2 name=turkey-v1 profile=turkey-v1
/ip ipsec identity add auth-method=digital-signature certificate=turkey-v1-client.p12_0 generate-policy=port-strict mode-config=turkey-v1 peer=turkey-v1 policy-template-group=turkey-v1
```

Если endpoint меняется, заменить `185.255.93.244/32` на актуальный IP VPS.

Если RouterOS v6 не доверяет серверному Let's Encrypt сертификату, импортировать актуальный ISRG root/intermediate certificate в `/certificate` и выставить ему `trusted=yes`. Это зависит от конкретной версии RouterOS и должно проверяться на живом роутере.

Если policy по какой-то причине не активировалась, historical note такой: иногда помогает удалить нужного активного peer, после чего policy активируется заново.

Скриншоты:

- [a.png](/Users/macuser/Development/vpn1/a.png)
- [b.png](/Users/macuser/Development/vpn1/b.png)

## Torrents Through IPsec

Адрес всей локальной сети:

```sh
/ip firewall address-list add address=192.168.88.0/24 list=torrents-local
```

Регулярки для определения torrent traffic:

```sh
/ip firewall layer7-protocol add name=BitTorrent regexp="\13bittorrent protocol"
/ip firewall layer7-protocol add name=DHT regexp=^d1:.d2:id20:
```

Адреса новых раздач в список torrent адресов:

```sh
/ip firewall mangle add action=add-src-to-address-list address-list=torrents-seeds address-list-timeout=1w chain=forward dst-address-list=torrents-local layer7-protocol=BitTorrent src-address-list=!torrents-seeds
/ip firewall mangle add action=add-dst-to-address-list address-list=torrents-seeds address-list-timeout=1w chain=forward dst-address-list=!torrents-seeds layer7-protocol=BitTorrent src-address-list=torrents-local
/ip firewall mangle add action=add-src-to-address-list address-list=torrents-seeds address-list-timeout=1w chain=forward dst-address-list=torrents-local layer7-protocol=DHT src-address-list=!torrents-seeds
/ip firewall mangle add action=add-dst-to-address-list address-list=torrents-seeds address-list-timeout=1w chain=forward dst-address-list=!torrents-seeds layer7-protocol=DHT src-address-list=torrents-local
```

Пометка коннектов к сидам:

```sh
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=rabisu3_ipsec_namespace passthrough=yes src-address-list=torrents-seeds
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=rabisu3_ipsec_namespace passthrough=yes dst-address-list=torrents-seeds
```

Обновить `fasttrack` и поднять выше на место старого:

```sh
/ip firewall filter add chain=forward action=fasttrack-connection connection-state=established,related connection-mark=!rabisu3_ipsec_namespace
```

Направить torrents через IPsec:

```sh
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] connection-mark=rabisu3_ipsec_namespace
```

## Russian Sites Through IPsec

Пометка коннектов к адресам из списка:

```sh
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=rabisu3_ipsec_namespace passthrough=yes src-address-list=russia
/ip firewall mangle add action=mark-connection chain=forward new-connection-mark=rabisu3_ipsec_namespace passthrough=yes dst-address-list=russia
```

Список адресов:

```sh
/ip firewall address-list add address=www.pochta.ru list=russia
/ip firewall address-list add address=lk.ttk.ru list=russia
/ip firewall address-list add address=ttk.ru list=russia
/ip firewall address-list add address=whatismyipaddress.com list=russia
```

## Cleanup

Очистить torrent addresses:

```sh
/ip firewall address-list remove [/ip firewall address-list find list=torrents-seeds]
```

## Full Tunnel

### Less flexible variant

```sh
/ip firewall address-list add address=192.168.88.0/24 list=rabisu3_ipsec_namespace-src
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] src-address-list=rabisu3_ipsec_namespace-src
/ip firewall mangle add action=mark-connection chain=forward ipsec-policy=out,ipsec new-connection-mark=ipsec
/ip firewall mangle add action=mark-connection chain=forward ipsec-policy=in,ipsec new-connection-mark=ipsec
/ip firewall filter add chain=forward action=fasttrack-connection connection-state=established,related connection-mark=!ipsec
```

### More flexible variant

Отключить `fasttrack`.

```sh
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] connection-mark=rabisu3_ipsec_namespace
/ip firewall address-list add address=192.168.88.0/24 list=rabisu3_ipsec_namespace-src
/ip firewall mangle add action=mark-connection chain=prerouting src-address-list=rabisu3_ipsec_namespace-src new-connection-mark=rabisu3_ipsec_namespace passthrough=yes
```

Historical note: в старых заметках есть и упрощенный вариант ниже; его стоит воспринимать как hypothesis, а не как гарантированную рекомендацию.

```sh
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] connection-mark=rabisu3_ipsec_namespace
/ip firewall mangle add action=mark-connection chain=prerouting new-connection-mark=rabisu3_ipsec_namespace passthrough=yes
```

## Selected Sites Only

Отключить `fasttrack`.

```sh
/ip ipsec mode-config set [ find name=rabisu3_ipsec_namespace ] connection-mark=rabisu3_ipsec_namespace
/ip firewall mangle add action=mark-connection chain=prerouting dst-address-list=rabisu3_ipsec_namespace-dst new-connection-mark=rabisu3_ipsec_namespace passthrough=yes
```

Примеры адресов:

```sh
/ip firewall address-list add address=www.protonmail.com list=rabisu3_ipsec_namespace-dst
/ip firewall address-list add address=mail.protonmail.com list=rabisu3_ipsec_namespace-dst
/ip firewall address-list add address=protonmail.com list=rabisu3_ipsec_namespace-dst
/ip firewall address-list add address=protonmail.recruitee.com list=rabisu3_ipsec_namespace-dst
/ip firewall address-list add address=rutracker.org list=rabisu3_ipsec_namespace-dst
```

## Per-Client Speed Limit

Отключить `fasttrack`.

```sh
/queue type add kind=pcq name=pcq-upload-custom pcq-classifier=src-address pcq-rate=2M
/queue type add kind=pcq name=pcq-download-custom pcq-classifier=dst-address pcq-rate=2M
/queue simple add name=Throttle-Each queue=pcq-upload-custom/pcq-download-custom target=192.168.1.0/24
```
