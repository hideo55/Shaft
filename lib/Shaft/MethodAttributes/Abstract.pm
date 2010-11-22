package Shaft::MethodAttributes::Abstract;
use strict;
use warnings;
use Shaft::MethodAttributes::Handler;

sub UNIVERSAL::Abstract : METHOD_ATTR {
	my ( $pkg, $symbol ) = @_;
	my $method = $pkg . '::' . *{$symbol}{NAME};
	my $code = sub {
		my ( $file, $line ) = (caller)[ 1, 2 ];
		die "call to abstract method $method at $file line $line.\n";
	};
	no strict 'refs';
	no warnings 'redefine';
	*{$method} = $code;
}

1;
__END__

=head1 NAME

Shaft::MethodAttributes::Abstract

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
