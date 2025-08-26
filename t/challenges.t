use strict; use warnings;
use Test::More;
use lib 'lib';
use DBI;
use JSON;
use MLM::Challenge::Store;
use MLM::Challenge::Purchase;

# Load config
my $config_path = "/Users/arfeenkhan/mlm-project/mlm/conf/config.json";
open my $fh, "<", $config_path or die "Cannot read config: $!";
local $/; my $json = <$fh>; close $fh;
my $cfg = decode_json($json);

# Connect to DB
my ($dsn,$user,$pass) = @{$cfg->{Db}};
my $dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 1, AutoCommit => 1 });

my $store = MLM::Challenge::Store->new(dbh=>$dbh, CUSTOM=>$cfg->{Custom});
my $purchase = MLM::Challenge::Purchase->new(dbh=>$dbh, CUSTOM=>$cfg->{Custom}, Income=>undef);

# Clean up test data first
$dbh->do("DELETE FROM `member_challenge_state` WHERE `member_id` IN (800,900)");
$dbh->do("DELETE FROM `member_challenge_attempt` WHERE `member_id` IN (800,900)");
$dbh->do("DELETE FROM `sale` WHERE `memberid` IN (900) AND `challenge_phase` IS NOT NULL");
$dbh->do("DELETE FROM `commissions` WHERE `payer_user_id`=900 AND `reason_code` LIKE 'CHALLENGE_%'");

# Seed member 900 & recruiter 800
$dbh->do("INSERT IGNORE INTO \`member\`(\`memberid\`,\`login\`,\`passwd\`,\`active\`,\`typeid\`,\`email\`,\`sid\`,\`pid\`,\`top\`,\`leg\`,\`signuptime\`,\`created\`) VALUES (800,'test800','x','Yes',1,'test800\@test.com',1,1,1,'L',NOW(),NOW())");
$dbh->do("INSERT IGNORE INTO \`member\`(\`memberid\`,\`login\`,\`passwd\`,\`active\`,\`typeid\`,\`email\`,\`sid\`,\`pid\`,\`top\`,\`leg\`,\`signuptime\`,\`created\`) VALUES (900,'test900','x','Yes',1,'test900\@test.com',800,800,1,'L',NOW(),NOW())");

# Seed fixed commission data
$dbh->do("INSERT IGNORE INTO `phase_fixed_commission`(`phase_number`,`price`,`it_percent`,`iq_percent`,`keeper_percent`) VALUES (0,0.00,0.10,0.30,0.40), (1,100.00,0.10,0.30,0.40), (2,200.00,0.10,0.30,0.40)");

# Test 1: Ensure visibility
$store->ensure_phase0_and_phase1_unlocked(900);
my ($p0_unlocked) = $dbh->selectrow_array("SELECT 1 FROM `member_challenge_state` WHERE `member_id`=900 AND `phase_number`=0");
ok($p0_unlocked, 'Phase 0 unlocked after ensure call');

# Test 2: Buy P1 (new)
my $r1 = $purchase->handle_challenge_purchase(900, 800, 1, undef);
ok($r1->{order_id}, 'Phase 1 order created');
is($r1->{repeat}, 0, 'Phase 1 first purchase not marked as repeat');

# Test 3: Complete P1 -> unlock P2
$store->mark_completed_and_maybe_unlock_next(900, 1);
my ($p2_unlocked) = $dbh->selectrow_array("SELECT 1 FROM `member_challenge_state` WHERE `member_id`=900 AND `phase_number`=2");
ok($p2_unlocked, 'Phase 2 unlocked after completing Phase 1');

# Test 4: Buy P2 (new)
my $r2 = $purchase->handle_challenge_purchase(900, 800, 2, undef);
ok($r2->{order_id}, 'Phase 2 order created');
is($r2->{repeat}, 0, 'Phase 2 first purchase not marked as repeat');

# Test 5: Repeat P1 (repeat)
my $r3 = $purchase->handle_challenge_purchase(900, 800, 1, undef);
ok($r3->{order_id}, 'Repeat Phase 1 order created');
is($r3->{repeat}, 1, 'Phase 1 repeat purchase correctly marked as repeat');

# Test 6: Check repeat count
my ($repeat_count) = $dbh->selectrow_array("SELECT `repeat_count` FROM `member_challenge_state` WHERE `member_id`=900 AND `phase_number`=1");
ok($repeat_count && $repeat_count >= 1, 'Repeat count incremented for Phase 1');

# Test 7: Check sales flags
my $sales = $dbh->selectall_arrayref(
  "SELECT `challenge_phase`,`repeat_flag` FROM `sale` WHERE `memberid`=900 AND `challenge_phase` IS NOT NULL ORDER BY `created`",
  { Slice => {} }
);
ok(grep($_->{challenge_phase}==1 && $_->{repeat_flag}==0, @$sales), 'First P1 sale annotated correctly');
ok(grep($_->{challenge_phase}==2 && $_->{repeat_flag}==0, @$sales), 'P2 sale annotated correctly');
ok(grep($_->{challenge_phase}==1 && $_->{repeat_flag}==1, @$sales), 'Repeat P1 sale annotated correctly');

# Test 8: Check member attempts
my $attempts = $dbh->selectall_arrayref(
  "SELECT `phase_number`, COUNT(*) as attempts, SUM(`is_repeat`) as repeats FROM `member_challenge_attempt` WHERE `member_id`=900 GROUP BY `phase_number`",
  { Slice => {} }
);
my $p1_attempts = (grep { $_->{phase_number} == 1 } @$attempts)[0];
ok($p1_attempts && $p1_attempts->{attempts} >= 2, 'Phase 1 has multiple attempts recorded');
ok($p1_attempts && $p1_attempts->{repeats} >= 1, 'Phase 1 has repeat attempts recorded');

# Test 9: Commissions exist
my $comms = $dbh->selectall_arrayref(
  "SELECT `reason_code` FROM `commissions` WHERE `payer_user_id`=900",
  { Slice => {} }
);
ok(scalar(@$comms) > 0, 'Commissions booked for purchases');

# Test 10: Admin unlock functionality
$store->admin_unlock_phase(900, 3);
my ($p3_admin_unlocked) = $dbh->selectrow_array("SELECT `unlocked_by_admin` FROM `member_challenge_state` WHERE `member_id`=900 AND `phase_number`=3");
ok($p3_admin_unlocked, 'Admin unlock sets unlocked_by_admin flag');

# Test 11: Phase unlock check
ok($store->is_phase_unlocked_for_member(900, 0), 'Phase 0 shows as unlocked');
ok($store->is_phase_unlocked_for_member(900, 1), 'Phase 1 shows as unlocked');
ok($store->is_phase_unlocked_for_member(900, 2), 'Phase 2 shows as unlocked');
ok($store->is_phase_unlocked_for_member(900, 3), 'Phase 3 shows as unlocked (admin)');
ok(!$store->is_phase_unlocked_for_member(900, 4), 'Phase 4 shows as locked');

done_testing();
