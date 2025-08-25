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

# Put the whole repo in /app
WORKDIR /app
COPY . /app

# ✅ Your repo root is the app; make a stable path for Apache/config.json
# /app/mlm -> /app (so /app/mlm/www == /app/www)
RUN ln -s /app /app/mlm || true

# Optional: if you later add cgi-bin/goto, make sure it can execute
RUN chmod +x /app/mlm/cgi-bin/goto 2>/dev/null || true

# Apache vhost (expects /app/mlm/www and /app/mlm/cgi-bin/goto)
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

ENV APP_ENV=production \
    PORT=8080

EXPOSE 8080
CMD ["apache2ctl", "-D", "FOREGROUND"]