FROM perl:5.36

# Apache + deps
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    libdbi-perl libdbd-mysql-perl \
    libtemplate-perl libxml-libxml-perl \
    libdigest-hmac-perl libcgi-pm-perl \
 && rm -rf /var/lib/apt/lists/*

# Render uses 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
RUN a2enmod cgid && a2enmod alias

# Put the whole repo in /app (your repo root IS the app root)
WORKDIR /app
COPY . /app

# Ensure CGI dir exists and permissions are correct
RUN mkdir -p /app/cgi-bin && chmod 755 /app /app/cgi-bin
RUN find /app/cgi-bin -type f -exec chmod 755 {} \; 2>/dev/null || true

# Apache vhost now points to /app/www and /app/cgi-bin
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

# Make CGI scripts executable (if present)
RUN chmod +x /app/cgi-bin/* 2>/dev/null || true

ENV APP_ENV=production \
    PORT=8080

EXPOSE 8080
CMD ["apache2ctl", "-D", "FOREGROUND"]