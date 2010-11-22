package Shaft::Meta::Attribute::Native::Trait::Code;
use Shaft::Role;
use Shaft::Meta::Attribute::Native::MethodProvider::Code;

with 'Shaft::Meta::Attribute::Native::Trait';

Public method_provider => (
	is => 'ro',
	isa => 'ClassName',
	predicate => 'has_method_provider',
	default => 'Shaft::Meta::Attribute::Native::MethodProvider::Code'
);

sub _helper_type { 'CodeRef' }

no Shaft::Role;
1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native::Trait::Code

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut