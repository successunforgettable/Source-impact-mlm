package IMPACT::CommissionHook;

use strict;
use warnings;
use IMPACT::Points;

=head1 NAME

IMPACT::CommissionHook - Integration hook for posting points when commissions are created

=head1 DESCRIPTION

This module provides the integration layer between the existing MLM commission system
and the new Points Wallet. It should be called whenever a commission record is created
to automatically post corresponding points to the member's wallet.

=cut

=head2 post_commission_points

Hook function to be called after commission insertion.
This is the main integration point with existing MLM logic.

Parameters:
- dbh: Database handle
- commission_id: ID of the commission record that was just created

Returns: points_ledger record ID or undef if commission not found

=cut

sub post_commission_points {
    my ($dbh, $commission_id) = @_;
    
    die "Database handle required" unless $dbh;
    die "commission_id required" unless defined $commission_id;
    
    # Fetch the commission details
    my $sql = q{
        SELECT commission_id, payer_user_id, receiver_user_id, amount, 
               reason_code, order_id, phase_id, created_at
        FROM commissions 
        WHERE commission_id = ?
    };
    
    my $commission = $dbh->selectrow_hashref($sql, undef, $commission_id);
    return unless $commission;
    
    # Only post points for positive amounts
    return unless $commission->{amount} > 0;
    
    # Use the IMPACT::Points module to post the points
    return IMPACT::Points::post_commission_points($dbh, {
        memberid    => $commission->{receiver_user_id},
        amount      => $commission->{amount},
        phase_id    => $commission->{phase_id},
        order_id    => $commission->{order_id},
        reason_code => $commission->{reason_code}
    });
}

=head2 batch_post_missing_points

Utility function to post points for commissions that don't have corresponding points yet.
Useful for handling commissions created before the points system was integrated.

Parameters:
- dbh: Database handle
- limit: Maximum number of commissions to process (default 100)

Returns: Number of points records created

=cut

sub batch_post_missing_points {
    my ($dbh, $limit) = @_;
    
    die "Database handle required" unless $dbh;
    $limit ||= 100;
    
    # Find commissions without corresponding points
    my $sql = q{
        SELECT c.commission_id, c.payer_user_id, c.receiver_user_id, c.amount,
               c.reason_code, c.order_id, c.phase_id, c.created_at
        FROM commissions c
        LEFT JOIN points_ledger p ON (
            p.memberid = c.receiver_user_id 
            AND p.saleid = c.order_id 
            AND p.points = c.amount
            AND p.note LIKE CONCAT('auto:commission:', c.commission_id)
        )
        WHERE c.amount > 0 
        AND p.id IS NULL
        ORDER BY c.created_at
        LIMIT ?
    };
    
    my $missing_commissions = $dbh->selectall_arrayref($sql, { Slice => {} }, $limit);
    my $count = 0;
    
    for my $commission (@$missing_commissions) {
        eval {
            my $points_id = IMPACT::Points::post_commission_points($dbh, {
                memberid    => $commission->{receiver_user_id},
                amount      => $commission->{amount},
                phase_id    => $commission->{phase_id},
                order_id    => $commission->{order_id},
                reason_code => $commission->{reason_code}
            });
            $count++ if $points_id;
        };
        warn "Failed to post points for commission $commission->{commission_id}: $@" if $@;
    }
    
    return $count;
}

=head2 verify_points_sync

Verify that points and commissions are in sync.

Parameters:
- dbh: Database handle

Returns: Hashref with sync statistics

=cut

sub verify_points_sync {
    my ($dbh) = @_;
    
    die "Database handle required" unless $dbh;
    
    my $stats = {};
    
    # Count total commissions
    ($stats->{total_commissions}) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM commissions WHERE amount > 0"
    );
    
    # Count commissions with matching points
    ($stats->{synced_commissions}) = $dbh->selectrow_array(q{
        SELECT COUNT(DISTINCT c.commission_id)
        FROM commissions c
        JOIN points_ledger p ON (
            p.memberid = c.receiver_user_id 
            AND p.saleid = c.order_id 
            AND p.points = c.amount
            AND p.source_code IN ('IT', 'PASSUP', 'KEEPER')
        )
        WHERE c.amount > 0
    });
    
    # Count total points from commissions
    ($stats->{total_commission_points}) = $dbh->selectrow_array(
        "SELECT COALESCE(SUM(points), 0) FROM points_ledger WHERE note LIKE 'auto:commission:%' OR note LIKE 'backfill:commission:%'"
    );
    
    # Calculate sync percentage
    $stats->{sync_percentage} = $stats->{total_commissions} > 0 
        ? sprintf("%.1f", ($stats->{synced_commissions} / $stats->{total_commissions}) * 100)
        : 0;
    
    return $stats;
}

1;

__END__

=head1 EXAMPLE INTEGRATION

To integrate with existing commission creation logic, add this call after commission insertion:

    # After inserting commission record
    my $commission_id = $dbh->last_insert_id(undef, undef, undef, undef);
    
    # Post corresponding points
    eval {
        IMPACT::CommissionHook::post_commission_points($dbh, $commission_id);
    };
    warn "Failed to post points for commission $commission_id: $@" if $@;

=cut


