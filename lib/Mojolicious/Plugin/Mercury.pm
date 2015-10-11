package Mojolicious::Plugin::Mercury;
# ABSTRACT: Mojolicious client plugin for Mercury

use Mojo::Base 'Mojolicious::Plugin';

sub register {
    my ( $self, $app, $conf ) = @_;
    my $base_url = $conf->{connect};
    $base_url =~ s/^http/ws/;
    $base_url =~ s{/$}{};
    $app->helper( 'mercury.bus' => sub {
        my ( $c, $topic, %events ) = @_;
        my $url = $base_url . '/bus/' . $topic;
        $c->app->log->debug( sprintf 'Connecting to bus "%s"', $url );
        my $ua = Mojo::UserAgent->new;
        $ua->websocket( $url, sub {
            my ( $ua, $tx ) = @_;
            if ( !$tx->is_websocket ) {
                $c->app->log->warn(
                    sprintf 'Could not connect to bus "%s": %s', $topic, $tx->res->body,
                );
            }
        } );
        for my $name ( keys %events ) {
            $ua->on( $name, $events{ $name } );
        }
        return $ua;
    } );
}

1;
