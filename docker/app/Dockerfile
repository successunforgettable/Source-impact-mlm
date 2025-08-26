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
FROM perl:5.36

# Apache + perl modules
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    libdbi-perl libdbd-mysql-perl \
    libtemplate-perl libxml-libxml-perl \
    libdigest-hmac-perl libcgi-pm-perl \
 && rm -rf /var/lib/apt/lists/*

# Render uses 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
RUN a2enmod cgid alias

WORKDIR /app
COPY . /app

# ✅ Install CGI test scripts into the system CGI directory
RUN mkdir -p /usr/lib/cgi-bin && chmod 755 /usr/lib/cgi-bin \
 && if [ -f /app/cgi-bin/env.cgi ];  then install -m 755 /app/cgi-bin/env.cgi  /usr/lib/cgi-bin/env.cgi;  fi \
 && if [ -f /app/cgi-bin/goto ];     then install -m 755 /app/cgi-bin/goto     /usr/lib/cgi-bin/goto;     fi \
 && if [ -f /app/cgi-bin/goto.cgi ]; then install -m 755 /app/cgi-bin/goto.cgi /usr/lib/cgi-bin/goto.cgi; fi

# Site config
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

ENV APP_ENV=production PORT=8080
EXPOSE 8080
CMD ["apache2ctl", "-D", "FOREGROUND"]
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