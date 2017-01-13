package Mercury::Pattern::Bus;
our $VERSION = '0.013';
# ABSTRACT: A messaging pattern where all peers share messages

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=cut

use Mojo::Base 'Mojo';

=attr peers

The list of peers connected to this bus.

=cut

has peers => sub { [] };

=method add_peer

    $pat->add_peer( $tx )

Add the given connection as a peer to this bus.

=cut

sub add_peer {
    my ( $self, $tx ) = @_;
    $tx->on( message => sub {
        my ( $tx, $msg ) = @_;
        $self->send_message( $msg, $tx );
    } );
    $tx->on( finish => sub {
        my ( $tx ) = @_;
        $self->remove_peer( $tx );
    } );
    push @{ $self->peers }, $tx;
    return;
}

=method remove_peer

Remove the connection from this bus. Called automatically by the C<finish>
handler.

=cut

sub remove_peer {
    my ( $self, $tx ) = @_;
    my @peers = @{ $self->peers };
    for my $i ( 0.. $#peers ) {
        if ( $peers[$i] eq $tx ) {
            splice @peers, $i, 1;
            return;
        }
    }
    return;
}

=method send_message

    $pat->send_message( $message, $from )

Send a message to all the peers on this bus. If a C<$from> websocket is
specified, will not send to that peer (they should know what they sent).

=cut

sub send_message {
    my ( $self, $msg, $from_tx ) = @_;
    my @peers = @{ $self->peers };
    if ( $from_tx ) {
        @peers = grep { $_ ne $from_tx } @peers;
    }
    $_->send( $msg ) for @peers;
}


1;
