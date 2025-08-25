package MLM::Signup::Model;

use strict;
use MLM::Model;
use vars qw($AUTOLOAD @ISA);

@ISA=('MLM::Model');

sub bulk {
  my $self = shift;
  return $self->get_args($self->{ARGS},
"SELECT count(*) AS counts
FROM member_signup WHERE signupstatus='Bulk'");
}

sub insert {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  my $err = $self->get_args($ARGS,
"SELECT 1 AS one FROM member WHERE login=?", $ARGS->{login});
  return $err if $err;
  return 3103 if $ARGS->{one}; # new account already exists
  $err = $self->get_args($ARGS,
"SELECT 1 AS one FROM member_signup WHERE login=? AND signupstatus='Yes'", $ARGS->{login});
  return $err if $err;
  return 3103 if $ARGS->{one}; # new account already exists

  return $self->SUPER::insert(@_);
}

sub signup_update {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  my $err = $self->do_sql(
"UPDATE member_signup SET signupstatus='No' WHERE signupid=?",
$ARGS->{signupid})
#"UPDATE member SET defpid=NULL, defleg=NUL
	|| $self->do_sql(
"UPDATE member SET defpid=?
WHERE defpid=? AND defleg=?", $ARGS->{memberid}, $ARGS->{pid}, $ARGS->{leg});

  return $err if $err;

  # Two-Up routing (baseline): initialize dual sponsors if configured
  my $cfg = $self->{CUSTOM}->{TwoUp};
  if ($cfg && $cfg->{enabled}) {
    my $recruiter_id = $ARGS->{sid} || $ARGS->{pid};
    my $new_user_id  = $ARGS->{memberid};
    # Initialize tracking sponsor to recruiter
    $self->do_sql("UPDATE member SET tracking_sponsor_id=? WHERE memberid=? AND (tracking_sponsor_id IS NULL OR tracking_sponsor_id=0)",
      $recruiter_id, $new_user_id);

    # Resolve pass-up routing: first two pass-ups go to recruiter's upline (real sponsor), keep afterward
    my $tmp = {};
    my $e2 = $self->get_args($tmp,
      "SELECT real_sponsor_id, sid AS upline_sid, passups_given FROM member WHERE memberid=?",
      $recruiter_id);
    return $e2 if $e2;
    my $passups = $tmp->{passups_given} || 0;
    my $upline_real = $tmp->{real_sponsor_id} || $tmp->{upline_sid} || $cfg->{company_member_id} || $recruiter_id;

    if ($passups < 2) {
      # PASS-UP: assign new member's real sponsor to recruiter's real/upline; increment recruiter counter
      $self->do_sql("UPDATE member SET real_sponsor_id=? WHERE memberid=?",
        $upline_real, $new_user_id);
      $self->do_sql("UPDATE member SET passups_given=passups_given+1 WHERE memberid=?", $recruiter_id);
      # audit
      my $reason = ($passups==0) ? 'PASSUP_1' : 'PASSUP_2';
      $self->do_sql("INSERT INTO passup_event (recruit_user_id, recruiter_user_id, receiver_user_id, reason) VALUES (?,?,?,?)",
        $new_user_id, $recruiter_id, $upline_real, $reason);
    } else {
      # KEEP: both real and tracking sponsor are recruiter
      $self->do_sql("UPDATE member SET real_sponsor_id=? WHERE memberid=?",
        $recruiter_id, $new_user_id);
      $self->do_sql("INSERT INTO passup_event (recruit_user_id, recruiter_user_id, receiver_user_id, reason) VALUES (?,?,?,?)",
        $new_user_id, $recruiter_id, $recruiter_id, 'KEEPER_3PLUS');
    }
  }
  return;
}

sub add_family {
  my $self = shift;
  my $ARGS = $self->{ARGS};

  return $self->do_sql(
"INSERT INTO family (parent, leg, child, level, created)
SELECT parent, leg, '".$ARGS->{memberid}."', level+1, NOW()
FROM family WHERE child=?", $ARGS->{pid})
	|| $self->do_sql(
"INSERT INTO family (parent, leg, child, level, created)
VALUES (?,?,?,1,NOW())", $ARGS->{pid}, $ARGS->{leg}, $ARGS->{memberid});

  return;
}

sub add_miles {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  my $memberid = $ARGS->{memberid};

  my $c = $ARGS->{credit};

  return $self->do_sql( 
"INSERT INTO family_leftright (memberid, level, numleft)
SELECT parent, level, $c FROM family WHERE child=? AND leg='L'
ON DUPLICATE KEY UPDATE numleft=numleft+$c", $memberid)
	|| $self->do_sql(
"UPDATE member
SET milel=milel+$c, countl=countl+1
WHERE memberid IN
(SELECT parent FROM family WHERE child=? AND leg='L')", $memberid)
	|| $self->do_sql(
"INSERT INTO family_leftright (memberid, level, numright)
SELECT parent, level, $c FROM family WHERE child=? AND leg='R'
ON DUPLICATE KEY UPDATE numright=numright+$c", $memberid)
	|| $self->do_sql(
"UPDATE member
SET miler=miler+$c, countr=countr+1
WHERE memberid IN
(SELECT parent FROM family WHERE child=? AND leg='R')", $memberid);
}

sub update_miles {
  my $self = shift;
  my $ARGS = $self->{ARGS};
  my $memberid = $ARGS->{memberid};

  my $c = $ARGS->{credit};
#  my $one = 0;
#  if ($ARGS->{cancelfirst}) {
#    $one = -1;
#  } elsif ($ARGS->{action} eq 'upgrade') {
#    $one = 1;
#  }

  return $self->do_sql( 
"UPDATE family_leftright INNER JOIN family
ON leftright.memberid=family.parent AND leftright.level=family.level
SET numleft=numleft+($c)
WHERE family.child=? AND leg='L'", $memberid)
	|| $self->do_sql(
    #"UPDATE member SET milel=milel+($c), countl=countl+($one)
"UPDATE member SET milel=milel+($c)
WHERE memberid IN
(SELECT parent FROM family WHERE child=? AND leg='L')", $memberid)
	|| $self->do_sql(
"UPDATE family_leftright INNER JOIN family
ON leftright.memberid=family.parent AND leftright.level=family.level
SET numleft=numleft+($c)
WHERE family.child=? AND leg='R'", $memberid)
	|| $self->do_sql(
    #"UPDATE member SET miler=miler+($c), countr=countr+($one)
"UPDATE member SET miler=miler+($c)
WHERE memberid IN
(SELECT parent FROM family WHERE child=? AND leg='R')", $memberid);
}

1;
