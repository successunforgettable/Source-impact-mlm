#!/usr/bin/perl

use lib qw(/SAMPLE_home/mlm/lib /SAMPLE_home/perl);
use strict;
use warnings;
use JSON;
use MLM::Beacon;
use Test::More;
use DBI;
use Data::Dumper;

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

# Clean up
$dbh->do("DELETE FROM commission_log WHERE commission_type LIKE 'leadership_%'");

# --- Test Data ---
my $member_model = MLM::Beacon->new(role=>"p");
my %members = (
    RD => { login => 'lead_test_RD', passwd => 'password123', email => 'rd@test.com' },
    VP => { login => 'lead_test_VP', passwd => 'password123', email => 'vp@test.com' },
    NTM => { login => 'lead_test_NTM', passwd => 'password123', email => 'ntm@test.com' },
    ANTM => { login => 'lead_test_ANTM', passwd => 'password123', email => 'antm@test.com' },
    S => { login => 'lead_test_S', passwd => 'password123', email => 's@test.com' },
);
my %member_ids;

# --- Test Execution ---

# 1. Create members
foreach my $role (keys %members) {
    my $resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{$role}}, sidlogin => 'gmarket' });
    $member_ids{$role} = JSON->new->decode($resp->content)->{data}->{memberid};
}

# 2. Setup Leadership Hierarchy
$dbh->do("INSERT INTO leadership_hierarchy (member_id, upline_id, position) VALUES (?, ?, ?)", undef, $member_ids{RD}, undef, 'RD');
$dbh->do("INSERT INTO leadership_hierarchy (member_id, upline_id, position) VALUES (?, ?, ?)", undef, $member_ids{VP}, $member_ids{RD}, 'VP');
$dbh->do("INSERT INTO leadership_hierarchy (member_id, upline_id, position) VALUES (?, ?, ?)", undef, $member_ids{NTM}, $member_ids{VP}, 'NTM');
$dbh->do("INSERT INTO leadership_hierarchy (member_id, upline_id, position) VALUES (?, ?, ?)", undef, $member_ids{ANTM}, $member_ids{NTM}, 'Assistant NTM');
# The sales person S is sponsored by ANTM
$dbh->do("UPDATE member SET sid=? WHERE memberid=?", undef, $member_ids{ANTM}, $member_ids{S});


# 3. Test Commission Flow
my $sale_bv = 1000;
$dbh->do("UPDATE def_type SET bv=? WHERE typeid=(SELECT typeid FROM member WHERE memberid=?)", undef, $sale_bv, $member_ids{S});
$admin->get_mockup("income", "action=run_all_tests");

# Verification
my $ranks = $config->{Custom}->{LEADERSHIP}->{ranks};
my $antm_comm = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=? AND commission_type='leadership_Assistant NTM'", undef, $member_ids{ANTM});
is(sprintf("%.2f", $antm_comm->{amount}), sprintf("%.2f", $sale_bv * $ranks->{'Assistant NTM'}->{rate}), "Assistant NTM gets 5%");

my $ntm_comm = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=? AND commission_type='leadership_NTM'", undef, $member_ids{NTM});
is(sprintf("%.2f", $ntm_comm->{amount}), sprintf("%.2f", $sale_bv * $ranks->{'NTM'}->{rate}), "NTM gets 5%");

my $vp_comm = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=? AND commission_type='leadership_VP'", undef, $member_ids{VP});
is(sprintf("%.2f", $vp_comm->{amount}), sprintf("%.2f", $sale_bv * $ranks->{'VP'}->{rate}), "VP gets 2%");

my $rd_comm = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=? AND commission_type='leadership_RD'", undef, $member_ids{RD});
is(sprintf("%.2f", $rd_comm->{amount}), sprintf("%.2f", $sale_bv * $ranks->{'RD'}->{rate}), "RD gets 1%");


# 4. Test NTM Breakaway
# Simulate NTM qualifying and breaking away
$dbh->do("UPDATE leadership_hierarchy SET upline_id = NULL WHERE member_id = ?", undef, $member_ids{NTM});
$dbh->do("DELETE FROM commission_log WHERE commission_type LIKE 'leadership_%'"); # Clear old logs

# Rerun compensation on the same sale
$admin->get_mockup("income", "action=run_all_tests");

my $vp_comm_after_breakaway = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=? AND source_member_id=?", undef, $member_ids{VP}, $member_ids{S});
ok(!defined $vp_comm_after_breakaway, "VP gets no commission from NTM's group after breakaway");

my $ntm_comm_after_breakaway = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=?", undef, $member_ids{NTM});
is(sprintf("%.2f", $ntm_comm_after_breakaway->{amount}), sprintf("%.2f", $sale_bv * ($ranks->{'NTM'}->{rate} + $ranks->{'Assistant NTM'}->{rate})), "NTM gets full 10% after breakaway");


done_testing();
$dbh->disconnect();
exit(0);
