package Mercury::Controller::PubSub;
our $VERSION = '0.011';
# ABSTRACT: Pub/sub message pattern controller

=head1 SYNOPSIS

    # myapp.pl
    use Mojolicious::Lite;
    plugin 'Mercury';
    websocket( '/pub/*topic' )
      ->to( controller => 'PubSub', action => 'pub' );
    websocket( '/sub/*topic' )
      ->to( controller => 'PubSub', action => 'sub' );

=head1 DESCRIPTION

This controller enables a L<pub/sub pattern|Mercury::Pattern::PubSub> on
a pair of endpoints (L<publish|/publish> and L<subscribe|/subscribe>.

For more information on the pub/sub pattern, see L<Mercury::Pattern::PubSub>.

=head1 SEE ALSO

=over

=item L<Mercury::Pattern::PubSub>

=item L<Mercury::Controller::PubSub::Cascade>

=item L<Mercury>

=back

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mercury::Pattern::PubSub;

=method publish

    $app->routes->websocket( '/pub/*topic' )
      ->to( controller => 'PubSub', action => 'publish' );

Controller action to connect a websocket as a publisher. A publish
client sends messages through the socket. The message will be sent to
all of the connected subscribers.

This endpoint requires a C<topic> in the stash.

=cut

sub publish {
    my ( $c ) = @_;
    my $pattern = $c->_pattern( $c->stash( 'topic' ) );
    $pattern->add_publisher( $c->tx );
    $c->rendered( 101 );
}

=method subscribe

    $app->routes->websocket( '/sub/*topic' )
      ->to( controller => 'PubSub', action => 'subscribe' );

Controller action to connect a websocket as a subscriber. A subscriber
will recieve every message sent by publishers.

This endpoint requires a C<topic> in the stash.

=cut

sub subscribe {
    my ( $c ) = @_;
    my $pattern = $c->_pattern( $c->stash( 'topic' ) );
    $pattern->add_subscriber( $c->tx );
    $c->rendered( 101 );
}

=method post

Post a new message to the given topic without subscribing or
establishing a WebSocket connection. This allows new messages to be
pushed by any HTTP client.

=cut

sub post {
    my ( $c ) = @_;
    my $topic = $c->stash( 'topic' );
    my $pattern = $c->_pattern( $topic );
    $pattern->send_message( $c->req->body );
    $c->render(
        status => 200,
        text => '',
    );
}

#=method _pattern
#
#   my $pattern = $c->_pattern( $topic );
#
# Get or create the L<Mercury::Pattern::PubSub> object for the given
# topic.
#
#=cut

sub _pattern {
    my ( $c, $topic ) = @_;
    my $pattern = $c->mercury->pattern( PubSub => $topic );
    if ( !$pattern ) {
        $pattern = Mercury::Pattern::PubSub->new;
        $c->mercury->pattern( PubSub => $topic => $pattern );
    }
    return $pattern;
}

1;
