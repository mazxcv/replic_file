#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use lib qw/lib/;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::Log;
use AnyEvent::IO;

use File::Path qw/make_path/;
use File::Spec;
use File::Basename;

use Data::Dumper;


my $info = {
	host       => '127.0.0.1',
	port       => 9009,
	accept_cb  => \&accept_cb,
	prepare_cb => \&prepare_cb,
};

my $cr = "\012\015";
# todo mem
my $file;
my $seek = 0;
my $handler;
my $fh;
my $cmd;
my $is_update = 0;
my $is_connect = 0;

my $sigint = AE::signal INT => sub { 
	AE::log note => "Interupt by client";
	$handler->destroy;
	exit 1
};

my $timer; $timer = AE::timer 0, 0.5, sub {

	if ($handler) {
		if ($file && -e $file) {
			$seek = -s $file;
			if ($is_update) {
				$cmd = "-d $seek\n"
			} else {
				$cmd = "-i $seek\n"
			}
		} else {
			$cmd = "-f\n";
		}

		my $write_quard; $write_quard = AnyEvent->io(
			fh => $fh,
			poll => 'w',
			cb => sub {
				undef $write_quard;
				$handler->push_write($cmd);

				my $read_guard;
				$read_guard = AnyEvent->io(
					fh => $fh,
					poll => 'r',
					cb => sub {
						undef $read_guard;
						$handler->unshift_read(line => sub {
							my ($handler, $line) = @_;
							my ($command, $params, $data) = $line =~ /([\-\w]+)(?:\s*(\d+)?)(?:\s*(.*)?)/;

							if ($command eq '-i' && $data eq '1') {
								$is_update = 1;
							}

							if ($command eq '-d' && $data) {
								# $data = unpack("H*", $data);
								# todo Иначе не придумал как передавать \n
								$data =~ s/\{n\}/\n/igs;
								aio_open $file, AnyEvent::IO::O_WRONLY | AnyEvent::IO::O_APPEND, 0644, sub {
									my ($fh) = @_ or return AE::log error => "file: $!";
									aio_write $fh, $data, sub {
										my $length = shift or return AE::log error => "file: $!";
										if ($length != length($data)) {
											return AE::log error => "file: $!";
										}
									};
									close $fh;
								};
								$is_update = 0;
							}
						});
					}
				);
			}
		);

	}

};


tcp_connect $info->{host}, $info->{port}, sub {
	($fh) = @_ or return AE::log error => "client: $!" && exit 1;

	# my $handler = new AnyEvent::Handle fh => $fh, timeout => 1, rbuf_max => 1024, no_delay => 1, keepalive => 1;

	$handler = AnyEvent::Handle->new(
		fh => $fh,
		timeout => 1,
		rbuf_max => 1024,
		no_delay => 1,
		on_error => sub {shift->destroy; exit 1;},
		on_eof => sub {shift->destroy; exit 1}
		# keepalive => 1,
	);


	$handler->on_read(sub {
		shift->push_read(line => sub {
			my ($handler, $line, $eol) = @_ or return AE::log error => "client: $!";
			my ($command, $params, $data) = $line =~ /([\-\w]+)(?:\s*(.*)?)(?:\s*(.*)?)/;
			if ($command eq '-f') {
				# todo minus fileno
				$file = File::Spec->catfile("data", "client", $params);
				my $dir = dirname($file);
				make_path($dir);
				qx/touch $file/;
			}
		});
	});

};

AE::cv->wait;