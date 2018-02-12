package Interface::AdminCommand;

use strict;
use warnings;
use utf8;

use Interface::Help;
use Interface::Admin;
use Interface::ClientCommand;

use Data::Dumper;


sub _get_app {
	return {
		help           => \&help,
		'-h'           => \&help,
		quit           => \&quit,
		'-q'           => \&quit,
		list           => \&list,
		'-l'           => \&list,
		connections    => \&connections,
		'-c'           => \&connections,
		unknow_command => \&unknow_command,
	};
}


sub _supported_command {
	return Interface::Help::_supported_command;
}


sub cr { return Interface::Help::cr }


sub command {
	my ($client, $line) = @_;
	my ($command, $params) = $line =~ /([\-\w]+)(?:\s*(.*)?)/;

	if ($client->is_admin) {
		if ($command ~~ @{ &_supported_command }) {
			_get_app->{$command}->($client, $command, $params);
		} else {
			unknow_command($client);
		}
	} else {
		Interface::ClientCommand::command($client, $line);
	}	
}


sub quit {
	my ($client, $command, $params) = @_;

	return Interface::Admin::leave_client($client, "Closed by quit");
}


sub help {
	my ($client, $command, $params) = @_;
	my ($word) = $params =~ /([\-\w]+)/;
	$word ||= "help";
	return $client->handle->push_write(Interface::Help::help($word));
}


sub list {
	my $cr = cr;
	my $message = "Supported command:\n";
	$message .= join ' ', grep {$_ ne "unknow_command"} @{ &_supported_command };
	$message .= ".$cr";
	return shift->handle->push_write($message);
}


sub connections {
	my ($client, $command, $params) = @_;

	my $cr = cr;
	my $connections = $client->get_all_connections;

	$params =~ s/^\s+//;
	$params =~ s/\s+$//;
	if ($params) {
		my ($id, $param) = $params =~ /(\d+)\s+([\-\w]+)/;

		my $supprted_command = Interface::Help::_supported_command;
		if (
				!(
					$id
					&& $connections->{$id}
					&& $param
					&& $param ~~ @{ $supprted_command }
				)
			) {
			return Interface::AdminCommand::_error_command_connection($client);
		}

		# normal command -c id -command
		my $slave = Interface::Admin->new($id);

		$slave->handle->push_write(sprintf "Admin sent command: %s\n", Interface::Help::name_command($param));
		Interface::AdminCommand::command($slave, $param);

	}

	my $decorator = '-';
	my $multi     = 38;

	my $message   = "Table connections:\n";
	$message     .= $decorator x $multi;
	$message     .= "\n";
	$message     .= '| ID  | TYPE  | HOST:PORT            |';
	$message     .= "\n";
	$message     .= $decorator x $multi;

	my $message_for_connections = "\n";
	for my $id_connect (sort keys %$connections) {
		my $connect = $connections->{$id_connect};

		$message_for_connections .= '| ';
		$message_for_connections .= sprintf '%-3s', $id_connect;
		$message_for_connections .= ' | ';

		$message_for_connections .= sprintf '%-5s', ($connect->{name} || '');
		$message_for_connections .= ' | ';

		my $host_port = $connect->{host} . ":" . $connect->{port};
		$message_for_connections .= sprintf '%-20s', $host_port;
		$message_for_connections .= ' | ';

		$message_for_connections .= "\n";
	}

	$message     .= $message_for_connections;
	$message     .= $decorator x $multi;
	$message     .= "\nSupported command: -q";
	$message     .= "\nUsage: -c [id command or alias]";
	$message     .= "\nExample: -c 6 -q  or connections 6 quit  . Command for 6-nd connection quit.$cr";

	return $client->handle->push_write("$message\n");
}

sub _error_command_connection {
	my $cr = cr;
	return shift->handle->push_write("Usage: -c [id command or alias].\nUse -c or command for show table connections.\nUse existing id and supported command.$cr");
}


sub unknow_command {
	return shift->handle->push_write(Interface::Help::help("unknow_command"));
}


1;