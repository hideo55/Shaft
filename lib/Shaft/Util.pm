package Shaft::Util;
use strict;
use warnings;
use Scalar::Util qw(blessed);
use Data::Util qw(install_subroutine get_code_ref);
use Sub::Name qw(subname);
use Shaft::Exception;

use Shaft::Exporter -setup => {
	exports => [
		qw/meta does find_meta does_role is_class_loaded load_class
			load_first_existing_class  throw_error throw_warn
			is_valid_method_name english_list quoted_english_list/
	],
	groups => {
		default => [],
		meta    => [qw/meta does/],
	}
};

my $class_pattern  = qr/\A[^\W\d]\w*(?:(?:\'|::)\w+)*\z/;
my $method_pattern = qr/\A[^\W\d]\w*\z/;

BEGIN {
	require Shaft::Meta::Module;
	
	*class_of              = \&Shaft::Meta::Module::_class_of;
	*get_metaclass_by_name = \&Shaft::Meta::Module::_get_metaclass_by_name;
	*store_metaclass_by_name
		= \&Shaft::Meta::Module::_store_metaclass_by_name;
	*remove_metaclass_by_name
		= \&Shaft::Meta::Module::_remove_metaclass_by_name;
	*does_metaclass_exist = \&Shaft::Meta::Module::_does_metaclass_exist;
	*get_all_metaclass_names
		= \&Shaft::Meta::Module::_get_all_metaclass_names;
	*get_all_metaclass_instances
		= \&Shaft::Meta::Module::_get_all_metaclass_instances;
	*weaken_metaclass = \&Shaft::Meta::Module::_weaken_metaclass;

	my $get_linear_isa;
	my $pkg_gen;
	if( $] >= 5.009_005){
		require mro;
	}
	else{
		require MRO::Compat;
	}
	*get_linear_isa = \&mro::get_linear_isa;
	*get_pkg_gen = \&mro::get_pkg_gen;
	
}

sub meta {
	require Shaft::Meta::Class;
	Shaft::Meta::Class->initialize( ref( $_[0] ) || $_[0] );
}

sub does {
	my ( $self, $role_name ) = @_;
	my $meta = Shaft::Util::class_of($self);
	( defined $role_name )
		or throw_error("You much supply a role name to does()");
	return defined($meta) && $meta->does_role($role_name);
}

sub find_meta { return class_of( $_[0] ) }

sub is_a_metaclass { blessed( $_[0] ) && $_[0]->can('create_anon_class') }

sub is_a_metarole { blessed( $_[0] ) && $_[0]->can('create_anon_role') }

sub is_a_type_constraint {
	blessed( $_[0] ) && $_[0]->can('_compiled_type_constraint');
}

my %_class_cache;

sub _get_valid_class_name {
	my $class = shift;
	my $name  = $class;
	if ( defined $_class_cache{$class} ) {
		return $_class_cache{$class};
	}
	return $_class_cache{$class} = 'main' if $name eq '::';
	$name =~ s/\A::/main::/;
	$name =~ /$class_pattern/
		? $_class_cache{$class}
		= $name
		: q{};
}

sub is_class_loaded {
	my $class = shift;

	return unless $class;

	my $name = _get_valid_class_name($class);

	return unless $name;

	no strict 'refs';
	return 1 if defined ${"${name}::VERSION"};
	return 1 if defined @{"${name}::ISA"};

	foreach ( keys %{"${name}::"} ) {
		next if substr( $_, -2, 2 ) eq '::';
		return 1 if defined &{"${name}::$_"};
	}

	my $filename = $name . '.pm';
	$filename =~ s{::}{/}g;
	return 1 if defined $INC{$filename};
}

sub load_class {
	load_first_existing_class( $_[0] );
	return 1;
}

sub _is_valid_class_name {
	my $class = shift;

	return 0 unless defined($class);
	return 0 if ref($class);
	return 0 unless length($class);

	return 1 if $class =~ /^\w+(?:::\w+)*$/;

	return 0;
}

sub load_first_existing_class {
	my @classes = @_
		or return;

	foreach my $class (@classes) {
		unless ( _is_valid_class_name($class) ) {
			my $display = defined($class) ? $class : 'undef';
			throw_error("Invalid class name ($display)");
		}
	}

	my $found;
	my %exceptions;
	for my $class (@classes) {
		return $class if is_class_loaded($class);
		my $filename = $class . '.pm';
		$filename =~ s{::}{/}g;
		my $e = do {
			local $@;
			eval { CORE::require($filename) };
			$@;
		};
		if ($e) {
			$exceptions{$class} = $e;
		}
		else {
			$found = $class;
			last;
		}
	}

	return $found if $found;

	throw_error(
		join(
			"\n",
			map {
				sprintf( "Could not load class (%s) because : %s",
					$_, $exceptions{$_} )
				} @classes
		)
	);
}

sub is_valid_method_name {
	my $method_name = shift;
	return $method_name =~ /$method_pattern/o ? 1 : 0;
}

sub does_role {
	my ( $class_or_obj, $role ) = @_;
	my $meta = class_of($class_or_obj);
	return unless defined $meta;
	return unless $meta->can('does_role');
	return 1 if $meta->does_role($role);
	return;
}

sub apply_all_roles {
	my $consumer = blessed $_[0] ? shift : Shaft::Meta::Class->initialize(shift);

	my @roles;

	# Basis of Data::OptList
	my $max = scalar(@_);
	for ( my $i = 0; $i < $max; $i++ ) {
		if ( $i + 1 < $max && ref( $_[ $i + 1 ] ) ) {
			push @roles, [ $_[ $i++ ] => $_[$i] ];
		}
		else {
			push @roles, [ $_[$i] => {} ];
		}
		my $role_name = $roles[-1][0];
		load_class($role_name);
		is_a_metarole( get_metaclass_by_name($role_name) )
			|| throw_error
			"Could not apply role : '$role_name' is not Shaft role";
	}
	if( @roles == 1 ){
		my ($role_name, $params) = @{ $roles[0] };
		get_metaclass_by_name($role_name)->apply( $consumer, $params );
	}
	else{
		Shaft::Meta::Role->combine(@roles)->apply($consumer);
	}
}

sub resolve_metatrait_alias {
	return resolve_metaclass_alias( @_, trait => 1 );
}

{
	my %cache;

	sub resolve_metaclass_alias {
		my ( $type, $metaclass_name, %options ) = @_;

		my $cache_key = $type . q{ } . ( $options{trait} ? '-Trait' : q{} );
		return $cache{$cache_key}{$metaclass_name}
			if $cache{$cache_key}{$metaclass_name};

		my $possible_full_name
			= 'Shaft::Meta::' 
			. $type
			. '::Custom::'
			. ( $options{trait} ? "Trait::" : "" )
			. $metaclass_name;

		my $loaded_class = load_first_existing_class( $possible_full_name,
			$metaclass_name );

		return $cache{$cache_key}{$metaclass_name}
			= $loaded_class->can('register_implementation')
			? $loaded_class->register_implementation
			: $loaded_class;
	}
}

sub english_list {
	my @items = @_;
	return $items[0] if @items == 1;
	return qq{$items[0] and $items[1]} if @items == 2;
	my $tail = pop @items;
	my $list = join q{, }, @items;
	$list .= qq{, and $tail};
	return $list;
}

sub quoted_english_list {
	my @items = @_;
	return qq{'$items[0]'} if @items == 1;
	return qq{'$items[0]' and '$items[1]'} if @items == 2;
	my $tail = pop @items;
	my $list = join q{, }, map{ qq{'$_'} }@items;
	$list .= qq{, and '$tail'};
	return $list;
}

sub throw_error {
	goto &Shaft::Exception::throw;
}

sub throw_warn {
	require Carp;
	Carp::carp(shift);
}

1;
__END__

=head1 NAME

Shaft::Util - Utility functions for Shaft

=head1 FUNCTIONS

=over 27

=item meta

=item does

=item class_of

=item get_all_metaclass_names

=item get_all_metaclass_instances

=item get_metaclass_by_name

=item store_metaclass_by_name

=item remove_metaclass_by_name

=item does_metaclass_exist

=item weaken_metaclass

=item is_a_metaclass

=item is_a_metarole

=item is_a_type_constraint

=item apply_all_roles

=item does_role

=item find_meta

=item get_all_metaclass

=item is_class_loaded

=item is_valid_method_name

=item load_class

=item load_first_existing_class

=item resolve_metaclass_alias

=item resolve_metatrait_alias

=item english_list

=item quoted_english_list

=item throw_error

=item throw_warn

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
