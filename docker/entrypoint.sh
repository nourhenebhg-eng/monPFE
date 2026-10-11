#!/bin/bash
set -e

VAULT_SECRETS_DIR="/vault/secrets"

echo "Loading HRMS secrets from Vault..."

# Vérifier que les quatre secrets ont bien été injectés.
for secret in app-key db-database db-username db-password; do
    if [ ! -s "${VAULT_SECRETS_DIR}/${secret}" ]; then
        echo "ERROR: Secret Vault absent ou vide : ${secret}"
        exit 1
    fi
done

# Charger les valeurs depuis les fichiers créés par Vault Agent.
export APP_KEY="$(cat "${VAULT_SECRETS_DIR}/app-key")"
export DB_DATABASE="$(cat "${VAULT_SECRETS_DIR}/db-database")"
export DB_USERNAME="$(cat "${VAULT_SECRETS_DIR}/db-username")"
export DB_PASSWORD="$(cat "${VAULT_SECRETS_DIR}/db-password")"

echo "Vault secrets loaded successfully."
echo "Waiting for MySQL..."

until php -r '
try {
    new PDO(
        "mysql:host=" . getenv("DB_HOST") .
        ";port=" . getenv("DB_PORT") .
        ";dbname=" . getenv("DB_DATABASE"),
        getenv("DB_USERNAME"),
        getenv("DB_PASSWORD")
    );
    exit(0);
} catch (Throwable $e) {
    exit(1);
}
' 2>/dev/null; do
    echo "MySQL not ready, retrying..."
    sleep 3
done

echo "MySQL ready!"

php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache

chmod -R 775 /var/www/storage
chown -R www-data:www-data /var/www/storage

php-fpm -D
exec nginx -g "daemon off;"
