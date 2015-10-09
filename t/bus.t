
use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

use Mercury;
my $app = Mercury->new;

my @peers;
for my $i ( 0..3 ) {
    my $t = Test::Mojo->new( $app )->websocket_ok( '/bus/foo' );
    push @peers, $t;
}

my $stranger_t = Test::Mojo->new( $app )->websocket_ok( '/bus/bar' );
$stranger_t->tx->on( message => sub {
    fail 'Stranger received message from wrong bus';
} );

subtest 'peer 0' => sub {
    $peers[0]->send_ok( { text => 'Hello' }, 'peer 0 sends message' );
    for my $i ( 1..3 ) {
        $peers[$i]
            ->message_ok( "peer $i received message" )
            ->message_is( 'Hello' );
    }
};

subtest 'peer 2' => sub {
    $peers[2]->send_ok( { text => 'Hello' }, 'peer 2 sends message' );
    for my $i ( 0, 1, 3 ) {
        $peers[$i]
            ->message_ok( "peer $i received message" )
            ->message_is( 'Hello' );
    }
};

for my $i ( 0..$#peers ) {
    $peers[$i]->finish_ok;
}
$stranger_t->finish_ok;

done_testing;
