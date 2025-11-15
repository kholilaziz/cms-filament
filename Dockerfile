# Tahap 1: Builder (Install dependencies)
FROM php:8.3-fpm-alpine AS builder

WORKDIR /var/www/html

# Install dependencies sistem
RUN apk add --no-cache \
    build-base \
    zip \
    unzip \
    git \
    curl \
    libzip-dev \
    libpng-dev \
    jpeg-dev \
    freetype-dev \
    oniguruma-dev \
    libxml2-dev \
    icu-dev \
    nodejs \
    npm

# Install ekstensi PHP
RUN docker-php-ext-install \
    pdo pdo_mysql \
    zip \
    gd \
    exif \
    bcmath \
    mbstring \
    xml \
    intl

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# === PERUBAHAN UTAMA DI SINI ===
# Salin SEMUA file aplikasi terlebih dahulu
# Ini memastikan file 'artisan' ada SEBELUM composer install
COPY . .

# Install dependencies Composer
# Sekarang 'php artisan package:discover' akan berhasil
RUN composer install --no-dev --no-interaction --no-progress --optimize-autoloader

# Install dependencies NPM & build assets
# File package.json dll. juga sudah ada karena 'COPY . .'
RUN npm install && npm run build

# ---

# Tahap 2: Final Image (Aplikasi utama)
FROM php:8.3-fpm-alpine AS app

WORKDIR /var/www/html

# Install dependencies RUNTIME minimal
RUN apk add --no-cache \
    libzip \
    libpng \
    jpeg \
    freetype \
    libxml2 \
    oniguruma \
    icu

# Copy ekstensi yang sudah di-compile dari tahap builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Copy user/group www-data
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Salin kode aplikasi (tanpa artefak build)
COPY . .

# Salin artefak build (vendor dan aset) dari tahap builder
# Ini akan menimpa/menambahkan folder vendor dan public/build
COPY --from=builder /var/www/html/vendor/ /var/www/html/vendor/
COPY --from=builder /var/www/html/public/build/ /var/www/html/public/build/

# Atur kepemilikan
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 9000
CMD ["php-fpm"]
