package Shaft::Util::TypeConstraints;
use strict;
use warnings;
use Shaft::Util qw(throw_error quoted_english_list);
use Scalar::Util qw(blessed reftype openhandle looks_like_number weaken);
use List::MoreUtils qw(uniq all);
use Data::Util qw(:check);
use Shaft::Meta::TypeConstraint;

use Shaft::Exporter -setup => {
	exports => [
		qw/as where message optimize_as from via type subtype class_type
			role_type duck_type coerce enum find_type_constraint/
	]
};

my %TYPE;
my %CONSTRAINT_CACHE = (
	Class => {},
	Role  => {},
	Enum  => {},
	Duck  => {},
);

sub as ($) {
	as => $_[0];
}

sub where (&) {
	where => $_[0];
}

sub message (&) {
	message => $_[0];
}

sub optimize_as (&) {
	optimize_as => $_[0];
}

sub from {@_}

sub via (&) { $_[0] }

BEGIN {
	no warnings 'uninitialized';
	my %optimized = (
		Any => {
			parent    => undef,
			optimized => undef,
		},
		Item => {
			parent    => 'Any',
			optimized => undef,
		},
		Undef => {
			parent    => 'Item',
			optimized => sub {
				!defined( $_[0] );
			},
		},
		Defined => {
			parent    => 'Item',
			optimized => sub {
				defined( $_[0] );
				}
		},
		Bool => {
			parent    => 'Defined',
			optimized => sub {
				!defined( $_[0] )
					|| $_[0]   eq ""
					|| "$_[0]" eq '1'
					|| "$_[0]" eq '0';
			},
		},
		Ref => {
			parent    => 'Defined',
			optimized => sub {
				ref( $_[0] );
			},
		},
		Value => {
			parent    => 'Defined',
			optimized => sub {
				is_value( $_[0] );
			},
		},
		Str => {
			parent    => 'Value',
			optimized => sub {
				defined( $_[0] ) && ref( \$_[0] ) eq 'SCALAR';
			},
		},
		Num => {
			parent    => 'Str',
			optimized => sub {
				!ref( $_[0] ) && looks_like_number( $_[0] );
			},
		},
		Int => {
			parent    => 'Num',
			optimized => sub {
				defined( $_[0] ) && !ref( $_[0] ) && $_[0] =~ /^-?[0-9]+$/;
			},
		},
		ScalarRef => {
			parent    => 'Ref',
			optimized => sub { is_scalar_ref( $_[0] ) }
		},
		ArrayRef => {
			parent    => 'Ref',
			optimized => sub { is_array_ref( $_[0] ) }
		},
		HashRef => {
			parent    => 'Ref',
			optimized => sub { is_hash_ref( $_[0] ) }
		},
		CodeRef => {
			parent    => 'Ref',
			optimized => sub { is_code_ref( $_[0] ) }
		},
		RegexpRef => {
			parent    => 'Ref',
			optimized => sub { is_regex_ref( $_[0] ) }
		},
		GlobRef => {
			parent    => 'Ref',
			optimized => sub { is_glob_ref( $_[0] ) }
		},

		FileHandle => {
			parent    => 'GlobRef',
			optimized => sub {
				is_glob_ref( $_[0] ) && openhandle( $_[0] )
					or is_instance( $_[0], "IO::Handle" );
			},
		},
		Object => {
			parent => 'Ref',
			optimized =>
				sub { blessed( $_[0] ) && blessed( $_[0] ) ne 'Regexp' }
		},
		ClassName => {
			parent    => 'Str',
			optimized => sub {
				Shaft::Util::is_class_loaded( $_[0] );
			},
		},
		RoleName => {
			parent    => 'ClassName',
			optimized => sub {
				Shaft::Util::is_class_loaded( $_[0] ) && 
				( Shaft::Util::find_meta( $_[0] ) 
				|| return )->isa('Shaft::Meta::Role') ? 1 : 0;
			},
		},

	);

	for my $name (
		qw/Any Item Undef Defined Bool Ref Value Str Num Int
		ScalarRef ArrayRef HashRef CodeRef RegexpRef GlobRef FileHandle Object
		ClassName RoleName/
		)
	{
		$TYPE{$name} = Shaft::Meta::TypeConstraint->new(
			name   => $name,
			parent => defined( $optimized{$name}->{parent} )
			? $TYPE{ $optimized{$name}->{parent} }
			: undef,
			constraint         => undef,
			optimized          => $optimized{$name}->{optimized},
			package_defined_in => __PACKAGE__,
		);
	}

	my @TYPE_KEYS = keys %TYPE;
	sub list_all_builtin_type_constraints {@TYPE_KEYS}    ##no critic
}

sub _get_constraint_cache {
	my ( $type, $key ) = @_;
	return $CONSTRAINT_CACHE{$type}->{$key};
}

sub _store_constraint_cache {
	my ( $type, $key, $constraint ) = @_;
	$CONSTRAINT_CACHE{$type}->{$key} = $constraint;
}

sub list_all_type_constraints {
	keys %TYPE;
}

sub export_type_constraints_as_functions {
	my $pkg = caller;
	for my $type ( list_all_builtin_type_constraints() ) {
		my $tc
			= $TYPE{$type}->has_optimized_type_constraint
			? $TYPE{$type}->optimized_type_constraint
			: $TYPE{$type}->_compiled_type_constraint;
			no strict 'refs';
			no warnings 'redefine';
			*{$pkg . '::' . $type} = sub { $tc->( $_[0] ) ? 1 : undef };
	}
}

sub coerce {
	my ( $name, %conf ) = @_;

	my $type = find_type_constraint($name)
		or throw_error
		"Cannot find type '$name', perhaps you forgot to load it.";

	$type->_add_type_coercions(%conf);

	return;
}

sub type {
	my ( $name, %conf ) = @_;

	_create_type_constraint( $name, undef, $conf{where}, $conf{message},
		$conf{optimize} );
}

sub subtype {
	my ( $name, %conf ) = @_;
	my $as = $conf{as} || 'Any';
	return _create_type_constraint( $name, $as, $conf{where}, $conf{message},
		$conf{optimize_as} );
}

sub enum {
	my ( $name, %valid );

	if ( !( @_ == 1 && ref( $_[0] ) eq 'ARRAY' ) ) {
		$name = shift;
	}

	my @elements = ( @_ == 1 && ref( $_[0] ) eq 'ARRAY' ) ? @{ $_[0] } : @_;

	( scalar(@elements) >= 2 )
		|| throw_error
		"You must have at least two values to enumerate through";

	my $enum_key = join( '|', uniq sort @elements );

	my $optimized = _get_constraint_cache( 'Enum', $enum_key );

	unless ($optimized) {
		%valid = map { $_ => undef } @elements;
		$optimized = sub {
			defined( $_[0] ) && !ref( $_[0] ) && exists( $valid{ $_[0] } );
		};
		_store_constraint_cache( 'Enum', $enum_key, $optimized );
	}

	_create_type_constraint( $name, 'Str', undef, undef, $optimized );
}

sub class_type {
	my ( $name, $options ) = @_;
	my $class = $options->{class} || $name;

	defined $class || throw_error "You must define a class name";

	my $optimized = _get_constraint_cache( 'Class', $class );
	unless ($optimized) {
		$optimized = sub {
			is_instance( $_[0], $class );
		};
		_store_constraint_cache( 'Class', $class, $optimized );
	}

	_create_type_constraint( $name, 'Object', undef, undef, $optimized );
}

sub role_type {
	my ( $name, $options ) = @_;
	my $role = $options->{role} || $name;

	defined $role || throw_error "You must define a role name";

	my $optimized = _get_constraint_cache( 'Role', $role );

	unless ($optimized) {
		$optimized = sub {
			Scalar::Util::blessed( $_[0] )
				&& Shaft::Util::does_role( $_[0], $role );
		};
		_store_constraint_cache( 'Role', $role, $optimized );
	}

	_create_type_constraint( $name, 'Object', undef, undef, $optimized );
}

sub duck_type {
	my ( $type_name, @methods ) = @_;
	if ( ref $type_name eq 'ARRAY' && @methods == 0 ) {
		@methods   = @$type_name;
		$type_name = undef;
	}
	if ( @methods == 1 && ref $methods[0] eq 'ARRAY' ) {
		@methods = @{ $methods[0] };
	}

	my $method_key = join( '|', uniq sort @methods );

	unless ($method_key) {
		throw_error "You must supply method name(s) which want to predicate";
	}

	my ( $message, $optimized );

	my $constraints = _get_constraint_cache( 'Duck', $method_key );

	if ($constraints) {
		$message   = $constraints->{message};
		$optimized = $constraints->{optimized};
	}
	else {
		$message = sub {
			my $value = $_;
			if (   !defined($value)
				|| !blessed($value)
				|| !( blessed($value) ne 'Regexp' ) )
			{
				$value = defined($value) ? overload::StrVal($value) : 'undef';
				return
					"Validation failed for '$type_name' failed with value '$value'";
			}
			my @missing = grep { !$value->can($_) } @methods;
			my $class = blessed $value;
			return
				  $class
				. " is missing methods "
				. quoted_english_list( @missing );
		};

		$optimized = sub {
			my $obj = shift;
			return
				   blessed($obj)
				&& blessed($obj) ne 'Regexp'
				&& all { $obj->can($_) } @methods;
		};

		_store_constraint_cache( 'Duck', $method_key,
			{ message => $message, optimized => $optimized } );
	}

	_create_type_constraint( $type_name, 'Object', undef, $message,
		$optimized );
}

sub _create_type_constraint {
	my $name      = shift;
	my $parent    = shift;
	my $check     = shift;
	my $message   = shift;
	my $optimized = shift;

	my $package = caller(1);

	if ( defined $name ) {
		my $existing_package
			= $TYPE{$name} ? $TYPE{$name}->package_defined_in : undef;
		if ( $existing_package && $existing_package ne $package ) {
			throw_error
				"The type constraint '$name' has already been created in $existing_package and cannot be created again in $package";

		}

		$name =~ /^[\w:\.]+$/
			or die qq{$name contains invalid characters for a type name.}
			. qq{ Names can contain alphanumeric character, ":", and "."\n};
	}

	my %opts = (
		name => $name || '__ANON__',
		package_defined_in => $package,
		( $check     ? ( constraint => $check )     : () ),
		( $message   ? ( message    => $message )   : () ),
		( $optimized ? ( optimized  => $optimized ) : () ),
	);

	my $constraint;
	if( defined($parent) && !blessed($parent) ){
		$parent = find_or_create_type_constraint($parent);
	}
	
	if (defined $parent )
	{
		$constraint = $parent->create_child_type(%opts);
	}
	else {
		$constraint = Shaft::Meta::TypeConstraint->new(%opts);
	}

	if ( defined $name ) {
		$TYPE{$name} = $constraint;
	}

	return $constraint;
}

sub _build_type_constraint {
	my $spec = shift;
	my $code;
	$spec =~ s/\s+//g;

	if ( $spec =~ /^([^\[]+)\[(.+)\]$/ ) {

		# parameterized
		my $constraint = $1;
		my $param      = $2;
		my $parent;

		if ( $constraint eq 'Maybe' ) {
			$parent = _build_type_constraint('Item');
		}
		else {
			$parent = _build_type_constraint($constraint);
		}
		my $child = _build_type_constraint($param);
		if ( $constraint eq 'ArrayRef' ) {
			$code = sub {
				for my $element ( @{ $_[0] } ) {
					return () unless $child->check($element);
				}
				return 1;
			};
		}
		elsif ( $constraint eq 'HashRef' ) {
			$code = sub {
				for my $element ( values %{ $_[0] } ) {
					return () unless $child->check($element);
				}
				return 1;
			};
		}
		elsif ( $constraint eq 'Maybe' ) {
			$code = sub {
				return 1 if !( defined( $_[0] ) ) || $child->check( $_[0] );
			};
		}
		else {
			throw_error(
				"Support for parameterized types other than Maybe, ArrayRef or HashRef is not implemented yet"
			);
		}
		$TYPE{$spec} = $parent->create_child_type(
			constraint => $code,
			name       => $spec,
			type_parameter => $child,
		);
	}
	else {
		$code = $TYPE{$spec};
		if ( !$code ) {

	   # is $spec a known role?  If so, constrain with 'does' instead of 'isa'
			require Shaft::Meta::Role;
			my $meta = Shaft::Util::get_metaclass_by_name($spec) or return;
			
			if ( $meta->isa('Shaft::Meta::Role') ) {
				role_type($spec);
			}
			else {
				class_type($spec);
			}
		}
	}
	return $TYPE{$spec};
}

sub find_type_constraint {
	my $type_constraint = shift;
	if( blessed($type_constraint) && $type_constraint->isa('Shaft::Meta::TypeConstraint') ){
		return $type_constraint;
	}
	else{
		return $TYPE{$type_constraint};
	}
}

sub find_or_create_type_constraint {
	my $type_constraint = shift;

	my $code;

	$type_constraint =~ s/\s+//g;

	$code = $TYPE{$type_constraint};
	if ( !$code ) {
		my @type_constraints = split /\|/, $type_constraint;
		if ( @type_constraints == 1 ) {
			$code = $TYPE{ $type_constraints[0] }
				|| _build_type_constraint( $type_constraints[0] );
		}
		else {
			my @code_list = map { $TYPE{$_} || _build_type_constraint($_) }
				@type_constraints;
			$code = Shaft::Meta::TypeConstraint->new(
				constraint => sub {
					my $i = 0;
					for my $code (@code_list) {
						return 1 if $code->check( $_[0] );
					}
					return 0;
				},
				name             => $type_constraint,
				type_constraints => \@code_list,
			);
			$TYPE{$type_constraint} = $code;
		}
	}
	return $code;
}

1;
__END__

=head1 NAME

Shaft::Util::TypeConstraints

=head1 EXPORTED FUNCTIONS

=over 13

=item type

=item subtype $name => ( where => '...', as => '...')

=item class_type  $name => $class

=item role_type $name => $role

=item duck_type $name => @methods;

=item coerce $name => ( { from => '...', via => sub{ ... } }, {  } )

=item as

=item where

=item from

=item via

=item message

=item optimize_as

=item enum

=item find_type_constraint

=back

=head1 FUNCTIONS

=over 4

=item export_type_constraints_as_functions

=item find_type_constraint

=item find_or_create_type_constraint

=item list_all_builtin_type_constraints

=item list_all_type_constraints

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
