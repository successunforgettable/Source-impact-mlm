FROM perl:5.36
RUN echo "USING NEW DOCKERFILE — marker v5"

# Apache + Perl modules
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    libdbi-perl libdbd-mysql-perl \
    libtemplate-perl libxml-libxml-perl \
    libdigest-hmac-perl libcgi-pm-perl \
 && rm -rf /var/lib/apt/lists/*

# Render uses 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
RUN a2enmod cgid alias

# App files
WORKDIR /app
COPY . /app

# --- Genelet + Perl path (README requirement) ---
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/genelet/perl.git /opt/genelet
ENV PERL5LIB=/opt/genelet:/app/lib

# --- Real router at /app/cgi-bin/goto (README Script=/cgi-bin/goto) ---
RUN mkdir -p /app/cgi-bin && \
    printf '%s\n' '#!/usr/bin/env perl' \
      'use strict; use warnings;' \
      'use FindBin;' \
      'use lib $ENV{PERL5LIB};' \
      'require Genelet::Dispatch;' \
      'Genelet::Dispatch::run();' \
      > /app/cgi-bin/goto && chmod 755 /app/cgi-bin/goto

# Apache vhost (maps CGI to /app/cgi-bin; static /app/www)
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

# Permissions
RUN chmod 755 /app /app/cgi-bin && find /app/cgi-bin -type f -exec chmod 755 {} \;

ENV APP_ENV=production PORT=8080
EXPOSE 8080
CMD ["apache2ctl", "-D", "FOREGROUND"]
