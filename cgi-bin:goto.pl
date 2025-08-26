#!/usr/bin/env perl
use strict;
use warnings;
use CGI qw(:standard);
use FindBin qw($Bin);
use Cwd qw(abs_path);
use File::Spec;
use JSON::PP;

# ------------------------------------------------------------
# Ready-to-run CGI router for Source-Impact-MLM
# - Loads config.json from repo root (/app/config.json)
# - Adds lib/ to @INC so MLM::* modules can be used
# - Tries to dispatch to MLM::App if available, else shows a basic page
# - Safe fallback with ?debug=1 to dump params/env
# ------------------------------------------------------------

# Detect app root (repo root). This script lives in /app/cgi-bin
my $script_dir = abs_path($Bin) || '/app/cgi-bin';
(my $APP_ROOT = $script_dir) =~ s{/cgi-bin$}{};  # -> /app
$APP_ROOT ||= '/app';

# Ensure lib path is available
BEGIN {
  my $libdir = File::Spec->catdir($APP_ROOT, 'lib');
  unshift @INC, $libdir if -d $libdir;
}

# Load config.json
my $config_path = File::Spec->catfile($APP_ROOT, 'config.json');
my $config = {};
if (-r $config_path) {
  eval {
    local $/; # slurp
    open my $fh, '<', $config_path or die "Cannot open $config_path: $!";
    my $json = <$fh> // '{}';
    close $fh;
    $config = JSON::PP->new->utf8->decode($json);
  };
}

# Helper: HTML escape
sub _e { my $s = shift // ''; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g; return $s; }

# Try to hand off to real app if present
my $cgi = CGI->new;
my $dispatched;
my $dispatch_err;

eval {
  require MLM::App;                # optional, if present in lib/MLM/App.pm
  my $app = MLM::App->new(
    config => $config,
    root   => $APP_ROOT,
  );
  # Convention: app->run($cgi) returns a full PSGI/CGI response body or prints itself.
  if ($app->can('run')) {
    my $out = $app->run($cgi);
    if (defined $out && $out ne '') {
      print $out; # assume headers included
    }
    $dispatched = 1;
  }
};
$dispatch_err = $@ if $@;

if ($dispatched) {
  exit 0;
}

# Fallback minimal router
my $debug = scalar $cgi->param('debug') || 0;
print header(-type => 'text/html; charset=utf-8');
print "<!doctype html><html><head><meta charset='utf-8'><title>Source-Impact-MLM</title>";
print "<style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Helvetica,Arial,sans-serif;padding:24px;max-width:900px;margin:auto}code,pre{background:#f6f8fa;padding:8px;border-radius:6px;display:block;overflow:auto}</style></head><body>";
print "<h1>Source-Impact-MLM</h1>";

if ($dispatch_err) {
  print "<p><strong>Note:</strong> Could not load <code>MLM::App</code>. Running fallback router.</p>";
  print "<pre>"._e($dispatch_err)."</pre>";
}

print "<h2>Routes</h2><ul>";
print "<li><a href='/healthz.html'>/healthz.html</a> (static)</li>";
print "<li><a href='/cgi-bin/goto?ping=1'>/cgi-bin/goto?ping=1</a> (CGI test)</li>";
print "<li><a href='/cgi-bin/env.cgi'>/cgi-bin/env.cgi</a> (environment)</li>";
print "</ul>";

print "<h2>Config</h2><pre>"._e(JSON::PP->new->pretty->encode($config))."</pre>";

if ($debug) {
  print "<h2>Params (debug)</h2><pre>";
  for my $p ($cgi->param) { print _e($p)."="._e(join(',', $cgi->param($p)))."\n"; }
  print "</pre>";
  print "<h2>ENV (debug)</h2><pre>";
  for my $k (sort keys %ENV) { print _e($k)."="._e($ENV{$k}//'')."\n"; }
  print "</pre>";
}

print "<hr><p style='color:#666'>CGI fallback router active. To enable full app, implement <code>MLM::App</code> in <code>lib/MLM/App.pm</code> with a <code>run($cgi)</code> method.</p>";
print "</body></html>";

exit 0;
