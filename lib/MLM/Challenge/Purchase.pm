package MLM::Challenge::Purchase;
use strict; 
use warnings;
use MLM::Challenge::Store;
use DBI;
use JSON;

sub new { 
    my ($class, %o) = @_; 
    my $self = bless { 
        dbh=>$o{dbh}, 
        CUSTOM=>$o{CUSTOM}, 
        Income=>$o{Income} 
    }, $class;
    $self->_ensure_dbh() unless $self->{dbh};
    return $self;
}

sub dbh { shift->{dbh} }

# Entry point called when a user buys a challenge package
# args: buyer_id, recruiter_id, phase_number, order_id
sub handle_challenge_purchase {
  my ($self, $buyer_id, $recruiter_id, $phase_number, $order_id) = @_;
  my $dbh = $self->dbh;
  my $cfg = $self->{CUSTOM} || {};

  # Load canonical price & fixed % for this phase
  my $phase = $dbh->selectrow_hashref(
    q{SELECT `price`,`it_percent`,`iq_percent`,`keeper_percent` FROM `phase_fixed_commission` WHERE `phase_number`=?},
    undef, $phase_number
  ) || die "phase_fixed_commission missing for phase $phase_number";

  # Enforce requires_prev unless unlocked_by_admin or repeat or user already completed prev
  my $requires_prev = 1;
  my ($pack_requires_prev) = $dbh->selectrow_array(
    q{SELECT `requires_prev` FROM `challenge_package` WHERE `phase_number`=? AND `active`=1 LIMIT 1},
    undef, $phase_number
  );
  $requires_prev = $pack_requires_prev if defined $pack_requires_prev;

  my $store = MLM::Challenge::Store->new(dbh=>$dbh, CUSTOM=>$cfg);
  $store->ensure_phase0_and_phase1_unlocked($buyer_id);

  my $is_repeat = 0;
  my ($prev_completed) = $dbh->selectrow_array(
    q{SELECT 1 FROM `member_challenge_state` WHERE `member_id`=? AND `phase_number`=? AND `completed_at` IS NOT NULL LIMIT 1},
    undef, $buyer_id, $phase_number
  );
  $is_repeat = $prev_completed ? 1 : 0;

  if ($cfg->{Challenges}->{enforce_requires_prev} && $requires_prev) {
    # Must have completed previous phase or admin unlocked
    my ($admin_unlocked) = $dbh->selectrow_array(
      q{SELECT 1 FROM `member_challenge_state` WHERE `member_id`=? AND `phase_number`=? AND `unlocked_by_admin`=1 LIMIT 1},
      undef, $buyer_id, $phase_number
    );
    my $prev_phase = $phase_number - 1;
    my ($has_prev_completed) = $dbh->selectrow_array(
      q{SELECT 1 FROM `member_challenge_state` WHERE `member_id`=? AND `phase_number`=? AND `completed_at` IS NOT NULL LIMIT 1},
      undef, $buyer_id, $prev_phase
    );
    die "Phase $phase_number locked (complete phase $prev_phase or admin unlock)" unless ($has_prev_completed || $admin_unlocked || $is_repeat || $phase_number == 1);
  }

  # Create sale row (annotated)
  $dbh->do(
    q{INSERT INTO `sale`(`memberid`,`amount`,`created`,`challenge_phase`,`repeat_flag`,`typeid`) VALUES (?,?,NOW(),?,?,1)},
    undef, $buyer_id, $phase->{price}, $phase_number, ($is_repeat?1:0)
  );
  my $orderid = $order_id || $dbh->last_insert_id(undef,undef,undef,undef);

  # Record attempt (and unlock state record if first time)
  $store->record_purchase_and_attempt($buyer_id, $phase_number, $phase->{price}, $orderid, $is_repeat);

  # Call existing 2-Up flow (per-phase instance + SoR reuse). Recruiter is who invited buyer to this phase.
  my $Income = $self->{Income};
  if ($Income && $Income->can('join_phase_instance_2up')) {
    $Income->join_phase_instance_2up($recruiter_id, $buyer_id, $phase_number, $phase->{price}, $orderid);
  } else {
    # Fallback to simple commission calculation
    $self->_calculate_simple_commission($buyer_id, $recruiter_id, $phase_number, $phase->{price}, $orderid);
  }

  return { order_id => $orderid, amount => $phase->{price}, phase_number => $phase_number, repeat => $is_repeat };
}

sub _calculate_simple_commission {
  my ($self, $buyer_id, $recruiter_id, $phase_number, $amount, $order_id) = @_;
  my $dbh = $self->dbh;
  
  # Get fixed commission percentages
  my $phase = $dbh->selectrow_hashref(
    q{SELECT `it_percent`,`iq_percent`,`keeper_percent` FROM `phase_fixed_commission` WHERE `phase_number`=?},
    undef, $phase_number
  ) || return;
  
  # Pay IT (10%)
  my $it_amount = sprintf('%.2f', $amount * $phase->{it_percent});
  if ($it_amount > 0) {
    $dbh->do(q{
      INSERT INTO commissions (payer_user_id, receiver_user_id, basis_amount, percent, amount, reason_code, order_id)
      VALUES (?,?,?,?,?,?,?)
    }, undef, $buyer_id, $recruiter_id, $amount, $phase->{it_percent}, $it_amount, "CHALLENGE_IT_P${phase_number}", $order_id);
  }
  
  # Get sponsor for IQ (30%)
  my ($sponsor_id) = $dbh->selectrow_array(
    q{SELECT sid FROM member WHERE memberid=?}, undef, $recruiter_id
  );
  
  if ($sponsor_id && $sponsor_id != $recruiter_id) {
    my $iq_amount = sprintf('%.2f', $amount * $phase->{iq_percent});
    if ($iq_amount > 0) {
      $dbh->do(q{
        INSERT INTO commissions (payer_user_id, receiver_user_id, basis_amount, percent, amount, reason_code, order_id)
        VALUES (?,?,?,?,?,?,?)
      }, undef, $buyer_id, $sponsor_id, $amount, $phase->{iq_percent}, $iq_amount, "CHALLENGE_IQ_P${phase_number}", $order_id);
    }
  }
  
  return 1;
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


