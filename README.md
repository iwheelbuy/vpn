# VPN Copy-Paste Install

Этот README снова начинается с рабочего сценария: открыть, заменить пару значений, вставить команды и получить VPN.

Текущая цель на май 2026:

- сервер: Debian 12 VPS + strongSwan IKEv2/IPsec;
- серверный сертификат: Let's Encrypt, для IP используется short-lived IP certificate;
- клиенты: свежие iOS/macOS через `mobileconfig`;
- роутер: MikroTik RouterOS v6 через импорт `.p12`;
- домашняя сеть: PrimeTel роутер уже убран, рабочий WAN path это `ONT -> MikroTik`, `PPPoE + VLAN 42`.

## Быстрая установка на root VPS

Заменить:

- `SERVER` на IP или FQDN сервера;
- `LE_EMAIL` на почту для Let's Encrypt;
- `SSH_KEY` и `SSH_USER`, если вход не `root` по обычному ключу.

Если VPS-провайдер просит SSH key при создании сервера, вставлять нужно публичный ключ:

```sh
pbcopy < ~/.ssh/rabisu_key.pub
```

Приватный `~/.ssh/rabisu_key` остается только на Mac и в панель VPS не копируется.

```sh
SERVER="185.255.93.244"
LE_EMAIL="subscriptions.iwheelbuy@gmail.com"
SSH_KEY="$HOME/.ssh/rabisu_key"
SSH_USER="root"

ssh -i "$SSH_KEY" "$SSH_USER@$SERVER" -p 22
```

На сервере:

```sh
BRANCH="rabisu_primetel"
SERVER="185.255.93.244"

rm -f step1.sh step2.sh
wget "https://raw.githubusercontent.com/iwheelbuy/vpn/${BRANCH}/step1.sh"
wget "https://raw.githubusercontent.com/iwheelbuy/vpn/${BRANCH}/step2.sh"
chmod +x step1.sh step2.sh

LE_EMAIL="subscriptions.iwheelbuy@gmail.com" P12_PASSWORD="123" ./step1.sh "$SERVER"
test -s /root/turkey-v1-client.p12 && ls -la /root/turkey-v1-client.p12
./step2.sh "$SERVER" > turkey-v1.mobileconfig
exit
```

На Mac:

```sh
SERVER="185.255.93.244"
SSH_KEY="$HOME/.ssh/rabisu_key"

scp -i "$SSH_KEY" "root@$SERVER:/root/turkey-v1.mobileconfig" ./
scp -i "$SSH_KEY" "root@$SERVER:/root/turkey-v1-client.p12" ./
```

Если `scp` пишет `No such file or directory` для `/root/turkey-v1-client.p12`, значит отдельный MikroTik `.p12` не был создан. На сервере выполнить:

```sh
openssl pkcs12 -export \
  -in /etc/ipsec.d/certs/client.pem \
  -inkey /etc/ipsec.d/private/client.pem \
  -certfile /etc/ipsec.d/cacerts/root.pem \
  -name "Turkey v1 Client" \
  -keypbe PBE-SHA1-3DES \
  -certpbe PBE-SHA1-3DES \
  -macalg sha1 \
  -passout pass:123 \
  -out /root/turkey-v1-client.p12 \
  -descert

chmod 600 /root/turkey-v1-client.p12
ls -la /root/turkey-v1-client.p12
exit
```

После этого повторить `scp` для `turkey-v1-client.p12`.

После скачивания можно прибраться на сервере:

```sh
SERVER="185.255.93.244"
SSH_KEY="$HOME/.ssh/rabisu_key"

ssh -i "$SSH_KEY" "root@$SERVER" -p 22
rm -f /root/step1.sh /root/step2.sh /root/turkey-v1.mobileconfig /root/turkey-v1-client.p12
exit
```

## Что должно быть открыто у VPS-провайдера

Открыть inbound:

- UDP `500`;
- UDP `4500`;
- TCP `22`;
- TCP `80` для Let's Encrypt HTTP-01 challenge и renew.

Если используется IP вместо домена, `step1.sh` запрашивает Let's Encrypt IP certificate через `--ip-address --preferred-profile shortlived`, поэтому renew запускается каждые 6 часов. Если используется FQDN, `step1.sh` берет обычный Let's Encrypt certificate через `-d`.

## iPhone и macOS

Для Apple-устройств нужен файл:

- `turkey-v1.mobileconfig`

Установка:

1. Передать `turkey-v1.mobileconfig` на iPhone или Mac.
2. Открыть профиль и установить его в Settings/System Settings.
3. Проверить VPN `Turkey v1`.

Серверный сертификат теперь публичный Let's Encrypt, поэтому отдельный root CA для сервера на Apple-устройство ставить не нужно. Внутри `mobileconfig` остается клиентский identity certificate, которым Apple-клиент аутентифицируется на strongSwan.

## MikroTik RouterOS v6

Для MikroTik нужен файл:

- `turkey-v1-client.p12`

Пароль по умолчанию:

```text
123
```

Если нужен другой пароль:

```sh
P12_PASSWORD="другой-пароль" ./step1.sh 185.255.93.244
```

Минимальный RouterOS v6 шаблон:

```routeros
/certificate import file-name=turkey-v1-client.p12 passphrase=123
/tool fetch url="https://letsencrypt.org/certs/isrgrootx1.pem" dst-path=isrgrootx1.pem
/certificate import file-name=isrgrootx1.pem
/certificate set [find where common-name~"ISRG"] trusted=yes
/tool fetch url="http://r13.i.lencr.org/" dst-path=letsencrypt-r13.der
```

После `fetch` импортировать `R13` отдельной командой. На prompt `passphrase:` ничего не вводить, просто нажать Enter:

```routeros
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

Проверка, что базовый tunnel поднялся:

```routeros
/ip ipsec active-peers print detail
/ip ipsec installed-sa print detail
```

Успешное состояние: `active-peers state=established`, `installed-sa state=mature`.

После базового tunnel есть несколько режимов маршрутизации:

- весь трафик одного устройства через VPN через `src-address-list`;
- конкретные сайты через `address-list` + `connection-mark`;
- torrent heuristic через старые `layer7`/peer address-list правила;
- full tunnel для всей LAN.

Подробные operational snippets лежат в [docs/routeros-reference.md](/Users/macuser/Development/vpn1/docs/routeros-reference.md).

## Что делает step1.sh

[step1.sh](/Users/macuser/Development/vpn1/step1.sh):

- ставит `strongswan`, `strongswan-pki`, `iptables-persistent`, `snapd`, `certbot`;
- создает private CA только для клиентских сертификатов;
- выпускает серверный сертификат через Let's Encrypt;
- настраивает `/etc/ipsec.conf`, `/etc/ipsec.secrets`, sysctl и iptables;
- открывает IKEv2/IPsec, NAT и MSS clamp;
- создает `/root/turkey-v1-client.p12` для MikroTik;
- настраивает renew hook, который обновляет `/etc/ipsec.d/certs/server.pem` и перезапускает strongSwan.

## Что делает step2.sh

[step2.sh](/Users/macuser/Development/vpn1/step2.sh):

- генерирует Apple `mobileconfig`;
- встраивает клиентский `.p12` с одноразовым случайным паролем внутри профиля;
- задает `RemoteIdentifier` равным IP/FQDN серверного сертификата;
- задает `LocalIdentifier` равным SAN клиентского сертификата;
- включает On-Demand: дома на trusted Wi-Fi отключаться, на cellular и прочих сетях подключаться.

## Проверка после установки

На сервере:

```sh
ipsec statusall
iptables -S
iptables -t nat -S
systemctl status strongswan-starter --no-pager
certbot certificates
```

На клиенте:

- iPhone/macOS: VPN подключается, внешний IP меняется на VPS;
- MikroTik: появляется active peer/policy, трафик идет через tunnel;
- если policy не активировалась, удалить active peer и дать RouterOS поднять его заново.

## Документация проекта

- [AGENTS.md](/Users/macuser/Development/vpn1/AGENTS.md) - правила безопасных изменений.
- [docs/current-state.md](/Users/macuser/Development/vpn1/docs/current-state.md) - текущий baseline и ограничения.
- [docs/primetel-bypass-runbook.md](/Users/macuser/Development/vpn1/docs/primetel-bypass-runbook.md) - подтвержденный PrimeTel bypass: `PPPoE + VLAN 42`.
- [docs/turkey-deploy.md](/Users/macuser/Development/vpn1/docs/turkey-deploy.md) - короткая deployment шпаргалка под текущий сервер.
