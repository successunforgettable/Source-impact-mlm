# Use official Perl base
FROM perl:5.36

# Install Apache + required modules
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    libdbi-perl libdbd-mysql-perl \
    libtemplate-perl libxml-libxml-perl \
    libdigest-hmac-perl libcgi-pm-perl \
 && rm -rf /var/lib/apt/lists/*

# Render routes to 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf

# Enable CGI (cgid for threaded MPM) and alias
RUN a2enmod cgid && a2enmod alias

# Work from /app
WORKDIR /app

# Copy the WHOLE repo (avoids path issues with mlm/)
COPY . /app

# If your app lives at /app/mlm, verify it's there (fails build if not)
RUN test -d /app/mlm || (echo "FATAL: /app/mlm not found. Repo layout mismatch." && ls -la /app && exit 1)

# Put our Apache vhost in place
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

# Ensure CGI entrypoint is executable (only if it exists)
RUN chmod +x /app/mlm/cgi-bin/goto || true

ENV APP_ENV=production \
    PORT=8080

EXPOSE 8080

CMD ["apache2ctl", "-D", "FOREGROUND"]