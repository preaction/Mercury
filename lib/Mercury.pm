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
use Mercury::PushPull;

my %pubsub_topics;
my %bus_topics;
my %pushpull;

=method add_bus_peer

    $c->add_bus_peer( $topic )

Add the current connection as a peer on the given bus topic. Connections can
be joined to only one topic.

=cut

sub add_bus_peer {
    my ( $c, $topic, %options ) = @_;
    $options{_controller} = $c;
    $bus_topics{ $topic }{ refaddr $c } = \%options;
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
    for my $id ( keys %{ $bus_topics{ $topic } } ) {
        my $peer = $bus_topics{ $topic }{ $id };
        next unless $id ne $self_id || $peer->{echo};
        $peer->{_controller}->send( $message );
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

One difference is that by default a sender will not receive a message
that they sent. To enable this behavior, pass a true value as the C<echo>
query parameter when establishing the websocket.

  $ua->websocket('/bus/foo?echo=1' => sub { ... });

=cut

sub route_websocket_bus {
    my ( $c ) = @_;
    Mojo::IOLoop->stream($c->tx->connection)->timeout(1200);

    my $topic = $c->stash( 'topic' );
    my $echo = $c->param('echo');
    $c->add_bus_peer( $topic, echo => $echo );

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

=route /pull/*topic

Establish a WebSocket to pull messages from the given C<topic>. Messages will
be routed in a round-robin fashion from pushers.

=cut

sub route_websocket_pull {
    my ( $c ) = @_;
    Mojo::IOLoop->stream($c->tx->connection)->timeout(1200);
    my $topic = $c->stash( 'topic' );
    my $pat = $pushpull{ $topic } ||= Mercury::PushPull->new( topic => $topic );
    $pat->add_puller( $c );
};

=route /push/*topic

Establish a WebSocket to push messages to the given C<topic>. Messages will be
routed in a round-robin fashion to a single puller.

=cut

sub route_websocket_push {
    my ( $c ) = @_;
    Mojo::IOLoop->stream($c->tx->connection)->timeout(1200);
    my $topic = $c->stash( 'topic' );
    my $pat = $pushpull{ $topic } ||= Mercury::PushPull->new( topic => $topic );
    $pat->add_pusher( $c );
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
    if ( my $origin = $app->config->{broker}{allow_origin} ) {
        # Allow only '*' for wildcards
        my @origin = map { quotemeta } ref $origin eq 'ARRAY' ? @$origin : $origin;
        s/\\\*/.*/g for @origin;

        $r = $r->under( '/' => sub {
            #say "Got origin: " . $_[0]->req->headers->origin;
            #say "Checking against: @origin";
            my $origin = $_[0]->req->headers->origin;
            if ( !$origin || !grep { $origin =~ /$_/ } @origin ) {
                $_[0]->render(
                    status => '401',
                    text => 'Origin check failed',
                );
                return;
            }
            return 1;
        } );
    }

    $r->websocket( '/sub/*topic' )->to( cb => \&route_websocket_sub )->name( 'sub' );
    $r->websocket( '/pub/*topic' )->to( cb => \&route_websocket_pub )->name( 'pub' );
    $r->websocket( '/bus/*topic' )->to( cb => \&route_websocket_bus )->name( 'bus' );
    $r->websocket( '/push/*topic' )->to( cb => \&route_websocket_push )->name( 'push' );
    $r->websocket( '/pull/*topic' )->to( cb => \&route_websocket_pull )->name( 'pull' );

    if ( $app->mode eq 'development' ) {
        # Enable the example app
        my $root = catdir( dirname( __FILE__ ), 'Mercury' );
        $app->static->paths->[0] = catdir( $root, 'public' );
        $app->renderer->paths->[0] = catdir( $root, 'templates' );
        $app->routes->any( '/' )->to( cb => sub { shift->render( 'index' ) } );
    }
}

1;
__END__

