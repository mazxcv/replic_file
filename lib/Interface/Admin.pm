package Interface::Admin;

use Data::Dumper;
our $connections;


sub new {
	my ($type, $arg) = @_;
	my $class = ref($type) || $type;
	my $c = {};
	bless($c, $class);
	$c->init($arg);

	return $c;
}


sub init {
	my ($c, $arg) = @_;
	$c->{_} = get_connection($arg);

	return $c;
}


sub name {
	my ($c, $name) = @_;

	if ($name) {
		$c->{_}->{name} = $name
	}

	return $c->{_}->{name};
}


sub password {
	my ($c, $password) = @_;

	if ($password) {
		$c->{_}->{password} = $password
	}

	return $c->{_}->{password};
}


sub is_admin {
	my ($c, $is_admin) = @_;

	if ($is_admin) {
		$c->{_}->{is_admin} = $is_admin
	}

	return $c->{_}->{is_admin};	
}

sub so_number {
	my $c = shif;

	return $c->{_}->{so_number};
}

sub handle {
	return shift->{_}->{handle};
}


sub host {
	return shift->{_}->{host};
}


sub port {
	return shift->{_}->{port};
}


sub leave_client {
	my ($client, $message) = @_;
	
	$client->handle->push_write("Bye, bye\n$message\n");
	my $message = $client->is_admin ? "Admin-client " : "Client ";
	$message .= $client->host . ":" . $client->port;
	$message .= " => closed.";
	AE::log note  => $message;

	return $client->destroy;
};


sub add_connection {
	my $conf = shift;
	$conf->{so_number} = fileno $conf->{socket_handler};
	$connections->{$conf->{so_number}} = $conf;
}


sub get_connection {
	my $arg = shift;
	return $connections->{$arg};
}

sub get_all_connections {
	return $connections;
}


sub destroy {
	my $client = shift;
	delete $connections->{$client->{_}->{so_number}};
	$client->handle->destroy;	
}

1;