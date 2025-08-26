FROM perl:5.36

# Install Apache + Perl modules
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    libdbi-perl libdbd-mysql-perl \
    libtemplate-perl libxml-libxml-perl \
    libdigest-hmac-perl libcgi-pm-perl \
 && rm -rf /var/lib/apt/lists/*

# Render listens on 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
RUN a2enmod cgid alias

# App files
WORKDIR /app
COPY . /app

# Apache vhost
COPY docker/app/mlm-apache.conf /etc/apache2/sites-available/000-default.conf

# Create guaranteed CGI test scripts in the system CGI dir
RUN set -e; \
  install -d -m 755 /usr/lib/cgi-bin; \
  printf '%s\n' '#!/usr/bin/env perl' \
    'use strict; use warnings;' \
    'print "Content-Type: text/plain; charset=utf-8\\n\\n";' \
    'for my $k (sort keys %ENV) {' \
    '  my $v = $ENV{$k} // q{};' \
    '  $v =~ s/\\n/\\\\n/g;' \
    '  print "$k=$v\\n";' \
    '}' \
    > /usr/lib/cgi-bin/env.cgi; \
  chmod 755 /usr/lib/cgi-bin/env.cgi; \
  printf '%s\n' '#!/usr/bin/env perl' \
    'use strict; use warnings; use CGI qw(:standard);' \
    'print header(-type => q{text/plain; charset=utf-8});' \
    'print "OK: CGI is alive at ".scalar(localtime)."\\n";' \
    'my $p = param(q{ping}); print "ping=$p\\n" if defined $p;' \
    > /usr/lib/cgi-bin/goto; \
  chmod 755 /usr/lib/cgi-bin/goto

ENV APP_ENV=production PORT=8080
EXPOSE 8080
CMD ["apache2ctl", "-D", "FOREGROUND"]
