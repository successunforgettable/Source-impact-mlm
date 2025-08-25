#!/usr/bin/perl

use lib qw(/app/mlm/lib);
use strict;
use warnings;
use JSON;
use Test::More;
use Data::Dumper;
use MLM::Beacon;

# Load config
my $config_path = "conf/config.json";
open(my $fh, '<', $config_path) or die "Cannot open $config_path: $!";
local $/;
my $json_text = <$fh>;
close($fh);

my $config = decode_json($json_text);
ok($config->{Custom}{TwoUp}{it_percent} == 0.10, "2UP it_percent is correct");
ok($config->{Custom}{TwoUp}{upline_percent} == 0.30, "2UP upline_percent is correct");
ok($config->{Custom}{TwoUp}{keeper_percent} == 0.40, "2UP keeper_percent is correct");

ok($config->{Custom}{Leadership}{enabled} == JSON::true, "Leadership is enabled");
ok($config->{Custom}{Leadership}{company_member_id} == 1, "Leadership company member ID is correct");
ok($config->{Custom}{Leadership}{percent}{ASSISTANT_NTM} == 0.05, "Leadership ASC rate is correct");
ok($config->{Custom}{Leadership}{percent}{NTM} == 0.10, "Leadership NTM rate is correct");

done_testing();
