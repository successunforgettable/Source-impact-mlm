package MLM::Challenge::Model;

use strict;
use MLM::Model;
use MLM::Challenge::Store;
use MLM::Challenge::Purchase;
use vars qw(@ISA);
use JSON;
use DBI;

@ISA=('MLM::Model');

# Challenge catalog and admin management

sub get_challenge_categories {
    my $self = shift;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    my $categories = $dbh->selectall_arrayref(q{
        SELECT category_id, name, slug, active, created_at
        FROM challenge_category
        ORDER BY name
    }, { Slice => {} });
    
    return $categories;
}

sub get_challenge_items {
    my ($self, $category_id) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    my $sql = q{
        SELECT ci.item_id, ci.category_id, ci.title, ci.slug, ci.description, 
               ci.image_url, ci.active, ci.created_at, cc.name as category_name
        FROM challenge_item ci
        JOIN challenge_category cc ON ci.category_id = cc.category_id
    };
    my @params = ();
    
    if ($category_id) {
        $sql .= " WHERE ci.category_id = ?";
        push @params, $category_id;
    }
    
    $sql .= " ORDER BY ci.title";
    
    my $items = $dbh->selectall_arrayref($sql, { Slice => {} }, @params);
    return $items;
}

sub get_challenge_packages {
    my ($self, $item_id) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    my $sql = q{
        SELECT cp.package_id, cp.item_id, cp.phase_number, cp.title, cp.price,
               cp.active, cp.requires_prev, cp.image_url, cp.created_at,
               ci.title as item_title, cc.name as category_name
        FROM challenge_package cp
        JOIN challenge_item ci ON cp.item_id = ci.item_id
        JOIN challenge_category cc ON ci.category_id = cc.category_id
    };
    my @params = ();
    
    if ($item_id) {
        $sql .= " WHERE cp.item_id = ?";
        push @params, $item_id;
    }
    
    $sql .= " ORDER BY cp.phase_number";
    
    my $packages = $dbh->selectall_arrayref($sql, { Slice => {} }, @params);
    return $packages;
}

sub create_challenge_category {
    my ($self, $name, $slug) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    $dbh->do(q{
        INSERT INTO challenge_category (name, slug) VALUES (?, ?)
    }, undef, $name, $slug);
    
    return $dbh->last_insert_id(undef,undef,undef,undef);
}

sub create_challenge_item {
    my ($self, $category_id, $title, $slug, $description, $image_url) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    $dbh->do(q{
        INSERT INTO challenge_item (category_id, title, slug, description, image_url) 
        VALUES (?, ?, ?, ?, ?)
    }, undef, $category_id, $title, $slug, $description, $image_url);
    
    return $dbh->last_insert_id(undef,undef,undef,undef);
}

sub create_challenge_package {
    my ($self, $item_id, $phase_number, $title, $price, $requires_prev, $image_url) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    $dbh->do(q{
        INSERT INTO challenge_package (item_id, phase_number, title, price, requires_prev, image_url) 
        VALUES (?, ?, ?, ?, ?, ?)
    }, undef, $item_id, $phase_number, $title, $price, $requires_prev, $image_url);
    
    return $dbh->last_insert_id(undef,undef,undef,undef);
}

sub delete_challenge_category {
    my ($self, $category_id) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    $dbh->do(q{DELETE FROM challenge_category WHERE category_id = ?}, undef, $category_id);
    return 1;
}

sub delete_challenge_item {
    my ($self, $item_id) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    $dbh->do(q{DELETE FROM challenge_item WHERE item_id = ?}, undef, $item_id);
    return 1;
}

sub delete_challenge_package {
    my ($self, $package_id) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    $dbh->do(q{DELETE FROM challenge_package WHERE package_id = ?}, undef, $package_id);
    return 1;
}

sub get_member_challenge_orders {
    my ($self, $member_id) = @_;
    $self->_ensure_dbh();
    my $dbh = $self->{DBH} || $self->dbh();
    
    my $orders = $dbh->selectall_arrayref(q{
        SELECT s.saleid, s.memberid, s.amount, s.challenge_phase, s.repeat_flag,
               s.created, cp.title as phase_title
        FROM sale s
        LEFT JOIN challenge_package cp ON s.challenge_phase = cp.phase_number
        WHERE s.challenge_phase IS NOT NULL
    } . ($member_id ? " AND s.memberid = ?" : "") . q{
        ORDER BY s.created DESC
    }, { Slice => {} }, ($member_id ? ($member_id) : ()));
    
    return $orders;
}

sub admin_unlock_member_phase {
    my ($self, $member_id, $phase_number) = @_;
    my $store = MLM::Challenge::Store->new(dbh => $self->{DBH} || $self->dbh());
    return $store->admin_unlock_phase($member_id, $phase_number);
}

sub mark_member_phase_completed {
    my ($self, $member_id, $phase_number) = @_;
    my $store = MLM::Challenge::Store->new(dbh => $self->{DBH} || $self->dbh());
    return $store->mark_completed_and_maybe_unlock_next($member_id, $phase_number);
}

sub get_member_progress {
    my ($self, $member_id) = @_;
    my $store = MLM::Challenge::Store->new(dbh => $self->{DBH} || $self->dbh());
    return $store->get_member_challenge_progress($member_id);
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


