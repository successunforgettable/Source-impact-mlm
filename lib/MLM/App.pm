package MLM::App;

use strict;
use warnings;
use Plack::Request;
use Plack::Response;

sub to_app {
    return sub {
        my $env = shift;
        my $req = Plack::Request->new($env);

        my $res = Plack::Response->new(200);
        $res->content_type('text/html');
        $res->body("<h1>MLM System is Running</h1><p>You can now start adding routes and logic.</p>");
        return $res->finalize;
    };
}

1;