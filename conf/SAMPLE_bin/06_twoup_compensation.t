#!/usr/bin/perl

use lib qw(/SAMPLE_home/mlm/lib /SAMPLE_home/perl);
use strict;
use warnings;
use JSON;
use MLM::Beacon;
use Test::More;
use DBI;

# Setup: Connect to DB and get admin credentials
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
$dbh->do("DELETE FROM income_amount WHERE bonusType IN ('2-Up', 'Leadership')");
$dbh->do("DELETE FROM income WHERE classify LIKE '2up_%' OR classify = 'leadership_pool'");
$dbh->do("UPDATE member_2up SET sales_count = 0, qualification_status = 'iT', qualification_date = NULL");

# Test Plan
# 1. Create a sponsor chain: A -> B -> C
# 2. C makes two sales (S1, S2), qualifying for iQ status.
# 3. B makes one sale (S3).
# 4. A makes one sale (S4). A is already iQ.
# 5. Run compensation.
# 6. Verify commissions and qualifications.

my $member_model = MLM::Beacon->new(role=>"p");

# Member data
my %members = (
    A => { login => 'test_A', passwd => 'password123', firstname => 'Test', lastname => 'UserA', email => 'a@test.com' },
    B => { login => 'test_B', passwd => 'password123', firstname => 'Test', lastname => 'UserB', email => 'b@test.com' },
    C => { login => 'test_C', passwd => 'password123', firstname => 'Test', lastname => 'UserC', email => 'c@test.com' },
    S1 => { login => 'test_S1', passwd => 'password123', firstname => 'Test', lastname => 'Sale1', email => 's1@test.com' },
    S2 => { login => 'test_S2', passwd => 'password123', firstname => 'Test', lastname => 'Sale2', email => 's2@test.com' },
    S3 => { login => 'test_S3', passwd => 'password123', firstname => 'Test', lastname => 'Sale3', email => 's3@test.com' },
    S4 => { login => 'test_S4', passwd => 'password123', firstname => 'Test', lastname => 'Sale4', email => 's4@test.com' },
);
my %member_ids;

# Create members and establish sponsor chain
my $sid_a = 1; # Assuming admin/system is sponsor
my $resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{A}}, sidlogin => 'gmarket' });
$member_ids{A} = JSON->new->decode($resp->content)->{data}->{memberid};

$resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{B}}, sidlogin => $members{A}{login} });
$member_ids{B} = JSON->new->decode($resp->content)->{data}->{memberid};

$resp = $member_model->post_mockup("signup", { action => 'insert', %{$members{C}}, sidlogin => $members{B}{login} });
$member_ids{C} = JSON->new->decode($resp->content)->{data}->{memberid};

# Manually set A to be iQ
$dbh->do("UPDATE member_2up SET qualification_status = 'iQ' WHERE memberid = ?", undef, $member_ids{A});

# C makes 2 sales
$member_model->post_mockup("signup", { action => 'insert', %{$members{S1}}, sidlogin => $members{C}{login} });
$member_model->post_mockup("signup", { action => 'insert', %{$members{S2}}, sidlogin => $members{C}{login} });

# B makes 1 sale
$member_model->post_mockup("signup", { action => 'insert', %{$members{S3}}, sidlogin => $members{B}{login} });

# A makes 1 sale
$member_model->post_mockup("signup", { action => 'insert', %{$members{S4}}, sidlogin => $members{A}{login} });

# Run compensation
$resp = $admin->get_mockup("income", "action=run_all_tests");
is($resp->code, 200, "run_all_tests executed successfully");

# Verification
# 1. C should now be iQ
my $c_status = $dbh->selectrow_hashref("SELECT qualification_status FROM member_2up WHERE memberid = ?", undef, $member_ids{C});
is($c_status->{qualification_status}, 'iQ', "Member C is now iQ");

# 2. Check commissions for C's first sale (S1)
#    - S1 gets iT bonus
#    - A (first iQ in upline) gets iQ bonus
my $s1_it = $dbh->selectrow_hashref("SELECT amount FROM income WHERE classify='2up_it' AND refid = (SELECT memberid FROM member WHERE login=?)", undef, $members{S1}{login});
ok($s1_it->{amount} > 0, "S1 received iT bonus");

my $a_iq_s1 = $dbh->selectrow_hashref("SELECT amount FROM income WHERE classify='2up_iq' AND memberid=? AND refid = (SELECT memberid FROM member WHERE login=?)", undef, $member_ids{A}, $members{S1}{login});
ok($a_iq_s1->{amount} > 0, "A received iQ bonus for sale S1");

# 3. Check commissions for B's sale (S3)
#    - S3 gets iT bonus
#    - A gets iQ bonus (C is now iQ, but the data might not have been refreshed mid-run, so A is still the first iQ found in the initial data load of the run)
my $a_iq_s3 = $dbh->selectrow_hashref("SELECT amount FROM income WHERE classify='2up_iq' AND memberid=? AND refid = (SELECT memberid FROM member WHERE login=?)", undef, $member_ids{A}, $members{S3}{login});
ok($a_iq_s3->{amount} > 0, "A received iQ bonus for sale S3");

# 4. Check commissions for A's sale (S4)
#    - A gets direct recruit bonus
my $a_direct = $dbh->selectrow_hashref("SELECT amount FROM income WHERE classify='2up_direct' AND memberid=? AND refid = (SELECT memberid FROM member WHERE login=?)", undef, $member_ids{A}, $members{S4}{login});
ok($a_direct->{amount} > 0, "A received direct recruit bonus for sale S4");


done_testing();

$dbh->disconnect();
exit(0);
