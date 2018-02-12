#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use lib qw/lib/;

use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::Log;

use Data::Dumper;

use Interface::AdminCommand;
use Interface::ClientCommand;

$0 = "replica-server";
$| = 1;

my $info  = {
	client_port       => 9009,
	client_host       => '127.0.0.1',
	client_accept_cb  => \&client_accept_cb,
	client_prepare_cb => \&client_prepare_cb,

	admin_port        => 9011,
	admin_host        => '127.0.0.2',
	admin_accept_cb   => \&admin_accept_cb,
	admin_prepare_cb  => \&admin_prepare_cb,
	admin_login       => "admin",
	admin_password    => "admin",
};



tcp_server $info->{client_host} => $info->{client_port}, $info->{client_accept_cb}, $info->{client_prepare_cb};
tcp_server $info->{admin_host } => $info->{admin_port }, $info->{admin_accept_cb }, $info->{admin_prepare_cb };


AE::cv->wait;


sub client_accept_cb {
	my ($socket_handler, $host, $port) = @_ or return AE::log error => "client: $!";

	AE::log note  => "Client connected: $host:$port";
	my $handler = new AnyEvent::Handle fh => $socket_handler, timeout => 1, rbuf_max => 1024, no_delay => 1, keepalive => 1;

	Interface::Admin::add_connection({
			port           => $port,
			host           => $host,
			handle         => $handler,
			socket_handler => $socket_handler
		});

	$handler->on_timeout(sub {
		my ($handler) = @_ or return AE::log error => "client: $!";
		$handler->destroy;
		AE::log error  => "Client $host:$port inactivity timeout $!";
	});

	$handler->on_read(sub {
		shift->push_read(line => sub {
			my ($handler, $line) = @_;

			my $client = Interface::Admin->new(fileno $socket_handler);
			if ($line =~ /(\S+)/) {
				return Interface::ClientCommand::command($client, $line);
			}

		})
	});

	$handler->on_error(sub {
		my ($handler, $fatal, $msg) = @_;
		$handler->destroy;
		AE::log error => "Client $host:$port error: $fatal => $msg";
	});

	$handler->on_eof(sub {
		shift->destroy; 
		AE::log error => "Client $host:$port eof";
	});

}


sub client_prepare_cb {
	my ($admin_handler, $host, $port) = @_ or return AE::log error => "server: $!";

	AE::log note  => "Server started $host:$port";
	return 0;
}


sub admin_accept_cb {
	my ($socket_handler, $host, $port) = @_ or return AE::log error => "Admin-client: $!";

	AE::log note  => "Admin-client connected: $host:$port";

	my $handler = new AnyEvent::Handle fh => $socket_handler;

	$handler->push_write("Welcome, confirm your entry, username:\n");

	Interface::Admin::add_connection({
			port           => $port,
			host           => $host,
			handle         => $handler,
			socket_handler => $socket_handler
		});

	$handler->on_read(sub {
		shift->push_read(line => sub {
			my ($handler, $line) = @_;

			my $client = Interface::Admin->new(fileno $socket_handler);

			unless (defined $client->name) {
				if ($line =~ /(\S+)/) {
					my $command = $1;
					$client->name($command);
					$client->handle->push_write("password:\n");
				}
				return;
			}

			unless (defined $client->password) {
				if ($line =~ /(\S+)/) {
					my $command = $1;
					AE::log note  => "Admin-client authorized";
					$client->password(1);
					if ($client->name eq $info->{admin_login} && $command eq $info->{admin_password}) {
						$client->is_admin(defined $client->name && $command);
						$client->handle->push_write("Hello, administrator. Use 'help' or 'list' for assistance or 'quit' for exit.\n>");
					} else {
						$client->leave_client("Invalid pair: login/password");
					}
				}
				return;
			}

			if ($client->is_admin) {
				if ($line =~ /(\w+)/) {
					return Interface::AdminCommand::command($client, $line);
				}
			}

		});
	});

	$handler->on_error(sub {
		my ($handler, $fatal, $msg) = @_;

		$handler->destroy;
		AE::log error => "Admin-client $host:$port error: $fatal => $msg";
	});
}


sub admin_prepare_cb {
	my ($admin_handler, $host, $port) = @_ or return AE::log error => "server: $!";
	AE::log note  => "Admin-server started $host:$port";
	return 0;	
}
