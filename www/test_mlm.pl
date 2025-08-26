#!/usr/bin/perl

use lib qw(/Users/arfeenkhan/mlm-project/perl /Users/arfeenkhan/mlm-project/mlm/lib);
use strict;

print "Testing MLM System Components...\n\n";

# Test 1: Basic module loading
print "1. Testing module loading:\n";
eval {
    use MLM::Model;
    print "   ✓ MLM::Model loaded successfully\n";
} or do {
    print "   ✗ Failed to load MLM::Model: $@\n";
};

eval {
    use MLM::Admin::Model;
    print "   ✓ MLM::Admin::Model loaded successfully\n";
} or do {
    print "   ✗ Failed to load MLM::Admin::Model: $@\n";
};

eval {
    use MLM::Member::Model;
    print "   ✓ MLM::Member::Model loaded successfully\n";
} or do {
    print "   ✗ Failed to load MLM::Member::Model: $@\n";
};

# Test 2: Database connection
print "\n2. Testing database connection:\n";
eval {
    use DBI;
    my $dbh = DBI->connect('dbi:mysql:mlm_system:localhost:3306', 'mlm_user', 'mlm_password123');
    if ($dbh) {
        print "   ✓ Database connection successful\n";
        $dbh->disconnect;
    } else {
        print "   ✗ Database connection failed\n";
    }
} or do {
    print "   ✗ Database connection test failed: $@\n";
};

# Test 3: Configuration loading
print "\n3. Testing configuration loading:\n";
eval {
    use JSON;
    my $config_file = '/Users/arfeenkhan/mlm-project/mlm/conf/config.json';
    if (-f $config_file) {
        open(my $fh, '<', $config_file) or die "Cannot open config file: $!";
        my $content = do { local $/; <$fh> };
        close $fh;
        my $config = decode_json($content);
        print "   ✓ Configuration file loaded successfully\n";
        print "   ✓ Database: " . $config->{Db}->[0] . "\n";
        print "   ✓ Project: " . $config->{Project} . "\n";
    } else {
        print "   ✗ Configuration file not found\n";
    }
} or do {
    print "   ✗ Configuration test failed: $@\n";
};

# Test 4: Basic MLM functionality
print "\n4. Testing basic MLM functionality:\n";
eval {
    my $model = MLM::Model->new();
    print "   ✓ MLM::Model instance created: " . ref($model) . "\n";
} or do {
    print "   ✗ MLM::Model instantiation failed: $@\n";
};

print "\n=== MLM System Test Complete ===\n";
print "If all tests passed, your MLM system is ready to use!\n";
