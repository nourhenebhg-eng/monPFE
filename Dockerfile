# ==================================================
# STAGE 1 : Build des assets Node
# ==================================================
FROM node:18-alpine AS nodebuild
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build


# ==================================================
# STAGE 2 : Dépendances PHP
# ==================================================
FROM composer:latest AS vendorbuild
WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist


# ==================================================
# STAGE FINAL : Image de production
# ==================================================
FROM php:8.1-fpm

ARG user=laravel
ARG uid=1000

RUN apt-get update && apt-get install -y \
    git curl libpng-dev libonig-dev \
    libxml2-dev libzip-dev zip unzip \
    nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install \
    pdo_mysql mbstring exif pcntl bcmath gd zip

RUN useradd -G www-data,root -u $uid -d /home/$user $user
RUN mkdir -p /home/$user/.composer && \
    chown -R $user:$user /home/$user

WORKDIR /var/www

COPY . .
COPY --from=vendorbuild /app/vendor ./vendor
COPY --from=nodebuild /app/public/build ./public/build

# Plus besoin de composer install ni npm ici
RUN chown -R $user:www-data /var/www \
    && chmod -R 755 /var/www/storage \
    && chmod -R 755 /var/www/bootstrap/cache

COPY docker/nginx/nginx.conf /etc/nginx/sites-available/default
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
