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

=route /bus/*topic

Establish a WebSocket message bus to send/receive messages on the given
C<topic>. All clients connected to the topic will receive all messages
published on the topic.

This is a shorter way of doing both C</pub/*topic> and C</sub/*topic>,
without the hierarchical message passing.

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

sub startup {
    my ( $app ) = @_;
    $app->plugin( 'Config', { default => { broker => { } } } );
    $app->commands->namespaces( [ 'Mercury::Command::mercury' ] );

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

    $r->websocket( '/bus/*topic' )->to( cb => \&route_websocket_bus )->name( 'bus' );

    $app->plugin( 'Mercury' );
    $r->websocket( '/push/*topic' )
      ->to( controller => 'PushPull', action => 'push' )
      ->name( 'push' );
    $r->websocket( '/pull/*topic' )
      ->to( controller => 'PushPull', action => 'pull' )
      ->name( 'pull' );

    $r->websocket( '/pub/*topic' )
      ->to( controller => 'PubSub::Cascade', action => 'publish' )
      ->name( 'pub' );
    $r->websocket( '/sub/*topic' )
      ->to( controller => 'PubSub::Cascade', action => 'subscribe' )
      ->name( 'sub' );

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

