
use Mojo::Base -strict;
use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new( 'Mercury' );

my @pulls;
my @got;
for my $i ( 0, 1 ) {
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
    $t->tx( $pulls[ 0 ] )
        ->message_ok( 'first puller got first message' )
        ->message_is( 'Hello' );
    shift @{ $got[ 0 ] };
    for my $i ( 1 ) {
        ok !@{ $got[ $i ] }, 'other pullers got no message';
    }
};

subtest 'second message' => sub {
    $t->tx( $push_tx )->send_ok({ text => 'Hello' });
    $t->tx( $pulls[ 1 ] )
        ->message_ok( 'second puller got second message' )
        ->message_is( 'Hello' );
    shift @{ $got[ 1 ] };
    for my $i ( 0 ) {
        ok !@{ $got[ $i ] }, 'other pullers got no message';
    }
};

subtest 'third message' => sub {
    $t->tx( $push_tx )->send_ok({ text => 'Hello' });
    $t->tx( $pulls[ 0 ] )
        ->message_ok( 'first puller got third message' )
        ->message_is( 'Hello' );
    shift @{ $got[ 0 ] };
};

subtest 'remove a puller' => sub {
    $t->tx( $pulls[1] )->finish_ok;
};

subtest 'fourth message' => sub {
    $t->tx( $push_tx )->send_ok({ text => 'Hello' });

    # This is likely a bug in Mojolicious somewhere...
    my $loop = Mojo::IOLoop->singleton;
    $loop->timer( 0.001, sub { $loop->stop } );
    $loop->start;

    $t->tx( $pulls[ 0 ] )
        ->message_ok( 'first puller got third message' )
        ->message_is( 'Hello' );
    shift @{ $got[ 0 ] };
};

subtest 'add a puller' => sub {
    my $tx = $t->websocket_ok( '/pull/foo' )->tx;
    push @pulls, $tx;
    my $queue = $got[ @got ] = [];
    $tx->on( message => sub {
        push @$queue, $_[1];
    } );
};

subtest 'fourth message' => sub {
    $t->tx( $push_tx )->send_ok({ text => 'Hello' });
    $t->tx( $pulls[ 0 ] )
        ->message_ok( 'first puller got fourth message' )
        ->message_is( 'Hello' );
    shift @{ $got[ 0 ] };
    for my $i ( 2 ) {
        ok !@{ $got[ $i ] }, 'other pullers got no message';
    }
};

subtest 'fifth message' => sub {
    $t->tx( $push_tx )->send_ok({ text => 'Hello' });
    $t->tx( $pulls[ 2 ] )
        ->message_ok( 'third puller got fifth message' )
        ->message_is( 'Hello' );
    shift @{ $got[ 2 ] };
    for my $i ( 0 ) {
        ok !@{ $got[ $i ] }, 'other pullers got no message';
    }
};

subtest 'remove all pullers' => sub {
    for my $i ( 0, 2 ) {
        $t->tx( $pulls[$i] )->finish_ok;
    }
};

subtest 'start again' => sub {
    my $tx = $t->websocket_ok( '/pull/foo' )->tx;
    push @pulls, $tx;
    my $queue = $got[ @got ] = [];
    $tx->on( message => sub {
        push @$queue, $_[1];
    } );
};

subtest 'sixth message' => sub {
    $t->tx( $push_tx )->send_ok({ text => 'Hello' });

    # This is likely a bug in Mojolicious somewhere...
    my $loop = Mojo::IOLoop->singleton;
    $loop->timer( 0.001, sub { $loop->stop } );
    $loop->start;

    $t->tx( $pulls[ 3 ] )
        ->message_ok( 'fourth puller got sixth message' )
        ->message_is( 'Hello' );
    shift @{ $got[ 3 ] };
};

$t->tx( $push_tx )->finish_ok;
$t->tx( $stranger_tx )->finish_ok;

done_testing;

