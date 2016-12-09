package Mercury::Pattern::PubSub;
our $VERSION = '0.011';
# ABSTRACT: Manage a pub/sub pattern for a single topic

=head1 SYNOPSIS

    # Connect the publisher
    my $pub_ua = Mojo::UserAgent->new;
    my $pub_tx = $ua->websocket( '/pub/foo' );

    # Connect the subscriber socket
    my $sub_ua = Mojo::UserAgent->new;
    my $sub_tx = $ua->websocket( '/sub/foo' );

    # Connect the two sockets using pub/sub
    my $pattern = Mercury::Pattern::PubSub->new;
    $pattern->add_publisher( $pub_tx );
    $pattern->add_subscriber( $sub_tx );

    # Send a message
    $sub_tx->on( message => sub {
        my ( $tx, $msg ) = @_;
        print $msg; # Hello, World!
    } );
    $pub_tx->send( 'Hello, World!' );

=head1 DESCRIPTION

This pattern connects publishers, which send messages, to subscribers,
which recieve messages. Each message sent by a publisher will be
received by all connected subscribers. This pattern is useful for
sending notification events and logging.

=head1 SEE ALSO

=over

=item L<Mercury::Controller::PubSub>

=item L<Mercury>

=back

=cut

use Mojo::Base 'Mojo';

=attr subscribers

Arrayref of connected websockets ready to receive messages

=cut

has subscribers => sub { [] };

=attr publishers

Arrayref of connected websockets ready to publish messages

=cut

has publishers => sub { [] };

=method add_subscriber

    $pat->add_subscriber( $tx );

Add the connection as a subscriber. Subscribers will receive all messages
sent by publishers.

=cut

sub add_subscriber {
    my ( $self, $tx ) = @_;
    $tx->on( finish => sub {
        my ( $tx ) = @_;
        $self->remove_subscriber( $tx );
    } );
    push @{ $self->subscribers }, $tx;
    return;
}

=method remove_subscriber

    $pat->remove_subscriber( $tx );

Remove a subscriber. Called automatically when a subscriber socket is
closed.

=cut

sub remove_subscriber {
    my ( $self, $tx ) = @_;
    my @subs = @{ $self->subscribers };
    for my $i ( 0.. $#subs ) {
        if ( $subs[$i] eq $tx ) {
            splice @subs, $i, 1;
            return;
        }
    }
}

=method add_publisher

    $pat->add_publisher( $tx );

Add a publisher to this topic. Publishers send messages to all
subscribers.

=cut

sub add_publisher {
    my ( $self, $tx ) = @_;
    $tx->on( message => sub {
        my ( $tx, $msg ) = @_;
        $self->send_message( $msg );
    } );
    $tx->on( finish => sub {
        my ( $tx ) = @_;
        $self->remove_publisher( $tx );
    } );
    push @{ $self->publishers }, $tx;
    return;
}

=method remove_publisher

    $pat->remove_publisher( $tx );

Remove a publisher from the list. Called automatically when the
publisher socket is closed.

=cut

sub remove_publisher {
    my ( $self, $tx ) = @_;
    my @pubs = @{ $self->publishers };
    for my $i ( 0.. $#pubs ) {
        if ( $pubs[$i] eq $tx ) {
            splice @pubs, $i, 1;
            return;
        }
    }
}

=method send_message

    $pat->send_message( $message );

Send a message to all subscribers.

=cut

sub send_message {
    my ( $self, $message ) = @_;
    $_->send( $message ) for @{ $self->subscribers };
    return;
}

1;

