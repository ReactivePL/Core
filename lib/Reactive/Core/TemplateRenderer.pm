package Reactive::Core::TemplateRenderer;

use warnings;
use strict;

use Moo;
use namespace::clean;
use Types::Standard qw(InstanceOf);

use Reactive::Core::JSONRenderer;

use constant {
    RENDER_TEMPLATE_FILE => 'File',
    RENDER_TEMPLATE_INLINE => 'Inline',
};

has json_renderer => (is => 'lazy', isa => InstanceOf['Reactive::Core::JSONRenderer']);

sub render {
    my $self = shift;
    my $type = shift;
    my $template = shift;
    my %paramters = @_;

    die "Method `->render(\$type, \$template, \%args)` must be overridden in subclass. $self";
}

sub escape {
    my $self = shift;
    my $string = shift;

    die "Method `->escape(\$string)` must be overridden in subclass. $self";
}

sub inject_snapshot {
    my $self = shift;
    my $html = shift;
    my $snapshot = shift;

    return $self->inject_attribute($html, 'reactive:snapshot', $snapshot);
}

sub inject_attribute {
    my $self = shift;
    my $html = shift;
    my $attribute = shift;
    my $value = shift;

    my $escaped_value = $self->escape($self->json_renderer->render($value));

    $html =~ s/^\s*(<[a-z\-]+(?:\s[^\/>]+)*)(\s*)(\/?>)/$1 $attribute="$escaped_value" $3/m;

    return $html;
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

1;
