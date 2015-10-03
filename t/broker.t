
use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new( 'Mercury' );

subtest 'bus' => sub {
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
        $t->tx( $peers[$i] )->finish_ok( 1000, "peer $i closed" );
    }
    $t->tx( $stranger_tx )->finish_ok( 1000, 'stranger left' );
};

subtest 'pubsub' => sub {

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
};

subtest 'push/pull' => sub {
    my @pulls;
    my @got;
    for my $i ( 0..3 ) {
        my $tx = $t->websocket_ok( '/pull/foo' )->tx;
        my $queue = $got[ $i ] = [];
        $tx->on( message => sub {
            push @$queue, $_[1];
        } );
        push @pulls, $tx;
    }

    my $stranger_tx = $t->websocket_ok( '/pull/bar' )->tx;
    $stranger_tx->on( message => sub {
        fail 'Stranger received message from wrong push';
    } );

    my $push_tx = $t->websocket_ok( '/push/foo' )->tx;

    subtest 'first message' => sub {
        $t->tx( $push_tx )->send_ok({ text => 'Hello' });
        $t->tx( $got[ 0 ] )
            ->message_ok( 'first puller got first message' )
            ->message_is( 'Hello' );
        shift @{ $got[ 0 ] };
        for my $i ( 1..3 ) {
            ok !@{ $got[ $i ] }, 'other pullers got no message';
        }
    };

    subtest 'second message' => sub {
        $t->tx( $push_tx )->send_ok({ text => 'Hello' });
        $t->tx( $got[ 1 ] )
            ->message_ok( 'second puller got second message' )
            ->message_is( 'Hello' );
        shift @{ $got[ 1 ] };
        for my $i ( 0, 2..3 ) {
            ok !@{ $got[ $i ] }, 'other pullers got no message';
        }
    };

    subtest 'remove a puller' => sub {
        $t->tx( $pulls[1] )->finish_ok( 1000, "puller closed" );
    };

    subtest 'add a puller' => sub {
        my $tx = $t->websocket_ok( '/pull/foo' )->tx;
        push @pulls, $tx;
        my $queue = $got[ @got ] = [];
        $tx->on( message => sub {
            push @$queue, $_[1];
        } );
    };

    subtest 'third message' => sub {
        $t->tx( $push_tx )->send_ok({ text => 'Hello' });
        $t->tx( $got[ 2 ] )
            ->message_ok( 'third puller got third message' )
            ->message_is( 'Hello' );
        shift @{ $got[ 2 ] };
        for my $i ( 0, 3..4 ) {
            ok !@{ $got[ $i ] }, 'other pullers got no message';
        }
    };

    subtest 'fourth message' => sub {
        $t->tx( $push_tx )->send_ok({ text => 'Hello' });
        $t->tx( $got[ 3 ] )
            ->message_ok( 'fourth puller got fourth message' )
            ->message_is( 'Hello' );
        shift @{ $got[ 3 ] };
        for my $i ( 0, 2, 4 ) {
            ok !@{ $got[ $i ] }, 'other pullers got no message';
        }
    };

    subtest 'fifth message' => sub {
        $t->tx( $push_tx )->send_ok({ text => 'Hello' });
        $t->tx( $got[ 4 ] )
            ->message_ok( 'fifth puller got fifth message' )
            ->message_is( 'Hello' );
        shift @{ $got[ 4 ] };
        for my $i ( 0, 2..3 ) {
            ok !@{ $got[ $i ] }, 'other pullers got no message';
        }
    };

    subtest 'sixth message (back to start)' => sub {
        $t->tx( $push_tx )->send_ok({ text => 'Hello' });
        $t->tx( $got[ 0 ] )
            ->message_ok( 'first puller got sixth message' )
            ->message_is( 'Hello' );
        shift @{ $got[ 0 ] };
        for my $i ( 2..4 ) {
            ok !@{ $got[ $i ] }, 'other pullers got no message';
        }
    };

    for my $i ( 0, 2..$#pulls ) {
        $t->tx( $pulls[$i] )->finish_ok( 1000, "pull $i closed" );
    }
    $t->tx( $push_tx )->finish_ok( 1000, 'pusher closed' );
    $t->tx( $stranger_tx )->finish_ok( 1000, 'stranger left' );
};

done_testing;
