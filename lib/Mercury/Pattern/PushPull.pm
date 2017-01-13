package Mercury::Pattern::PushPull;
our $VERSION = '0.013';
# ABSTRACT: Manage a push/pull pattern for a single topic

=head1 SYNOPSIS

    # Connect the pusher
    my $push_ua = Mojo::UserAgent->new;
    my $push_tx = $ua->websocket( '/push/foo' );

    # Connect the puller socket
    my $pull_ua = Mojo::UserAgent->new;
    my $pull_tx = $ua->websocket( '/pull/foo' );

    # Connect the two sockets using push/pull
    my $pattern = Mercury::Pattern::PushPull->new;
    $pattern->add_pusher( $push_tx );
    $pattern->add_puller( $pull_tx );

    # Send a message
    $pull_tx->on( message => sub {
        my ( $tx, $msg ) = @_;
        print $msg; # Hello, World!
    } );
    $push_tx->send( 'Hello, World!' );

=head1 DESCRIPTION

This pattern connects pushers, which send messages, to pullers, which
recieve messages. Each message sent by a pusher will be received by
a single puller. This pattern is useful for dealing out jobs to workers.

=head1 SEE ALSO

=over

=item L<Mercury::Controller::PushPull>

=item L<Mercury>

=back

=cut

use Mojo::Base 'Mojo';

=attr pullers

Connected websockets ready to receive messages.

=cut

has pullers => sub { [] };

=attr pushers

Connected websockets who will be pushing messages.

=cut

has pushers => sub { [] };

=attr current_puller_index

The puller we will use to send the next message from a pusher.

=cut

has current_puller_index => sub { 0 };

=method add_puller

    $pat->add_puller( $tx );

Add a puller to this broker. Pullers are given messages in a round-robin, one
at a time, by pushers.

=cut

sub add_puller {
    my ( $self, $tx ) = @_;
    $tx->on( finish => sub {
        my ( $tx ) = @_;
        $self->remove_puller( $tx );
    } );
    push @{ $self->pullers }, $tx;
    return;
}

=method add_pusher

    $pat->add_pusher( $tx );

Add a pusher to this broker. Pushers send messages to be processed by pullers.

=cut

sub add_pusher {
    my ( $self, $tx ) = @_;
    $tx->on( message => sub {
        my ( $tx, $msg ) = @_;
        $self->send_message( $msg );
    } );
    $tx->on( finish => sub {
        my ( $tx ) = @_;
        $self->remove_pusher( $tx );
    } );
    push @{ $self->pushers }, $tx;
    return;
}

=method send_message

    $pat->send_message( $msg );

Send the given message to the next puller in line.

=cut

sub send_message {
    my ( $self, $msg ) = @_;
    my $i = $self->current_puller_index;
    my @pullers = @{ $self->pullers };
    $pullers[ $i ]->send( $msg );
    $self->current_puller_index( ( $i + 1 ) % @pullers );
    return;
}

=method remove_puller

    $pat->remove_puller( $tx );

Remove a puller from the list. Called automatically when the puller socket
is closed.

=cut

sub remove_puller {
    my ( $self, $tx ) = @_;
    my @pullers = @{ $self->pullers };
    for my $i ( 0.. $#pullers ) {
        if ( $pullers[$i] eq $tx ) {
            splice @{ $self->pullers }, $i, 1;
            my $current_puller_index = $self->current_puller_index;
            if ( $i > 0 && $current_puller_index >= $i ) {
                $self->current_puller_index( $current_puller_index - 1 );
            }
            return;
        }
    }
}

=method remove_pusher

    $pat->remove_pusher( $tx );

Remove a pusher from the list. Called automatically when the pusher socket
is closed.

=cut

sub remove_pusher {
    my ( $self, $tx ) = @_;
    my @pushers = @{ $self->pushers };
    for my $i ( 0.. $#pushers ) {
        if ( $pushers[$i] eq $tx ) {
            splice @pushers, $i, 1;
            return;
        }
    }
}

1;
