#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use lib qw/lib/;

use IO::Socket;
use AnyEvent::Log;


my $info = {
    admin_host       => '127.0.0.2',
    admin_port       => 9011,
};


my ($kpid, $handler, $line);


    # admin_login      => "admin",
    # admin_password   => "admin",

$handler = IO::Socket::INET->new(
		Proto => "tcp",
		PeerAddr => $info->{admin_host},
		PeerPort => $info->{admin_port}
	) or return AE::log error => "Admin-client: Can\'t connect to $info->{admin_host}: $info->{admin_port}:$!";

$handler->autoflush;

AE::log note => "Admin-client: Connected";

AE::log error => "Admin-client: Can\'t fork: $!" unless defined($kpid = fork());

if ($kpid) {
	while (defined ($line = <$handler>)) {
		print STDOUT $line
	}
	kill("TERM" => $kpid)
} else {
	while (defined($line = <STDIN>)) {
		print $handler $line
	}
}

exit;