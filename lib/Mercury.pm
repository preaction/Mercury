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

sub startup {
    my ( $app ) = @_;
    $app->plugin( 'Config', { default => { broker => { } } } );
    $app->commands->namespaces( [ 'Mercury::Command::mercury' ] );

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

    $r->websocket( '/bus/*topic' )
      ->to( controller => 'Bus', action => 'connect' )
      ->name( 'bus' );

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

