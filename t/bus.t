
use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new( 'Mercury' );

my @peers;
for my $i ( 0..3 ) {
    $t->websocket_ok( '/bus/foo' );
    push @peers, $t->tx;
}

my $stranger_tx = $t->websocket_ok( '/bus/bar' )->tx;
$stranger_tx->on( message => sub {
    fail 'Stranger received message from wrong bus';
} );

subtest 'peer 0' => sub {
    $t->tx( $peers[0] )->send_ok( { text => 'Hello' }, 'peer 0 sends message' );
    for my $i ( 1..3 ) {
        $t->tx( $peers[$i] )
            ->message_ok( "peer $i received message" )
            ->message_is( 'Hello' );
    }
};

subtest 'peer 2' => sub {
    $t->tx( $peers[2] )->send_ok( { text => 'Hello' }, 'peer 2 sends message' );
    for my $i ( 0, 1, 3 ) {
        $t->tx( $peers[$i] )
            ->message_ok( "peer $i received message" )
            ->message_is( 'Hello' );
    }
};

for my $i ( 0..$#peers ) {
    $t->tx( $peers[$i] )->finish_ok;
}
$t->tx( $stranger_tx )->finish_ok;

done_testing;
