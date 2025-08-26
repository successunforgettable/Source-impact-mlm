#!/bin/bash

# MLM System Startup Script
echo "Starting MLM System..."

# Set environment variables
export PERL5LIB="/Users/arfeenkhan/mlm-project/perl:/Users/arfeenkhan/mlm-project/mlm/lib:/opt/homebrew/Cellar/perl-dbd-mysql/5.013/libexec/lib/perl5"
export MLM_HOME="/Users/arfeenkhan/mlm-project/mlm"
export GENELET_HOME="/Users/arfeenkhan/mlm-project/perl"

# Check if MySQL is running
echo "Checking MySQL status..."
if brew services list | grep -q "mysql.*started"; then
    echo "✓ MySQL is running"
else
    echo "Starting MySQL..."
    brew services start mysql
    sleep 3
fi

# Test database connection
echo "Testing database connection..."
if mysql -u mlm_user -pmlm_password123 mlm_system -e "SELECT 1" >/dev/null 2>&1; then
    echo "✓ Database connection successful"
else
    echo "✗ Database connection failed"
    echo "Please check your MySQL configuration"
    exit 1
fi

# Test MLM modules
echo "Testing MLM modules..."
if perl -e "use MLM::Model; print 'OK';" >/dev/null 2>&1; then
    echo "✓ MLM modules loaded successfully"
else
    echo "✗ Failed to load MLM modules"
    exit 1
fi

echo ""
echo "=== MLM System is Ready ==="
echo "You can now:"
echo "1. Run the test script: perl www/test_mlm.pl"
echo "2. Test the CGI script: perl www/cgi-bin/goto"
echo "3. Start a web server to test the web interface"
echo ""
echo "To start a simple web server for testing:"
echo "cd www && python3 -m http.server 8080 --cgi"
echo "Then visit: http://localhost:8080/cgi-bin/test.cgi"
echo ""
echo "Environment variables have been set for this session."
echo "To make them permanent, they are already in your ~/.zshrc file."
