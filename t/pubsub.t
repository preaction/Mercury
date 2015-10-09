
use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new( 'Mercury' );

subtest 'exact topic' => sub {
    $t->websocket_ok( '/pub/foo', 'publish websocket' );
    my $pub_tx = $t->tx;

    my @subs;
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
};

subtest 'topic hierarchy' => sub {
    my %subs;
    $t->websocket_ok( '/sub/foo', 'parent subscriber' );
    $subs{parent} = $t->tx;
    $t->websocket_ok( '/sub/foo/bar', 'child subscriber' );
    $subs{child} = $t->tx;

    subtest 'publish on child topic' => sub {
        $t->websocket_ok( '/pub/foo/bar', 'publish websocket' );
        my $pub_tx = $t->tx;

        $t->tx( $pub_tx )->send_ok({ text => 'Hello' });
        for my $sub_tx ( values %subs ) {
            $t->tx( $sub_tx )
                ->message_ok( 'sub received message' )
                ->message_is( 'Hello' );
        }

        $t->tx( $pub_tx )->finish_ok;
    };

    subtest 'publish on parent topic' => sub {
        $t->websocket_ok( '/pub/foo', 'publish websocket' );
        my $pub_tx = $t->tx;

        $subs{child}->on( message => sub {
            fail "Got child message!";
        } );

        $t->tx( $pub_tx )->send_ok({ text => 'Hello' });
        $t->tx( $subs{parent} )
            ->message_ok( 'sub received message' )
            ->message_is( 'Hello' );

        $t->tx( $pub_tx )->finish_ok;
        $subs{child}->unsubscribe( 'message' );
    };

    for my $tx ( values %subs ) {
        $t->tx( $tx )->finish_ok;
    }
};

done_testing;
