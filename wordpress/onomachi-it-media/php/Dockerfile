FROM php:8.4-fpm
RUN docker-php-ext-install mysqli pdo pdo_mysql
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]