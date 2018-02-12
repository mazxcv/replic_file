package Interface::ClientCommand;

use AnyEvent::IO;
use AnyEvent::Log;
use Interface::Help;

use Data::Dumper;

our $config = {
	file              => "data/test.txt",
};


sub _supported_command {
	[ qw/
		-q
		-f
		-i
		quit
		-d
	/ ];
}


sub _get_app {
	return {
		'-f' => \&_name_of_file,
		'-q' => \&_quit,
		quit => \&_quit,
		'-i' => \&_is_download_file,
		'-d' => \&_download_content,
	}
}


sub command {
	my ($client, $line) = @_;
	my ($command, $params) = $line =~ /([\-\w]+)(?:\s*(.*)?)/;


	if ($command ~~ @{ &_supported_command }) {
		_get_app->{$command}->($client, $command, $params);
	} else {
		unknow_command($client);
	}

}


sub _name_of_file {
	my ($client, $command, $params) = @_;
	my $message = "-f " . $config->{file} . "\n";

	return $client->handle->push_write($message);
}


sub _quit {
	my ($client, $command, $params) = @_;

	return Interface::Admin::leave_client($client, "Closed by quit");
}

sub _is_download_file {
	my ($client, $command, $params) = @_;

	my $size = -s $config->{file};
	my $seek = int($params);
	my $message = "$command $params " . ($size > $seek ? 1 : 0) . "\n";

	return $client->handle->push_write($message);
}

sub _download_content {
	my ($client, $command, $params) = @_;

	unless (-e $config->{file}) {
		AE::log error => "Config: not found file";
		return $client->handle->push_write(undef);
	}

	aio_open $config->{file}, AnyEvent::IO::O_RDONLY, 0, sub {
		my ($fh) = @_ or return AE::log error => "File: $!";
		my $size = -s _;
		my $seek = int $params;
		if ($size > $seek) {
			aio_seek $fh, $seek, 0, sub {
				@_ or return AE::log error => "File: $!";
				aio_read $fh, $size, sub {
					my ($data) = @_ or return AE::log error => "File: $!";
					$data =~ s/\n/{n}/igs;
					my $read_size = length $data or return AE::log error => "File: empty data";

					return $client->handle->push_write("-d $seek $data\n");
				}
			}
		} else {
			return $client->handle->push_write("Wrong seek\n");
		}
			
	}
}


sub unknow_command {
	return shift->handle->push_write(Interface::Help::help("unknow_command"));
}

1;