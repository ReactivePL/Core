package Reactive::Core;

use 5.006;
use strict;
use warnings;

use Moo;
use namespace::clean;
use Types::Standard qw( Str Int HashRef ArrayRef InstanceOf);
use Scalar::Util 'blessed';
use Data::Printer;

use Module::Load;
use Module::Loader;

use Reactive::Core::JSONRenderer;

use Module::Installed::Tiny qw(module_source);
use Digest::SHA qw(sha256_hex);

has secret => (is => 'ro', isa => Str);
has template_renderer => (is => 'ro', isa => InstanceOf['Reactive::TemplateRenderer']);
has component_namespaces => (is => 'ro', isa => ArrayRef[Str]);

has component_map => (is => 'lazy', isa => HashRef[Str]);
has json_renderer => (is => 'lazy', isa => InstanceOf['Reactive::Core::JSONRenderer']);

=head1 NAME

Reactive::Core - The great new Reactive::Core!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Reactive::Core;

    my $foo = Reactive::Core->new();
    ...


=head1 SUBROUTINES/METHODS

=head2 initial_render

=cut

sub initial_render {
    my $self = shift;
    my $component_name = shift;
    my %args = @_;

    my $component = $self->_initialize_component($component_name, %args);

    if ($component->can('mounted')) {
        $component->mounted();
    }

    my ($html, $snapshot) = $self->_to_snapshot($component);

    return $self->template_renderer->inject_snapshot($html, $snapshot);
}

=head2 process_request

=cut

sub process_request {
    my $self = shift;
    my $payload = shift;

    my $component = $self->_from_snapshot($payload->{snapshot});

    if (my $method = $payload->{callMethod}) {
        $self->_call_method($component, $method);
    }

    if (my $update = $payload->{updateProperty}) {
        $self->_update_property($component, @{$update});
    }

    if (my $increment = $payload->{increment}) {
        $self->_update_property(
            $component,
            $increment,
            $payload->{snapshot}{data}{$increment} + 1
        );
    }

    if (my $decrement = $payload->{decrement}) {
        $self->_update_property(
            $component,
            $decrement,
            $payload->{snapshot}{data}{$decrement} - 1
        );
    }

    if (my $unset = $payload->{unset}) {
        $self->_update_property(
            $component,
            $unset,
            undef
        );
    }

    my ($html, $snapshot) = $self->_to_snapshot($component);

    return {
        html => $html,
        snapshot => $snapshot,
    };
}

sub _initialize_component {
    my $self = shift;
    my $component_name = shift;
    my %args = @_;

    my $component_class = $self->component_map->{$component_name};

    my $component = $component_class->new(%args);

    return $component;
}

sub _get_property_names {
    my $self = shift;
    my $component = shift;

    my $component_class = $component;
    if (ref $component) {
        $component_class = blessed $component;
    }

    my @keys = keys(%{
        'Moo'->_constructor_maker_for($component_class)->all_attribute_specs
    });

    return @keys;
}

sub _get_properties {
    my $self = shift;
    my $component = shift;

    my @keys = $self->_get_property_names($component);

    my %properties = map { $_ => $component->$_ } @keys;

    return %properties;
}

sub _get_component_name {
    my $self = shift;
    my $component = shift;

    my $name = blessed $component;
    $name =~ s/.*:://gi;

    return $name;
}

sub _snapshot_data {
    my $self = shift;
    my $component = shift;

    my %properties = $self->_get_properties($component);

    return {
        component => $self->_get_component_name($component),
        data => \%properties,
    };
}

sub _from_snapshot {
    my $self = shift;
    my $snapshot = shift;

    my $checksum_from_snapshot = delete $snapshot->{checksum};
    my $checksum = $self->_generate_checksum($snapshot);

    if ($checksum_from_snapshot ne $checksum) {
        die "checksum doesnt match";
    }

    my $component = $self->_initialize_component($snapshot->{component}, %{$snapshot->{data}});

    return $component;
}

sub _to_snapshot {
    my $self = shift;
    my $component = shift;

    my %properties = $self->_get_properties($component);

    my $template = $component->render;

    my $html = $self->template_renderer->render($template, %properties, self => $component);

    my $snapshot = $self->_snapshot_data($component);
    $snapshot = $self->json_renderer->process_data($snapshot);

    $snapshot->{checksum} = $self->_generate_checksum($snapshot);

    return ($html, $snapshot);
}

sub _generate_checksum {
    my $self = shift;
    my $snapshot = shift;

    my $component_class = $self->component_map->{$snapshot->{component}};

    my $module_src_digest = sha256_hex(module_source($component_class));
    my $snapshot_digest = sha256_hex($self->json_renderer->canonical_json->encode($snapshot));
    my $secret_digest = sha256_hex($self->secret);

    return sha256_hex(sprintf '%s:%s:%s', $module_src_digest, $snapshot_digest, $secret_digest);
}

sub _call_method {
    my $self = shift;
    my $component = shift;
    my $method = shift;

    $component->$method();
}

sub _update_property {
    my $self = shift;
    my $component = shift;
    my $property = shift;
    my $value = shift;

    $component->$property($value);

    if ($component->can('updated')) {
        $component->updated($property);
    }
}

sub _build_component_map {
    my $self = shift;

    my $loader  = Module::Loader->new;
    my %result;

    foreach my $ns (@{$self->component_namespaces}) {
        foreach my $component ($loader->find_modules($ns)) {
            $loader->load($component);

            my $name = $component;
            $name =~ s/.*:://gi;

            $result{$name} = $component;
        }
    }

    return \%result;
}

sub _build_json_renderer {
    return Reactive::Core::JSONRenderer->new();
}

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

1; # End of Reactive::Core
