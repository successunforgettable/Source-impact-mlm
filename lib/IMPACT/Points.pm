package IMPACT::Points;

use strict;
use warnings;
use DBI;

=head1 NAME

IMPACT::Points - Points Wallet Service for Real-time Commission to Points Conversion

=head1 DESCRIPTION

This module handles the automatic posting of points to member wallets when commissions
are earned. Points are awarded on a 1:1 basis with commission amounts and support
dual currency (USD/INR) based on member location.

=cut

=head2 add_points

Add points to a member's wallet with full audit trail.

Parameters:
- dbh: Database handle
- memberid: Member ID to credit points
- phase: Phase number (optional)
- saleid: Sale ID that generated the points (optional)
- source: Source code ('IT', 'PASSUP', 'KEEPER', 'UPGRADE', 'WITHDRAWAL', 'ADJUST')
- points: Amount of points to add (can be negative for spending)
- currency: Currency code ('USD' or 'INR')
- note: Optional note for audit trail

Returns: points_ledger record ID

=cut

sub add_points {
    my ($dbh, %params) = @_;
    
    # Validate required parameters
    die "Database handle required" unless $dbh;
    die "memberid required" unless defined $params{memberid};
    die "source required" unless $params{source};
    die "points required" unless defined $params{points};
    die "currency required" unless $params{currency};
    
    # Validate source code
    my %valid_sources = map { $_ => 1 } qw(IT PASSUP KEEPER UPGRADE WITHDRAWAL ADJUST);
    die "Invalid source code: $params{source}" unless $valid_sources{$params{source}};
    
    # Validate currency
    die "Invalid currency: $params{currency}" unless $params{currency} =~ /^(USD|INR)$/;
    
    my $sql = q{
        INSERT INTO points_ledger (memberid, phase, saleid, source_code, points, currency, note)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    };
    
    my $sth = $dbh->prepare($sql);
    $sth->execute(
        $params{memberid},
        $params{phase},
        $params{saleid},
        $params{source},
        $params{points},
        $params{currency},
        $params{note} || "auto:$params{source}"
    );
    
    return $dbh->last_insert_id(undef, undef, undef, undef);
}

=head2 currency_for_member

Determine the appropriate currency for a member based on their profile.
Currently uses a simple heuristic but can be enhanced with country/region data.

Parameters:
- dbh: Database handle
- memberid: Member ID

Returns: Currency code ('USD' or 'INR')

=cut

sub currency_for_member {
    my ($dbh, $memberid) = @_;
    
    die "Database handle required" unless $dbh;
    die "memberid required" unless defined $memberid;
    
    # Default to USD
    my $currency = 'USD';
    
    # Try to get country from member profile
    my $sql = q{SELECT country FROM member WHERE memberid = ?};
    my $row = $dbh->selectrow_hashref($sql, undef, $memberid);
    
    # If member is from India, use INR
    if ($row && $row->{country} && $row->{country} eq 'IN') {
        $currency = 'INR';
    }
    
    return $currency;
}

=head2 get_balance

Get current points balance for a member in specified currency.

Parameters:
- dbh: Database handle
- memberid: Member ID
- currency: Currency code (optional, if not provided returns all currencies)

Returns: Balance amount or hashref of balances by currency

=cut

sub get_balance {
    my ($dbh, $memberid, $currency) = @_;
    
    die "Database handle required" unless $dbh;
    die "memberid required" unless defined $memberid;
    
    if ($currency) {
        my $sql = q{
            SELECT COALESCE(SUM(points), 0) as balance 
            FROM points_ledger 
            WHERE memberid = ? AND currency = ?
        };
        my ($balance) = $dbh->selectrow_array($sql, undef, $memberid, $currency);
        return $balance || 0;
    } else {
        my $sql = q{
            SELECT currency, SUM(points) as balance 
            FROM points_ledger 
            WHERE memberid = ? 
            GROUP BY currency
        };
        my $results = $dbh->selectall_hashref($sql, 'currency', undef, $memberid);
        return $results || {};
    }
}

=head2 post_commission_points

Automatically post points when a commission is created.
This is the main integration point with the existing MLM system.

Parameters:
- dbh: Database handle
- commission_data: Hashref with commission details
  - memberid: Member receiving the commission
  - amount: Commission amount
  - phase_id: Phase number
  - order_id: Sale/order ID
  - reason_code: Commission type (IT_DIRECT, PASSUP_1, etc.)

Returns: points_ledger record ID

=cut

sub post_commission_points {
    my ($dbh, $commission_data) = @_;
    
    die "Database handle required" unless $dbh;
    die "Commission data required" unless $commission_data && ref $commission_data eq 'HASH';
    
    # Map commission reason codes to points source codes
    my %source_mapping = (
        'IT_DIRECT'    => 'IT',
        'PASSUP_1'     => 'PASSUP',
        'PASSUP_2'     => 'PASSUP',
        'PASSUP_COMPRESSED' => 'PASSUP',
        'KEEPER_3PLUS' => 'KEEPER'
    );
    
    my $source = $source_mapping{$commission_data->{reason_code}} || 'PASSUP';
    my $currency = currency_for_member($dbh, $commission_data->{memberid});
    
    return add_points($dbh,
        memberid => $commission_data->{memberid},
        phase    => $commission_data->{phase_id},
        saleid   => $commission_data->{order_id},
        source   => $source,
        points   => $commission_data->{amount},
        currency => $currency,
        note     => "auto:commission:$commission_data->{reason_code}"
    );
}

1;

__END__

=head1 EXAMPLE USAGE

    use IMPACT::Points;
    
    # Add points when commission is earned
    my $points_id = IMPACT::Points::post_commission_points($dbh, {
        memberid    => 123,
        amount      => 100.00,
        phase_id    => 2,
        order_id    => 5001,
        reason_code => 'IT_DIRECT'
    });
    
    # Check member balance
    my $balance = IMPACT::Points::get_balance($dbh, 123, 'USD');

=cut


