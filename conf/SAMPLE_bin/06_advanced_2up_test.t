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
$dbh->do("DELETE FROM commission_log");
$dbh->do("UPDATE member SET status='iT', pass_up_count=0, current_phase=1");

# --- Test Data ---
my $member_model = MLM::Beacon->new(role=>"p");
my %members = (
    A => { login => 'adv_test_A', passwd => 'password123', email => 'adv_a@test.com' },
    B => { login => 'adv_test_B', passwd => 'password123', email => 'adv_b@test.com' },
    C => { login => 'adv_test_C', passwd => 'password123', email => 'adv_c@test.com' },
    S1 => { login => 'adv_test_S1', passwd => 'password123', email => 'adv_s1@test.com' },
    S2 => { login => 'adv_test_S2', passwd => 'password123', email => 'adv_s2@test.com' },
    S3 => { login => 'adv_test_S3', passwd => 'password123', email => 'adv_s3@test.com' },
);
my %member_ids;

# --- Test Execution ---

# 1. Create sponsor chain A -> B -> C
my $resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{A}}, sidlogin => 'gmarket' });
$member_ids{A} = JSON->new->decode($resp->content)->{data}->{memberid};
$dbh->do("UPDATE member SET status='iQ' WHERE memberid = ?", undef, $member_ids{A}); # A is top-level IQ

$resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{B}}, sidlogin => $members{A}{login} });
$member_ids{B} = JSON->new->decode($resp->content)->{data}->{memberid};

$resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{C}}, sidlogin => $members{B}{login} });
$member_ids{C} = JSON->new->decode($resp->content)->{data}->{memberid};


# 2. Test Pass-Up: C (iT) recruits S1 and S2
$member_model->post_mockup("signup", { action => 'insert', %{$members{S1}}, sidlogin => $members{C}{login} });
my $s1_id = $dbh->selectrow_array("SELECT memberid FROM member WHERE login=?", undef, $members{S1}{login});
$member_model->post_mockup("signup", { action => 'insert', %{$members{S2}}, sidlogin => $members{C}{login} });
my $s2_id = $dbh->selectrow_array("SELECT memberid FROM member WHERE login=?", undef, $members{S2}{login});


# Run compensation
$admin->get_mockup("income", "action=run_all_tests");

# Verification for Pass-Up
my $c_data = $dbh->selectrow_hashref("SELECT status, pass_up_count FROM member WHERE memberid = ?", undef, $member_ids{C});
is($c_data->{status}, 'iQ', "Member C becomes iQ after 2 pass-ups");
is($c_data->{pass_up_count}, 2, "Member C pass_up_count is 2");

my $c_commission_s1 = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=? AND source_member_id=?", undef, $member_ids{C}, $s1_id);
is($c_commission_s1->{amount}, 10, "C gets 10% recruiter commission for S1"); # Assuming BV is 100

my $a_commission_s1 = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=? AND source_member_id=?", undef, $member_ids{A}, $s1_id);
is($a_commission_s1->{amount}, 30, "A gets 30% upline commission for S1");

# 3. Test IQ Commission: C (now iQ) recruits S3
$member_model->post_mockup("signup", { action => 'insert', %{$members{S3}}, sidlogin => $members{C}{login} });
my $s3_id = $dbh->selectrow_array("SELECT memberid FROM member WHERE login=?", undef, $members{S3}{login});
$admin->get_mockup("income", "action=run_all_tests");

my $c_commission_s3 = $dbh->selectrow_hashref("SELECT amount FROM commission_log WHERE recipient_member_id=? AND source_member_id=?", undef, $member_ids{C}, $s3_id);
is($c_commission_s3->{amount}, 40, "C gets full 40% IQ commission for S3");


# 4. Test Phase Logic (Simplified)
# B is phase 1, A is phase 10 (implicitly). S4 is a phase 2 sale under B.
$dbh->do("UPDATE member SET current_phase=2 WHERE memberid = ?", undef, $s1_id); # S1 is now a phase 2 sale
$admin->get_mockup("income", "action=run_all_tests");

my $phase_comm = $dbh->selectall_arrayref("SELECT recipient_member_id, amount FROM commission_log WHERE source_member_id=? AND phase_level=2", { Slice => {} }, $s1_id);
my $b_got_paid = 0;
my $a_got_paid = 0;
foreach my $row (@$phase_comm) {
    $b_got_paid = 1 if $row->{recipient_member_id} == $member_ids{B};
    $a_got_paid = 1 if $row->{recipient_member_id} == $member_ids{A};
}
ok(!$b_got_paid, "B (unqualified at Phase 2) does not receive Phase 2 commission");
ok($a_got_paid, "A (qualified upline) receives roll-up Phase 2 commission");


done_testing();
$dbh->disconnect();
exit(0);
