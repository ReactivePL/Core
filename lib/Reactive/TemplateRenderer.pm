package Reactive::TemplateRenderer;

use warnings;
use strict;

use Moo;
use namespace::clean;
use Types::Standard qw(InstanceOf);

use Reactive::JSONRenderer;

has json_renderer => (is => 'lazy', isa => InstanceOf['Reactive::JSONRenderer']);

sub render {
    my $self = shift;
    my $template = shift;
    my %paramters = @_;

    die "Method `->render(\$template, \%args)` must be overridden in subclass. $self";
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
    return ReactivePL::JSONRenderer->new();
}

1;
