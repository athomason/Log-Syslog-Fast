package ServerCreator;

sub new {
    my $class = shift;
    return bless {label => $_[0], listen => $_[1]}, $class;
}


sub listen {
    my $self = shift;
    $self->{listen}->();
}

package Server;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}
sub proto {
    my $self = shift;
    return $self->{proto};
}

sub address {
    my $self = shift;
    return @{ $self->{address} };
}

sub connect {
    my $self = shift;
    my $class = shift;
    return $class->new($self->proto, $self->address, @_);
}

sub close {
    my $self = shift;
    $self->{listener} = undef;
}

# remove unix socket file on server close
sub DESTROY {
    my $self = shift;
    if ($self->{address}[1] == 0) {
        unlink $self->{address}[0];
    }
}

package StreamServer;

use base 'Server';

sub accept {
    my $self = shift;
    my $receiver = $self->{listener}->accept;
    $receiver->blocking(0);
    return $receiver;
}

package DgramServer;

use base 'Server';

sub accept {
    my $self = shift;
    return $self->{listener};
}

1;
