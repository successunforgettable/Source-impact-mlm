use strict;
use warnings;
use Test::More;
use lib 'lib';
use MLM::Income::Model;

my $m = MLM::Income::Model->new();
$m->{ARGS}->{TwoUp} = { enabled => 1, upline_percent => 0, keeper_percent => 0, company_member_id => 1 };
$m->_ensure_dbh();

if (! $m->{DBH}) {
    plan skip_all => 'DB connection not available (install DBD::mysql and set conf/config.json Db)';
    exit;
}

# Seed members (idempotent)
$m->do_sql("INSERT IGNORE INTO member (memberid, login, passwd, active, typeid, email, sid, pid, top, leg, signuptime, created) VALUES (100,'upline','x','Yes',1,'upline\@example.com',1,1,1,'L',NOW(),NOW())");
$m->do_sql("INSERT IGNORE INTO member (memberid, login, passwd, active, typeid, email, sid, pid, top, leg, signuptime, created) VALUES (200,'recruiter','x','Yes',1,'recruiter\@example.com',1,1,1,'L',NOW(),NOW())");
$m->do_sql("INSERT IGNORE INTO member (memberid, login, passwd, active, typeid, email, sid, pid, top, leg, signuptime, created) VALUES (301,'r1','x','Yes',1,'r1\@example.com',1,1,1,'L',NOW(),NOW())");
$m->do_sql("INSERT IGNORE INTO member (memberid, login, passwd, active, typeid, email, sid, pid, top, leg, signuptime, created) VALUES (302,'r2','x','Yes',1,'r2\@example.com',1,1,1,'L',NOW(),NOW())");
$m->do_sql("INSERT IGNORE INTO member (memberid, login, passwd, active, typeid, email, sid, pid, top, leg, signuptime, created) VALUES (303,'r3','x','Yes',1,'r3\@example.com',1,1,1,'L',NOW(),NOW())");

# Reset recruiter passups and link to upline
$m->_update_member(200, { passups_given => 0, real_sponsor_id => 100, tracking_sponsor_id => undef });

# Clean audit/ledger
$m->do_sql("DELETE FROM passup_event");
$m->do_sql("DELETE FROM commissions");

# R1: PASSUP_1
$m->handle_new_recruit_2up(200, 301, 1000.00, 5001);
my $r1 = $m->_get_member(301);
is($r1->{real_sponsor_id} + 0, 100, 'R1 real sponsor is upline');
is($r1->{tracking_sponsor_id} + 0, 200, 'R1 tracking sponsor is recruiter');

# R2: PASSUP_2
$m->handle_new_recruit_2up(200, 302, 1000.00, 5002);
my $r2 = $m->_get_member(302);
is($r2->{real_sponsor_id} + 0, 100, 'R2 real sponsor is upline');

# R3: KEEPER_3PLUS
$m->handle_new_recruit_2up(200, 303, 1000.00, 5003);
my $r3 = $m->_get_member(303);
is($r3->{real_sponsor_id} + 0, 200, 'R3 kept by recruiter');

# Idempotency: re-run R1 should not double
$m->handle_new_recruit_2up(200, 301, 1000.00, 5001);
my $count = $m->_count_commissions_for_order(5001);
is($count + 0, 1, 'No duplicate commissions for same order');

done_testing();



