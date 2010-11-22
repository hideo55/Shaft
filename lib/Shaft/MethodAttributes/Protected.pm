package Shaft::MethodAttributes::Protected;
use strict;
use warnings;
use Shaft::MethodAttributes::Handler;
use Shaft::Util qw/throw_error/;

sub UNIVERSAL::Private : METHOD_ATTR {
	my ( $package, $symbol, $referent ) = @_;
	my $method = *{$symbol}{NAME};
	no warnings 'redefine';
	*{$symbol} = sub {
		my $caller = scalar(caller);
		throw_error "$method() is a private method of $package!" 
			unless ( $package eq $caller );
		goto &$referent;
	};
}

sub UNIVERSAL::Protected : METHOD_ATTR {
	my ( $package, $symbol, $referent ) = @_;
	my $method = *{$symbol}{NAME};
	no warnings 'redefine';
	*{$symbol} = sub {
		my $caller = scalar(caller);
		throw_error "$method() is a protected method of $package!" 
			unless ( $caller->isa($package) );
		goto &$referent;
	};
}

sub UNIVERSAL::Public : METHOD_ATTR {

	# NOP
}

1;
__END__

=head1 NAME

Shaft::MethodAttributes::AccessModifier

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
