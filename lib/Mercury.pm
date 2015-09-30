package Mercury;
# ABSTRACT: Main broker application class

=head1 DESCRIPTION

This is the main broker application class. With this class, you can add a
message broker inside your L<Mojolicious> application.

It is not necessary to use Mojolicious in order to use Mercury. For how to use
Mercury to broker messages for any application, see L<the main
Mercury documentation|mercury>. For how to start the broker application, see
L<the mercury broker command documentation|Mercury::Command::broker> or
run C<mercury help broker>.

=cut

use Mojo::Base 'Mojolicious';
use Scalar::Util qw( refaddr );
use File::Basename qw( dirname );
use File::Spec::Functions qw( catdir );

my %pubsub_topics;
my %bus_topics;

=method add_bus_peer

    $c->add_bus_peer( $topic )

Add the current connection as a peer on the given bus topic. Connections can
be joined to only one topic.

=cut

sub add_bus_peer {
    my ( $c, $topic ) = @_;
    $bus_topics{ $topic }{ refaddr $c } = $c;
    return;
}

=method remove_bus_peer

Remove the current connection from the given bus topic. Must be called to clean
up the state.

=cut

sub remove_bus_peer {
    my ( $c, $topic ) = @_;
    delete $bus_topics{ $topic }{ refaddr $c };
    return;
}

=method send_bus_message

    $c->send_bus_message( $topic, $message )

Send a message to all the peers on the given bus. Will not send to the current
peer (they should know what they sent).

=cut

sub send_bus_message {
    my ( $self, $topic, $message ) = @_;
    my $self_id = refaddr $self;
    for my $id ( grep { $_ ne $self_id } keys %{ $bus_topics{ $topic } } ) {
        $bus_topics{ $topic }{ $id }->send( $message );
    }
    return;
}

=method add_topic_subscriber

    $c->add_topic_subscriber( $topic );

Add the current connection as a subscriber to the given topic. Connections can
be subscribed to only one topic, but they will receive all messages to
child topics as well.

=cut

sub add_topic_subscriber {
    my ( $self, $topic ) = @_;
    $pubsub_topics{ $topic }{ refaddr $self } = $self;
    return;
}

=method remove_topic_subscriber

    $c->remote_topic_subscriber( $topic );

Remove the current connection from the given topic. Must be called to clean up
the state.

=cut

sub remove_topic_subscriber {
    my ( $self, $topic ) = @_;
    delete $pubsub_topics{ $topic }{ refaddr $self };
    return;
}

=method publish_topic_message

    $c->publish_topic_message( $topic, $message );

Publish a message on the given topic. The message will be sent once to any subscriber
of this topic or any child topics.

=cut

sub publish_topic_message {
    my ( $self, $topic, $message ) = @_;
    my @parts = split m{/}, $topic;
    my @topics = map { join '/', @parts[0..$_] } 0..$#parts;
    for my $topic ( @topics ) {
        $_->send( $message ) for values %{ $pubsub_topics{ $topic } };
    }
    return;
}

=route /bus/*topic

Establish a WebSocket message bus to send/recieve messages on the given
C<topic>. All clients connected to the topic will receive all messages
published on the topic.

This is a shorter way of doing both C</pub/*topic> and C</sub/*topic>,
without the hierarchal message passing.

=cut

sub route_websocket_bus {
    my ( $c ) = @_;
    Mojo::IOLoop->stream($c->tx->connection)->timeout(1200);

    my $topic = $c->stash( 'topic' );
    $c->add_bus_peer( $topic );

    $c->on( message => sub {
        my ( $c, $msg ) = @_;
        $c->send_bus_message( $topic, $msg );
    } );

    $c->on( finish => sub {
        my ( $c ) = @_;
        $c->remove_bus_peer( $topic );
    } );
};

=route /sub/*topic

Establish a WebSocket to subscribe to the given C<topic>. Messages published
to the topic or any child topics will be sent to this subscriber.

=cut

sub route_websocket_sub {
    my ( $c ) = @_;
    Mojo::IOLoop->stream($c->tx->connection)->timeout(1200);

    my $topic = $c->stash( 'topic' );
    $c->add_topic_subscriber( $topic );

    $c->on( finish => sub {
        my ( $c ) = @_;
        $c->remove_topic_subscriber( $topic );
    } );
};

=route /pub/*topic

Establish a WebSocket to publish to the given C<topic>. Messages published to
the topic will be sent to all subscribers to the topic or any parent topics.

=cut

sub route_websocket_pub {
    my ( $c ) = @_;
    Mojo::IOLoop->stream($c->tx->connection)->timeout(1200);

    my $topic = $c->stash( 'topic' );
    $c->on( message => sub {
        my ( $c, $message ) = @_;
        $c->publish_topic_message( $topic, $message );
    } );
}

sub startup {
    my ( $app ) = @_;
    $app->plugin( 'Config', { default => { broker => { } } } );
    $app->commands->namespaces( [ 'Mercury::Command::mercury' ] );

    $app->helper( add_topic_subscriber => \&add_topic_subscriber );
    $app->helper( remove_topic_subscriber => \&remove_topic_subscriber );
    $app->helper( publish_topic_message => \&publish_topic_message );
    $app->helper( add_bus_peer => \&add_bus_peer );
    $app->helper( remove_bus_peer => \&remove_bus_peer );
    $app->helper( send_bus_message => \&send_bus_message );
    my $r = $app->routes;
    $r->websocket( '/sub/*topic' )->to( cb => \&route_websocket_sub )->name( 'sub' );
    $r->websocket( '/pub/*topic' )->to( cb => \&route_websocket_pub )->name( 'pub' );
    $r->websocket( '/bus/*topic' )->to( cb => \&route_websocket_bus )->name( 'bus' );

    if ( $app->mode eq 'development' ) {
        # Enable the example app
        my $root = catdir( dirname( __FILE__ ), 'Mercury' );
        $app->static->paths->[0] = catdir( $root, 'public' );
        $app->renderer->paths->[0] = catdir( $root, 'templates' );
        $r->any( '/' )->to( cb => sub { shift->render( 'index' ) } );
    }
}

1;
__END__

