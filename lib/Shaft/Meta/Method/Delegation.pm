package Shaft::Meta::Method::Delegation;
use strict;
use warnings;
use Shaft::Meta::Method::Generated;
use Scalar::Util qw(blessed weaken);
use Shaft::Util qw(throw_error throw_warn);

our @ISA = qw(Shaft::Meta::Method::Generated);

sub new {
	goto &wrap;
}

sub _initialize_body {
	my $params = shift;

	my $method_to_call = $params->{delegate_to_method};

	return $method_to_call if ref $method_to_call;

	my $attribute = $params->{attribute};

	my $meta     = $attribute->associated_class;
	my $package  = $meta->name;
	my $accessor = $attribute->reader;

	my $curried = '';
	my @curried_argments =  @{ $params->{curried_argments} || [] };
	if( @curried_argments > 0 ){
		$curried = 'unshift @_,@curried_argments;';
	}

	my $code = <<"__CODE__";
package $package;
sub {
	my \$instance = shift;
	$curried
	return \$instance->$accessor->$method_to_call(\@_);
};
__CODE__

	my $coderef = eval $code;
	
	return $coderef;
}


{
	my %_meta;

	sub wrap {
		my ( $class, %params ) = @_;

		( exists $params{attribute} )
			|| throw_error "You must supply an attribute to construct with";

		( blessed( $params{attribute} )
				&& $params{attribute}->isa('Shaft::Meta::Attribute') )
			|| throw_error("You must supply an attribute which is a 'Shaft::Meta::Attribute'");

		( $params{delegate_to_method} && ( !ref $params{delegate_to_method} )
				|| ( 'CODE' eq ref $params{delegate_to_method} ) )
			|| throw_error('You must supply a delegate_to_method which is a method name or a CODE reference');

		( !defined($params{curried_argments} ) )
				|| ( 'ARRAY' eq ref $params{curried_argments} )
			|| throw_error('You must supply a curried_arguments which is an ARRAY reference');

		my $code = _initialize_body( \%params );

		my $method = $class->SUPER::wrap(
			$code,
			package_name => $params{package_name},
			name         => $params{name},
		);

		$_meta{$$method} = \%params;
		weaken( $_meta{$$method}{attribute} );

		return $method;
	}

	sub associated_attribute {
		return $_meta{ ${ $_[0] } }{attribute};
	}

	sub clone {
		my $self  = shift;
		my $clone = $self->SUPER::clone(@_);
		$_meta{$$clone} = $_meta{$$self};
		return $clone;
	}

	sub DEMOLISH {
		return if $_[1];
		delete $_meta{ ${ $_[0] } };
	}

	sub delegate_to_method {
		return $_meta{ ${ $_[0] } }{delegate_to_method};
	}
}


1;
__END__

=head1 NAME

Shaft::Meta::Method::Delegation - 

=head1 METHODS

=over 4

=item new

=item associated_attribute

=item clone

=item wrap

=item delegate_to_method

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
