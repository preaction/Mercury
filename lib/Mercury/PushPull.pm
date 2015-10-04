package Mercury::PushPull;
# ABSTRACT: Push/pull message pattern

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Mojo::Base 'Mojo';

=attr topic

This object's topic, for accounting purposes.

=cut

has 'topic';

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

    $pat->add_puller( $c );

Add a puller to this broker. Pullers are given messages in a round-robin, one
at a time, by pushers.

=cut

sub add_puller {
    my ( $self, $c ) = @_;
    $c->on( finish => sub {
        my ( $c ) = @_;
        $self->remove_puller( $c );
    } );
    push @{ $self->pullers }, $c;
    return;
}

=method add_pusher

    $pat->add_pusher( $c );

Add a pusher to this broker. Pushers send messages to be processed by pullers.

=cut

sub add_pusher {
    my ( $self, $c ) = @_;
    $c->on( message => sub {
        my ( $c, $msg ) = @_;
        $self->send_message( $msg );
    } );
    $c->on( finish => sub {
        my ( $c ) = @_;
        $self->remove_pusher( $c );
    } );
    push @{ $self->pushers }, $c;
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

    $pat->remove_puller( $c );

Remove a puller from the list. Called automatically when the puller socket
is closed.

=cut

sub remove_puller {
    my ( $self, $c ) = @_;
    my @pullers = @{ $self->pullers };
    for my $i ( 0.. $#pullers ) {
        if ( $pullers[$i] eq $c ) {
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

    $pat->remove_pusher( $c );

Remove a pusher from the list. Called automatically when the pusher socket
is closed.

=cut

sub remove_pusher {
    my ( $self, $c ) = @_;
    my @pushers = @{ $self->pushers };
    for my $i ( 0.. $#pushers ) {
        if ( $pushers[$i] eq $c ) {
            splice @pushers, $i, 1;
            return;
        }
    }
}

1;
