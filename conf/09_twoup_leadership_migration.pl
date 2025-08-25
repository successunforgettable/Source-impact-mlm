#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use DBI;

# CONFIG
my $dsn = "DBI:mysql:database=mlm;host=localhost";
my $username = "mlmuser";
my $password = "MlmSecurePass123!";  # Change if needed

my $dbh = DBI->connect($dsn, $username, $password, {
    RaiseError => 1,
    PrintError => 0,
    mysql_enable_utf8 => 1
});

# Create member_2up table if not exists
$dbh->do(q{
    CREATE TABLE IF NOT EXISTS member_2up (
        id INT AUTO_INCREMENT PRIMARY KEY,
        memberid VARCHAR(100),
        uplineid VARCHAR(100),
        phase INT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
});

# Create member_leadership table if not exists
$dbh->do(q{
    CREATE TABLE IF NOT EXISTS member_leadership (
        id INT AUTO_INCREMENT PRIMARY KEY,
        memberid VARCHAR(100),
        leaderid VARCHAR(100),
        bonus_type VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
});

print "✅ Tables ensured. You can now insert sample data or run payout tests.\n";

$dbh->disconnect;