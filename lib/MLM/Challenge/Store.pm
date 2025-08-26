package MLM::Challenge::Store;
use strict; 
use warnings;
use DBI;
use JSON;

sub new { 
    my ($class, %o) = @_; 
    my $self = bless { 
        dbh => $o{dbh}, 
        CUSTOM => $o{CUSTOM} 
    }, $class;
    $self->_ensure_dbh() unless $self->{dbh};
    return $self;
}

sub dbh { shift->{dbh} }

# Public API
sub ensure_phase0_and_phase1_unlocked {
  my ($self, $member_id) = @_;
  my $dbh = $self->dbh;
  # Phase 0 unlocked by default
  $dbh->do(q{
    INSERT IGNORE INTO `member_challenge_state`(`member_id`,`phase_number`)
    VALUES (?,0)
  }, undef, $member_id);

  # Phase 1 visible to purchase (not auto-unlocked; user must buy)
  # If you want Phase 1 pre-unlocked for viewing, skip writing anything here.
  return 1;
}

sub admin_unlock_phase {
  my ($self, $member_id, $phase_number) = @_;
  my $dbh = $self->dbh;
  $dbh->do(q{
    INSERT INTO `member_challenge_state`(`member_id`,`phase_number`,`unlocked_by_admin`)
    VALUES (?,?,1)
    ON DUPLICATE KEY UPDATE `unlocked_by_admin`=1
  }, undef, $member_id, $phase_number);
  return 1;
}

sub is_phase_unlocked_for_member {
  my ($self, $member_id, $phase_number) = @_;
  my $dbh = $self->dbh;
  my ($c) = $dbh->selectrow_array(
    q{SELECT 1 FROM `member_challenge_state` WHERE `member_id`=? AND `phase_number`=? LIMIT 1},
    undef, $member_id, $phase_number
  );
  return $c ? 1 : 0;
}

# Called after purchase completes successfully
sub record_purchase_and_attempt {
  my ($self, $member_id, $phase_number, $amount, $order_id, $is_repeat) = @_;
  my $dbh = $self->dbh;
  $dbh->do(q{
    INSERT INTO `member_challenge_attempt`(`member_id`,`phase_number`,`order_id`,`amount`,`is_repeat`)
    VALUES (?,?,?,?,?)
  }, undef, $member_id, $phase_number, $order_id, $amount, $is_repeat ? 1 : 0);

  if ($is_repeat) {
    $dbh->do(q{
      INSERT INTO `member_challenge_state`(`member_id`,`phase_number`,`repeat_count`)
      VALUES (?,?,1)
      ON DUPLICATE KEY UPDATE `repeat_count`=`repeat_count`+1
    }, undef, $member_id, $phase_number);
  } else {
    $dbh->do(q{
      INSERT IGNORE INTO `member_challenge_state`(`member_id`,`phase_number`)
      VALUES (?,?)
    }, undef, $member_id, $phase_number);
  }
  return 1;
}

# Mark completion; optionally unlock next phase for purchase
sub mark_completed_and_maybe_unlock_next {
  my ($self, $member_id, $phase_number) = @_;
  my $dbh = $self->dbh;
  $dbh->do(q{
    UPDATE `member_challenge_state` SET `completed_at`=COALESCE(`completed_at`, NOW())
    WHERE `member_id`=? AND `phase_number`=?
  }, undef, $member_id, $phase_number);

  my $cfg = $self->{CUSTOM}->{Challenges} || {};
  if ($cfg->{auto_unlock_next_on_complete}) {
    my $next = $phase_number + 1;
    $dbh->do(q{
      INSERT IGNORE INTO `member_challenge_state`(`member_id`,`phase_number`)
      VALUES (?,?)
    }, undef, $member_id, $next);
  }
  return 1;
}

sub get_member_challenge_progress {
  my ($self, $member_id) = @_;
  my $dbh = $self->dbh;
  
  my $progress = $dbh->selectall_arrayref(q{
    SELECT mcs.phase_number, mcs.unlocked_at, mcs.completed_at, 
           mcs.unlocked_by_admin, mcs.repeat_count,
           cp.title, cp.price, cp.requires_prev
    FROM member_challenge_state mcs
    LEFT JOIN challenge_package cp ON mcs.phase_number = cp.phase_number
    WHERE mcs.member_id = ?
    ORDER BY mcs.phase_number
  }, { Slice => {} }, $member_id);
  
  return $progress;
}

sub get_available_packages {
  my ($self, $member_id) = @_;
  my $dbh = $self->dbh;
  
  my $packages = $dbh->selectall_arrayref(q{
    SELECT cp.package_id, cp.item_id, cp.phase_number, cp.title, cp.price,
           cp.requires_prev, cp.image_url, ci.title as item_title,
           cc.name as category_name,
           CASE WHEN mcs.member_id IS NOT NULL THEN 1 ELSE 0 END as is_unlocked,
           CASE WHEN mcs.completed_at IS NOT NULL THEN 1 ELSE 0 END as is_completed,
           mcs.repeat_count
    FROM challenge_package cp
    JOIN challenge_item ci ON cp.item_id = ci.item_id
    JOIN challenge_category cc ON ci.category_id = cc.category_id
    LEFT JOIN member_challenge_state mcs ON cp.phase_number = mcs.phase_number AND mcs.member_id = ?
    WHERE cp.active = 1 AND ci.active = 1 AND cc.active = 1
    ORDER BY cp.phase_number
  }, { Slice => {} }, $member_id);
  
  return $packages;
}

sub _ensure_dbh {
    my $self = shift;
    # Only return if we have a real DBI handle
    if ($self->{dbh}) {
        my $ok;
        eval { $ok = ($self->{dbh}->can('prepare') ? 1 : 0) };
        return if $ok;
    }
    my $config_path = '/Users/arfeenkhan/mlm-project/mlm/conf/config.json';
    if (open my $fh, '<', $config_path) {
        local $/; my $json = <$fh>; close $fh;
        my $cfg = eval { decode_json($json) } || {};
        if ($cfg->{Db} && ref $cfg->{Db} eq 'ARRAY') {
            my ($dsn,$user,$pass) = @{$cfg->{Db}};
            my $dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1 });
            $self->{dbh} = $dbh;
        }
    }
    return;
}

1;


