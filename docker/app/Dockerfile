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

WORKDIR /app
COPY . /app

# 🔎 Auto-discover your MLM app dir and symlink it to /app/mlm
# Strategy:
# 1) Prefer a folder that contains cgi-bin/goto
# 2) Else look for a folder that has both views/ and www/
# 3) Symlink that folder to /app/mlm
RUN set -e; \
  MLMDIR=""; \
  CANDIDATE="$(dirname "$(dirname "$(find /app -maxdepth 5 -type f -name goto -path '*/cgi-bin/*' | head -n1)")")"; \
  if [ -n "$CANDIDATE" ] && [ -d "$CANDIDATE" ]; then MLMDIR="$CANDIDATE"; fi; \
  if [ -z "$MLMDIR" ]; then \
    CANDIDATE2="$(find /app -maxdepth 4 -type d -name views -printf '%h\n' 2>/dev/null | head -n1)"; \
    if [ -n "$CANDIDATE2" ] && [ -d "$CANDIDATE2/www" ]; then MLMDIR="$CANDIDATE2"; fi; \
  fi; \
  if [ -z "$MLMDIR" ]; then \
    echo 'FATAL: Could not locate your MLM app directory (no cgi-bin/goto or views+www found).'; \
    echo 'Repo tree under /app:'; ls -la /app; \
    exit 1; \
  fi; \
  echo "Detected MLM dir: $MLMDIR"; \
  ln -s "$MLMDIR" /app/mlm; \
  test -x /app/mlm/cgi-bin/goto || chmod +x /app/mlm/cgi-bin/goto || true

# Apache vhost
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

ENV APP_ENV=production \
    PORT=8080

EXPOSE 8080
CMD ["apache2ctl", "-D", "FOREGROUND"]