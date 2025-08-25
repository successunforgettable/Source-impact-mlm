package MLM::Income::Model;

use strict;
use MLM::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('MLM::Model');

sub log_commissions {
    my $self = shift;
    my $commissions = shift;
    my $sth = $self->{dbh}->prepare(
        "INSERT INTO commission_log (transaction_id, source_member_id, recipient_member_id, commission_type, amount, phase_level, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())"
    );
    foreach my $c (@$commissions) {
        my $tid = "T" . time() . int(rand(1000));
        $sth->execute($tid, $c->{source_member_id}, $c->{recipient_member_id}, $c->{type}, $c->{amount}, $c->{phase});
    }
    $sth->finish();
    return;
}

sub run_to_yesterday {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  my $join = ($ARGS->{from} && $ARGS->{to}) ? "'".$ARGS->{to}."'" : "DATE_SUB(CURDATE(), INTERVAL 1 DAY)";
  my $yesterday = ($ARGS->{from} && $ARGS->{to})
    ? "w1.daily BETWEEN '".$ARGS->{from}."' AND '".$ARGS->{to}."'"
    : "w1.daily<=DATE_SUB(CURDATE(), INTERVAL 1 DAY)";

  my $arr = [];

  my $err = $self->select_sql($arr,
"SELECT DATE_SUB(w1.daily, INTERVAL 7 DAY) AS start_daily,
    DATE_SUB(w1.daily, INTERVAL 1 DAY) AS end_daily,
    DATE_SUB(w4.daily, INTERVAL 28 DAY) AS start_monthly,
    c1_id, w1.daily, weekly, statusBinary, statusUp, statusAffiliate, c4_id, status
FROM cron_1week w1
LEFT JOIN cron_4week w4 ON (w1.c1_id=w4.c4_id AND w4.daily<=$join)
WHERE (statusBinary='No' OR statusUp='No' OR statusAffiliate='No' OR status='No')
AND $yesterday
ORDER BY c1_id");
  return $err if $err;

  for my $item (@$arr) {
    $err = $self->call_once({model=>"member", action=>"bulk"}, {upto=>$item->{end_daily}});
    return $err if $err;
    $ARGS->{start_monthly} = $item->{start_monthly};
    $ARGS->{start_daily} = $item->{start_daily};
    $ARGS->{end_daily} = $item->{end_daily};
    if ($item->{c4_id} && $item->{status} eq 'No') {
      $ARGS->{c4_id} = $item->{c4_id}-1;
      $ARGS->{to_run_direct} = 1;  
    }
    $ARGS->{c1_id} = $item->{c1_id}-1;
    if ($item->{statusBinary} eq 'No') {
      $ARGS->{to_run_binary} = 1;  
    }
    if ($item->{statusUp} eq 'No') {
      $ARGS->{to_run_match} = 1;
    }
    if ($item->{statusAffiliate} eq 'No') {
      $ARGS->{to_run_affiliate} = 1;  
    }
    return $self->run_cron();
  }

  return;
}

sub run_all_tests {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  for my $item (qw(to_run_direct to_run_binary to_run_match to_run_affiliate to_run_2up to_run_leadership)) {
    $ARGS->{$item} = 1;
  }
  return $self->run_cron();
}

sub run_daily {
  my $self = shift;

  return $self->is_week1_affiliate() || $self->is_week1_binary() || $self->is_week1_match() || $self->is_week4_direct() || $self->is_week1_2up() || $self->is_week1_leadership() || $self->run_cron();
}

sub run_cron {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  my $err;
  # Legacy plans - assuming they still use the old `income` table flow
  if ($ARGS->{to_run_direct}) {
    $err = $self->week4_direct() || $self->inserts() || $self->done_week4_direct() || $self->monthly_direct();
    return $err if $err;
  }
  if ($ARGS->{to_run_binary}) {
    $err = $self->week1_binary() || $self->inserts() || $self->done_week1_binary() || $self->weekly_binary();
    return $err if $err;
  }
  if ($ARGS->{to_run_match}) {
    $err = $self->week1_match() || $self->inserts() || $self->done_week1_match() || $self->weekly_match();
    return $err if $err;
  }
  if ($ARGS->{to_run_affiliate}) {
    $err = $self->week1_affiliate() || $self->inserts() || $self->done_week1_affiliate() || $self->weekly_affiliate();
    return $err if $err;
  }

  # New Advanced Plans
  if ($ARGS->{to_run_2up}) {
    $err = $self->week1_2up() || $self->done_week1_2up();
    return $err if $err;
  }
  if ($ARGS->{to_run_leadership}) {
    $err = $self->week1_leadership() || $self->done_week1_leadership();
    return $err if $err;
  }

  # Transfer newly logged commissions to income_ledger
  my $rate = $self->{config}->{Custom}->{RATE_shop};
  my $weekid = $ARGS->{c1_id} || $ARGS->{c4_id}; # Use the relevant week ID

  my $new_commissions = [];
  $self->select_sql($new_commissions, "SELECT recipient_member_id, SUM(amount) as total_amount, commission_type FROM commission_log WHERE weekid = ? GROUP BY recipient_member_id, commission_type", $weekid);

  # This part becomes more complex as commission_log doesn't have a 'status'.
  # For now, we assume all logged commissions for the week are new.
  # A more robust solution would add a status to commission_log.

  # A simplified transfer to income_amount for ledger processing
  my $sth = $self->{dbh}->prepare("INSERT INTO income_amount (memberid, weekid, amount, bonusType, status, created) VALUES (?, ?, ?, ?, 'New', NOW())");
  foreach my $comm (@$new_commissions) {
      my $bonusType = $comm->{commission_type};
      # Map commission_type to a shorter bonusType if needed, e.g. '2up_passup_recruiter' -> '2-Up'
      $bonusType = '2-Up' if $bonusType =~ /^2up_/;
      $bonusType = 'Leadership' if $bonusType =~ /^leadership_/;
      $sth->execute($comm->{recipient_member_id}, $weekid, $comm->{total_amount}, $bonusType);
  }
  $sth->finish();

  # The original income_ledger logic can now run.
  my $test_str = "AND weekid=0" if ($ARGS->{isTest} eq '1');
  return $self->do_sql(
"INSERT INTO income_ledger (memberid, weekid, amount, balance, shop_balance, old_ledgerid, status, created)
SELECT tmp.memberid, tmp.weekid, tmp.amount, IFNULL(v.balance,0)+(1-$rate)*tmp.amount, IFNULL(v.shop_balance,0)+$rate*tmp.amount, v.ledgerid, 'Weekly' AS status, NOW()
FROM (
  SELECT memberid, weekid, SUM(amount) AS amount
  FROM income_amount
  WHERE status='New' $test_str
  AND bonusType IN ('Direct', 'Binary', 'Up', 'Down', 'Affiliate', '2-Up', 'Leadership')
  GROUP BY memberid, weekid
) tmp
LEFT JOIN (
  SELECT l.memberid, l.ledgerid, l.balance, l.shop_balance
  FROM income_ledger l
  INNER JOIN view_balance v USING (ledgerid)
) v ON (tmp.memberid=v.memberid)") || $self->do_sql(
"UPDATE income_amount SET status='Done' WHERE status='New' $test_str");
}

sub is_week1_affiliate {
  my $self = shift;
  return $self->get_args($self->{ARGS},
"SELECT c1_id, daily AS start_daily, DATE_ADD(daily, INTERVAL 6 DAY) AS end_daily, 1 AS to_run_affiliate
FROM cron_1week
WHERE statusAffiliate='No' AND DATE_ADD(daily, INTERVAL 7 DAY)=CURDATE()");
}

sub week1_affiliate {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  $self->{LISTS} = [];
  return $self->select_sql($self->{LISTS},
"SELECT 'affiliate' AS classify, '".$ARGS->{c1_id}."' AS weekid,
	COUNT(*) AS amount, t.typeid AS refid, 1 AS lev,
	s.memberid AS memberid
FROM member m
INNER JOIN member_affiliate s ON (m.affiliate=s.memberid)
INNER JOIN def_type t USING (typeid)
WHERE m.active='Yes'
AND (DATE(m.signuptime) BETWEEN ? AND ?)
GROUP BY s.memberid, t.typeid", $ARGS->{start_daily}, $ARGS->{end_daily});
}
 
sub done_week1_affiliate {
  my $self = shift;
  return $self->do_sql(
"UPDATE cron_1week SET statusAffiliate='Yes'
WHERE c1_id=? AND statusAffiliate='No'", $self->{ARGS}->{c1_id});
}

sub weekly_affiliate {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  my $bonus = $ARGS->{rate_affiliate};

  return $self->do_sql(
"INSERT INTO income_amount (memberid, amount, weekid, bonusType, created)
SELECT memberid, SUM(amount*t.price*$bonus), weekid, 'Affiliate', NOW()
FROM income i
INNER JOIN def_type t ON (i.refid=t.typeid)
WHERE classify='affiliate' AND paystatus='new' AND weekid=?
GROUP BY memberid", $ARGS->{c1_id}) || $self->do_sql(
"UPDATE income SET paystatus='paid'
WHERE paystatus='new' AND classify='affiliate'
AND weekid=?", $ARGS->{c1_id});
}

sub is_week1_binary {
  my $self = shift;
  return $self->get_args($self->{ARGS},
"SELECT c1_id, daily AS start_daily, DATE_ADD(daily, INTERVAL 6 DAY) AS end_daily, 1 AS to_run_binary
FROM cron_1week
WHERE statusBinary='No' AND DATE_ADD(daily, INTERVAL 7 DAY)=CURDATE()");
}

sub week1_binary {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  my $UNIT = $ARGS->{BIN}->{unit};

  my $lists = [];
  my $err = $self->select_sql($lists,
"SELECT memberid, FLOOR(miler/$UNIT) AS miler, FLOOR(milel/$UNIT) AS milel, yes21
FROM member m
INNER JOIN def_type t USING (typeid)
WHERE active='Yes'
AND m.miler>=$UNIT AND m.milel>=$UNIT");
  return $err if $err;

  #l1:r1 => 1, l1:r2 => 2, l2:r1 => 3
  $self->{LISTS} = [];
  for my $item (@$lists) {
    my $miler = $item->{miler};
    my $milel = $item->{milel};

    my $amount = $miler;
    my $refid = $milel;
    my $lev = 11;
    if (($item->{yes21} eq 'Yes') and ($milel>=2*$miler)) {
      $refid = 2*$miler;
      $lev = 21;
    }
    if ($miler>$milel) {
      $amount = $milel;
      $refid = $miler;
      $lev = 11;
      if (($item->{yes21} eq 'Yes') and ($miler>=2*$milel)) {
        $refid = 2*$milel;
        $lev = 12;
      }
    }

    push @{$self->{LISTS}}, {
memberid=>$item->{memberid},
classify=>'binary',
weekid  =>$ARGS->{c1_id},
amount  =>$amount,
refid   =>$refid,
lev     =>$lev
    }
  } 
  return;
}
 
sub done_week1_binary {
  my $self = shift;
  return $self->do_sql(
"UPDATE cron_1week SET statusBinary='Yes'
WHERE c1_id=? AND statusBinary='No'", $self->{ARGS}->{c1_id});
}

sub weekly_binary {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  my $BIN = $ARGS->{BIN};
  my $rate = $BIN->{rate};
  my $rate21 = $BIN->{rate21};
  my $unit = $BIN->{unit};

  my $err = $self->do_sql(
"INSERT INTO income_amount (memberid, amount, weekid, bonusType, created)
SELECT tmp.memberid, IF(raw>c_upper, c_upper, raw), weekid, 'Binary', NOW()
FROM (
	SELECT i.memberid, i.weekid, IF(i.lev>11, i.amount*$unit*$rate21, i.amount*$unit*$rate) AS raw, c_upper
	FROM income i
	INNER JOIN member m USING (memberid)
	INNER JOIN def_type t USING (typeid)
	WHERE i.classify='binary' AND i.paystatus='new'
	AND i.weekid=?
) tmp", $ARGS->{c1_id}) || $self->do_sql(
"UPDATE income SET paystatus='paid'
WHERE paystatus='new' AND classify='binary'
AND weekid=?", $self->{ARGS}->{c1_id}) || $self->do_sql(
"UPDATE member m 
INNER JOIN income i USING (memberid)
SET m.miler=m.miler-IF(i.lev=12, 2*i.amount*$unit, i.amount*$unit),
    m.milel=m.milel-IF(i.lev=21, 2*i.amount*$unit, i.amount*$unit)
WHERE i.classify='binary' AND i.paystatus='paid'
AND i.weekid=?", $ARGS->{c1_id});
}

sub is_week1_match {
  my $self = shift;
  return $self->get_args($self->{ARGS},
"SELECT c1_id, daily AS start_daily, DATE_ADD(daily, INTERVAL 6 DAY) AS end_daily, 1 AS to_run_match
FROM cron_1week
WHERE statusUp='No' AND DATE_ADD(daily, INTERVAL 7 DAY)=CURDATE()");
}

sub week1_match {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  $ARGS->{MAX} = 0;
  my $ref_match = {};
  my $tmp = [];
  my $err = $self->select_sql($tmp,
"SELECT typeid, lev, rate FROM def_match");
  return $err if $err;
  for my $item (@$tmp) {
    $ref_match->{$item->{typeid}}->{$item->{lev}} = $item->{rate}; 
    $ARGS->{MAX} = $item->{lev} if ($ARGS->{MAX} < $item->{lev});
  }

  my $parent = {};
  $tmp = [];
  $err = $self->select_sql($tmp,
"SELECT m.memberid, m.sid, s.typeid, s.active
FROM member m
LEFT JOIN member s ON (m.sid=s.memberid)
WHERE m.active='Yes'") and return $err;
  for my $item (@$tmp) {
    $parent->{$item->{memberid}} = $item;
  }

  $tmp = [];
  $err = $self->select_sql($tmp,
"SELECT m.memberid, m.typeid
FROM member m
WHERE (DATE(m.signuptime) BETWEEN ? AND ?)
AND m.active='Yes'", $ARGS->{start_daily}, $ARGS->{end_daily}) and return $err;

  my $counts = {};
  for my $item (@$tmp) {
    my $childid = $item->{memberid}; 
    for (my $i=1; $i<=$ARGS->{MAX}; $i++) {
      my $ref = $parent->{$childid};
      last unless $ref;
      my $sid = $ref->{sid};
      last if ($sid==$ARGS->{top_memberid});
      $childid = $sid;
      next if ($i==1); # the direct bonus is already in week4_direct
      next unless (($ref->{active} eq 'Yes') and $ref_match->{$ref->{typeid}} and $ref_match->{$ref->{typeid}}->{$i});
      $counts->{$sid}->{$item->{typeid}}->{$i} += 1;
    }
  }

  $self->{LISTS} = [];
  for my $sid (keys %$counts) {
    for my $typeid (keys %{$counts->{$sid}}) {
       for my $level (keys %{$counts->{$sid}->{$typeid}}) {
		 push @{$self->{LISTS}}, {
classify=>'matchup',
weekid  =>$ARGS->{c1_id},
memberid=>$sid,
refid   =>$typeid,
lev     =>$level,
amount  =>$counts->{$sid}->{$typeid}->{$level}};
      }
    } 
  } 

  return;
}
 
sub done_week1_match {
  my $self = shift;
  return $self->do_sql(
"UPDATE cron_1week SET statusUp='Yes'
WHERE c1_id=? AND statusUp='No'", $self->{ARGS}->{c1_id});
}

sub weekly_match {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  my $cut = $ARGS->{rate_matchdown};

  return $self->do_sql(
"INSERT INTO income_amount (memberid, amount, weekid, bonusType, created)
SELECT i.memberid, SUM(i.amount*t.price*h.rate), weekid, 'Up', NOW()
FROM income i
INNER JOIN def_type t ON (i.refid=t.typeid)
INNER JOIN def_match h ON (i.refid=h.typeid AND i.lev=h.lev)
WHERE i.classify='matchup' AND i.paystatus='new' AND i.weekid=?
GROUP BY i.memberid", $ARGS->{c1_id}) || $self->do_sql(
"UPDATE income SET paystatus='paid'
WHERE classify='matchup' AND paystatus='new'
AND weekid=?", $ARGS->{c1_id}) || $self->do_sql(
"INSERT INTO income_amount (memberid, amount, weekid, bonusType, created)
SELECT m.memberid, SUM(i.amount*$cut/tmp.counts), weekid, 'Down', NOW()
FROM income_amount i
INNER JOIN (SELECT s.sid, count(*) AS counts
	FROM member s
	INNER JOIN member m ON (s.memberid=m.sid)
	WHERE m.active='Yes'
	GROUP BY s.sid) tmp ON (i.memberid=tmp.sid)
INNER JOIN member m ON (i.memberid=m.sid)
WHERE i.weekid=? AND i.bonusType='Up' AND m.active='Yes'
GROUP BY m.memberid", $ARGS->{c1_id});
}

sub is_week4_direct {
  my $self = shift;
  return $self->get_args($self->{ARGS},
"SELECT c4_id, daily AS start_monthly, DATE_ADD(daily, INTERVAL 27 DAY) AS end_daily, 1 AS to_run_direct
FROM cron_4week
WHERE status='No' AND DATE_ADD(daily, INTERVAL 28 DAY)=CURDATE()");
}

sub week4_direct {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  $self->{LISTS} = [];
  return $self->select_sql($self->{LISTS},
"SELECT m.sid AS memberid, m.typeid AS refid, 1 AS lev,
	COUNT(*) AS amount, '".$ARGS->{c4_id}."' AS weekid, 'direct' AS classify
FROM member m
INNER JOIN def_type t ON (m.typeid=t.typeid)
INNER JOIN member s ON (m.sid=s.memberid)
WHERE (DATE(m.signuptime) BETWEEN ? AND ?) AND m.active='Yes'
GROUP BY m.sid, m.typeid", $ARGS->{start_monthly}, $ARGS->{end_daily});
}

sub done_week4_direct {
  my $self = shift;
  return $self->do_sql(
"UPDATE cron_4week SET status='Yes'
WHERE c4_id=? AND status='No'", $self->{ARGS}->{c4_id});
}

sub monthly_direct {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  return $self->do_sql(
"INSERT INTO income_amount (memberid, amount, weekid, bonusType, created)
SELECT i.memberid, SUM(i.amount*d.bonus), '".$ARGS->{c4_id}."', 'Direct', NOW()
FROM income i
INNER JOIN member m USING (memberid)
INNER JOIN def_direct d ON (m.typeid=d.typeid AND i.refid=d.whoid)
WHERE i.classify='direct' AND i.paystatus='new' AND i.weekid=?
GROUP BY i.memberid", $ARGS->{c4_id}) || $self->do_sql(
"UPDATE income SET paystatus='paid'
WHERE classify='direct' AND paystatus='new'
AND weekid=?", $ARGS->{c4_id});
}

# --- 2-Up + Leadership Compensation Plan ---

sub _get_upline {
    my ($self, $member_id, $sponsors_href) = @_;
    my @upline;
    my $current_id = $member_id;
    my %visited;
    while (defined $current_id && $current_id > 1 && !$visited{$current_id}) {
        $visited{$current_id} = 1;
        my $sponsor_id = $sponsors_href->{$current_id};
        last unless defined $sponsor_id;
        push @upline, $sponsor_id;
        $current_id = $sponsor_id;
    }
    return \@upline;
}

sub is_week1_2up {
    my $self = shift;
    return $self->get_args($self->{ARGS},
"SELECT c1_id, daily AS start_daily, DATE_ADD(daily, INTERVAL 6 DAY) AS end_daily, 1 AS to_run_2up
FROM cron_1week
WHERE status_2up='No' AND DATE_ADD(daily, INTERVAL 7 DAY)=CURDATE()");
}

sub week1_2up {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    my $config = $self->{config}->{Custom}->{TWOUP};
    my @commissions;

    # 1. Fetch all members data once to build hierarchy and status map
    my ($sponsors, $members) = ({}, {});
    my $all_members_data = [];
    my $err = $self->select_sql($all_members_data, "SELECT memberid, sid, status, current_phase, pass_up_count FROM member");
    return $err if $err;
    foreach my $m (@$all_members_data) {
        $sponsors->{$m->{memberid}} = $m->{sid};
        $members->{$m->{memberid}} = $m;
    }

    # 2. Get all sales for the period
    my $sales = [];
    $err = $self->select_sql($sales,
        "SELECT m.memberid, m.sid, m.typeid, p.bv, m.current_phase AS sale_phase
         FROM member m
         JOIN def_type p ON m.typeid = p.typeid
         WHERE m.active = 'Yes' AND DATE(m.signuptime) BETWEEN ? AND ?",
        $ARGS->{start_daily}, $ARGS->{end_daily}
    );
    return $err if $err;

    # 3. Process each sale
    for my $sale (@$sales) {
        my $recruiter_id = $sale->{sid};
        my $recruiter = $members->{$recruiter_id};
        next unless $recruiter;

        # 3a. Handle pass-up logic for ITs
        if ($recruiter->{status} eq 'iT') {
            my $upline = $self->_get_upline($recruiter_id, $sponsors);
            my $pass_up_recipient_id;
            foreach my $upline_id (@$upline) {
                if ($members->{$upline_id} && $members->{$upline_id}->{status} eq 'iQ') {
                    $pass_up_recipient_id = $upline_id;
                    last;
                }
            }

            if ($pass_up_recipient_id) {
                # Recruiter gets 10%
                push @commissions, { source_member_id => $sale->{memberid}, recipient_member_id => $recruiter_id, type => '2up_passup_recruiter', amount => $sale->{bv} * $config->{recruiter_commission_rate_qualifying}, phase => $sale->{sale_phase} };
                # Qualified upline gets 30%
                push @commissions, { source_member_id => $sale->{memberid}, recipient_member_id => $pass_up_recipient_id, type => '2up_passup_upline', amount => $sale->{bv} * $config->{upline_commission_rate_qualifying}, phase => $sale->{sale_phase} };

                # Update pass-up count for recruiter
                $recruiter->{pass_up_count}++;
                if ($recruiter->{pass_up_count} >= $config->{pass_up_requirement}) {
                    $recruiter->{status} = 'iQ';
                }
            }
        } else { # Recruiter is IQ
            # 3b. Handle regular IQ commission
            my $upline = $self->_get_upline($recruiter_id, $sponsors);
            my $phase_recipient_id = $recruiter_id;

            # Find nearest upline qualified for the sale's phase
            if($recruiter->{current_phase} < $sale->{sale_phase}) {
                foreach my $upline_id (@$upline) {
                    if ($members->{$upline_id} && $members->{$upline_id}->{status} eq 'iQ' && $members->{$upline_id}->{current_phase} >= $sale->{sale_phase}) {
                        # Check if this upline member is phase-qualified
                        my $downline_count_at_phase = 0;
                        # This check is simplified, a real implementation would need to query the downline
                        $phase_recipient_id = $upline_id;
                        last;
                    }
                }
            }
            push @commissions, { source_member_id => $sale->{memberid}, recipient_member_id => $phase_recipient_id, type => '2up_iq_commission', amount => $sale->{bv} * $config->{iq_commission_rate}, phase => $sale->{sale_phase} };
        }
    }

    # 4. Log all commissions
    $self->log_commissions(\@commissions);

    # 5. Batch update member statuses
    my $sth = $self->{dbh}->prepare("UPDATE member SET status = ?, pass_up_count = ? WHERE memberid = ?");
    foreach my $member_id (keys %$members) {
        my $m = $members->{$member_id};
        # Only update if changed
        if ($m->{status} ne $all_members_data->[0]->{status} || $m->{pass_up_count} != $all_members_data->[0]->{pass_up_count}) {
           $sth->execute($m->{status}, $m->{pass_up_count}, $member_id);
        }
    }
    $sth->finish();

    return;
}

sub done_week1_2up {
    my $self = shift;
    return $self->do_sql(
"UPDATE cron_1week SET status_2up='Yes'
WHERE c1_id=? AND status_2up='No'", $self->{ARGS}->{c1_id});
}

sub weekly_2up {
    # This method might be deprecated in favor of direct logging in commission_log
    # and then transferring to income_ledger.
    return;
}

sub is_week1_leadership {
    my $self = shift;
    return $self->get_args($self->{ARGS},
"SELECT c1_id, daily AS start_daily, DATE_ADD(daily, INTERVAL 6 DAY) AS end_daily, 1 AS to_run_leadership
FROM cron_1week
WHERE status_leadership='No' AND DATE_ADD(daily, INTERVAL 7 DAY)=CURDATE()");
}

sub week1_leadership {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    my $config = $self->{config}->{Custom}->{LEADERSHIP};
    my @commissions;

    # 1. Fetch sales volume for the week
    my $total_volume_arr = [];
    $self->select_sql($total_volume_arr,
        "SELECT SUM(p.bv) AS total_bv FROM member m JOIN def_type p ON m.typeid = p.typeid WHERE m.active = 'Yes' AND DATE(m.signuptime) BETWEEN ? AND ?",
        $ARGS->{start_daily}, $ARGS->{end_daily}
    );
    my $total_volume = $total_volume_arr->[0]->{total_bv} || 0;

    # 2. Fetch leadership hierarchy
    my ($leaders, $hierarchy) = ({}, {});
    my $leaders_data = [];
    $self->select_sql($leaders_data, "SELECT member_id, upline_id, position FROM leadership_hierarchy");
    foreach my $l (@$leaders_data) {
        $leaders->{$l->{member_id}} = $l;
        push @{$hierarchy->{$l->{upline_id}}}, $l->{member_id} if $l->{upline_id};
    }

    # 3. Calculate and log commissions for each sale
    my $sales = [];
    $self->select_sql($sales, "SELECT memberid, sid, bv FROM member m JOIN def_type p ON m.typeid = p.typeid WHERE m.active = 'Yes' AND DATE(m.signuptime) BETWEEN ? AND ?", $ARGS->{start_daily}, $ARGS->{end_daily});

    foreach my $sale (@$sales) {
        my $upline = $self->_get_upline($sale->{sid}, $sponsors);
        my %paid_ranks;
        foreach my $upline_id (@$upline) {
            my $leader = $leaders->{$upline_id};
            next unless $leader;
            my $rank = $leader->{position};
            my $rank_config = $config->{ranks}->{$rank};

            if ($rank_config && !$paid_ranks{$rank}) {
                 push @commissions, {
                    source_member_id => $sale->{memberid},
                    recipient_member_id => $upline_id,
                    type => "leadership_$rank",
                    amount => $sale->{bv} * $rank_config->{rate},
                    phase => 0
                };
                $paid_ranks{$rank} = 1; # Pay each rank once per sale
            }
        }
    }

    # 4. Log commissions
    $self->log_commissions(\@commissions);

    # Logic for NTM breakaway and orphan assignment would be complex and is omitted here.
    # It would involve altering the leadership_hierarchy table.

    return;
}

sub done_week1_leadership {
    my $self = shift;
    return $self->do_sql(
"UPDATE cron_1week SET status_leadership='Yes'
WHERE c1_id=? AND status_leadership='No'", $self->{ARGS}->{c1_id});
}

sub weekly_leadership {
    # This method is also likely deprecated.
    return;
}

1;
