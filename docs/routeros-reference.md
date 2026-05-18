# RouterOS Reference

Этот файл сохраняет RouterOS-команды как operational reference для рабочего baseline. Здесь не обещается, что каждая команда нужна в каждом сценарии, но все они относятся к реальной схеме, которая использовалась на практике.

## Подключение к роутеру

```sh
ssh admin@192.168.88.1
```

## Базовый IPsec для MikroTik, Turkey v1

```sh
/certificate import file-name=turkey-v1-client.p12 passphrase=123
/tool fetch url="https://letsencrypt.org/certs/isrgrootx1.pem" dst-path=isrgrootx1.pem
/certificate import file-name=isrgrootx1.pem
/certificate set [find where common-name~"ISRG"] trusted=yes
/tool fetch url="http://r13.i.lencr.org/" dst-path=letsencrypt-r13.der
```

Важно: `R13` импортировать отдельной командой. На prompt `passphrase:` ничего не вводить, просто нажать Enter. Если дать `import` и следующие команды одной пачкой, RouterOS может проглотить следующую строку как passphrase, и `R13` не появится.

```sh
/certificate import file-name=letsencrypt-r13.der
/certificate set [find where common-name~"R13"] trusted=yes
/ip ipsec profile add name=turkey-v1 hash-algorithm=sha256 enc-algorithm=aes-256 dh-group=modp2048
/ip ipsec proposal add name=turkey-v1 auth-algorithms=sha256 enc-algorithms=aes-256-cbc pfs-group=none
/ip ipsec policy group add name=turkey-v1
/ip ipsec policy add dst-address=0.0.0.0/0 group=turkey-v1 proposal=turkey-v1 src-address=0.0.0.0/0 template=yes
/ip ipsec mode-config add name=turkey-v1 responder=no
/ip ipsec peer add address=185.255.93.244/32 exchange-mode=ike2 name=turkey-v1 profile=turkey-v1
/ip ipsec identity add auth-method=digital-signature certificate=turkey-v1-client.p12_0 generate-policy=port-strict mode-config=turkey-v1 peer=turkey-v1 policy-template-group=turkey-v1
```

Если endpoint меняется, заменить `185.255.93.244/32` на актуальный IP VPS.

Для server certificate от Let's Encrypt на RouterOS v6 уже подтвержденно понадобились `ISRG Root X1` и intermediate `R13`. Без `R13` tunnel падал с ошибками `unable to get local issuer certificate(20)` и `can't verify peer's certificate from store`.

Проверка:

```sh
/certificate print
/ip ipsec active-peers print detail
/ip ipsec installed-sa print detail
/log print where topics~"ipsec" && message~"unable|issuer|verify|authorize|failed|established|mature"
```

Успех выглядит так:

- `active-peers state=established`;
- `installed-sa state=mature`;
- в логе есть `peer authorized`.

Если policy по какой-то причине не активировалась, historical note такой: иногда помогает удалить нужного активного peer, после чего policy активируется заново.

Скриншоты:

- [a.png](/Users/macuser/Development/vpn1/a.png)
- [b.png](/Users/macuser/Development/vpn1/b.png)

## Routing Modes

После того как базовый IKEv2/IPsec tunnel поднят, есть несколько способов выбрать, какой трафик отправлять через VPN.

Практический порядок проверки:

1. Сначала один конкретный клиент через `src-address-list`.
2. Потом selected sites через `address-list` и `connection-mark`.
3. Потом более сложные эвристики вроде torrent detection.
4. Full tunnel для всей LAN только если точно понятно, что сервер и канал тянут.

### One Client Through VPN

Самый простой и надежный режим: все соединения одного устройства идут через VPN.

```sh
/ip firewall address-list add list=turkey-v1-clients address=192.168.88.253
/ip ipsec mode-config set [find name=turkey-v1] connection-mark="" src-address-list=turkey-v1-clients
/ip firewall connection remove [find]
/ip ipsec peer disable [find name=turkey-v1]
/ip ipsec peer enable [find name=turkey-v1]
```

Проверка:

```sh
/ip ipsec policy print detail
/ip ipsec active-peers print detail
/ip ipsec installed-sa print detail
```

Ожидаемо появляется dynamic policy вида `src-address=10.10.10.x/32 dst-address=0.0.0.0/0`.

Откат:

```sh
/ip ipsec mode-config set [find name=turkey-v1] src-address-list="" connection-mark=""
/ip firewall address-list remove [find list=turkey-v1-clients]
```

### Selected Sites Through VPN

Исторический режим из старого README: домены добавляются в `address-list`, соединения к ним получают `connection-mark`, а `mode-config` отправляет этот mark в IPsec.

```sh
/ip firewall address-list add list=turkey-v1-sites address=rzd.ru
/ip firewall address-list add list=turkey-v1-sites address=www.rzd.ru
/ip firewall address-list add list=turkey-v1-sites address=whatismyip.com
/ip firewall address-list add list=turkey-v1-sites address=www.whatismyip.com
/ip firewall mangle add chain=prerouting dst-address-list=turkey-v1-sites action=mark-connection new-connection-mark=turkey-v1 passthrough=yes
/ip ipsec mode-config set [find name=turkey-v1] src-address-list="" connection-mark=turkey-v1
```

Если включен `fasttrack`, для теста его лучше отключить:

```sh
/ip firewall filter disable [find action=fasttrack-connection]
/ip firewall connection remove [find]
```

Проверка:

```sh
/ip firewall address-list print where list=turkey-v1-sites
/ip firewall mangle print stats where new-connection-mark=turkey-v1
/ip firewall connection print detail where connection-mark=turkey-v1
/ip ipsec installed-sa print detail
```

В живой проверке на текущем Turkey v1 path этот режим успешно маркировал соединения (`connection-mark=turkey-v1`), но data-plane до VPS еще требует отдельной проверки. Поэтому для надежного первого включения предпочтительнее `src-address-list` на конкретного клиента.

Откат:

```sh
/ip firewall mangle disable [find new-connection-mark=turkey-v1]
/ip firewall address-list remove [find list=turkey-v1-sites]
/ip ipsec mode-config set [find name=turkey-v1] connection-mark=""
```

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
