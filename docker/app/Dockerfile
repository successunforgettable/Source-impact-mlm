# Use the official Perl image (Debian-based)
FROM perl:5.36

# Install Apache + required modules and Perl deps your app needs
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    libdbi-perl libdbd-mysql-perl \
    libtemplate-perl libxml-libxml-perl \
    libdigest-hmac-perl libcgi-pm-perl \
 && rm -rf /var/lib/apt/lists/*

# Apache on Render should listen on 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

# Enable CGI (use cgid for threaded MPM) and alias
RUN a2enmod cgid && a2enmod alias

# Container working dir
WORKDIR /app/mlm

# Copy your app (adjust path if your repo layout differs)
# Expecting repo root has: mlm/{cgi-bin,conf,lib,views,www}
COPY mlm /app/mlm

# Put our Apache vhost in place
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

# Ensure CGI entrypoint is executable
RUN chmod +x /app/mlm/cgi-bin/goto

# Environment Render expects
ENV APP_ENV=production \
    PORT=8080

EXPOSE 8080

# Run Apache in foreground
CMD ["apache2ctl", "-D", "FOREGROUND"]