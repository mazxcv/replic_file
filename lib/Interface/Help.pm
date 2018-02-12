package Interface::Help;

use strict;
use warnings;
use utf8;

use Data::Dumper;

our $CR = "\012\015";

our $help = {
	help           => "Usage help [command] or -h [command]. Without arguments: display this help.$CR",
	quit           => "Usage quit or -q. Quit the command interface.$CR",
	unknow_command => "Unknow command enter help, list or quit.$CR",
	list           => "Usage list or -l. Get list command$CR",
	connections    => "Usage connections or -c. Get list connections\nUsage: -c [id command or alias]\nExample: -c 6 -q  or connections 6 quit\nSupport command '-q quit'.\nCommand for 6-nd connection quit.$CR"
};


our $aliaces = {
	'-h' => $help->{help},
	'-c' => $help->{connections},
	'-l' => $help->{list},
	'-q' => $help->{quit}
};


sub cr { return $CR; }


sub name_command {
	my $command = shift;
	return {
			'-q' => 'quit',
			quit => 'quit'
		} -> {$command};
}


sub _supported_command {
	my @aliaces = keys %$aliaces;
	my @help    = keys %$help;
	return [ @aliaces, @help ];
}


sub help {
	my $key = shift;
	my $message = $help->{$key} || $aliaces->{$key} || $help->{unknow_command};
	return $message;
}


1;