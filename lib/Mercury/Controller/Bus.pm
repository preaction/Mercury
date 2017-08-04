package Mercury::Controller::Bus;
our $VERSION = '0.014';
# ABSTRACT: A messaging pattern where all subscribers share messages

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojolicious::Controller';
use Mercury::Pattern::Bus;

=method connect

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

sub connect {
    my ( $c ) = @_;

    my $topic = $c->stash( 'topic' );
    my $pattern = $c->_pattern( $topic );
    $pattern->add_peer( $c->tx );
    if ( $c->param( 'echo' ) ) {
        $c->tx->on( message => sub {
            my ( $tx, $msg ) = @_;
            $tx->send( $msg );
        } );
    }

    $c->rendered( 101 );
};

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
# Get or create the L<Mercury::Pattern::Bus> object for the given
# topic.
#
#=cut

sub _pattern {
    my ( $c, $topic ) = @_;
    my $pattern = $c->mercury->pattern( Bus => $topic );
    if ( !$pattern ) {
        $pattern = Mercury::Pattern::Bus->new;
        $c->mercury->pattern( Bus => $topic => $pattern );
    }
    return $pattern;
}

1;
