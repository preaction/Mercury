
use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

my $bt = Test::Mojo->new( 'Mercury' );
my $burl = $bt->ua->server->url;
$burl =~ s/^http/ws/;
note "Broker: " . $burl;

{
    package MyApp;
    use Mojo::Base 'Mojolicious';
}

my $t = Test::Mojo->new( 'MyApp' );
note "Test app: " . $t->ua->server->url;
my $app = $t->app;
$app->plugin( 'Mercury', { connect => $burl } );

subtest 'bus' => sub {
    my $ua = $app->mercury->bus( 'topic',
        message => sub {
            my ( $ua, $msg ) = @_;
            is $msg, 'Hello';
            Mojo::IOLoop->stop;
        },
    );

    my $timeout = Mojo::IOLoop->timer( 5, sub { fail "Timeout reached"; Mojo::IOLoop->stop } );
    note "WS URL: " . $burl . 'bus/topic';
    $bt->ua->websocket( $burl . 'bus/topic' => sub {
        my ( $ua, $tx ) = @_;
        if ( $tx->is_websocket ) {
            $tx->send( { text => 'Hello' } );
        }
        else {
            fail "HTTP Error: " . $tx->res->code;
            note $tx->res->body;
        }
    } );
    Mojo::IOLoop->start;
};

done_testing;
__END__

subtest 'subscribe' => sub {
    my $sub = $app->mercury->sub( 'topic' );
};

subtest 'publish' => sub {

};

subtest 'push' => sub {

};

subtest 'pull' => sub {

};

done_testing;

