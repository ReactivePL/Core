package Reactive::Core::Utils::Proxy;

use warnings;
use strict;

use Moo;
use namespace::clean;

use Types::Standard qw/Maybe Object/;
use Scalar::Util 'blessed';

has _instance => (is => 'lazy', isa => Maybe[Object]);

sub AUTOLOAD {
    our $AUTOLOAD;
    my $self = shift;
    my $method = $AUTOLOAD;
    my @args = @_;

    $method =~ s/.*:://;

    printf "Autoload called for %s->%s\n", blessed $self // $self, $method;

    return $self->_instance->$method(@args);
}

1;
