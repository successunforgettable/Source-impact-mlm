#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use JSON;
use Getopt::Long;

my $config_file = 'config.json';
GetOptions('config=s' => \$config_file);

unless (-e $config_file) {
    die "Configuration file '$config_file' not found. Use --config path/to/config.json\n";
}

print "Reading configuration from '$config_file'...\n";
my $config;
{
    local $/;
    open(my $fh, '<', $config_file) or die "Cannot open $config_file: $!";
    my $json_text = <$fh>;
    close($fh);
    $config = decode_json($json_text);
    die "Failed to decode configuration from $config_file." unless $config;
}

print "Connecting to the database...\n";
my $dbh = DBI->connect(@{$config->{Db}}) or die "Database connection failed: $DBI::errstr";
print "Database connection successful.\n\n";

# Drop old tables if they exist
my @drop_statements = (
    { sql => "DROP TABLE IF EXISTS `income_2up`", message => "Dropping old income_2up table..." },
    { sql => "DROP TABLE IF EXISTS `income_leadership`", message => "Dropping old income_leadership table..." },
    { sql => "DROP TABLE IF EXISTS `member_2up`", message => "Dropping old member_2up table..." },
    { sql => "DROP TABLE IF EXISTS `member_leadership`", message => "Dropping old member_leadership table..." },
);

foreach my $stmt (@drop_statements) {
    print $stmt->{message} . "\n";
    eval { $dbh->do($stmt->{sql}) };
    print "SUCCESS.\n\n";
}

my @sql_statements = (
    {
        sql => "ALTER TABLE member ADD COLUMN status ENUM('iT','iQ') DEFAULT 'iT'",
        message => "Altering member table to add status..."
    },
    {
        sql => "ALTER TABLE member ADD COLUMN current_phase TINYINT(3) DEFAULT 1",
        message => "Altering member table to add current_phase..."
    },
    {
        sql => "ALTER TABLE member ADD COLUMN pass_up_count TINYINT(3) DEFAULT 0",
        message => "Altering member table to add pass_up_count..."
    },
    {
        sql => "ALTER TABLE member ADD COLUMN leadership_position VARCHAR(50) DEFAULT NULL",
        message => "Altering member table to add leadership_position..."
    },
    {
        sql => "ALTER TABLE member ADD COLUMN leadership_qual_status VARCHAR(50) DEFAULT NULL",
        message => "Altering member table to add leadership_qual_status..."
    },
    {
        sql => q{
            CREATE TABLE IF NOT EXISTS commission_log (
              log_id int(10) unsigned NOT NULL AUTO_INCREMENT,
              transaction_id varchar(255) NOT NULL,
              source_member_id int(10) unsigned NOT NULL,
              recipient_member_id int(10) unsigned NOT NULL,
              commission_type varchar(50) NOT NULL,
              amount decimal(10,2) NOT NULL,
              phase_level tinyint(3) DEFAULT 1,
              created_at timestamp DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (log_id),
              KEY idx_recipient (recipient_member_id),
              KEY idx_source (source_member_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        },
        message => "Creating commission_log table..."
    },
    {
        sql => q{
            CREATE TABLE IF NOT EXISTS leadership_hierarchy (
              member_id int(10) unsigned NOT NULL,
              upline_id int(10) unsigned DEFAULT NULL,
              position varchar(50) NOT NULL,
              PRIMARY KEY (member_id),
              KEY idx_upline (upline_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        },
        message => "Creating leadership_hierarchy table..."
    },
    {
        sql => q{
            CREATE TABLE IF NOT EXISTS orphan_assignments (
              orphan_id int(10) unsigned NOT NULL,
              assigned_ntm_id int(10) unsigned NOT NULL,
              assignment_date date NOT NULL,
              PRIMARY KEY (orphan_id),
              KEY idx_ntm (assigned_ntm_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        },
        message => "Creating orphan_assignments table..."
    }
);

foreach my $stmt (@sql_statements) {
    print $stmt->{message} . "\n";
    eval {
        $dbh->do($stmt->{sql});
        print "SUCCESS.\n\n";
    };
    if ($@) {
        if ($@ =~ /Duplicate column name/i) {
            print "WARNING: $@. This might be okay if the script was run before.\n\n";
        } else {
            $dbh->disconnect();
            die "FATAL ERROR: $@. Aborting migration.";
        }
    }
}

$dbh->disconnect();

print "Advanced compensation plan migration script completed.\n";

exit;
