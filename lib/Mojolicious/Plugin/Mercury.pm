package Mojolicious::Plugin::Mercury;

# ABSTRACT: Plugin for Mojolicious to add Mercury functionality

=head1 SYNOPSIS

    # myapp.pl
    use Mojolicious::Lite;
    plugin 'Mercury';

=head1 DESCRIPTION

This plugin adds L<Mercury> to your L<Mojolicious> application, allowing you
to build a websocket message broker customized to your needs.

After adding the plugin, you can add basic messaging patterns by using the Mercury
controllers, or you can mix and match your patterns using the Mercury::Pattern
classes.

Controllers handle establishing the websocket connections and giving
them to the right Pattern object, and the Pattern object handles passing
messages between the connected sockets. Controllers can create multiple
instances of a single Pattern to isolate messages to a single topic.

=head2 Controllers

Controllers are L<Mojolicious::Controller> subclasses with route handlers
to establish websocket connections and add them to a Pattern. The built-in
Controllers each handle one pattern, but you can add one socket to multiple
Patterns to customize your message passing.

The built-in controllers are:

=over

=item L<Mercury::Controller::PushPull>

Establish a L<Push/Pull pattern|Mercury::Pattern::PushPull> on a topic.

=back

=head2 Patterns

The Pattern objects handle transmission of messages on a single topic.
Pattern objects take in L<Mojo::Transaction::WebSocket> objects (gotten
by the controller using C<< $c->tx >> inside a C<websocket> route).

The built-in patterns are:

=over

=item L<Mercury::Pattern::PushPull>

A push/pull pattern has each message sent by a pusher delivered to one and
only one puller. This pattern is useful for job workers.

=back

=head1 SEE ALSO

=over

=item L<Mercury>

=item L<Mojolicious::Plugins>

=back

=cut

use Mojo::Base 'Mojolicious::Plugin';

#=attr _patterns
#
# A repository for pattern objects to share between controller
# instances.
#
#=cut

has _patterns => sub { {} };

=method pattern

    my $pattern = $c->mercury->pattern( PushPull => $topic );
    $c->mercury->pattern( PushPull => $topic => $pattern );

Accessor for the pattern repository. Pattern objects track a single topic
and are registered by a namespace (likely the pattern type).

=cut

sub pattern {
    my ( $self, $namespace, $topic, $pattern ) = @_;
    if ( $pattern ) {
        $self->_patterns->{ $namespace }{ $topic } = $pattern;
        return;
    }
    return $self->_patterns->{ $namespace }{ $topic };
}

=method register

Register the plugin with the Mojolicious app. Called automatically by Mojolicious
when you use C<< $app->plugin( 'Mercury' ) >>.

=cut

sub register {
    my ( $self, $app, $conf ) = @_;
    $app->helper( 'mercury.pattern' => sub { shift; $self->pattern( @_ ) } );
    push @{$app->routes->namespaces}, 'Mercury::Controller';
}

1;
