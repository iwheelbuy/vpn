# Turkey Deploy

Короткая шпаргалка под текущий сервер. Для объяснений и generic-варианта см. [README.md](/Users/macuser/Development/vpn1/README.md).

## Values

```sh
SERVER="185.255.93.244"
LE_EMAIL="subscriptions.iwheelbuy@gmail.com"
SSH_KEY="$HOME/.ssh/rabisu_key"
BRANCH="rabisu_primetel"
P12_PASSWORD="123"
```

## Install

Если VPS еще создается и панель просит SSH key, скопировать публичный ключ:

```sh
pbcopy < ~/.ssh/rabisu_key.pub
```

Приватный `~/.ssh/rabisu_key` не вставлять в панель провайдера.

На Mac:

```sh
SERVER="185.255.93.244"
SSH_KEY="$HOME/.ssh/rabisu_key"

ssh -i "$SSH_KEY" "root@$SERVER" -p 22
```

На сервере:

```sh
SERVER="185.255.93.244"
LE_EMAIL="subscriptions.iwheelbuy@gmail.com"
BRANCH="rabisu_primetel"
P12_PASSWORD="123"

rm -f step1.sh step2.sh
wget "https://raw.githubusercontent.com/iwheelbuy/vpn/${BRANCH}/step1.sh"
wget "https://raw.githubusercontent.com/iwheelbuy/vpn/${BRANCH}/step2.sh"
chmod +x step1.sh step2.sh

LE_EMAIL="$LE_EMAIL" P12_PASSWORD="$P12_PASSWORD" ./step1.sh "$SERVER"
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

Если `/root/turkey-v1-client.p12` не найден, зайти на сервер и создать его из уже готовых client cert/key:

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

Затем повторить `scp` для `turkey-v1-client.p12`.

## Cleanup

```sh
SERVER="185.255.93.244"
SSH_KEY="$HOME/.ssh/rabisu_key"

ssh -i "$SSH_KEY" "root@$SERVER" -p 22
rm -f /root/step1.sh /root/step2.sh /root/turkey-v1.mobileconfig /root/turkey-v1-client.p12
exit
```

## Artifacts

- `turkey-v1.mobileconfig` - iPhone/macOS profile.
- `turkey-v1-client.p12` - MikroTik client certificate.
- `.p12` password - `123`, unless `P12_PASSWORD` was changed before running `step1.sh`.

## Notes

- TCP `80` must be reachable from the internet for Let's Encrypt.
- UDP `500` and `4500` must be open for IKEv2/IPsec.
- With a bare IP address, the script uses a short-lived Let's Encrypt IP certificate and renews it frequently.
- With an FQDN, the same script uses a normal Let's Encrypt domain certificate.
