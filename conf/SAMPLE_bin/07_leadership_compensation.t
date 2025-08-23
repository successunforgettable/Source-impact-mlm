#!/usr/bin/perl

use lib qw(/SAMPLE_home/mlm/lib /SAMPLE_home/perl);
use strict;
use warnings;
use JSON;
use MLM::Beacon;
use Test::More;
use DBI;

# Setup
my $admin = MLM::Beacon->new(role=>"a");
my $err = $admin->get_credential("gmarket","gmarketIsCool");
die "Admin login failed: $err" if $err;

my $config;
{
    local $/;
    open(my $fh, '<', 'conf/config.json') or die "Cannot open conf/config.json: $!";
    my $json_text = <$fh>;
    close($fh);
    $config = decode_json($json_text);
}
my $dbh = DBI->connect(@{$config->{Db}}) or die "DB connection failed: $DBI::errstr";

# Clean up previous test data
$dbh->do("DELETE FROM income_amount WHERE bonusType = 'Leadership'");
$dbh->do("DELETE FROM income WHERE classify = 'leadership_pool'");

# Test Plan
# 1. Create two members, L1 and L2.
# 2. Manually promote L1 to ASC and L2 to SC.
# 3. Create a new sale to generate BV.
# 4. Run compensation.
# 5. Verify that L1 and L2 received a share of the leadership pool.

my $member_model = MLM::Beacon->new(role=>"p");

# Member data
my %members = (
    L1 => { login => 'test_L1', passwd => 'password123', firstname => 'Leader', lastname => 'User1', email => 'l1@test.com' },
    L2 => { login => 'test_L2', passwd => 'password123', firstname => 'Leader', lastname => 'User2', email => 'l2@test.com' },
    S5 => { login => 'test_S5', passwd => 'password123', firstname => 'Test', lastname => 'Sale5', email => 's5@test.com' },
);
my %member_ids;

# Create members
$resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{L1}}, sidlogin => 'gmarket' });
$member_ids{L1} = JSON->new->decode($resp->content)->{data}->{memberid};

$resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{L2}}, sidlogin => 'gmarket' });
$member_ids{L2} = JSON->new->decode($resp->content)->{data}->{memberid};

# Promote members
$dbh->do("UPDATE member_leadership SET rank_name = 'ASC', rank_level = 1 WHERE memberid = ?", undef, $member_ids{L1});
$dbh->do("UPDATE member_leadership SET rank_name = 'SC', rank_level = 2 WHERE memberid = ?", undef, $member_ids{L2});

# Create a sale to generate volume
# Assuming the new member package has a BV of 1000.
$member_model->post_mockup("signup", { action => 'insert', %{$members{S5}}, sidlogin => 'gmarket', typeid => 1 });

# Run compensation
$resp = $admin->get_mockup("income", "action=run_all_tests");
is($resp->code, 200, "run_all_tests executed successfully");

# Verification
# 1. Get total BV for the week
my $total_bv = $dbh->selectrow_hashref("SELECT SUM(p.bv) as total FROM member m JOIN def_type p ON m.typeid = p.typeid WHERE login=?", undef, $members{S5}{login})->{total};

# 2. Calculate expected pool
my $pool_percentage = $config->{Custom}->{LEADERSHIP}->{pool_percentage};
my $expected_pool = $total_bv * $pool_percentage;

# 3. Calculate expected shares
my $asc_rate = $config->{Custom}->{LEADERSHIP}->{ranks}->{ASC}->{rate};
my $sc_rate = $config->{Custom}->{LEADERSHIP}->{ranks}->{SC}->{rate};
my $total_shares = $asc_rate + $sc_rate;
my $share_value = $expected_pool / $total_shares;

my $expected_l1_commission = $asc_rate * $share_value;
my $expected_l2_commission = $sc_rate * $share_value;

# 4. Get actual commissions
my $l1_commission = $dbh->selectrow_hashref("SELECT amount FROM income_amount WHERE memberid = ? AND bonusType = 'Leadership'", undef, $member_ids{L1});
my $l2_commission = $dbh->selectrow_hashref("SELECT amount FROM income_amount WHERE memberid = ? AND bonusType = 'Leadership'", undef, $member_ids{L2});

ok(defined $l1_commission->{amount}, "L1 received leadership commission");
ok(defined $l2_commission->{amount}, "L2 received leadership commission");

# Use a tolerance for float comparison
is(sprintf("%.2f", $l1_commission->{amount}), sprintf("%.2f", $expected_l1_commission), "L1 commission is correct");
is(sprintf("%.2f", $l2_commission->{amount}), sprintf("%.2f", $expected_l2_commission), "L2 commission is correct");

done_testing();

$dbh->disconnect();
exit(0);
