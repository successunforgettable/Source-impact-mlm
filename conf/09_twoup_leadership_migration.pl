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

my @sql_statements = (
    {
        sql => "ALTER TABLE cron_1week ADD COLUMN status_2up ENUM('No','Yes') DEFAULT 'No'",
        message => "Altering cron_1week table to add status_2up..."
    },
    {
        sql => "ALTER TABLE cron_1week ADD COLUMN status_leadership ENUM('No','Yes') DEFAULT 'No'",
        message => "Altering cron_1week table to add status_leadership..."
    },
    {
        sql => q{
            CREATE TABLE IF NOT EXISTS member_leadership (
              memberid int(10) unsigned NOT NULL,
              rank_level tinyint(3) DEFAULT 0,
              rank_name varchar(50) DEFAULT 'MEMBER',
              qualified_date datetime DEFAULT NULL,
              personal_volume decimal(10,2) DEFAULT 0,
              team_volume decimal(10,2) DEFAULT 0,
              active_legs int(10) DEFAULT 0,
              created_at timestamp DEFAULT CURRENT_TIMESTAMP,
              updated_at timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (memberid),
              FOREIGN KEY (memberid) REFERENCES member(memberid) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        },
        message => "Creating member_leadership table..."
    },
    {
        sql => q{
            CREATE TABLE IF NOT EXISTS member_2up (
              memberid int(10) unsigned NOT NULL,
              first_up int(10) unsigned DEFAULT NULL,
              second_up int(10) unsigned DEFAULT NULL,
              qualification_status ENUM('iT','iQ') DEFAULT 'iT',
              qualification_date datetime DEFAULT NULL,
              sales_count int(10) DEFAULT 0,
              created_at timestamp DEFAULT CURRENT_TIMESTAMP,
              updated_at timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
              PRIMARY KEY (memberid),
              FOREIGN KEY (memberid) REFERENCES member(memberid) ON DELETE CASCADE,
              FOREIGN KEY (first_up) REFERENCES member(memberid) ON DELETE SET NULL,
              FOREIGN KEY (second_up) REFERENCES member(memberid) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        },
        message => "Creating member_2up table..."
    },
    {
        sql => q{
            CREATE TABLE IF NOT EXISTS income_2up (
              incomeid int(10) unsigned NOT NULL AUTO_INCREMENT,
              weekid int(10) unsigned NOT NULL,
              memberid int(10) unsigned NOT NULL,
              sale_memberid int(10) unsigned NOT NULL,
              commission_type ENUM('iT','iQ','direct_recruit') NOT NULL,
              amount decimal(10,2) NOT NULL,
              bv int(10) unsigned NOT NULL,
              typeid tinyint(3) unsigned NOT NULL,
              created_at timestamp DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (incomeid),
              FOREIGN KEY (memberid) REFERENCES member(memberid),
              FOREIGN KEY (sale_memberid) REFERENCES member(memberid),
              FOREIGN KEY (weekid) REFERENCES week1(weekid),
              KEY idx_week_member (weekid, memberid)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        },
        message => "Creating income_2up table..."
    },
    {
        sql => q{
            CREATE TABLE IF NOT EXISTS income_leadership (
              incomeid int(10) unsigned NOT NULL AUTO_INCREMENT,
              weekid int(10) unsigned NOT NULL,
              memberid int(10) unsigned NOT NULL,
              rank_name varchar(50) NOT NULL,
              override_amount decimal(10,2) NOT NULL,
              pool_percentage decimal(5,4) NOT NULL,
              created_at timestamp DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (incomeid),
              FOREIGN KEY (memberid) REFERENCES member(memberid),
              FOREIGN KEY (weekid) REFERENCES week1(weekid),
              KEY idx_week_member (weekid, memberid)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8
        },
        message => "Creating income_leadership table..."
    },
    {
        sql => q{
            INSERT INTO member_leadership (memberid)
            SELECT memberid FROM member
            ON DUPLICATE KEY UPDATE memberid=memberid
        },
        message => "Initializing member_leadership records for existing members..."
    },
    {
        sql => q{
            INSERT INTO member_2up (memberid)
            SELECT memberid FROM member
            ON DUPLICATE KEY UPDATE memberid=memberid
        },
        message => "Initializing member_2up records for existing members..."
    }
);

foreach my $stmt (@sql_statements) {
    print $stmt->{message} . "\n";
    eval {
        $dbh->do($stmt->{sql});
        print "SUCCESS.\n\n";
    };
    if ($@) {
        # Don't die on "Duplicate column name" or "Table already exists" errors
        if ($@ =~ /Duplicate column name/i or $@ =~ /Table.*already exists/i) {
            print "WARNING: $@. This might be okay if the script was run before.\n\n";
        } else {
            $dbh->disconnect();
            die "FATAL ERROR: $@. Aborting migration.";
        }
    }
}

$dbh->disconnect();

print "Migration script completed.\n";

exit;
