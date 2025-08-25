package MLM::Income::Model;

use strict;
use warnings;
use Carp ();
use POSIX qw(strftime);

# ------------------------------------------------------------------------------
# Constructor
# ------------------------------------------------------------------------------
sub new {
    my ($class, %args) = @_;
    my $self = bless {
        dbh    => $args{dbh},        # DBI handle (optional for pure dry-run tests)
        config => $args{config} || {},   # parsed config.json hashref
        logfh  => $args{logfh},      # optional filehandle for logging
    }, $class;
    return $self;
}

# ------------------------------------------------------------------------------
# Private helpers
# ------------------------------------------------------------------------------
sub _cfg      { $_[0]->{config} || {} }
sub _custom   { $_[0]->_cfg->{Custom} || {} }
sub _enable   { $_[0]->_custom->{ENABLE} || {} }

sub _enabled {
    my ($self, $key) = @_;
    my $en = $self->_enable;
    return $en->{$key} ? 1 : 0;
}

sub _now_utc {
    return strftime("%Y-%m-%d %H:%M:%S", gmtime());
}

sub _log {
    my ($self, $msg) = @_;
    my $prefix = "[Income] " . _now_utc() . " ";
    if (my $fh = $self->{logfh}) {
        print $fh $prefix . $msg . "\n";
    } else {
        # fallback
        warn $prefix . $msg . "\n";
    }
}

# Deposit helper (no-op if no DB)
sub _deposit_income {
    my ($self, %tx) = @_;
    # %tx = (
    #   source_memberid => ...,     # who generated the commission event
    #   recipient_id    => ...,     # who gets the money
    #   kind            => 'twoup' | 'leadership',
    #   amount          => 0 + ...,
    #   phase           => 1..10,
    #   note            => '...'
    # )
    my $dbh = $self->{dbh};
    if (!$dbh) {
        $self->_log("DRY-RUN deposit [$tx{kind}] to member $tx{recipient_id} amount $tx{amount} (no DB handle)");
        return 1;
    }
    # Example insert — adjust to your real schema/table names as needed
    my $sql = q{
        INSERT INTO income_ledger
            (memberid, amount, kind, note, created_at)
        VALUES (?, ?, ?, ?, UTC_TIMESTAMP())
    };
    my $sth = $dbh->prepare($sql);
    $sth->execute($tx{recipient_id}, $tx{amount} + 0, $tx{kind}, ($tx{note} || ''));
    return 1;
}

# ------------------------------------------------------------------------------
# Public runners
# ------------------------------------------------------------------------------
# weektype: 'week1' (weekly) or 'week4' (monthly) or custom
sub run_cron {
    my ($self, $weektype) = @_;

    # Always compute in the order required by the spec:
    # 1) TwoUp (40%)
    if ($self->_enabled('TWOUP')) {
        $self->weekly_twoup($weektype);
    } else {
        $self->_log("TwoUp disabled via config ENABLE.TWOUP=false");
    }

    # 2) Leadership (14%)
    if ($self->_enabled('LEADERSHIP')) {
        $self->weekly_leadership($weektype);
    } else {
        $self->_log("Leadership disabled via config ENABLE.LEADERSHIP=false");
    }

    # All legacy plans are hard-disabled (no-ops)
    return 1;
}

sub run_daily {
    my ($self) = @_;
    # If your system differentiates week1/week4 by date, you can branch here.
    # Minimal behavior: run weekly path.
    return $self->run_cron('week1');
}

sub run_all_tests {
    my ($self) = @_;
    # Execute both week paths to satisfy functional tests if needed.
    $self->run_cron('week1');
    $self->run_cron('week4');
    return 1;
}

# ------------------------------------------------------------------------------
# TWOUP (40%) — core weekly calculator
# ------------------------------------------------------------------------------
sub weekly_twoup {
    my ($self, $weektype) = @_;
    $self->_log("Start weekly_twoup [$weektype]");

    my $c  = $self->_custom->{TWOUP} || {};
    my $IT = $c->{iT_rate}                // 0.10;  # 10% to immediate recruiter during IT
    my $IQ = $c->{iQ_rate}                // 0.30;  # 30% to nearest IQ/upline during IT
    my $DIR= $c->{direct_recruit_rate}    // 0.40;  # 40% for direct from 3rd recruit onward
    my $QR = $c->{qualification_requirement} // 2;  # pass-ups to become IQ
    my $MX = $c->{max_payout}             // 40;    # informational cap (percent)

    # -----
    # NOTE:
    # Replace the illustrative loops below with your real event queries.
    # Typically you’ll:
    #  1) Read all “new recruit” events in the window
    #  2) For each recruit, decide whether recruiter is IT or IQ
    #  3) Route: if recruiter still IT and pass-ups < 2 → split (10% recruiter, 30% nearest IQ)
    #            else → 40% direct to recruiter (IQ)
    #  4) Record transactions via _deposit_income
    # -----

    # Example DRY-RUN flow:
    my @events = $self->_fetch_new_recruit_events($weektype); # stub returns empty by default

    foreach my $ev (@events) {
        my $recruiter_id     = $ev->{recruiter_id};
        my $source_member_id = $ev->{new_member_id};
        my $phase            = $ev->{phase} || 1;
        my $amount_base      = $ev->{amount} + 0; # dollar base to apply percentage

        my $rec_state = $self->_fetch_member_state($recruiter_id); # { status => 'IT'|'IQ', passups => 0.., nearest_iq => memberid }
        if ($rec_state->{status} ne 'IQ' && ($rec_state->{passups} // 0) < $QR) {
            # Still IT → split
            my $it_amt = sprintf("%.2f", $amount_base * $IT);
            my $iq_amt = sprintf("%.2f", $amount_base * $IQ);
            my $iq_id  = $rec_state->{nearest_iq};

            $self->_deposit_income(
                source_memberid => $source_member_id,
                recipient_id    => $recruiter_id,
                kind            => 'twoup',
                amount          => $it_amt,
                phase           => $phase,
                note            => "IT split ($IT)"
            );

            if ($iq_id) {
                $self->_deposit_income(
                    source_memberid => $source_member_id,
                    recipient_id    => $iq_id,
                    kind            => 'twoup',
                    amount          => $iq_amt,
                    phase           => $phase,
                    note            => "IQ split ($IQ)"
                );
            }

            # Update pass-up count if this recruit qualifies as a pass-up
            $self->_increment_passup($recruiter_id);
        } else {
            # IQ (or has completed pass-ups) → direct 40%
            my $dir_amt = sprintf("%.2f", $amount_base * $DIR);
            $self->_deposit_income(
                source_memberid => $source_member_id,
                recipient_id    => $recruiter_id,
                kind            => 'twoup',
                amount          => $dir_amt,
                phase           => $phase,
                note            => "Direct ($DIR)"
            );
        }

        # Phase-routing rule:
        # If recruiter is not qualified at this phase (fewer than 2 people at that phase),
        # route to nearest qualified upline at that phase instead.
        # Implement your real lookup here if needed by your tests/spec.
        $self->_apply_phase_qualification_reroute($ev);
    }

    $self->_log("End weekly_twoup [$weektype]");
    return 1;
}

# Optional week1/finish hooks (kept for compatibility with older runners/tests)
sub is_week1_twoup     { 1 }
sub week1_twoup        { shift->weekly_twoup('week1') }
sub done_week1_twoup   { 1 }

# ------------------------------------------------------------------------------
# LEADERSHIP (14%) — after TwoUp
# ------------------------------------------------------------------------------
sub weekly_leadership {
    my ($self, $weektype) = @_;
    $self->_log("Start weekly_leadership [$weektype]");

    my $L  = $self->_custom->{LEADERSHIP} || {};
    my $rk = $L->{ranks} || {};
    # Expected ranks:
    #  - ASC (label "Assistant NTM") → 5%
    #  - SC  (label "NTM")           → 10% (5% + 5% split model as per your spec)
    #  - VP  → 2%
    #  - PRESIDENT → 1%
    #  - RD  → 1%

    # Compute leadership pools/overrides over relevant business during period.
    # Replace with your real computation (volumes, trees, orphans integration).
    my @business = $self->_fetch_business_activity($weektype); # stub

    for my $b (@business) {
        my $amount_base = $b->{amount} + 0;
        my $phase       = $b->{phase} || 1;

        # Walk leadership chain upwards and pay per configured rates.
        my @chain = @{ $self->_fetch_leadership_chain($b->{memberid}) }; # [ {memberid => X, key => 'ASC'|'SC'|'VP'|'PRESIDENT'|'RD'} ... ]

        for my $node (@chain) {
            my $key   = $node->{key};
            my $conf  = $rk->{$key} || {};
            my $rate  = $conf->{rate} // 0;
            next unless $rate > 0;

            my $amt   = sprintf("%.2f", $amount_base * $rate);
            $self->_deposit_income(
                source_memberid => $b->{memberid},
                recipient_id    => $node->{memberid},
                kind            => 'leadership',
                amount          => $amt,
                phase           => $phase,
                note            => "Leadership $key ($rate)"
            );
        }
    }

    $self->_log("End weekly_leadership [$weektype]");
    return 1;
}

sub is_week1_leadership   { 1 }
sub week1_leadership      { shift->weekly_leadership('week1') }
sub done_week1_leadership { 1 }

# ------------------------------------------------------------------------------
# Legacy plans: hard disabled (no-ops)
# ------------------------------------------------------------------------------
sub weekly_binary     { 1 }
sub is_week1_binary   { 0 }
sub week1_binary      { 1 }
sub done_week1_binary { 1 }

sub weekly_unilevel     { 1 }
sub is_week1_unilevel   { 0 }
sub week1_unilevel      { 1 }
sub done_week1_unilevel { 1 }

sub weekly_team     { 1 }
sub is_week1_team   { 0 }
sub week1_team      { 1 }
sub done_week1_team { 1 }

sub weekly_affiliate     { 1 }
sub is_week1_affiliate   { 0 }
sub week1_affiliate      { 1 }
sub done_week1_affiliate { 1 }

# ------------------------------------------------------------------------------
# Stubs you can wire to real data access
# ------------------------------------------------------------------------------
sub _fetch_new_recruit_events {
    my ($self, $weektype) = @_;
    # Return list of recruit events:
    #  { new_member_id => ..., recruiter_id => ..., amount => 1000, phase => 1 }
    return ();
}

sub _fetch_member_state {
    my ($self, $memberid) = @_;
    # Return member state hashref:
    #  { status => 'IT'|'IQ', passups => 0..2, nearest_iq => memberid }
    return { status => 'IQ', passups => 2, nearest_iq => undef };
}

sub _increment_passup {
    my ($self, $memberid) = @_;
    # Update pass-up counter when a pass-up occurred
    return 1;
}

sub _apply_phase_qualification_reroute {
    my ($self, $event) = @_;
    # If recruiter not qualified at event->{phase}, reroute commission to nearest qualified upline.
    # This stub assumes TwoUp routing already handled upstream.
    return 1;
}

sub _fetch_business_activity {
    my ($self, $weektype) = @_;
    # Return list of business items that leadership commissions apply to:
    #  { memberid => ..., amount => 1000, phase => 1 }
    return ();
}

sub _fetch_leadership_chain {
    my ($self, $memberid) = @_;
    # Return upstream leadership chain as arrayref (nearest first):
    #  [ { memberid => 12, key => 'ASC' }, { memberid => 34, key => 'SC' }, { memberid => 56, key => 'VP' }, ... ]
    return [];
}

1;

__END__

=pod

=head1 NAME

MLM::Income::Model - Compensation engine for TwoUp (40%) + Leadership (14%)

=head1 DESCRIPTION

This version intentionally DISABLES legacy plans (Binary/Unilevel/Team/Affiliate)
and executes only TwoUp first, then Leadership, controlled by config.json:

  Custom.ENABLE = {
    TWOUP: true,
    LEADERSHIP: true,
    BINARY: false,
    UNILEVEL: false,
    TEAM: false,
    AFFILIATE: false
  }

=head1 ENTRYPOINTS

  run_cron($weektype)    - main scheduler (calls weekly_twoup then weekly_leadership)
  run_daily()            - convenience daily runner
  run_all_tests()        - test helper

=head1 AUTHOR

Your Team

=cut