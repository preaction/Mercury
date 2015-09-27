
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new( 'Mojolicious::Broker' );

$t->websocket_ok( '/pub/foo', 'publish websocket' );
my $pub_tx = $t->tx;

$t->websocket_ok( '/sub/foo', 'subscriber one' );
push @subs, $t->tx;
$t->websocket_ok( '/sub/foo', 'subscriber two' );
push @subs, $t->tx;

$t->tx( $pub_tx )->send_ok({ text => 'Hello' });
for my $sub_tx ( @subs ) {
    $t->tx( $sub_tx )
        ->message_ok( 'sub received message' )
        ->message_is( 'Hello' );
}

for my $tx ( $pub_tx, @subs ) {
    $t->tx( $tx )->finish_ok;
}

done_testing;
