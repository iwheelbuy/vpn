# PrimeTel Bypass Runbook

## Goal

Цель этого runbook: убрать управляемый роутер PrimeTel из домашней схемы, если это возможно без замены провайдера и без использования PrimeTel TV.

Желаемая целевая схема:

`fiber -> ONT -> MikroTik -> home network`

Здесь:

- `ONT` остается как провайдерская оптическая коробка, если она уже выдает обычный Ethernet;
- PrimeTel роутер полностью убирается из тракта;
- MikroTik берет на себя WAN, NAT, маршрутизацию и затем VPN/policy-routing задачи.

## Confirmed Working Direction

По итогам живого теста уже подтверждено следующее:

- PrimeTel интернет можно поднять без PrimeTel роутера;
- рабочая логика использует `VLAN 42`;
- транспорт это `PPPoE`;
- реальные PPPoE credentials можно вытащить через сниффинг промежуточной сессии;
- после подстановки `MAC`, `VLAN 42` и корректных `PPPoE` credentials соединение поднимается.
- финальная рабочая физическая схема: `fiber -> Huawei ONT -> MikroTik -> home network`

Это означает, что bypass PrimeTel для internet-only сценария не является теорией, а уже подтвержден практикой.

## Final Outcome

На текущем этапе подтвержден реальный working path для internet-only сценария:

1. Оставить провайдерский `Huawei ONT`.
2. Убрать `ZTE ZXHN H268Q` из тракта.
3. Поднять на MikroTik:
   - clone WAN MAC;
   - `VLAN 42`;
   - `PPPoE client`;
   - `NAT`;
   - локальный DNS relay для клиентов.
4. Подключить `ONT -> ether1 MikroTik`.
5. Дождаться, пока PPPoE-сессия поднимется и ONT/провайдер отпустит старую сессию.

Замечание по поведению:

- после замены `ZTE` на `MikroTik` интернет может подняться не мгновенно;
- в живом тесте сначала не было default route и `ping` не шел;
- спустя небольшую задержку `PPPoE` поднялся и интернет заработал.

## Working Parameters

Для текущего подключения подтверждены такие параметры:

- WAN protocol: `PPPoE`
- VLAN ID: `42`
- PPPoE username: extracted successfully during PAP fallback test
- PPPoE password: extracted successfully from PAP capture
- working WAN MAC: был успешно использован MAC, который ZTE реально использовал как PPPoE source MAC

Важно:

- реальные credentials и живые backup-файлы не должны коммититься в git;
- в документации лучше хранить сам процесс, а не секреты в открытом виде;
- если нужен локальный backup MikroTik, его лучше хранить вне репозитория или в зашифрованном виде.

## Why This Exists

Сейчас PrimeTel роутер полностью закрыт и не управляется локально. Из-за этого:

- нельзя нормально настраивать его WAN/LAN логику;
- нельзя уверенно отключать лишние функции;
- неудобно строить чистую схему с MikroTik;
- сложно контролировать NAT и дальнейший VPN routing.

Поэтому первая цель не GPON-stick, а именно попытка подключить MikroTik напрямую к ONT.

## Current Hypotheses

Порядок проверки такой:

1. `PPPoE + VLAN 42`
2. `DHCP/IPoE + VLAN 42`
3. `PPPoE` или `DHCP` на другом VLAN
4. `MAC clone` WAN-интерфейса PrimeTel роутера
5. Дополнительный provider-specific вариант, если всплывут PPPoE credentials или другие настройки
6. Только потом замена ONT через `GPON/ONU/SFP stick`

Важно: `VLAN 42` сейчас является рабочей гипотезой, а не подтвержденным фактом именно для этого подключения.

Update after live test: для этого конкретного подключения `VLAN 42 + PPPoE` уже можно считать подтвержденным фактом.

## What Is Needed From The User

Перед выездом в дом или до начала тестов желательно собрать:

- точную модель ONT;
- фото или текст со стикера ONT;
- точную модель PrimeTel роутера;
- фото или текст со стикера PrimeTel роутера;
- какой порт ONT сейчас подключен к WAN PrimeTel роутера;
- есть ли на PrimeTel роутере наклейка с WAN MAC или PPPoE-данными;
- есть ли в договоре, письмах или SMS от PrimeTel логин/пароль для интернета;
- нужен ли только интернет, без TV и без телефонии.

Полезно отдельно зафиксировать:

- MAC-адрес WAN-порта PrimeTel роутера, если его получится где-то увидеть;
- текущую рабочую схему кабелей;
- что происходит по индикаторам ONT после отключения PrimeTel и подключения MikroTik.

## Hardware Identified From Photos

По состоянию на 16 мая 2026 из фотографий уже удалось определить:

- PrimeTel роутер: `ZTE ZXHN H268Q`
- MAC на корпусе PrimeTel роутера: `34:36:54:FE:8F:ED`
- ONT: `Huawei OptiXstar HG8010H V6` или близкая маркировка `HG8010Hv6`
- ONT сейчас подключен так, что Ethernet с ONT идет в `WAN` порт ZTE
- у ONT на фото горят `POWER` и `PON`, `LOS` не горит, что похоже на нормальное состояние линка

Это уже закрывает значительную часть `Step 0`.

## Current Physical Layout

По фотографиям текущая физическая схема выглядит так:

`fiber -> Huawei ONT -> Ethernet -> ZTE ZXHN H268Q WAN -> PrimeTel router LAN -> home network`

Для bypass-теста целевая временная перестановка такая:

`fiber -> Huawei ONT -> Ethernet -> MikroTik ether1`

Но PrimeTel роутер нужно держать под рукой, чтобы быстро вернуть рабочую схему.

## Suggested Session Workflow

Во время следующей сессии с агентом удобно сообщать один из статусов:

- `Step 0`: еще только собираем данные с ONT и PrimeTel.
- `Step 1`: тестируем `PPPoE + VLAN 42`.
- `Step 2`: тестируем `DHCP/IPoE + VLAN 42`.
- `Step 3`: тестируем другие VLAN.
- `Step 4`: тестируем `MAC clone`.
- `Step 5`: решаем, идем ли в GPON-stick/ONU replacement.

Текущее реальное состояние после фото:

- `Step 0` частично пройден;
- модели устройств уже известны;
- исторически следующая практическая точка входа была `Step 1`, но сейчас уже есть подтвержденный working path и главная задача сместилась в его аккуратную фиксацию и перенос на MikroTik.

## Breakthrough Summary

Был использован следующий практический алгоритм:

1. Подключить WAN MikroTik в ноутбук.
2. Создать VLAN-интерфейс на физическом интерфейсе.
3. Поднять локальный PPPoE server на этом VLAN.
4. Включить Wireshark и снять попытку аутентификации клиентского устройства.
5. Вытащить реальные PPPoE login/password.
6. Настроить на целевом роутере:
   - MAC, который ожидает схема;
   - `VLAN 42`;
   - реальные PPPoE credentials.
7. Проверить, что интернет поднимается без PrimeTel роутера.

По сообщению пользователя это уже сработало на Keenetic:

- в Keenetic был подставлен MAC MikroTik;
- был выставлен `VLAN 42`;
- были добавлены проснифанные `PPPoE` login/password;
- соединение поднялось успешно.

Это очень важный operational result: логика провайдера совместима с third-party router при наличии правильных параметров.

Дополнительный важный результат:

- обычный `PPPoE trap` сначала дал только логин, потому что ZTE предпочитал `CHAP/MS-CHAP`;
- после ограничения тестового PPPoE server до `PAP` ZTE начал слать пароль в PAP payload;
- plaintext credentials были успешно извлечены из `.pcap` через Wireshark.

## Test Assumptions For MikroTik

Ниже команды даны для такого предположения:

- `ether1` это WAN, который идет в ONT;
- `ether2` это временный LAN-порт для ноутбука;
- MikroTik можно безопасно сбросить;
- RouterOS v6 CLI доступен через терминал;
- локальная сеть MikroTik на время теста будет `192.168.88.0/24`.

Если у модели другие порты, нужно просто заменить имена интерфейсов.

## Safety Before Testing

Перед началом:

1. Сохранить текущий экспорт конфигурации MikroTik, если на нем уже есть что-то полезное.
2. Подготовить ноутбук с Ethernet.
3. Держать PrimeTel роутер рядом, чтобы можно было быстро вернуть интернет.
4. На время тестов не смешивать VPN-конфигурацию с WAN-диагностикой.

## Minimal Reset And Base LAN Setup

После reset или на чистом MikroTik сначала нужен минимальный доступ с ноутбука.

Команды:

```routeros
/system identity set name=primetel-bypass-test
/interface bridge add name=bridge-lan
/interface bridge port add bridge=bridge-lan interface=ether2
/ip address add address=192.168.88.1/24 interface=bridge-lan
/ip pool add name=pool-lan ranges=192.168.88.100-192.168.88.199
/ip dhcp-server add name=dhcp-lan interface=bridge-lan address-pool=pool-lan disabled=no
/ip dhcp-server network add address=192.168.88.0/24 gateway=192.168.88.1 dns-server=1.1.1.1,8.8.8.8
/ip dns set allow-remote-requests=yes servers=1.1.1.1,8.8.8.8
```

Если нужно, можно добавить остальные LAN-порты в bridge:

```routeros
/interface bridge port add bridge=bridge-lan interface=ether3
/interface bridge port add bridge=bridge-lan interface=ether4
/interface bridge port add bridge=bridge-lan interface=ether5
```

## Variant A

### Step 1: PPPoE Over VLAN 42

Это первая и главная попытка.

Команды:

```routeros
/interface vlan add name=vlan42-wan interface=ether1 vlan-id=42
/interface pppoe-client add name=pppoe-out1 interface=vlan42-wan user="PPPOE_LOGIN" password="PPPOE_PASSWORD" add-default-route=yes use-peer-dns=yes disabled=no max-mtu=1492 max-mru=1492
/ip firewall nat add chain=srcnat out-interface=pppoe-out1 action=masquerade
```

Проверки:

```routeros
/interface pppoe-client print detail
/log print where message~"pppoe"
/ip address print
/ping 1.1.1.1
/ping 8.8.8.8
/tool traceroute 1.1.1.1
```

Признаки успеха:

- интерфейс `pppoe-out1` поднялся;
- MikroTik получил WAN IP;
- `ping` наружу работает;
- есть default route через `pppoe-out1`.

Update after live tests:

- discovery и auth path на `PPPoE + VLAN 42` подтверждены;
- при тестовых credentials была ошибка аутентификации;
- после получения реальных credentials схема оказалась рабочей.

Если PPPoE credentials неизвестны:

- сначала проверить документы от PrimeTel;
- затем попробовать запросить у поддержки только интернет-логин/пароль;
- если логин/пароль недоступны, переходить к следующему шагу, потому что возможно у провайдера IPoE/DHCP.

### Step 2: DHCP Or IPoE Over VLAN 42

Если `PPPoE + VLAN 42` не взлетел, пробуем DHCP на том же VLAN.

Сначала отключить PPPoE-клиент:

```routeros
/interface pppoe-client disable pppoe-out1
```

Дальше:

```routeros
/ip dhcp-client add interface=vlan42-wan add-default-route=yes use-peer-dns=yes disabled=no
/ip firewall nat add chain=srcnat out-interface=vlan42-wan action=masquerade
```

Проверки:

```routeros
/ip dhcp-client print detail
/log print where message~"dhcp"
/ip route print
/ip address print
/ping 1.1.1.1
```

## Variant B

### Step 3: Try Other VLAN IDs

Если `VLAN 42` не работает ни с PPPoE, ни с DHCP, рабочая гипотеза может быть в другом VLAN.

Удобная тактика:

1. Удалить или отключить старый DHCP/PPPoE клиент.
2. Менять только VLAN ID.
3. На каждом VLAN пробовать сначала `DHCP`, потом `PPPoE`, или наоборот, если есть зацепки по провайдеру.

Пример для `VLAN 10`:

```routeros
/interface vlan set vlan42-wan name=vlan10-wan vlan-id=10
/ip dhcp-client add interface=vlan10-wan add-default-route=yes use-peer-dns=yes disabled=no
```

Если нужен новый VLAN вместо переименования, можно так:

```routeros
/interface vlan add name=vlanXX-wan interface=ether1 vlan-id=XX
```

Практически имеет смысл проверять только те VLAN, для которых есть основания:

- данные из форумов;
- подсказки от провайдера;
- параметры, найденные на наклейках, в письмах или в интернете;
- захват трафика между ONT и PrimeTel, если до этого дойдет отдельной задачей.

### Step 4: MAC Clone

Если провайдер или ONT ожидает знакомый MAC, можно попробовать клонировать MAC WAN-интерфейса PrimeTel роутера.

Команда:

```routeros
/interface ethernet set ether1 mac-address=AA:BB:CC:DD:EE:FF
```

После этого обычно полезно:

```routeros
/interface disable ether1
/interface enable ether1
```

И затем повторить попытки:

- `DHCP` без VLAN;
- `DHCP` на `VLAN 42`;
- `PPPoE` на `VLAN 42`.

Практический update: в живом обходе оказался значим MAC, который был подставлен на целевом роутере. Этот шаг нельзя считать факультативным, если без него сессия не поднимается.

Нужно отдельно фиксировать, какой именно MAC оказался рабочим в финальной схеме:

- MAC PrimeTel роутера;
- MAC MikroTik WAN;
- MAC, который был вбит вручную на альтернативном роутере.

## Optional Direct DHCP Without VLAN

Хотя основной упор идет на VLAN-сценарии, иногда есть смысл быстро проверить и прямой DHCP без VLAN:

```routeros
/ip dhcp-client add interface=ether1 add-default-route=yes use-peer-dns=yes disabled=no
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

Это не основной вариант, но он дешевый по времени.

## Useful Diagnostics On MikroTik

Полезные команды во время тестов:

```routeros
/interface print
/interface ethernet print detail
/interface vlan print detail
/interface monitor-traffic ether1
/ip dhcp-client print detail
/interface pppoe-client print detail
/ip route print detail
/ip address print detail
/log print
/ping 1.1.1.1
/ping 8.8.8.8
```

Если нужно проверить только link-state:

```routeros
/interface ethernet monitor ether1
```

## What To Report Back After Each Attempt

После каждой попытки полезно принести агенту:

- какой именно шаг тестировался;
- какие команды были применены;
- поднялся ли link на `ether1`;
- появился ли IP на WAN;
- появился ли default route;
- работает ли `ping 1.1.1.1`;
- что показывает `/log print`;
- какая модель ONT и PrimeTel роутера.

Для этого конкретного кейса модели уже известны, так что дальше особенно важны:

- сработал ли `PPPoE + VLAN 42`;
- появился ли WAN IP;
- нужно ли искать PPPoE credentials;
- помогает ли `DHCP/IPoE` на том же VLAN;
- есть ли необходимость в `MAC clone`.

## Future Attempts If ONT To MikroTik Fails

Если обычный Ethernet handoff от ONT не удастся использовать напрямую, следующие варианты такие:

1. Достать точные WAN-параметры PrimeTel через документы, саппорт или захват трафика.
2. Исследовать, есть ли `MAC binding` или provider-specific provisioning.
3. Проверить, можно ли временно вставить managed switch между ONT и PrimeTel для наблюдения за negotiation и VLAN.
4. Отдельно изучить замену ONT через `GPON/ONU/SFP stick`.

На текущем этапе этот раздел уже менее приоритетен, потому что обычный Ethernet handoff от ONT и third-party router path оказались работоспособными.

## GPON Stick Path

Этот путь пока не первый.

К нему имеет смысл переходить, если:

- ONT -> MikroTik по Ethernet не работает;
- выяснится, что PrimeTel/ONT-связка держится на более глубокой provider provisioning логике;
- появятся точные данные по GPON identity, совместимой с сетью провайдера.

Что тогда потребуется дополнительно:

- модель ONT;
- серийный номер ONT;
- возможно `LOID`, `PLOAM` или другие GPON identity поля;
- понимание, совместим ли конкретный GPON module/stick с OLT провайдера.

## Session State

Текущий статус этого runbook:

- baseline-гипотеза уже подтверждена практически;
- `PPPoE + VLAN 42` подтверждены как рабочие для этого подключения;
- реальные credentials были успешно извлечены через сниффинг;
- bypass с third-party router уже сработал;
- bypass именно на MikroTik тоже сработал;
- GPON-stick уходит в низкий приоритет как исследовательский запасной трек;
- модели уже частично подтверждены по фото:
  - `Huawei OptiXstar HG8010H V6` ONT
  - `ZTE ZXHN H268Q` роутер PrimeTel
- еще не подтверждены PPPoE credentials и не снят WAN MAC именно с WAN-стороны логически, хотя MAC корпуса ZTE уже известен.
- 16 мая 2026 выполнен живой тест `ONT -> MikroTik ether1 -> VLAN 42 -> PPPoE`.
- На `ether1` есть нормальный линк `1Gbps full-duplex`.
- PPPoE discovery на `VLAN 42` отвечает, но с тестовыми значениями получена ошибка `failed to authenticate ourselves to peer`.
- Это сильный признак, что `VLAN 42 + PPPoE` действительно является правильным направлением, а текущий блокер это именно отсутствие реальных PPPoE credentials.
- DHCP на `VLAN 42` пока не подтвержден как рабочий; приоритет смещается на поиск PPPoE логина/пароля.
- После этого credentials были получены, и пользователь подтвердил успешный запуск на Keenetic с `VLAN 42`, рабочим `MAC` и проснифанными `PPPoE` данными.
- После этого схема была перенесена на MikroTik, и интернет поднялся напрямую через `ONT -> MikroTik`.

Следующее минимальное действие от пользователя:

- сделать локальный backup MikroTik вне git;
- задокументировать рабочую WAN-конфигурацию в санитайзед виде;
- затем переходить к следующему этапу: VPN/policy-routing уже поверх прямого `ONT -> MikroTik` подключения.
