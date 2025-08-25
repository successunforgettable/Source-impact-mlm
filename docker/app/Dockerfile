# Runs the Perl CGI app (Genelet/mlm) under Apache on port 8080
FROM perl:5.36-apache

# Install runtime deps you use (from README)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libdbi-perl libdbd-mysql-perl libtemplate-perl libxml-libxml-perl \
    libdigest-hmac-perl libcgi-fast-perl \
 && rm -rf /var/lib/apt/lists/*

# Apache listens on 8080 to match Render's default
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

# Enable CGI and configure an mlm site
RUN a2enmod cgi && a2enmod alias

# App directory inside container
WORKDIR /app/mlm

# Copy your project into the image (adjust if your repo layout differs)
# Expecting repo root to contain: mlm/{cgi-bin,conf,lib,views,www}
COPY mlm /app/mlm

# Apache site config for mlm (adds /cgi-bin/goto and sets DocumentRoot)
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

# Make sure CGI entrypoint is executable
RUN chmod +x /app/mlm/cgi-bin/goto

ENV APP_ENV=production \
    PORT=8080

EXPOSE 8080
CMD ["apache2-foreground"]