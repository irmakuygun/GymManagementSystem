#!/bin/bash
# Gym Management System — kurulum + başlatma scripti
# Kullanım: VS Code'da klasörü aç, terminale ./start.sh yaz.
# İlk çalıştırmada .venv kurar, MySQL şifresini sorar, veritabanını yükler.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"
DB_DIR="$SCRIPT_DIR/database"

# --- 1) python3 ve mysql var mı? ---
if ! command -v python3 >/dev/null 2>&1; then
    echo "HATA: python3 bulunamadı. Kurmak için:  brew install python3"
    exit 1
fi
if ! command -v mysql >/dev/null 2>&1; then
    echo "HATA: mysql client bulunamadı. Kurmak için:"
    echo "  brew install mysql"
    echo "  brew services start mysql"
    exit 1
fi

cd "$APP_DIR"

# --- 2) .venv yoksa veya başka makineden geldiyse (bozuksa) yeniden kur ---
if [ ! -f ".venv/bin/python3" ] || ! .venv/bin/python3 -c "" >/dev/null 2>&1; then
    echo "==> Python sanal ortamı (.venv) oluşturuluyor..."
    rm -rf .venv
    python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

echo "==> Bağımlılıklar kuruluyor..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# --- 3) .env yoksa oluştur (MySQL şifresini sor) ---
if [ ! -f ".env" ]; then
    echo ""
    echo "==> İlk kurulum: .env dosyası yok."
    printf "MySQL root şifresini gir: "
    read -rs DB_PASSWORD_INPUT
    echo ""

    FLASK_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")

    cat > .env <<EOF
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=$DB_PASSWORD_INPUT
DB_NAME=gym_management
FLASK_SECRET=$FLASK_SECRET
EOF
    echo "==> .env yazıldı."
fi

# --- 4) .env'i oku ---
set -a
# shellcheck disable=SC1091
source .env
set +a

# --- 5) MySQL'e bağlan, şifre yanlışsa yeniden sor ---
export MYSQL_PWD="$DB_PASSWORD"

while true; do
    MYSQL_ERR=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -e "SELECT 1" 2>&1 >/dev/null) && break
    if echo "$MYSQL_ERR" | grep -q "Access denied"; then
        echo ""
        echo "MySQL şifresi yanlış. Lütfen doğru MySQL root şifresini gir."
        printf "MySQL root şifresi: "
        read -rs DB_PASSWORD_INPUT
        echo ""
        DB_PASSWORD="$DB_PASSWORD_INPUT"
        export MYSQL_PWD="$DB_PASSWORD"
        # .env'i yeniden yaz - sadece şifre değişiyor, FLASK_SECRET ve diğerleri korunuyor
        cat > .env <<EOF
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$DB_NAME
FLASK_SECRET=$FLASK_SECRET
EOF
    else
        echo "HATA: MySQL'e bağlanılamadı."
        echo "  - MySQL çalışıyor mu?  ('brew services start mysql')"
        echo "$MYSQL_ERR"
        exit 1
    fi
done

DB_EXISTS=$(mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -N -B \
    -e "SHOW DATABASES LIKE '$DB_NAME'" 2>/dev/null)

if [ -z "$DB_EXISTS" ]; then
    echo "==> '$DB_NAME' veritabanı yok — schema + functions + triggers + views + sample data yükleniyor..."
    cd "$DB_DIR"
    for f in 01_schema.sql 03_functions.sql 04_triggers.sql 05_views.sql 02_data.sql; do
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" < "$f"
    done
    cd "$APP_DIR"
    echo "==> Veritabanı kuruldu."
fi

unset MYSQL_PWD

# --- 6) Flask başlat ---
echo ""
echo "==> Flask başlatılıyor — http://127.0.0.1:5050"
echo "==> Kapatmak için Ctrl+C."
echo ""
python app.py
