package MLM::Phase::Model;

use strict;
use MLM::Model;
use vars qw(@ISA);
use JSON;
use DBI;

@ISA=('MLM::Model');

# Phase unlock and challenge completion logic

sub unlock_phase_for_member {
    my ($self, $memberid, $phase_number, $admin_unlock) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    # Check if already unlocked
    my ($exists) = $dbh->selectrow_array(
        "SELECT 1 FROM member_phase_unlock WHERE memberid=? AND phase_number=?",
        undef, $memberid, $phase_number
    );
    return if $exists;
    
    # Insert unlock record
    $dbh->do(
        "INSERT INTO member_phase_unlock (memberid, phase_number, unlocked_by_admin) VALUES (?,?,?)",
        undef, $memberid, $phase_number, ($admin_unlock ? 1 : 0)
    );
    
    return 1;
}

sub is_phase_unlocked {
    my ($self, $memberid, $phase_number) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    my ($unlocked) = $dbh->selectrow_array(
        "SELECT 1 FROM member_phase_unlock WHERE memberid=? AND phase_number=?",
        undef, $memberid, $phase_number
    );
    
    return $unlocked ? 1 : 0;
}

sub get_available_phases {
    my ($self, $memberid) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    # Get all phases with their unlock status
    my $phases = $dbh->selectall_arrayref(q{
        SELECT p.packageid, p.phase_number, p.title, p.description, p.price, p.unlock_condition,
               CASE WHEN u.phase_number IS NOT NULL THEN 1 ELSE 0 END AS unlocked,
               CASE WHEN s.phase_number IS NOT NULL THEN 1 ELSE 0 END AS completed
        FROM product_package p
        LEFT JOIN member_phase_unlock u ON p.phase_number = u.phase_number AND u.memberid = ?
        LEFT JOIN (
            SELECT DISTINCT phase_number FROM sale WHERE memberid = ? AND paystatus = 'Delivered'
        ) s ON p.phase_number = s.phase_number
        WHERE p.phase_number IS NOT NULL
        ORDER BY p.phase_number
    }, { Slice => {} }, $memberid, $memberid);
    
    return $phases;
}

sub check_and_unlock_next_phase {
    my ($self, $memberid, $completed_phase) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    # Check if the package for this phase unlocks the next one
    my ($unlocks_next) = $dbh->selectrow_array(
        "SELECT completion_unlocks_next FROM product_package WHERE phase_number=? LIMIT 1",
        undef, $completed_phase
    );
    
    return unless $unlocks_next;
    
    my $next_phase = $completed_phase + 1;
    
    # Check if next phase exists and requires previous completion
    my ($next_exists) = $dbh->selectrow_array(
        "SELECT 1 FROM product_package WHERE phase_number=? AND unlock_condition='previous_phase_completed'",
        undef, $next_phase
    );
    
    if ($next_exists) {
        $self->unlock_phase_for_member($memberid, $next_phase, 0);
    }
    
    return $next_phase;
}

sub handle_phase_purchase {
    my ($self, $memberid, $phase_number, $basis_amount, $order_id) = @_;
    
    # Check if this is a repeat purchase
    my $repeat_flag = $self->is_phase_completed($memberid, $phase_number) ? 1 : 0;
    
    # Process commission without BV
    $self->process_phase_commission($memberid, $phase_number, $basis_amount, $order_id, $repeat_flag);
    
    # If not a repeat, unlock phase and check for next unlock
    unless ($repeat_flag) {
        $self->unlock_phase_for_member($memberid, $phase_number, 0);
        $self->check_and_unlock_next_phase($memberid, $phase_number);
    }
    
    return $repeat_flag;
}

sub is_phase_completed {
    my ($self, $memberid, $phase_number) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    my ($completed) = $dbh->selectrow_array(
        "SELECT 1 FROM sale WHERE memberid=? AND phase_number=? AND paystatus='Delivered' LIMIT 1",
        undef, $memberid, $phase_number
    );
    
    return $completed ? 1 : 0;
}

sub process_phase_commission {
    my ($self, $memberid, $phase_number, $basis_amount, $order_id, $repeat_flag) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    # Get commission matrix for this phase
    my $commission_rates = $dbh->selectall_arrayref(
        "SELECT level, commission_percent FROM phase_commission WHERE phase_number=? ORDER BY level",
        { Slice => {} }, $phase_number
    );
    
    return unless @$commission_rates;
    
    # Get upline chain
    my @upline = $self->get_upline_chain($memberid, scalar(@$commission_rates));
    
    # Pay commissions to each level
    for my $i (0 .. $#$commission_rates) {
        my $rate = $commission_rates->[$i];
        my $upline_id = $upline[$i] || next;
        
        my $percent = $rate->{commission_percent} / 100.0;
        my $amount = sprintf('%.2f', $basis_amount * $percent);
        
        next unless $amount > 0;
        
        # Book commission
        $dbh->do(q{
            INSERT INTO commissions (payer_user_id, receiver_user_id, basis_amount, percent, amount, reason_code, order_id, phase_id)
            VALUES (?,?,?,?,?,?,?,?)
        }, undef, $memberid, $upline_id, $basis_amount, $percent, $amount, 
           "PHASE_${phase_number}_L" . ($i+1), $order_id, $phase_number);
    }
    
    return 1;
}

sub get_upline_chain {
    my ($self, $memberid, $levels) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    my @upline;
    my $current = $memberid;
    
    for my $level (1 .. $levels) {
        my ($sponsor) = $dbh->selectrow_array(
            "SELECT sid FROM member WHERE memberid=?", undef, $current
        );
        last unless $sponsor && $sponsor != $current;
        
        push @upline, $sponsor;
        $current = $sponsor;
    }
    
    return @upline;
}

sub admin_unlock_phase {
    my ($self, $memberid, $phase_number) = @_;
    return $self->unlock_phase_for_member($memberid, $phase_number, 1);
}

sub get_member_progress {
    my ($self, $memberid) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    my $progress = $dbh->selectall_arrayref(q{
        SELECT p.phase_number, p.title, p.price,
               CASE WHEN u.phase_number IS NOT NULL THEN 1 ELSE 0 END AS unlocked,
               CASE WHEN s.phase_number IS NOT NULL THEN 1 ELSE 0 END AS completed,
               COUNT(s.saleid) AS purchase_count
        FROM product_package p
        LEFT JOIN member_phase_unlock u ON p.phase_number = u.phase_number AND u.memberid = ?
        LEFT JOIN sale s ON p.phase_number = s.phase_number AND s.memberid = ? AND s.paystatus = 'Delivered'
        WHERE p.phase_number IS NOT NULL
        GROUP BY p.phase_number, p.title, p.price, u.phase_number
        ORDER BY p.phase_number
    }, { Slice => {} }, $memberid, $memberid);
    
    return $progress;
}

sub _ensure_dbh {
    my $self = shift;
    # Only return if we have a real DBI handle
    if ($self->{DBH}) {
        my $ok;
        eval { $ok = ($self->{DBH}->can('prepare') ? 1 : 0) };
        return if $ok;
    }
    my $config_path = '/Users/arfeenkhan/mlm-project/mlm/conf/config.json';
    if (open my $fh, '<', $config_path) {
        local $/; my $json = <$fh>; close $fh;
        my $cfg = eval { decode_json($json) } || {};
        if ($cfg->{Db} && ref $cfg->{Db} eq 'ARRAY') {
            my ($dsn,$user,$pass) = @{$cfg->{Db}};
            my $dbh = DBI->connect($dsn, $user, $pass, { RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1 });
            $self->{DBH} = $dbh;
        }
    }
    return;
}

1;


