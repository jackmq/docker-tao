FROM php:5.6-apache

MAINTAINER Ivan Klimchuk <ivan@klimchuk.com> (@alroniks)

RUN a2enmod rewrite expires

RUN usermod -u 1000 www-data
RUN usermod -G staff www-data

# install required packages
RUN apt-get update && \
    apt-get install -y \
        libpng12-dev \
        libjpeg-dev \
        zip \
        unzip \
        sudo \
        git && \
    rm -rf /var/lib/apt/lists/* 

# install php extensions
RUN docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr && \
    docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd && \
    docker-php-ext-configure mysql --with-mysql=mysqlnd && \
    docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install pdo && \
    docker-php-ext-install pdo_mysql && \
    docker-php-ext-install mysqli && \
    docker-php-ext-install mysql && \
    docker-php-ext-install gd && \
    docker-php-ext-install mbstring && \
    docker-php-ext-install opcache && \
    docker-php-ext-install zip

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=1'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

WORKDIR /var/www/html

RUN git clone --depth 1 https://github.com/oat-sa/package-tao.git . -b develop

# install composer
RUN curl -sS https://getcomposer.org/installer | php

# install dependencies
RUN php composer.phar install

RUN chown -R www-data:www-data /var/www/html

ENV MYSQL_USER=mysql \
    MYSQL_DATA_DIR=/var/lib/mysql \
    MYSQL_RUN_DIR=/run/mysqld \
    MYSQL_LOG_DIR=/var/log/mysql \
    DB_USER=tao \
    DB_PASS=tao \
    DB_NAME=tao \
    TAO_AUTOINSTALL=1 \
    TAO_DB_DRIVER=pdo_mysql \
    TAO_DB_NAME=tao \
    TAO_DB_USER=tao \
    TAO_DB_PASSWORD=tao \
    TAO_MODULE_URL=http://192.168.99.100:80
    
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server \
 && rm -rf ${MYSQL_DATA_DIR} \
 && rm -rf /var/lib/apt/lists/*

COPY tao-docker-entrypoint.sh /tao-entrypoint.sh
RUN chmod +x /tao-entrypoint.sh
COPY mysql-docker-entrypoint.sh /mysql-entrypoint.sh
RUN chmod +x /mysql-entrypoint.sh


RUN echo "pdo_mysql.default_socket=/var/run/mysqld/mysqld.sock" >> /usr/local/etc/php/conf.d/docker-php-ext-mysqli.ini
RUN echo "mysql.default_socket=/var/run/mysqld/mysqld.sock" >> /usr/local/etc/php/conf.d/docker-php-ext-mysqli.ini
RUN echo "mysqli.default_socket=/var/run/mysqld/mysqld.sock" >> /usr/local/etc/php/conf.d/docker-php-ext-mysqli.ini

# supervisor
RUN apt-get update && apt-get install -y openssh-server apache2 supervisor
RUN mkdir -p /var/lock/apache2 /var/run/apache2 /var/run/sshd /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80

#ENTRYPOINT ["/entrypoint.sh"]
#CMD ["php-fpm"]

CMD ["/usr/bin/supervisord"]