# Current State

## Summary

На май 2026 года этот репозиторий фиксирует рабочий baseline VPN-схемы:

- VPS поднимает IKEv2/IPsec на базе strongSwan.
- Для нового Turkey v1 path серверный сертификат выпускается через Let's Encrypt, включая short-lived IP certificate для bare IP endpoint.
- Apple-клиент получает `mobileconfig` с сертификатной аутентификацией.
- iPhone подтвержденно работает с этой схемой.
- MikroTik RouterOS v6 используется как рабочая точка для IPsec-маршрутизации и selective/full tunnel сценариев.

Параллельно с этим baseline у проекта есть отдельный исследовательский трек по домашней сети пользователя: попытка убрать управляемый PrimeTel роутер из схемы и заменить его прямым подключением `ONT -> MikroTik`. Этот трек не считается подтвержденным baseline и документируется отдельно в [docs/primetel-bypass-runbook.md](/Users/macuser/Development/vpn1/docs/primetel-bypass-runbook.md).

Этот baseline важен сам по себе: он рабочий, пусть и исторически накопленный. Документация не должна подменять его "идеализированной" версией.

## Main Flow

### 1. VPS setup

[step1.sh](/Users/macuser/Development/vpn1/step1.sh) делает следующее:

- обновляет пакеты;
- ставит `strongswan`, `strongswan-pki`, `iptables-persistent`, `zsh`, `snapd` и свежий `certbot`;
- генерирует private root CA для client certificate;
- выпускает публично доверенный server certificate через Let's Encrypt;
- создает `/etc/ipsec.conf` и `/etc/ipsec.secrets`;
- включает `ip_forward` и связанные sysctl-настройки;
- настраивает `iptables` для IKE/IPsec и NAT;
- экспортирует клиентский сертификат в `.p12`.

Ключевые параметры текущего baseline:

- IKE для нового Turkey v1 path: `aes256-sha256-modp2048!`
- ESP для нового Turkey v1 path: `aes256-sha256!`
- server auth: certificate
- client auth: certificate
- right source pool: `10.10.10.0/24`
- DNS: `1.1.1.1`, `8.8.8.8`

### 2. Apple profile generation

[step2.sh](/Users/macuser/Development/vpn1/step2.sh) генерирует `mobileconfig`, внутри которого:

- создается IKEv2 VPN payload;
- встраивается клиентский `.p12`;
- root CA для server trust больше не встраивается в Apple profile, потому что server certificate должен быть публично доверенным Let's Encrypt certificate;
- включается `OnDemandEnabled`;
- задаются trusted Wi-Fi SSID, на которых VPN автоматически отключается;
- на cellular и на прочих сетях профиль пытается подключаться автоматически.

Это важная часть baseline, потому что рабочее поведение на iPhone зависит не только от сервера, но и от конкретного содержимого `mobileconfig`.

### 3. MikroTik usage

Исторические команды RouterOS из старого README остаются полезными как operational reference:

- импорт `.p12` на роутер;
- создание `profile`, `proposal`, `policy group`, `mode-config`, `peer`, `identity`;
- selective routing через `mangle` и `connection-mark`;
- учет влияния `fasttrack`;
- варианты для torrent traffic, списка отдельных сайтов и full tunnel.

Сами команды вынесены в [docs/routeros-reference.md](/Users/macuser/Development/vpn1/docs/routeros-reference.md), чтобы не смешивать baseline-описание с длинной operational-шпаргалкой.

Важно: RouterOS-команды здесь не являются "абстрактным примером". Они описывают реально используемый operational pattern и не должны упрощаться без причины.

## Generic Vs Provider-Specific

### Generic

К generic части относятся:

- strongSwan как IKEv2/IPsec termination point;
- certificate-based auth;
- Apple `mobileconfig`;
- MikroTik selective/full tunnel routing logic;
- необходимость открыть UDP `500` и `4500`;
- экспорт клиентского PKCS#12 и импорт на клиентские устройства.

### Provider-specific

К provider-specific части относятся:

- способ входа на сервер;
- имя пользователя (`root`, `admin` и т.п.);
- firewall/security group конкретного провайдера;
- особенности bootstrap-окружения;
- возможный статический IP или DNS-имя.

Текущий репозиторий исторически содержит следы сценариев для Rabisu и AWS, но сам подход не привязан только к ним.

## Known Limitations

- README ранее был больше набором команд, чем документацией.
- Скрипты не параметризованы как полноценный reusable toolchain.
- В репозитории смешаны рабочие шаги, исторические заметки и provider-specific детали.
- В `step1.sh` и `step2.sh` есть значения и решения, которые сегодня хочется перепроверить с точки зрения безопасности и совместимости, но пока они считаются частью рабочего baseline.
- Старый self-signed server certificate path работал на iPhone, но был слабым местом для свежих macOS/iOS из-за trust behavior. Новый path пытается убрать это через Let's Encrypt server certificate, но требует живой проверки на iOS/macOS/MikroTik.

## Safety Notes

- Наличие рабочего состояния важнее "красивого" рефакторинга.
- Любые изменения в сертификатах, CA, SAN/CN, алгоритмах, `Payload*` полях и RouterOS policy-routing должны считаться потенциально ломающими.
- Переход на Let's Encrypt server certificate является поведенческим изменением, а не простым рефакторингом: его нужно проверять на реальном Apple-клиенте и RouterOS v6.
- Файл `rabisu3-client.p12` сейчас находится в рабочем дереве как локальный артефакт и не должен попадать в историю репозитория.

## Recommended Near-Term Improvements

Вот короткий список улучшений, которые выглядят полезными и относительно безопасными:

1. `.gitignore` для `.p12` и `.mobileconfig` уже стоит держать как базовую защиту от случайного коммита.
2. Вынести provider-specific команды из основного README в отдельный раздел или файл-пример.
3. Отделить "рабочий baseline" от "идей для улучшений", чтобы агент не принимал старые заметки за обязательную конфигурацию.
4. Сделать dry documentation для ручной проверки: что именно проверять после каждого изменения.
5. Позже аккуратно проверить, какие параметры мешают нормальной установке профиля на macOS, не ломая iPhone-сценарий.
