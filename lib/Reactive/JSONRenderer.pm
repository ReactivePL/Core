package Reactive::JSONRenderer;

use warnings;
use strict;

use Moo;

use Types::Standard qw( is_Bool is_Str is_Num is_HashRef is_ArrayRef InstanceOf );
use Reactive::Types qw( is_Boolean is_DateTime is_DBIx is_SerializedDBIx to_SerializedDBIx);

use DateTime::Format::ISO8601;
use JSON::MaybeXS;

has json => (is => 'lazy', isa => InstanceOf[qw/Cpanel::JSON::XS JSON::XS JSON::PP/]);
has canonical_json => (is => 'lazy', isa => InstanceOf[qw/Cpanel::JSON::XS JSON::XS JSON::PP/]);

sub render {
    my $self = shift;
    my $data = shift;

    my $processed = $self->process_data($data);

    return $self->json->encode($processed);
}

sub process_data {
    my $self = shift;
    my $data = shift;

    if (is_Boolean($data) || is_Str($data) || is_Num($data) || is_SerializedDBIx($data)) {
        return $data;
    }

    if (is_DateTime($data)) {
        return DateTime::Format::ISO8601->format_datetime($data);
    }

    if (is_DBIx($data)) {
        return to_SerializedDBIx($data);
    }

    if (is_ArrayRef($data)) {
        return [
            map { $self->process_data($_) } @{ $data }
        ];
    }

    if (is_HashRef($data)) {
        return {
            map { $_ => $self->process_data($data->{$_}) } keys %{ $data }
        };
    }

    return $data;
}

sub _build_json {
    my $self = shift;

    return JSON::MaybeXS->new(utf8 => 1, pretty => 1);
}

sub _build_canonical_json {
    my $self = shift;

    return JSON::MaybeXS->new(utf8 => 1, canonical => 1);
}

1;
