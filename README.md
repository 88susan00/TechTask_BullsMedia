# Multi-Site Reverse Proxy Infrastructure (DevOps Test Task)

Повноцінне рішення для розгортання та автоматичного моніторингу мультисайтового веб-середовища на базі Docker Compose із маршрутизацією через Nginx Reverse Proxy, налаштуванням фаєрволу та watchdog-скриптом самовідновлення (auto-healing).

---

## Архітектура проекту

Стек складається з наступних компонентів, що працюють у єдиній ізольованій Docker-мережі (`web`):

```
                       [ Інтернет / Клієнт ]
                                 │
                            Порт 80 (HTTP)
                                 ▼
                     ┌───────────────────────┐
                     │  Nginx Reverse Proxy  │
                     │     (порт 80:80)      │
                     └───────────┬───────────┘
                                 │
     ┌───────────────────────────┼───────────────────────────┐
     │ /site1/                   │ /site2/                   │ /site3/
     ▼                           ▼                           ▼
┌──────────────┐            ┌──────────────┐            ┌────────────────────────┐
│    site1     │            │    site2     │            │         site3          │
│ (Static HTML)│            │ (Static HTML)│            │   (PHP 8.3 CLI Built-in)│
│  порт 80     │            │  порт 80     │            │      порт 8083         │
└──────────────┘            └──────────────┘            └────────────────────────┘
                                                                    
```

* **`proxy` (Nginx:alpine):** Єдина публічна точка входу (порт `80`). Приймає запити, прокидає заголовки клієнта (`Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) та перенаправляє трафік на відповідні внутрішні сервіси.
* **`site1` & `site2`:** Статичні веб-сервери Nginx, доступні за шляхами `/site1/` та `/site2/`.
* **`site3`:** PHP-додаток на базі PHP 8.3 CLI (слухає порт `8083`), доступний за шляхом `/site3/`, з вбудованим ендпоінтом `/healthz` для моніторингу стану.
* **Watchdog Script (`all-services-check.sh`):** Фоновий скрипт для регулярної перевірки працездатності контейнерів через Docker Health status та автоматичного перезапуску в разі збою.

---

## 📂 Структура репозиторію

```text
TechTask_BullsMedia/
├── docker-compose.yml        # Головний маніфест запуску та зв'язку сервісів
├── all-services-check.sh     # Скрипт моніторингу та автоперезапуску сервісів
├── proxy/
│   └── nginx.conf            # Конфігурація зворотного проксі (upstream та location)
├── site1/
│   ├── Dockerfile
│   ├── index.html
│   └── nginx.conf
├── site2/
│   ├── Dockerfile
│   ├── index.html
│   └── nginx.conf
├── site3/
│   ├── Dockerfile            # Збірка PHP 8.3 CLI контейнера (порт 8083)
│   └──index.php             # Основний додаток та обробка /healthz
└── README.md                 # Документація та покрокова інструкція
```

---

## Покрокова інструкція розгортання на «голому» сервері (Bare-metal / VPS)

Інструкція протестована на **Ubuntu 22.04 / 24.04 LTS** (GCP / Oracle Cloud / AWS).

### Крок 1: Оновлення системи та встановлення базових утиліт

Підключіться до сервера через SSH та оновіть системні пакети:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git ufw -y
```

---

### Крок 2: Налаштування фаєрволу (UFW)

Забезпечуємо принцип мінімальних привілеїв: відкриваємо тільки порти `22` (SSH) та `80` (HTTP).

```bash
# Встановлюємо політику за замовчуванням
sudo ufw enable

# Відкриваємо критично важливі порти
sudo ufw allow 22/tcp comment 'SSH Access'
sudo ufw allow 80/tcp comment 'HTTP Web Traffic'

# Активуємо фаєрвол (підтвердіть дію 'y')
sudo ufw --force enable

# Перевіряємо статус
sudo ufw status verbose
```

---

### Крок 3: Встановлення Docker та Docker Compose (Official Engine)

Встановлюємо офіційний Docker Engine та Docker Compose Plugin:

```bash
sudo apt remove docker.io docker-compose docker-doc podman-docker containerd runc -y
sudo apt install ca-certificates curl gnupg lsb-release -y

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

---

### Крок 4: Клонування репозиторію

Створюємо робочу директорію та клонуємо проект:

```bash
mkdir TechTask_BullsMedia
cd TechTask_BullsMedia
git init
git clone https://github.com/88susan00/TechTask_BullsMedia.git TechTask_BullsMedia
```

---

### Крок 5: Запуск проекту через Docker Compose

Збираємо образи та піднімаємо всі сервіси у фоновому режимі:

```bash
docker compose up -d --build
```

Перевірте статус запущених контейнерів:
```bash
docker compose ps
```
Усі сервіси (`proxy`, `site1`, `site2`, `site3`) повинні мати статус `Up`, а для `site1/2/3` стан повинен бути `(healthy)`.

---

## 🔍 Перевірка працездатності сервісів

Виконайте запити локально або з будь-якого зовнішнього комп'ютера:

```bash
# 1. Перевірка статичного Site 1
curl -I http://<IP_СЕРВЕРА>/site1/

# 2. Перевірка статичного Site 2
curl -I http://<IP_СЕРВЕРА>/site2/

# 3. Перевірка PHP додатку Site 3
curl http://<IP_СЕРВЕРА>/site3/

# 4. Перевірка Healthcheck ендпоінту Site 1, 2, 3
curl -i http://<IP_СЕРВЕРА>/site(1, 2, 3)/healthz
# Очікувана відповідь: HTTP/1.1 200 OK, тіло: OK
```

---

## 🛡 Watchdog & Автоматичне відновлення (Self-Healing)

У проекті реалізовано скрипт перевірки працездатності `all-services-check.sh`. Він аналізує стан контейнерів через Docker Health API та у разі виникнення помилок або зависання перезапускає відповідний сервіс.

### Запуск скрипту моніторингу:

```bash
# Надаємо права на виконання
chmod +x all-services-check.sh

# Створюємо unit‑файл
sudo nano /etc/systemd/system/techtask.service
```

### Вміст techtask.service
```bash
[Unit]
Description=TechTask BullsMedia startup script
After=network.target

[Service]
ExecStart=/home/<ІМʼЯ ВАШОГО КОРИСТУВАЧА>/TechTask_BullsMedia/all-services-check.sh
Restart=always
User=<ІМʼЯ ВАШОГО КОРИСТУВАЧА>
WorkingDirectory=/home/mkiselyov88/TechTask_BullsMedia

[Install]
WantedBy=multi-user.target
```

### Запуск та керування сервісом:
```bash
# Перезавантажуємо systemd
sudo systemctl daemon-reload

# Активуємо автозапуск
sudo systemctl enable techtask.service

# Запускаємо вручну для перевірки
sudo systemctl start techtask.service
```

Перегляд логів роботи watchdog:
```bash
systemctl status techtask.service
journalctl -u techtask.service -f
```

---

## 📜 Історія комітів (Commit Conventions)

Репозиторій сформовано згідно з вимогами атомарних комітів (Conventional Commits):

* `chore: initialize project structure` — базове створення структури проекту
* `feat: add static website containers` — конфігурація та сторінки для site1, site2
* `feat: add PHP demo application` — реалізація сервісу site3 та healthz
* `fix: correct PHP upstream port in nginx` — узгодження портів проксі та додатка
* `Add nginx config files` — налаштування routing правил у proxy
* `Fix for healthcheck site` — впровадження docker healthcheck
* `Add reliability script` — базовий watchdog-скрипт
* `Fix docker compose yml` — оптимізація мереж та залежностей
* `Reliability script update` — покращення стабільності моніторингу
