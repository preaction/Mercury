package Mercury;
# ABSTRACT: A message broker for WebSockets

=head1 SYNOPSIS

    mercury broker [-l <listen>]

=head1 DESCRIPTION

This is a message broker that enables a simple publish/subscribe messaging
pattern. A single socket is either a subscription to all messages on a topic,
or a publishing socket allowed to send messages to that topic.

WebSockets are a powerful tool, enabling many features previously impossible,
difficult, or ugly for web developers to implement. Where once only an HTTP
request could get data from a server, now a persistent socket can allow the
server to send updates without the client needing to specifically request it.

=head2 Server-side Communication

WebSockets do not need to be a communication channel purely between browser and
server. The Mojolicious web framework has excellent support for WebSockets.
Using that support, we can communicate between different server processes.

This solves the problem with client-to-client communication in a parallelized
web server where all clients may not be connected to the same server process.
The server processes can use a central message broker to coordinate and pass
messages from one client to another.

=head2 Message Topics

Requesting a WebSocket from the URL C</sub/leela> creates a subscription to the
topic C<leela>. Requesting a WebSocket from the URL C</pub/leela> allows
sending messages to the C<leela> topic, which are then received by all the
subscribers.

Topics are heirarchical to allow for broad subscriptions without requring more
sockets. A subscription to the topic C<wong> receives all messages published to
the topic C<wong> or any child topic like C<wong/amy> or C<wong/leo>.

=head2 Example App

In C<development> mode (the default), the broker provides an example
application to test the messaging patterns.

You can change the mode by using the C<-m> flag to the
L<C<mercury> command|Mercury::Command::mercury> or the C<MOJO_MODE> environment
variable.

=cut

use Mojo::Base 'Mojolicious';
use Scalar::Util qw( refaddr );
use File::Basename qw( dirname );
use File::Spec::Functions qw( catdir );

my %topics;

=method add_topic_subscriber

    $c->add_topic_subscriber( $topic );

Add the current connection as a subscriber to the given topic. Connections can
be subscribed to only one topic, but they will receive all messages to
child topics as well.

=cut

sub add_topic_subscriber {
    my ( $self, $topic ) = @_;
    $topics{ $topic }{ refaddr $self } = $self;
    return;
}

=method remove_topic_subscriber

    $c->remote_topic_subscriber( $topic );

Remove the current connection from the given topic. Must be called to clean up
the state.

=cut

sub remove_topic_subscriber {
    my ( $self, $topic ) = @_;
    delete $topics{ $topic }{ refaddr $self };
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
        $_->send( $message ) for values %{ $topics{ $topic } };
    }
    return;
}

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
    $app->helper( add_topic_subscriber => \&add_topic_subscriber );
    $app->helper( remove_topic_subscriber => \&remove_topic_subscriber );
    $app->helper( publish_topic_message => \&publish_topic_message );
    my $r = $app->routes;
    $r->websocket( '/sub/*topic' )->to( cb => \&route_websocket_sub )->name( 'sub' );
    $r->websocket( '/pub/*topic' )->to( cb => \&route_websocket_pub )->name( 'pub' );

    if ( $app->mode eq 'development' ) {
        # Enable the example app
        $app->home->parse( catdir( dirname( __FILE__ ), 'Mercury' ) );
        $app->static->paths->[0] = $app->home->rel_dir('public');
        $app->renderer->paths->[0] = $app->home->rel_dir('templates');
        $r->get( '/' )->to( cb => sub { shift->render( 'index' ) } );
    }
}

1;
__END__

