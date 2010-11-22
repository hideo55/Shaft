package Shaft::Meta::Method::Constructor;
use strict;
use warnings;
use Shaft::Meta::Method::Generated;
our @ISA = qw(Shaft::Meta::Method::Generated);

sub generate_inlined_constructor {
	my ( $class, $meta ) = @_;
	my $code = $class->SUPER::generate_inlined_constructor($meta);
	return $class->wrap(
		$code,
		package_name => $meta->name,
		name         => 'new'
	);
}

sub _generate_process_attributes {
	shift;
	my ( $meta, $instance_slot_gen, $attrs ) = @_;

	my @process_attrs;
	my $has_trigger;
	
	for my $i ( 0 .. @$attrs -1 ) {
		my $attr = $attrs->[$i];
		my $instance_slot
			= $instance_slot_gen->( $attr->associated_class->name, $attr->name );
		my $attr_slot = "\$attrs[$i]";
		my $check_slot = "\$checks[$i]";
		my $key = $attr->name;
		my $has_type_constraint = $attr->has_type_constraint;
		
		my $code;

		if ( defined $attr->init_arg ) {
			my $from = $attr->init_arg;
			$code .= "if ( exists \$args->{'$from'}){\n";

			if ( $has_type_constraint && $attr->should_coerce ) {
				$code
					.= "my \$value = ${attr_slot}->type_constraint->coerce(\$args->{'$from'});\n";

			}
			else {
				$code .= "my \$value = \$args->{'$from'};\n";
			}

			if ($has_type_constraint) {
				$code .= <<"__CODE__"
${check_slot}->(\$value) or ${attr_slot}->verify_type_constraint_error('$key',\$value,${attr_slot}->type_constraint);
__CODE__

			}

			$code .= "$instance_slot = \$value;\n";

			if ( $attr->is_weak_ref ) {
				$code
					.= "Scalar::Util::weaken($instance_slot) if ref(\$value);\n";
			}

			if ( $attr->has_trigger ) {
				$has_trigger++;
				$code
					.= "push \@triggers, [${attr_slot}->trigger, \$value ];";
			}

			$code .= "\n} else {\n";

		}

		if ( $attr->has_default || $attr->has_builder ) {
			unless ( $attr->is_lazy ) {
				my $default = $attr->default;
				my $builder = $attr->builder;

				$code .= "my \$value = ";
				if (  $has_type_constraint && $attr->should_coerce ) {
					$code
						.= "${attr_slot}->type_constraint->coerce(";
				}
				
				
				if ( $attr->has_default ){
					$code .= "${attr_slot}->default(\$self)";
				} 
				else {
					$code
						.= "${attr_slot}->_call_builder(\$self)";
				}

				if ( $attr->should_coerce ) {
					$code .= ");\n";
				}
				else {
					$code .= ";\n";
				}

				if ($has_type_constraint ) {
					$code
						.= "${check_slot}->(\$value) or 	${attr_slot}->verify_type_constraint_error('$key',\$value,${attr_slot}->type_constraint);";
				}

				$code .= "$instance_slot = \$value;\n";

				if ( $attr->is_weak_ref ) {
					$code
						.= "Scalar::Util::weaken($instance_slot) if ref( \$value );\n";
				}

			}
		}
		elsif ( $attr->is_required ) {
			$code
				.= "throw_error('Attribute ($key) is required');\n";
		}

		$code .= "}\n" if defined $attr->init_arg;

		push @process_attrs, $code if defined $code;
	}


	if ($has_trigger) {
		unshift @process_attrs, 'my @triggers;';
		push @process_attrs,
			q{ $_->[0]->($self, $_->[1]) for (@triggers); };
	}
	return join "\n", @process_attrs;
}

1;
__END__

=head1 NAME

Shaft::Meta::Method::Constructor

=head1 METHODS

=over 4

=item generate_inlined_constructor

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
