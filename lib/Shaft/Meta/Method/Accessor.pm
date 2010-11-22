package Shaft::Meta::Method::Accessor;
use strict;
use warnings;
use Shaft::Meta::Method::Generated;
use Scalar::Util qw(blessed weaken);
use Shaft::Util qw(throw_error throw_warn);

our @ISA = qw(Shaft::Meta::Method::Generated);

sub new {
	goto &wrap;
}

sub generate_accessors {
	my ( $class, $attr ) = @_;
	my $meta      = $attr->associated_class;
	my $accessors = $class->SUPER::generate_accessors($attr);
	for my $name ( keys %$accessors ) {
		my $method = $class->wrap(
			$accessors->{$name},
			package_name => $meta->name,
			name         => $name,
			attribute    => $attr,
		);
		$meta->add_method( $name => $method );
		$attr->associate_method($method);
	}
}

sub _generate_accessors {
	shift;
	my ( $attribute, $instance_slot ) = @_;

	my %accessors;

	my $class = $attribute->associated_class->name;
	my $name  = $attribute->name;

	my $self  = '$_[0]';
	my $value = '$_[1]';

	if ( $attribute->is_ro
		|| ( $attribute->reader ne $attribute->writer ) )
	{
		$accessors{ $attribute->reader }
				= _generate_reader( $attribute, $instance_slot );

		if ( $attribute->has_writer ) {
			$accessors{ $attribute->writer }
				= _generate_writer( $attribute, $instance_slot );
		}
	}
	else {
		$accessors{ $attribute->reader }
			= _generate_accessor( $attribute, $instance_slot );
	}

	#clearer
	if ( $attribute->has_clearer ) {
		my $clearer = $attribute->clearer;
		$accessors{$clearer}
			= _generate_clearer( $attribute, $instance_slot );
	}

	#predicate
	if ( $attribute->has_predicate ) {
		my $predicate = $attribute->predicate;
		$accessors{$predicate}
			= _generate_predicate( $attribute, $instance_slot );
	}

	#reseter
	if ( $attribute->has_reseter ) {
		$accessors{ $attribute->reseter }
			= _generate_reseter( $attribute, $instance_slot );
	}

	return \%accessors;
}

sub _generate_writer {
	my ( $attribute, $instance_slot ) = @_;

	my $class         = $attribute->associated_class->name;
	my $name          = $attribute->name;
	my $default       = $attribute->default;
	my $builder       = $attribute->builder;
	my $is_weak       = $attribute->is_weak_ref;
	my $trigger       = $attribute->trigger;
	my $should_deref  = $attribute->should_auto_deref;
	my $constraint    = $attribute->type_constraint;
	my $should_coerce = $attribute->should_coerce;
	my $accessor_name = $attribute->reader;
	my $reader_name   = $attribute->reader;
	my $writer_name   = $attribute->writer;

	my $compiled_type_constraint
		= $constraint ? $constraint->_compiled_type_constraint : undef;

	my $self  = '$_[0]';
	my $value = '$_[1]';

	my $writer = <<"__CODE__";
sub{
__CODE__

	if ( $attribute->is_private ) {
		$writer .= <<"__CODE__";
	unless ( caller eq '$class' ) {
		throw_error(\"$writer_name() is a private method of $class\");
	}
__CODE__

	}
	elsif ( $attribute->is_protected ) {
		$writer .= <<"__CODE__";
	unless ( caller->isa('$class') ) {
		throw_error(\"$writer_name() is a protected method of $class\");
	}
__CODE__
	}

	$writer .= <<"__CODE__";
	return if( \@_ < 2);
__CODE__

	if ($should_coerce) {
		$writer .= <<"__CODE__";
		my \$val = \$constraint->coerce($value);
__CODE__

		$value = '$val';
	}

	if ($compiled_type_constraint) {
		$writer .= <<"__CODE__";
		unless(\$compiled_type_constraint->($value)){
			\$attribute->verify_type_constraint_error('$name',$value,\$constraint);
		}
__CODE__

	}

	$writer
		.= "\t${instance_slot} = $value;\n";

	if ($is_weak) {
		$writer
			.= "\tScalar::Util::weaken(${instance_slot}) if ref(${instance_slot});\n";
	}

	if ($trigger) {
		$writer .= "\t\$trigger->($self,$value);\n";
	}

	$writer .= <<"__CODE__";
	1;
};
__CODE__

	return $writer;
}

sub _generate_reader {
	my ( $attribute, $instance_slot ) = @_;

	my $class         = $attribute->associated_class->name;
	my $name          = $attribute->name;
	my $default       = $attribute->default;
	my $builder       = $attribute->builder;
	my $is_weak       = $attribute->is_weak_ref;
	my $trigger       = $attribute->trigger;
	my $should_deref  = $attribute->should_auto_deref;
	my $constraint    = $attribute->type_constraint;
	my $should_coerce = $attribute->should_coerce;
	my $reader_name   = $attribute->reader;

	my $compiled_type_constraint
		= $constraint
		? $constraint->_compiled_type_constraint
		: undef;

	my $self  = '$_[0]';
	my $value = '$_[1]';

	my $reader = <<"__CODE__";
sub{
__CODE__

	if ( $attribute->is_private ) {
		$reader .= <<"__CODE__";
	unless ( caller eq '$class' ) {
		throw_error(\"$reader_name() is a private method of $class\");
	}
__CODE__

	}
	elsif ( $attribute->is_protected ) {
		$reader .= <<"__CODE__";
	unless ( caller->isa('$class') ) {
		throw_error(\"$reader_name() is a protected method of $class\");
	}
__CODE__

	}

	$reader .= <<"__CODE__";
	throw_error(\"Can't modify read-only attribute ($name).\") if \@_ >= 2;
__CODE__
	$reader .= <<"__CODE__";
	my \$id = \${$self};
__CODE__

	if ( $attribute->is_lazy ) {
		$reader
			.= "\tif( ! exists ${instance_slot}){\n";

		if ( $attribute->has_default ) {
			$reader .= "\t\tmy \$value = \$attribute->default($self);\n";
		}
		else{
			$reader
				.= "\t\tmy \$value = \$attribute->_call_builder($self);\n";
		}

		if ($should_coerce) {
			$reader .= <<"__CODE__";
		\$value = \$constraint->coerce(\$value);
__CODE__
		}

		if ($compiled_type_constraint) {
			$reader .= <<"__CODE__";
		unless(\$compiled_type_constraint->(\$value)){
			\$attribute->verify_type_constraint_error('$name',\$value,\$constraint);
		}
__CODE__

		}

		$reader .= <<"__CODE__";
		${instance_slot} = \$value;
	}
__CODE__

	}

	if ($should_deref) {
		if ( $constraint->name =~ /^ArrayRef/ ) {
			$reader .= <<"__CODE__";
	if(wantarray){
		return \@{ ${instance_slot} };
	}
__CODE__

		}
		else {
			$reader .= <<"__CODE__";
	if(wantarray){
		return \%{ ${instance_slot} };
	}
__CODE__

		}
	}

	$reader .= <<"__CODE__";
	return ${instance_slot};
};
__CODE__
	return $reader;
}

sub _generate_accessor {
	my ( $attribute, $instance_slot ) = @_;

	my $class         = $attribute->associated_class->name;
	my $name          = $attribute->name;
	my $default       = $attribute->default;
	my $builder       = $attribute->builder;
	my $is_weak       = $attribute->is_weak_ref;
	my $trigger       = $attribute->trigger;
	my $should_deref  = $attribute->should_auto_deref;
	my $constraint    = $attribute->type_constraint;
	my $should_coerce = $attribute->should_coerce;
	my $accessor_name = $attribute->reader;

	my $compiled_type_constraint
		= $constraint
		? $constraint->_compiled_type_constraint
		: undef;

	my $self  = '$_[0]';
	my $value = '$_[1]';

	my $accessor = <<"__CODE__";
sub{
__CODE__

	if ( $attribute->is_private ) {
		$accessor .= <<"__CODE__";
	unless ( caller eq '$class' ) {
		throw_error(\"$accessor_name() is a private method of $class\");
	}
__CODE__

	}
	elsif ( $attribute->is_protected ) {
		$accessor .= <<"__CODE__";
	unless ( caller->isa('$class') ) {
		throw_error(\"$accessor_name() is a protected method of $class\");
	}
__CODE__

	}

	$accessor .= <<"__CODE__";
	if( \@_ >= 2 ){
__CODE__

	if ($should_coerce) {
		$accessor .= <<"__CODE__";
	my \$val =\$constraint->coerce($value);
__CODE__

		$value = '$val';

	}

	if ($compiled_type_constraint) {
		$accessor .= <<"__CODE__";
	unless(\$compiled_type_constraint->($value)){
		\$attribute->verify_type_constraint_error('$name',$value,\$constraint);
	}
__CODE__

	}

	if ( !$is_weak && !$trigger && !$should_deref ) {
		$accessor .= <<"__CODE__";
	return ${instance_slot} = $value;
__CODE__

	}
	else {
		$accessor .= <<"__CODE__";
	${instance_slot} = $value;
__CODE__
		if ($is_weak) {
			$accessor .= <<"__CODE__";
	Scalar::Util::weaken(${instance_slot}) if ref(${instance_slot});
__CODE__
		}

		if ($trigger) {
			$accessor .= <<"__CODE__";
	\$trigger->($self,$value);
__CODE__

		}
	}

	$accessor .= <<"__CODE__";
	}
__CODE__


	if ( $attribute->is_lazy ) {
		$accessor .= <<"__CODE__";
	if( ! exists ${instance_slot} ){
__CODE__

		if ( $attribute->has_default ) {
			$accessor .= <<"__CODE__";
		my \$value = \$attribute->default($self);
__CODE__

		}
		else {
			$accessor .= <<"__CODE__";
		my \$value = \$attribute->_call_builder($self);
__CODE__

		}

		if ($should_coerce) {
			$accessor .= <<"__CODE__";
		\$value = \$constraint->coerce(\$value);
__CODE__
		}

		if ($compiled_type_constraint) {
			$accessor .= <<"__CODE__";
		unless(\$compiled_type_constraint->(\$value)){
			\$attribute->verify_type_constraint_error('$name',\$value,\$constraint);
		}
__CODE__

		}

		$accessor .= <<"__CODE__";
		${instance_slot} = \$value;
	}
__CODE__

	}

	if ($should_deref) {
		if ( $constraint->name =~ /^ArrayRef/ ) {
			$accessor .= <<"__CODE__";
	if(wantarray){
		return \@{ ${instance_slot} || [] };
	}
__CODE__

		}
		else {
			$accessor .= <<"__CODE__";
	if(wantarray){
		return \%{ ${instance_slot} || {} };
	}
__CODE__

		}
	}

	$accessor .= <<"__CODE__";
	return ${instance_slot};
};
__CODE__

	return $accessor;

}

sub _generate_clearer {
	my ( $attribute, $instance_slot ) = @_;
	my $class   = $attribute->associated_class->name;
	my $name    = $attribute->name;
	my $clearer = $attribute->clearer;

	my $code = <<"__CODE__";
sub{
__CODE__

	if ( $attribute->is_private ) {
		$code
			.= "throw_error \"$clearer() is private method of $class\" unless caller eq '$class';\n";
	}
	elsif ( $attribute->is_protected ) {
		$code
			.= "throw_error \"$clearer() is protected method of $class\" unless caller->isa('$class');\n";
	}
	
	$code .= "delete ${instance_slot};}";

	return $code;
}

sub _generate_predicate {
	my ( $attribute, $instance_slot ) = @_;
	my $class     = $attribute->associated_class->name;
	my $name      = $attribute->name;
	my $predicate = $attribute->predicate;

	my $code = <<"__CODE__";
sub{
__CODE__

	if ( $attribute->is_private ) {
		$code
			.= "throw_error \"$predicate() is private method of $class\" unless caller eq '$class';\n";
	}
	elsif ( $attribute->is_protected ) {
		$code
			.= "throw_error \"$predicate() is protected method of $class\" unless caller->isa('$class');\n";
	}
	$code
		.= "exists( ${instance_slot} );}";
}

sub _generate_reseter {
	my ( $attribute, $instance_slot ) = @_;

	my $class         = $attribute->associated_class->name;
	my $name          = $attribute->name;
	my $default       = $attribute->default;
	my $builder       = $attribute->builder;
	my $is_weak       = $attribute->is_weak_ref;
	my $trigger       = $attribute->trigger;
	my $should_deref  = $attribute->should_auto_deref;
	my $constraint    = $attribute->type_constraint;
	my $should_coerce = $attribute->should_coerce;

	my $reseter = $attribute->reseter;

	my $compiled_type_constraint
		= $constraint ? $constraint->_compiled_type_constraint : undef;

	my $self = '$_[0]';

	my $reseter_code .= <<"__CODE__";
sub{
__CODE__

	if ( $attribute->is_private ) {
		$reseter_code
			.= "throw_error \"$reseter() is private method of $class\" unless caller eq '$class';";
	}
	elsif ( $attribute->is_protected ) {
		$reseter_code
			.= "throw_error \"$reseter() is protected method of $class\" unless caller->isa('$class');";
	}

	if ( $attribute->has_default ){
		$reseter_code .= 'my $value = $attribute->default($_[0]);';
	}
	else {
		$reseter_code .= 'my $value = $attribute->_call_builder($_[0]);';
	}

	if ( $attribute->should_coerce ) {
		$reseter_code .= <<"__CODE__";
				my \$val = \$constraint->coerce(\$value);
				\$value = \$val;
__CODE__
	}

	if ($compiled_type_constraint) {
		$reseter_code .= <<"__CODE__";
		unless(\$compiled_type_constraint->(\$value)){
			\$attribute->verify_type_constraint_error('$name',\$value,\$constraint);
		}
__CODE__
	}

	$reseter_code
		.= "${instance_slot} = \$value;1;};";

	return $reseter_code;
}

{
	my %_meta;

	sub wrap {
		my ( $class, $code, %params ) = @_;

		( exists $params{attribute} )
			|| throw_error "You must supply an attribute to construct with";

		( blessed( $params{attribute} )
				&& $params{attribute}->isa('Shaft::Meta::Attribute') )
			|| throw_error
			"You must supply an attribute which is a 'Shaft::Meta::Attribute'";

		my $method = $class->next::method(
			$code,
			package_name => $params{package_name},
			name         => $params{name},
		);

		$_meta{$$method} = { attribute => $params{attribute}, };
		weaken( $_meta{$$method}{attribute} );

		return $method;
	}

	sub associated_attribute {
		return $_meta{ ${ $_[0] } }{attribute};
	}

	sub clone {
		my $self  = shift;
		my $clone = $self->next::method(@_);
		$_meta{$$clone} = $_meta{$$self};
		return $clone;
	}

	sub DEMOLISH {
		return if $_[1];
		delete $_meta{ ${ $_[0] } };
	}
}
1;
__END__

=head1 NAME

Shaft::Meta::Method::Accessor - 

=head1 METHODS

=over 4

=item new

=item associated_attribute

=item clone

=item generate_accessors

=item wrap

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
