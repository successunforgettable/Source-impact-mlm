package MLM::Income::Model;

use strict;
use MLM::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('MLM::Model');

sub inserts {
  my $self = shift;

  for my $item (@{$self->{LISTS}}) {
    my $err = $self->do_sql(
"INSERT INTO income (memberid, classify, weekid, refid, amount, lev, created)
VALUES (?,?,?,?,?,?,NOW())",$item->{memberid}, $item->{classify},
	$item->{weekid}, $item->{refid}, $item->{amount}, $item->{lev});
    return $err if $err;
  }

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
  if ($ARGS->{to_run_2up}) {
    $err = $self->week1_2up() || $self->inserts() || $self->done_week1_2up() || $self->weekly_2up();
    return $err if $err;
  }
  if ($ARGS->{to_run_leadership}) {
    $err = $self->week1_leadership() || $self->inserts() || $self->done_week1_leadership() || $self->weekly_leadership();
    return $err if $err;
  }

  my $test_str = "AND weekid=0" if ($ARGS->{isTest} eq '1');
  my $rate = $ARGS->{rate_shop};

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

# --------------------- 2-Up Compensation Plan ---------------------

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
    my $weekid = $ARGS->{c1_id};

    # 1. Get all sales for the period
    my $sales = [];
    my $err = $self->select_sql($sales,
        "SELECT m.memberid, m.sid, m.typeid, p.bv
         FROM member m
         JOIN def_type p ON m.typeid = p.typeid
         WHERE m.active = 'Yes' AND DATE(m.signuptime) BETWEEN ? AND ?",
        $ARGS->{start_daily}, $ARGS->{end_daily}
    );
    return $err if $err;

    # Get all member 2-up data and sponsor data to build a tree
    my ($sponsors, $member_2up_data) = ({}, {});
    my $members_data = [];
    $err = $self->select_sql($members_data, "SELECT m.memberid, m.sid, u.qualification_status, u.sales_count FROM member m JOIN member_2up u ON m.memberid = u.memberid");
    return $err if $err;

    foreach my $m (@$members_data) {
        $sponsors->{$m->{memberid}} = $m->{sid};
        $member_2up_data->{$m->{memberid}} = $m;
    }

    $self->{LISTS} = [];
    my @qualification_updates;

    for my $sale (@$sales) {
        my $purchaser_id = $sale->{memberid};
        my $sponsor_id = $sale->{sid};
        my $bv = $sale->{bv} || 0;

        # 2. iT Commission for the purchaser (10% of BV)
        my $it_commission = $bv * $config->{iT_rate};
        if ($it_commission > 0) {
            push @{$self->{LISTS}}, { memberid => $purchaser_id, classify => '2up_it', weekid => $weekid, refid => $purchaser_id, amount => $it_commission, lev => 0 };
        }

        # 3. Find qualified iQ member in upline
        my $current_upline_id = $sponsor_id;
        my $iq_recipient_id = undef;
        my $is_direct_recruit = 0;

        if ($member_2up_data->{$sponsor_id} && $member_2up_data->{$sponsor_id}->{qualification_status} eq 'iQ') {
             $iq_recipient_id = $sponsor_id;
             $is_direct_recruit = 1;
        } else {
            # Traverse upline to find first iQ
            my $next_upline_id = $current_upline_id;
            my %visited;
            while(defined $next_upline_id && $next_upline_id > 1 && !$visited{$next_upline_id}) {
                $visited{$next_upline_id} = 1;
                my $upline_data = $member_2up_data->{$next_upline_id};
                if ($upline_data && $upline_data->{qualification_status} eq 'iQ') {
                    $iq_recipient_id = $next_upline_id;
                    last;
                }
                $next_upline_id = $sponsors->{$next_upline_id};
            }
        }

        # 4. Apply iQ commission (30%) or direct recruit (40%)
        if (defined $iq_recipient_id) {
            my $commission_rate = $is_direct_recruit ? $config->{direct_recruit_rate} : $config->{iQ_rate};
            my $commission = $bv * $commission_rate;
            my $commission_type = $is_direct_recruit ? '2up_direct' : '2up_iq';
            if ($commission > 0) {
                push @{$self->{LISTS}}, { memberid => $iq_recipient_id, classify => $commission_type, weekid => $weekid, refid => $purchaser_id, amount => $commission, lev => 1 };
            }
        }

        # 5. Update sponsor's qualification status
        my $sponsor_data = $member_2up_data->{$sponsor_id};
        if ($sponsor_data && $sponsor_data->{qualification_status} eq 'iT') {
            my $new_sales_count = ($sponsor_data->{sales_count} || 0) + 1;
            my $new_status = $sponsor_data->{qualification_status};

            if ($new_sales_count >= $config->{qualification_requirement}) {
                $new_status = 'iQ';
            }
            push @qualification_updates, { memberid => $sponsor_id, sales_count => $new_sales_count, status => $new_status };
        }
    }

    # Batch update qualification statuses
    if (@qualification_updates) {
        my $sth = $self->{dbh}->prepare("UPDATE member_2up SET sales_count = ?, qualification_status = ?, qualification_date = NOW() WHERE memberid = ?");
        foreach my $update (@qualification_updates) {
            $sth->execute($update->{sales_count}, $update->{status}, $update->{memberid});
        }
        $sth->finish();
    }

    return;
}

sub done_week1_2up {
    my ($self, $weekid) = @_;
    return $self->do_sql(
"UPDATE cron_1week SET status_2up='Yes'
WHERE c1_id=? AND status_2up='No'", $self->{ARGS}->{c1_id});
}

sub weekly_2up {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    my $weekid = $ARGS->{c1_id};
    my $config = $self->{config}->{Custom}->{TWOUP};
    my $max_payout_abs = $config->{max_payout};

    # Move calculated commissions into income_amount, respecting max_payout
    my $err = $self->do_sql(
        "INSERT INTO income_amount (memberid, amount, weekid, bonusType, created)
         SELECT i.memberid, LEAST(i.amount, ?), i.weekid, '2-Up', NOW()
         FROM income i
         WHERE i.classify LIKE '2up_%' AND i.paystatus = 'new' AND i.weekid = ?",
         $max_payout_abs, $weekid
    );
    return $err if $err;

    # Mark as paid
    return $self->do_sql(
        "UPDATE income SET paystatus='paid'
         WHERE paystatus='new' AND classify LIKE '2up_%' AND weekid=?", $weekid);
}

# --------------------- Leadership Compensation Plan ---------------------

sub is_week1_leadership {
    my ($self, $weekid) = @_;
    return $self->get_args($self->{ARGS},
"SELECT c1_id, daily AS start_daily, DATE_ADD(daily, INTERVAL 6 DAY) AS end_daily, 1 AS to_run_leadership
FROM cron_1week
WHERE status_leadership='No' AND DATE_ADD(daily, INTERVAL 7 DAY)=CURDATE()");
}

sub week1_leadership {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    my $config = $self->{config}->{Custom}->{LEADERSHIP};
    my $weekid = $ARGS->{c1_id};

    # 1. Calculate total leadership pool
    my $total_volume_arr = [];
    my $err = $self->select_sql($total_volume_arr,
        "SELECT SUM(p.bv) AS total_bv FROM member m JOIN def_type p ON m.typeid = p.typeid WHERE m.active = 'Yes' AND DATE(m.signuptime) BETWEEN ? AND ?",
        $ARGS->{start_daily}, $ARGS->{end_daily}
    );
    return $err if $err;
    my $total_volume = $total_volume_arr->[0]->{total_bv} || 0;
    my $leadership_pool = $total_volume * $config->{pool_percentage};

    # 2. Identify qualified leaders
    my $leaders = [];
    $err = $self->select_sql($leaders, "SELECT memberid, rank_name, rank_level FROM member_leadership WHERE rank_level > 0");
    return $err if $err;

    $self->{LISTS} = [];
    return unless $leadership_pool > 0 && @$leaders;

    # 3. Distribute pool based on rank
    my $total_shares = 0;
    my %leader_shares;
    foreach my $leader (@$leaders) {
        my $rank_config = $config->{ranks}->{$leader->{rank_name}};
        if ($rank_config) {
            my $shares = $rank_config->{rate}; # Using rate as a proxy for shares
            $leader_shares{$leader->{memberid}} = $shares;
            $total_shares += $shares;
        }
    }

    return unless $total_shares > 0;

    my $share_value = $leadership_pool / $total_shares;

    foreach my $leader (@$leaders) {
        my $memberid = $leader->{memberid};
        if (exists $leader_shares{$memberid}) {
            my $commission = $leader_shares{$memberid} * $share_value;
            push @{$self->{LISTS}}, {
                memberid => $memberid,
                classify => 'leadership_pool',
                weekid   => $weekid,
                refid    => $memberid,
                amount   => $commission,
                lev      => $leader->{rank_level}
            };
        }
    }

    return;
}

sub done_week1_leadership {
    my ($self, $weekid) = @_;
    return $self->do_sql(
"UPDATE cron_1week SET status_leadership='Yes'
WHERE c1_id=? AND status_leadership='No'", $self->{ARGS}->{c1_id});
}

sub weekly_leadership {
    my $self = shift;
    my $ARGS = $self->{ARGS};
    my $weekid = $ARGS->{c1_id};

    my $err = $self->do_sql(
        "INSERT INTO income_amount (memberid, amount, weekid, bonusType, created)
         SELECT i.memberid, i.amount, i.weekid, 'Leadership', NOW()
         FROM income i
         WHERE i.classify = 'leadership_pool' AND i.paystatus = 'new' AND i.weekid = ?",
         $weekid
    );
    return $err if $err;

    return $self->do_sql(
        "UPDATE income SET paystatus='paid'
         WHERE paystatus='new' AND classify = 'leadership_pool' AND weekid=?", $weekid);
}

1;
