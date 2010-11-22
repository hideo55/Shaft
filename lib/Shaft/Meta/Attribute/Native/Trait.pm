package Shaft::Meta::Attribute::Native::Trait;
use Shaft::Role;
use Shaft::Util::TypeConstraints;
use Scalar::Util qw/blessed/;

Public method_constructors => (
	is      => 'ro',
	isa     => 'HashRef',
	lazy    => 1,
	default => sub {
		my $self = shift;
		return +{} unless $self->has_method_provider;
		my $method_provider = $self->method_provider->meta;
		return +{ map { $_ => $method_provider->get_method_body($_) }
				$method_provider->get_method_list };
	}
);

before '_process_options' => sub {
	my ( $self, $name, $options ) = @_;

	my $type = $self->_helper_type;

	$self->_check_helper_type( $options, $name );

	$options->{is} = $self->_default_is
		if !exists $options->{is} && $self->can('_default_is');

	$options->{default} = $self->_default_default
		if !exists $options->{default} && $self->can('_default_default');

};

sub _check_helper_type {
	my ( $self, $options, $name ) = @_;

	my $type = $self->_helper_type;

	$options->{isa} = $type
		unless exists $options->{isa};

	my $isa = Shaft::Util::TypeConstraints::find_or_create_type_constraint(
		$options->{isa} );

	( $isa->is_a_type_of($type) )
		|| throw_error
		"The type constraint for $name must be a subtype of $type but it's a $isa";
}

around '_canonicalize_handles' => sub {
	my $next    = shift;
	my $self    = shift;
	my $handles = $self->handles;
	
	return unless $handles;
	
	unless ( 'HASH' eq ref($handles) ) {
		throw_error(
			"The 'handles' option for attribute(" . $self->name . ") must be a HASH reference, not " . ( $handles || 'undef' ));
	}

	return map {
		my $to = $handles->{$_};
		$to = [$to] unless ref $to;
		$_ => $to
	} keys %$handles;
};

before 'install_accessors' => sub { (shift)->_check_handles_values };

sub _check_handles_values {
	my $self = shift;

	my $method_constructors = $self->method_constructors;

	my %handles = $self->_canonicalize_handles;

	for my $original_method ( values %handles ) {
		my $name = $original_method->[0];
		( exists $method_constructors->{$name} )
			|| throw_error "$name is an unsupported method type";
	}

}

around '_make_delegation_method' => sub {
	my $next = shift;
	my ( $self, $handle_name, $method_to_call ) = @_;

	my ( $name, @curried_args ) = @$method_to_call;

	my $method_constructor = $self->method_constructors->{$name};
	
	my $code = $method_constructor->( $self, $self->reader, $self->writer );

	return $next->(
		$self,
		$handle_name,
		sub {
			my $instance = shift;
			return $code->( $instance, @curried_args, @_ );
		},
	);

};

sub make_eval_closure {
	my ( $attr, $codepart ) = @_;
	my $class = $attr->associated_class->name;
	my $code  = <<"__CODE__";
package $class;
$codepart
__CODE__
	local $@;
	my $coderef = eval $code;    ## no critic
	warn $code if $@;
	return $coderef;
}

no Shaft::Role;
1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native::Trait;

=head1 METHODS

=over 4

=item make_eval_closure

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
