package Mercury::Controller::PushPull;

# ABSTRACT: Push/pull message pattern controller

=head1 SYNOPSIS

    # myapp.pl
    use Mojolicious::Lite;
    plugin 'Mercury';
    websocket( '/push/*topic' )
      ->to( controller => 'PushPull', action => 'push' );
    websocket( '/pull/*topic' )
      ->to( controller => 'PushPull', action => 'pull' );

=head1 DESCRIPTION

This controller enables a L<push/pull pattern|Mercury::Pattern::PushPull> on
a pair of endpoints (L<push|/push> and L<pull|/pull>.

For more information on the push/pull pattern, see L<Mercury::Pattern::PushPull>.

=head1 SEE ALSO

=over

=item L<Mercury::Pattern::PushPull>

=item L<Mercury>

=back

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mercury::Pattern::PushPull;

=method push

    $app->routes->websocket( '/push/*topic' )
      ->to( controller => 'PushPull', action => 'push' );

Controller action to connect a websocket to a push endpoint. A push client
sends messages through the socket. The message will be sent to one of the
connected pull clients in a round-robin fashion.

This endpoint requires a C<topic> in the stash.

=cut

sub push {
    my ( $c ) = @_;
    my $pattern = $c->_pattern( $c->stash( 'topic' ) );
    $pattern->add_pusher( $c->tx );
    $c->rendered( 101 );
}

=method pull

    $app->routes->websocket( '/pull/*topic' )
      ->to( controller => 'PushPull', action => 'pull' );

Controller action to connect a websocket to a pull endpoint. A pull
client will recieve messages from push clients in a round-robin fashion.
One message from a pusher will be received by exactly one puller.

This endpoint requires a C<topic> in the stash.

=cut

sub pull {
    my ( $c ) = @_;
    my $pattern = $c->_pattern( $c->stash( 'topic' ) );
    $pattern->add_puller( $c->tx );
    $c->rendered( 101 );
}

#=method _pattern
#
#   my $pattern = $c->_pattern( $topic );
#
# Get or create the L<Mercury::Pattern::PushPull> object for the given
# topic.
#
#=cut

sub _pattern {
    my ( $c, $topic ) = @_;
    my $pattern = $c->mercury->pattern( PushPull => $topic );
    if ( !$pattern ) {
        $pattern = Mercury::Pattern::PushPull->new;
        $c->mercury->pattern( PushPull => $topic => $pattern );
    }
    return $pattern;
}

1;
