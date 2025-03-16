package Reactive::Core::Types;

use warnings;
use strict;

use DateTime;
use DateTime::Format::ISO8601;

use Type::Library -extends => [ 'Types::Standard' ], -declare => qw/
    DateTime
    Boolean
    DBIx
    SerializedDBIx
/;

use Type::Tiny::Class;
use Types::TypeTiny qw/BoolLike/;

use Type::Utils qw( assert );
use Scalar::Util 'blessed';

use constant ISO8601_REGEX => qr{(\d{4}-[01]\d-[0-3]\d)T[0-2]\d:[0-5]\d:[0-5]\d(\.\d+)?([+-][0-2]\d:[0-5]\d|Z)};

my $dt = __PACKAGE__->add_type(
    Type::Tiny::Class->new(
        name    => 'DateTime',
        class   => 'DateTime',
    )
);
$dt->coercion->add_type_coercions(
  Int,                     q{ DateTime->from_epoch(epoch => $_) },
  Undef,                   q{ DateTime->now() },
  StrMatch[ISO8601_REGEX], q{ DateTime::Format::ISO8601->parse_datetime($_) }
);

my $boolean = __PACKAGE__->add_type(
    name => 'Boolean',
    parent => Enum[\0, \1],
);

$boolean->coercion->add_type_coercions(
    BoolLike, q{ $_ ? \1 : \0 },
);

my $serialized_dbix = __PACKAGE__->add_type(
    name => 'SerializedDBIx',
    parent => Dict[
        model => Str,
        id => Int|Str,
        summary => HashRef,
    ],
);

$serialized_dbix->coercion->add_type_coercions(
    DBIx, sub {
        return {
            model => blessed $_,
            id => $_->id,
            summary => $_->can('short_summary') ? $_->short_summary : {},
        };
    },
);

my $dbix = __PACKAGE__->add_type(
    name => 'DBIx',
    parent => InstanceOf['DBIx::Class::Core'],

    constraint_generator => sub {
        my $model = shift;
        assert_Str $model;
        # needs to return a coderef to use as a constraint for the
        # parameterized type
        return sub { assert InstanceOf[$model], $_ };
    },

    # probably the most complex bit
    coercion_generator => sub {
        my ( $parent_type, $child_type, $model ) = @_;
        my $schema = dbic_schema();

        require Type::Coercion;
        return Type::Coercion->new(
            type_coercion_map => [
                Num | Str, sub {
                    return $schema->resultset($model)->find($_);
                },
                $serialized_dbix, sub {
                    return $schema->resultset($model)->find($_->{id});
                },
            ],
        );
    },
);

$dbix->coercion->add_type_coercions(
    $serialized_dbix, sub {
        return dbic_schema()->resultset($_->{model})->find($_->{id});
    },
);

sub dbic_schema { die '`dbic_schema` must be overridden for DBIx coercions to work' }

=head1 AUTHOR

Robert Moore, C<< <robert at r-moore.tech> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-reactive-core at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Reactive-Core>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Reactive::Core


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Reactive-Core>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Reactive-Core>

=item * Search CPAN

L<https://metacpan.org/release/Reactive-Core>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2025 by Robert Moore.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

__PACKAGE__->make_immutable;
1;
