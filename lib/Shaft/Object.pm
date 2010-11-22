package Shaft::Object;
use strict;
use warnings;

use Scalar::Util qw/blessed refaddr/;
use Data::Util qw/get_code_ref anon_scalar :check/;
use Clone ();
use Shaft::Util qw/:meta throw_error throw_warn find_meta/;
use Devel::GlobalDestruction ();

{

	my %_objects;
	my %_methods;
	my %_hooks;

	sub rebless {
		my $self  = shift;
		my $class = shift;
		Internals::SvREADONLY( $$self, 0 );
		bless $self, $class;
		Internals::SvREADONLY( $$self, 1 );
	}

	sub new_object {
		my $class = shift;
		my $args  = shift;

		my $self = bless anon_scalar(), $class;
		$$self = $self + 0;
		Internals::SvREADONLY( $$self, 1 );

		my $id = $$self;

		$_objects{$id} = {};
		$_methods{$id} = {};
		$_hooks{$id}   = { '__MAP__' => {} };

		my @triggers;
		my $has_trigger = 0;

		for my $super ( reverse @{ mro::get_linear_isa($class) } ) {

			$_objects{$id}{$super} = {};
			my $object = {};

			my $meta = Shaft::Util::get_metaclass_by_name($super)
				or next;

			for my $attr ( map{ $meta->get_attribute($_) } $meta->get_attribute_list ) {
				my $attr_name = $attr->name;
				my $init_arg  = $attr->init_arg;

				my $compiled_type_constraint
					= $attr->type_constraint
					? $attr->type_constraint->_compiled_type_constraint
					: undef;

				my $value;

				if ( defined($init_arg) && exists $args->{$init_arg} ) {
					if ( $attr->has_type_constraint && $attr->should_coerce )
					{
						$value = $attr->type_constraint->coerce(
							$args->{$init_arg} );
					}
					else {
						$value = $args->{$init_arg};
					}

					if ( $compiled_type_constraint
						&& !( $compiled_type_constraint->($value) ) )
					{
						$attr->verify_type_constraint_error( $attr_name,
							$value, $attr->type_constraint );
					}

					$object->{$attr_name} = $value;

					if ( $attr->is_weak_ref ) {
						Scalar::Util::weaken( $object->{$attr_name} )
							if ref($value);
					}

					if ( $attr->has_trigger ) {
						$has_trigger++;
						push @triggers, [ $attr->trigger, $value ];
					}

				}
				elsif ( $attr->has_default || $attr->has_builder ) {
					unless ( $attr->is_lazy ) {
						my $def_val;
						if ( $attr->has_default ){
							$def_val = $attr->default($self);
						}
						else {
							$def_val = $attr->_call_builder($self);
						}

						if (   $attr->has_type_constraint
							&& $attr->should_coerce )
						{
							$value = $attr->type_constraint->coerce($def_val);
						}
						else {
							$value = $def_val;
						}

						if ( $compiled_type_constraint
							&& !( $compiled_type_constraint->($value) ) )
						{
							$attr->verify_type_constraint_error( $attr_name,
								$value, $attr->type_constraint );
						}

						$object->{$attr_name} = $value;

						if ( $attr->is_weak_ref ) {
							Scalar::Util::weaken( $object->{$attr_name} )
								if ref($value);
						}

					}
				}
				elsif ( $attr->is_required ) {
					throw_error("Attribute ($attr_name) is required");
				}

			}

			$_objects{$id}{$super} = $object;

		}

		if ($has_trigger) {
			for my $trigger (@triggers) {
				$trigger->[0]->( $self, $trigger->[1] );
			}
		}

		return $self;
	}

	sub new {
		my $invocant = shift;
		my $class = ref($invocant) || $invocant;
		return unless $class;
		my $args = $class->BUILDARGS(@_);
		my $self = $class->new_object($args);
		$self->BUILDALL($args);
		return $self;
	}

	sub BUILDARGS {
		my ( $class, @args ) = @_;
		my $args = do {
			if ( @args == 1 ) {
				if ( defined( $args[0] ) && ref( $args[0] ) eq 'HASH' ) {
					+{ %{ $args[0] } };
				}
				else {
					throw_error(
						"Single argment to new() must be HASH reference");
				}
			}
			else {
				+{@args};
			}
		};
		return $args;
	}

	sub BUILDALL {
		my $self  = shift;
		my $class = blessed $self;
		for my $super ( reverse @{ mro::get_linear_isa($class) } ) {
			my $build = get_code_ref( $super, 'BUILD' );
			if ( defined $build ) {
				$build->( $self, @_ );
			}
		}
	}

	sub _generate_BUILDARGS {
		shift;
		my $meta = shift;
		if ($meta->name->can('BUILDARGS')
			!= Shaft::Object->can('BUILDARGS')
			)
		{
			return 'my $args = $class->BUILDARGS(@_);';
		}
		else {
			return <<'__CODE__';
my $args;
if( scalar(@_) == 1 ){
	( ref( $_[0] ) eq 'HASH' ) || throw_error("Single argment to new() must be HASH reference");
	$args = +{ %{ $_[0] } };
}else{
	$args = +{@_};
}
__CODE__

		}
	}

	sub _generate_BUILDALL {
		shift;
		my $meta = shift;
		if ( $meta->name->can('BUILD') ) {
			my @code = ();
			for my $base ( reverse $meta->linearized_isa ) {
				if ( get_code_ref( $base, 'BUILD' ) ) {
					push @code, "${base}::BUILD(\$self,\$args);";
				}
			}
			return join "\n", @code;
		}
		else {
			return q{};
		}
	}

	sub _generate_instance {
		my ( $self, $var, $class_var ) = @_;
		return <<"__CODE__";
	my $var = bless Data::Util::anon_scalar(), $class_var;
	\$$var = refaddr $var;
	Internals::SvREADONLY( \$$var, 1 );
__CODE__
	}

	sub generate_inlined_constructor {
		my ( $invocant, $meta ) = @_;

		my $class = $meta->name;

		my $buildargs = $invocant->_generate_BUILDARGS($meta);

		my $gen_instance = $invocant->_generate_instance( '$self', '$class' );

		my %attrs;
		my %compiled_type_constraint;
		my @init_base;
		my @process_attrs;
		my $has_trigger = 0;
		

		for my $base ( reverse $meta->linearized_isa ) {
			my $base_meta = Shaft::Util::get_metaclass_by_name($base)
				or next;
			push @init_base, "\$object->{'$base'} = {};";
		}

		my @attrs = $meta->get_all_attributes;
		my @checks
			= map { $_ ? $_->_compiled_type_constraint : undef }
			map { $_->type_constraint } @attrs;
		my $generate_instance_slot = sub {
			my ( $base, $attr_name ) = @_;
			return "\$object->{'$base'}{'$attr_name'}";
		};
		
		my $init_base = join "\n", @init_base;
		my $process_attrs = $invocant->_generate_process_attributes( $meta,
			$generate_instance_slot, \@attrs );
		my $buildall = $invocant->_generate_BUILDALL($meta);
		my $objects  = \%_objects;
		my $methods  = \%_methods;
		my $hooks    = \%_hooks;

		my $src = <<"__CODE__";
sub{
	my \$invocant = shift;
	my \$class = ref(\$invocant)|| \$invocant;
	return unless \$class;
	return \$class->Shaft::Object::new(\@_) if \$class ne '$class';
	$buildargs
	$gen_instance
	my \$id = \$\$self;
	my \$object = {};
	\$objects->{\$id} = \$object;
	\$methods->{\$id} = {};
	\$hooks->{\$id} = { '__MAP__' => {} };
	$init_base
	$process_attrs
	$buildall
	return \$self;
};
__CODE__

		$src = qq{#line 0 "generated method"\n} . $src;
		my $code = eval $src;
		throw_error $@ if $@;

		return $code;
	}

	sub DESTROY {
		my $self = shift;

		my @isa;
		if ( my $meta = find_meta($self) ) {
			@isa = $meta->linearized_isa;
		}
		else {
			@isa = @{ mro::get_linear_isa( ref $self ) };
		}
		
		my $igd = Devel::GlobalDestruction::in_global_destruction();

		for my $class (@isa) {
			if ( my $demolish = get_code_ref( $class, 'DEMOLISH' ) ) {
				$demolish->($self,$igd);
			}
		}
		return if $igd;
		my $id = $$self;
		delete $_objects{$id};
		delete $_methods{$id};
		delete $_hooks{$id};
	}

	sub generate_inlined_destructor {
		my ( undef, $meta ) = @_;

		my $demolishall = do {
			if ( $meta->name->can('DEMOLISH') ) {
				my @code = ();
				for my $base ( $meta->linearized_isa ) {
					if ( get_code_ref( $base, 'DEMOLISH' ) ) {
						push @code, "${base}::DEMOLISH(\$self,\$igd);";
					}
				}
				join "\n", @code;

			}
			else {
				q{};
			}
		};

		my $objects = \%_objects;
		my $methods = \%_methods;
		my $hooks   = \%_hooks;

		my $src = <<"__CODE__";
sub {
	my \$self = shift;
	my \$igd = Devel::GlobalDestruction::in_global_destruction();
	$demolishall
	my \$id = \$\$self;
	return if \$igd;
	delete \$objects->{\$id};
	delete \$methods->{\$id};
	delete \$hooks->{\$id};
};
__CODE__

		$src = qq{#line 0 "generated method"\n} . $src;
		my $code = eval $src;
		throw_error $@ if $@;

		return $code;
	}

	sub clone {
		my $self  = shift;
		my $class = blessed $self;
		unless ($class) {
			throw_error("clone() is instance method.");
		}
		my $id      = $$self;
		my $data    = Clone::clone( $_objects{$id} );
		my $methods = Clone::clone( $_methods{$id} );
		my $hooks   = Clone::clone( $_hooks{$id} );
		my $clone   = bless anon_scalar(), $class;
		$$clone = refaddr $clone;
		Internals::SvREADONLY( $$clone, 1 );
		$id            = $$clone;
		$_objects{$id} = $data;
		$_methods{$id} = $methods;
		$_hooks{$id}   = $hooks;

		return $clone;
	}

	sub _dump {
		my $self = shift;
		require Data::Dumper;
		no warnings 'once';
		my $name = ref($self);
		local $Data::Dumper::Indent   = 1;
		local $Data::Dumper::Terse    = 1;
		local $Data::Dumper::Sortkeys = 1;
		local $Data::Dumper::Deparse  = 1;
		return Data::Dumper::Dumper( { $name => $_objects{$$self} } );
	}

	sub _serialize {
		my $self = shift;
		require Storable;
		my $data = {
			data   => $_objects{$$self},
			hook   => $_hooks{$$self},
			method => $_methods{$$self},
		};
		return Storable::nfreeze($data);
	}

	sub _deserialize {
		my ( $self, $data ) = @_;
		return unless $data;
		require Storable;
		my $data_ref = Storable::thaw($data);
		return unless ( ref $data_ref eq 'HASH' );
		$_objects{$$self} = $data_ref->{data};
		$_hooks{$$self}   = $data_ref->{hook};
		$_methods{$$self} = $data_ref->{method};
	}

	sub add_singleton_method {
		my ( $self, $name, $coderef ) = @_;

		unless ( blessed $self ) {
			throw_error("add_singleton_method() is instance method.");
		}

		unless ( defined($coderef) && ref($coderef) eq 'CODE' ) {
			throw_error('$obj->add_singleton_method( name => sub{...} )');
		}

		$_methods{$$self}{$name} = $coderef;
	}

	sub remove_singleton_method {
		my ( $self, $name ) = @_;

		unless ( blessed $self ) {
			throw_error("remove_singleton_method() is instance method.");
		}

		if ( exists( $_methods{$$self}{$name} ) ) {
			delete $_methods{$$self}{$name};
		}
	}

	sub AUTOLOAD {
		my $method = our $AUTOLOAD;
		$method =~ s/.*:://o;

		my $coderef;
		if ( is_instance( $_[0], 'Shaft::Object' ) ) {
			$coderef = $_methods{ ${ $_[0] } }{$method};
		}

		if ($coderef) {
			goto &$coderef;
		}
		else {
			my $class = blessed($_[0]) || $_[0];
			for my $base_class ( @{ mro::get_linear_isa($class) } ) {
				if ( my $automethod
					= get_code_ref( $base_class, 'AUTOMETHOD' ) )
				{
					local $CALLER::_ = $_;
					local $_         = $method;
					my $automethod_entry = $automethod->(@_);
					if ( ref $automethod_entry eq 'CODE' ) {
						goto &$automethod_entry;
					}
				}
			}
			@_ = ("Can't locate object method $method via $class");
			goto &throw_error;
		}
	}

	{
		my $can_orig = \&UNIVERSAL::can;
		no warnings 'redefine', 'once';
		*UNIVERSAL::can = sub {
			my ( $invocant, $method ) = @_;
			if ( defined $invocant ) {
				if ( my $coderef = $can_orig->(@_) ) {
					return $coderef;
				}

				if ( is_instance( $invocant, 'Shaft::Object' ) ) {
					my $coderef = $_methods{$$invocant}{$method};
					return $coderef if $coderef;
				}

				my $class = ref($invocant) || $invocant;
				for my $base_class ( @{ mro::get_linear_isa($class) } ) {
					if ( my $autoload
						= get_code_ref( $base_class, 'AUTOMETHOD' ) )
					{
						local $CALLER::_ = $_;
						local $_         = $method;
						my $autoload_screw = $autoload->(@_);
						if ( ref $autoload_screw eq 'CODE' ) {
							return $autoload_screw;
						}
					}
				}
			}
			return;
		};
	}

	sub add_hook {
		my ( $self, $hook_point, $hook ) = @_;
		my $id = $$self;

		if ( ref $hook ne 'CODE' ) {
			throw_error "You must supply CODE reference as hook";
		}
		unless ( exists( $_hooks{$id}->{$hook_point} ) ) {
			$_hooks{$id}->{$hook_point} = [];
		}

		push @{ $_hooks{$id}->{$hook_point} }, $hook;
		
		return;
	}

	sub clear_hook {
		my ( $self, $hook_point ) = @_;
		delete $_hooks{$$self}{$hook_point};
	}

	sub has_hook {
		my ( $self, $hook_point ) = @_;
		return unless defined $hook_point;
		my $id = $$self;
		unless ( exists( $_hooks{$id}->{$hook_point} ) ) {
			return;
		}
		return scalar( @{ $_hooks{$id}->{$hook_point} } );
	}

	sub call_hook {
		my ( $self, $hook_point, $reverse ) = @_;

		my $caller = caller;
		unless ( $self->isa($caller) ) {
			throw_error "call_hook() is a private method of " . blessed $self;
		}

		return unless defined $hook_point;

		my $id = $$self;

		return unless exists $_hooks{$id}->{$hook_point};

		my $hooks = $_hooks{$id}->{$hook_point};
		my @result;

		for my $hook ( $reverse ? reverse @$hooks : @$hooks )
		{
			push @result, $hook->();
		}

		return @result;
	}

	sub generate_accessors {
		my ( $self, $attribute ) = @_;

		my $class      = $attribute->associated_class->name;
		my $name       = $attribute->name;
		my $default    = $attribute->default;
		my $trigger    = $attribute->trigger;
		my $constraint = $attribute->type_constraint;
		my $compiled_type_constraint
			= $constraint
			? $constraint->_compiled_type_constraint
			: undef;

		my $instance_slot
			= sprintf( q{$objects->{${$_[0]}}{'%s'}{'%s'}}, $class, $name );

		my $accessors
			= $self->_generate_accessors( $attribute, $instance_slot );
		my $objects = \%_objects;
		for my $name ( keys %$accessors ) {
			my $src = $accessors->{$name};
			$src = qq{#line 0 "generated method"\n} . $src;
			my $code = eval $src;
			throw_error $@ if $@;
			$accessors->{$name} = $code;
		}

		return $accessors;
	}

}

1;
__END__

=head1 NAME

Shaft::Object

=head1 METHODS

=over 17

=item new

=item new_object

=item rebless

=item add_hook

=item clear_hook

=item has_hook

=item call_hook

=item clone

=item DESTROY

=item AUTOLOAD

=item add_singleton_method

=item remove_singleton_method

=item meta

=item does

=item generate_inlined_constructor

=item generate_inlined_destructor

=item generate_accessors

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
