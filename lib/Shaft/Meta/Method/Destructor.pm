package Shaft::Meta::Method::Destructor;
use strict;
use warnings;
use Shaft::Meta::Method::Generated;
our @ISA = qw(Shaft::Meta::Method::Generated);

sub generate_inlined_destructor {
	my ( $class, $meta ) = @_;
	my $code = $class->SUPER::generate_inlined_destructor($meta);
	$class->wrap(
		$code,
		package_name => $meta->name,
		name         => 'DESTORY'
	);
}

1;
__END__

=head1 NAME

Shaft::Meta::Method::Destructor

=head1 METHODS

=over 4

=item generate_inlined_destructor

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
