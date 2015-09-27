package Mojolicious::Command::broker;
# ABSTRACT: Run a broker

=head1 SYNOPSIS

  Usage: APPLICATION broker [OPTIONS]

    ./myapp.pl broker
    ./myapp.pl broker -l http://*:8080
    ./myapp.pl broker -l http://127.0.0.1:8080 -l https://[::]:8081
    ./myapp.pl broker -l 'https://*:443?cert=./server.crt&key=./server.key'

  Options:
    -b, --backlog <size>                 Listen backlog size, defaults to
                                         SOMAXCONN
    -c, --clients <number>               Maximum number of concurrent
                                         connections, defaults to 1000
    -i, --inactivity-timeout <seconds>   Inactivity timeout, defaults to 20
                                         minutes
    -l, --listen <location>              One or more locations you want to
                                         listen on, defaults to the value of
                                         MOJO_LISTEN or "http://*:3000"
    -p, --proxy                          Activate reverse proxy support,
                                         defaults to the value of
                                         MOJO_REVERSE_PROXY

=head1 DESCRIPTION

L<Mojolicious::Command::broker> starts the L<Mojolicious::Broker> application.

=cut

use Mojo::Base 'Mojolicious::Command';
use Mojolicious::Broker;

use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use Mojo::Server::Daemon;

=attr description

    my $description = $cmd->description;
    $cmd = $cmd->description('Foo');

Short description of this command, used for the command list.

=cut

has description => 'Start WebSocket message broker';

=attr usage

    my $usage = $cmd->usage;
    $cmd = $cmd->usage('Foo');

Usage information for this command, used for the help screen.

=cut

has usage => sub { shift->extract_usage };

=method run

  $cmd->run(@ARGV);

Run this command.

=cut

sub run {
    my ( $self, @args ) = @_;

    my $daemon = Mojo::Server::Daemon->new(
        app => Mojolicious::Broker->new,
        inactivity_timeout => 1200,
    );

    GetOptionsFromArray( \@args,
        'b|backlog=i' => sub { $daemon->backlog($_[1]) },
        'c|clients=i' => sub { $daemon->max_clients($_[1]) },
        'i|inactivity-timeout=i' => sub { $daemon->inactivity_timeout($_[1]) },
        'l|listen=s' => \my @listen,
        'p|proxy' => sub { $daemon->reverse_proxy(1) },
    );

    $daemon->listen(\@listen) if @listen;
    $daemon->run;
}

1;
__END__

=head1 SEE ALSO

=over 4

=item *

L<Mojolicious::Broker>

=item *

L<Mojolicious::Command>

=item *
L<Mojolicious>

=item *

L<Mojolicious::Guides>

=item *

L<http://mojolicio.us>

=back

