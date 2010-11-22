package Shaft::Meta::Attribute;
use strict;
use warnings;
use Shaft::Object;
use Scalar::Util qw(blessed);
use Shaft::Util qw(throw_error throw_warn);
use Shaft::Meta::Method::Accessor;
use Shaft::Meta::Method::Delegation;
use Data::Util();
use Sub::Name ();

our @ISA = qw(Shaft::Object);

my %valid_options = map { $_ => undef } (
	'accessor',
	'auto_deref',
	'builder',
	'clearer',
	'default',
	'documentation',
	'does',
	'handles',
	'init_arg',
	'is',
	'lazy',
	'lazy_build',
	'modifier',
	'name',
	'predicate',
	'reader',
	'required',
	'reseter',
	'should_coerce',
	'traits',
	'trigger',
	'type_constraint',
	'weak_ref',
	'writer',

	# internally used
	'associated_class',
	'associated_methods',
);

{
	my %_meta;

	sub BUILDARGS {
		my ( $class, $name, %args ) = @_;
		my $args = $class->_process_options( $name, {%args} );
		$args->{name}               = $name;
		$args->{init_arg}           = $name unless exists $args{init_arg};
		$args->{associated_methods} = [];

		#check attribute options
		my @bad = grep { !exists $valid_options{$_} } keys %{$args};
		if ( @bad && $class ne __PACKAGE__ ) {
			my %valid_attrs = (
				map { $_ => undef }
					grep {defined}
					map  { $_->init_arg() } $class->meta->get_all_attributes()
			);
			@bad = grep { !exists $valid_attrs{$_} } @bad;
		}
		if (@bad) {
			throw_warn(
				"Found unknown argument(s) passed to '$name' attribute constructor in '$class': "
					. Shaft::Util::english_list(@bad) );
		}

		$args->{_create_args} = \%args;
		return $args;
	}

	sub BUILD {
		my ( $self, $args ) = @_;
		$_meta{$$self} = $args;
	}

	sub DEMOLISH {
		return if $_[1];
		delete $_meta{ ${ $_[0] } };
	}

	{
		my %methods;
		for my $method (
			qw/name predicate clearer reseter handles type_constraint trigger builder modifier
			init_arg reader writer documentation associated_class _create_args/
			)
		{
			$methods{$method} = sub { $_meta{ ${ $_[0] } }{$method} };
		}

		for my $method (qw/required lazy lazy_build weak_ref/) {
			$methods{"is_$method"} = sub { $_meta{ ${ $_[0] } }{$method} };
		}

		for my $method (
			qw/default predicate clearer reseter handles type_constraint trigger builder reader writer documentation/
			)
		{
			$methods{"has_$method"}
				= sub { exists $_meta{ ${ $_[0] } }{$method} };
		}

		for my $key ( keys %methods ) {
			Data::Util::install_subroutine( 'Shaft::Meta::Attribute',
				$key => Sub::Name::subname( $key => $methods{$key} ) );
		}
	}

	sub is_ro {
		$_meta{ ${ $_[0] } }{is} eq 'ro';
	}

	sub is_rw {
		$_meta{ ${ $_[0] } }{is} eq 'rw';
	}

	sub is_private {
		$_meta{ ${ $_[0] } }{modifier} eq 'Private';
	}

	sub is_protected {
		$_meta{ ${ $_[0] } }{modifier} eq 'Protected';
	}

	sub is_public {
		$_meta{ ${ $_[0] } }{modifier} eq 'Public';
	}
	sub access_type       { $_meta{ ${ $_[0] } }{is} }
	sub should_auto_deref { $_meta{ ${ $_[0] } }{auto_deref} }
	sub should_coerce     { $_meta{ ${ $_[0] } }{should_coerce} }
	
	sub default {
		my ($self, $instance) = @_;
		return unless $self->has_default;
		my $default = $_meta{$$self}{default};
		if( defined($instance) && ref($default) eq 'CODE' ){
			return $default->($instance);
		}
		return $default;
	}

	sub associate_method {
		my ( $self, $method ) = @_;
		push @{ $_meta{$$self}{associated_methods} }, $method;
	}

	sub associated_methods {
		@{ $_meta{ ${ $_[0] } }{associated_methods} };
	}

	sub attach_to_class {
		Scalar::Util::weaken( $_meta{ ${ $_[0] } }{associated_class}
				= $_[1] );
	}

	sub detach_from_class {
		delete $_meta{ ${ $_[0] } }{associated_class};
	}

}

sub accessor_metaclass {'Shaft::Meta::Method::Accessor'}

sub delegation_metaclass {'Shaft::Meta::Method::Delegation'}

sub get_read_method_ref {
	my $self = shift;
	return $self->associated_class->get_method_body( $self->reader );
}

sub get_write_method_ref {
	my $self = shift;
	return $self->associated_class->get_method_body( $self->writer );
}

sub does {
	my ( $self, $role_name ) = @_;
	my $name = eval {
		Shaft::Util::resolve_metatrait_alias( Attribute => $role_name );
	};
	return 0 if !defined($name);
	return $self->Shaft::Object::does($name);
}

sub interpolate_class {
	my ( $class, $args ) = @_;

	if ( my $metaclass_name = delete $args->{metaclass} ) {
		$class = Shaft::Util::resolve_metaclass_alias( 'Attribute',
			$metaclass_name );
		throw_error
			"You must supply the class name that inheritance of 'Shaft::Meta::Attribute' to the 'metaqclass' option"
			unless $class->isa('Shaft::Meta::Attribute');
	}

	my @traits;

	if ( my $traits = delete $args->{traits} ) {
		my $i = 0;
		while ( $i < @$traits ) {
			my $trait = $traits->[ $i++ ];

			$trait
				= Shaft::Util::resolve_metatrait_alias( Attribute => $trait );

			next if $class->does($trait);
			push @traits, $trait;
			push @traits, $traits->[ $i++ ]
				if $traits->[$i] && ref( $traits->[$i] );
		}

		if (@traits) {
			$class = Shaft::Meta::Class->create_anon_class(
				superclasses => [$class],
				roles        => \@traits,
				cache        => 1,
			)->name;
		}
	}

	return ( wantarray ? ( $class, @traits ) : $class );
}

sub _canonicalize_args {
	my ( $self, $name, $args ) = @_;

	if ( $args->{lazy_build} ) {
		$args->{lazy}     = 1;
		$args->{required} = 1;
		$args->{builder}  = "_build_${name}" unless exists $args->{builder};

		if ( $name =~ /^_/ ) {
			$args->{clearer}   = "_clear${name}" if !exists( $args->{clearer} );
			$args->{predicate} = "_has${name}"   if !exists( $args->{predicate} );
		}
		else {
			$args->{clearer}   = "clear_${name}" if !exists( $args->{clearer} );
			$args->{predicate} = "has_${name}"   if !exists( $args->{predicate} );
		}

	}

	if ( delete $args->{clear} ) {
		unless ( exists $args->{clearer} ) {
			if ( $name =~ /^_/ ) {
				$args->{clearer} = "_clear${name}";
			}
			else {
				$args->{clearer} = "clear_${name}";
			}
		}
	}

	if ( delete $args->{reset} ) {
		unless ( exists $args->{reseter} ) {
			if ( $name =~ /^_/ ) {
				$args->{reseter} = "_reset${name}";
			}
			else {
				$args->{reseter} = "reset_${name}";
			}
		}
	}

	$args->{is} ||= 'ro';

	$args->{modifier} ||= 'Public';

	if ( delete $args->{pbp_style} ) {
		if ( $name =~ /^_/ ) {
			$args->{reader} = "_get${name}";
			$args->{writer} = "_set${name}" if $args->{is} eq 'rw';
		}
		else {
			$args->{reader} = "get_${name}";
			$args->{writer} = "set_${name}" if $args->{is} eq 'rw';
		}
	}
	else {
		if ( !exists $args->{reader} ) {
			$args->{reader} = $name;
		}
		if ( $args->{is} eq 'rw' && !exists $args->{writer} ) {
			$args->{writer} = $name;
		}
	}
	if ( $args->{is} eq 'ro' && exists $args->{writer} ) {
		delete $args->{writer};
	}
	
}

sub _validate_args {
	my ( $self, $name, $args ) = @_;

	unless ( Shaft::Util::is_valid_method_name($name) ) {
		throw_error
			"Can't use '$name' for attribute  name because it's contain invalid character";
	}

	unless ( Shaft::Util::is_valid_method_name( $args->{reader} ) ) {
		throw_error "Can't use '"
			. $args->{reader}
			. "' for reader method name because it's contain invalid character";
	}

	if ( exists $args->{writer} ) {
		unless ( Shaft::Util::is_valid_method_name( $args->{writer} ) ) {
			throw_error "Can't use '"
				. $args->{writer}
				. "' for writer method name because it's contain invalid character";
		}
	}

	if (   $args->{modifier} ne 'Private'
		&& $args->{modifier} ne 'Protected'
		&& $args->{modifier} ne 'Public' )
	{
		throw_error
			"Modifier for attribute ($name) must be 'Private', 'Protected' or 'Public'";
	}

	if ( $args->{lazy_build} && exists $args->{default} ) {
		throw_error
			"Can't use option 'lazy_build' and 'defult' for same attribute ($name)";
	}

	if (   $args->{lazy}
		&& !exists( $args->{default} )
		&& !exists( $args->{builder} ) )
	{
		throw_error
			"Can't use 'lazy' option for attribute ($name) without default value('default' or 'builder')";
	}

	if ( ref( $args->{default} ) && ref( $args->{default} ) ne 'CODE' ) {
		throw_warn
			"References are not recomanded as default values. Should be wrap the defaut of '$name' in a CODE reference (ex: sub { [] } )";
	}

	if (   $args->{reseter}
		&& !exists( $args->{default} )
		&& !exists( $args->{builder} ) )
	{
		throw_error
			"Can't use 'reseter' option for attribute ($name) without default_value('default' or 'builder')";
	}

	if ( $args->{auto_deref} && !exists $args->{isa} ) {
		throw_error
			"Can't auto-dereference without type constranint('ArrayRef' or 'HashRef') on attribute ($name)";
	}

	if (   $args->{auto_deref}
		&& $args->{isa} !~ /^ArrayRef/
		&& $args->{isa} !~ /^HashRef/ )
	{
		throw_error
			"Can't auto-dereference anything other than a ArrayRef or HashRef on Attribute ($name)";
	}

	if ( $args->{trigger} && ref( $args->{trigger} ) ne 'CODE' ) {
		throw_error "Trigger must be a CODE reference on attribute ($name)";
	}

	return 1;
}

sub _process_options {
	my ( $self, $name, $args ) = @_;

	$args->{name} = $name;

	$self->_canonicalize_args( $name, $args );
	$self->_validate_args( $name, $args );

	if ( $args->{isa} ) {
		if (   $args->{isa} =~ /^([^\[]+)\[.+\]$/
			&& $1 ne 'ArrayRef'
			&& $1 ne 'HashRef'
			&& $1 ne 'Maybe' )
		{
			throw_error
				"Got isa => $args->{isa}, but Shaft does not yet support parameterized types for containers other than ArrayRef, HashRef, and Maybe";
		}
		my $type_constraint = delete $args->{isa};
		if ( exists $args->{does} ) {
			if ( eval { $type_constraint->can('does') } ) {
				( $type_constraint->does( $args->{does} ) )
					|| throw_error
					"Can't have an isa option and a does option if the isa does not do the does on attribute ($name)";
			}
			else {
				throw_error
					"Can't have an isa option which can't ->does() on attribute ($name)";
			}
		}
		if ( blessed($type_constraint)
			&& $type_constraint->isa('Shaft::Meta::TypeConstraint') )
		{
			$args->{type_constraint} = $type_constraint;
		}
		else {
			$args->{type_constraint}
				= Shaft::Util::TypeConstraints::find_or_create_type_constraint(
				$type_constraint)
				|| Shaft::Util::TypeConstraints::class_type($type_constraint);
		}
	}
	elsif ( $args->{does} ) {
		if ( blessed( $args->{does} )
			&& $args->{does}->isa('Shaft::Meta::TypeConstraint') )
		{
			$args->{type_constraint} = $args->{does};
		}
		else {
			$args->{type_constraint}
				= Shaft::Util::TypeConstraints::find_or_create_type_constraint(
				$args->{does} )
				|| Shaft::Util::TypeConstraints::role_type( $args->{does} );
		}
	}

	if ( $args->{coerce} ) {
		( exists $args->{type_constraint} )
			|| throw_error
			"You cannot have coercion without specifying a type constraint on attribute ($name)";
		$args->{should_coerce} = delete $args->{coerce};
	}

	return $args;
}

sub install_accessors {
	my $attr = shift;
	$attr->accessor_metaclass->generate_accessors($attr);
	$attr->install_delegation if $attr->has_handles;
}

sub remove_accessors {
	my $attr = shift;
	my $meta = $attr->associated_class;
	for my $method ( $attr->associated_methods ) {
		$meta->remove_method( $method->name );
	}
}

sub _canonicalize_handles {
	my $self    = shift;
	my $handles = $self->handles;
	if ( my $handle_type = ref($handles) ) {
		if ( $handle_type eq 'HASH' ) {
			return %$handles;
		}
		elsif ( $handle_type eq 'ARRAY' ) {
			return map { $_ => $_ } @$handles;
		}
		elsif ( $handle_type eq 'Regexp' ) {
			( $self->has_type_constraint )
				|| throw_error
				"Cannot delegate methods based on a Regexp without a type constraint (isa)";
			my $class_or_role = $self->type_constraint;
			my $meta = Shaft::Meta::Class->initialize("$class_or_role");
			return map { $_ => $_ }
				grep { !Shaft::Object->can($_) && $_ =~ $handles }
				Shaft::Util::is_a_metarole($meta)
				? $meta->get_method_list
				: $meta->get_all_method_names;
		}
		elsif ( $handle_type eq 'CODE' ) {
			( $self->has_type_constraint )
				|| throw_error "Cannot find delegate metaclass for attribute "
				. $self->name;
			my $class_or_role = $self->type_constraint;
			return $handles->(
				$self, Shaft::Meta::Class->initialize("$class_or_role")
			);
		}
		else {
			throw_error
				"Unable to canonicalize the 'handles' option with $handles";
		}
	}
	else {
		my $role_meta = eval {
			Shaft::Util::load_class($handles)
				unless Shaft::Util::is_class_loaded($handles);
			$handles->meta;
		};
		if ($@) {
			throw_error(
				"Unable to canonicalize the 'handles' option with $handles because : $@"
			);
		}

		( blessed $role_meta && $role_meta->isa('Shaft::Meta::Role') )
			|| throw_error(
			"Unable to canonicalize the 'handles' option with $handles because ->meta is not a Shaft::Meta::Role"
			);

		return map { $_ => $_ }
			grep { $_ ne 'meta' } (
			$role_meta->get_method_list, $role_meta->get_required_method_list
			);
	}

}

sub _make_delegation_method {
	my ( $self, $handle_name, $method_to_call ) = @_;
	my @curried_argments;
	( $method_to_call, @curried_argments ) = @$method_to_call
		if 'ARRAY' eq ref($method_to_call);

	my $method = $self->delegation_metaclass->new(
		name               => $handle_name,
		package_name       => $self->associated_class->name,
		attribute          => $self,
		delegate_to_method => $method_to_call,
		curried_argments   => \@curried_argments,
	);
}

sub install_delegation {
	my $self = shift;
	my $meta = $self->associated_class;

	my $class_name = $meta->name;

	my %handles = $self->_canonicalize_handles;

	for my $handle ( keys %handles ) {
		my $method_to_call = $handles{$handle};

		( !$meta->has_method($handle) )
			|| throw_error
			"You cannot overwrite a locally defined method ($handle) with a delegation";

		next
			if $class_name->isa("Shaft::Object")
				and $handle =~ /^BUILD|DEMOLISH$/
				|| Shaft::Object->can($handle);

		my $method
			= $self->_make_delegation_method( $handle, $method_to_call );
		$meta->add_method( $handle => $method );
		$self->associate_method($method);
	}
}

my @legal_options_for_inheritance = qw(
	default coerce required documentation lazy isa handles
	builder metaclass traits lazy_build weak_ref
);

sub legal_options_for_inheritance {
	@legal_options_for_inheritance;
}

sub clone_and_inherit_options {
	my $self    = shift;
	my %options = @_;

	my %args = %{ $self->_create_args };

	delete $args{handles};

	my @legal_options = $self->legal_options_for_inheritance;

	foreach my $legal_option (@legal_options) {
		if ( exists $options{$legal_option} ) {
			$args{$legal_option} = delete $options{$legal_option};
		}
	}

	my $modifier      = delete $options{modifier} || 'Public';
	my $orig_modifier = $args{modifier}           || 'Public';
	if ( $modifier ne $orig_modifier ) {
		throw_error "Can't override attribute option 'modifier'";
	}

	my ( $attribute_class, @traits )
		= ref($self)->interpolate_class( \%args );
	$args{traits} = \@traits if @traits;

	( scalar( keys %options ) == 0 )
		|| throw_error 'Illegal inherited options => ('
		. join( ',', keys %options ) . ')';

	$attribute_class->new( $self->name, %args );
}

sub verify_against_type_constraint {
	my ( $self, $value ) = @_;
	my $tc = $self->type_constraint;
	return 1 unless $tc;

	local $_ = $value;
	return 1 if $tc->check($value);

	$self->verify_type_constraint_error( $self->name, $value, $tc );
}

sub verify_type_constraint_error {
	my ( $self, $name, $value, $type ) = @_;
	throw_error(
		"Attribute ($name) does not pass the type constraint because: "
			. $type->get_message($value) );
}

sub coerce_constraint {
	my $type = $_[0]->type_constraint
		or return $_[1];
	return $type->coerce( $_[1] );
}

sub _call_builder {
	my ( $self, $instance ) = @_;
	my $builder = $self->builder;
	return $instance->$builder() if $instance->can($builder);
	throw_error( blessed($instance)
			. " does not support builder method '"
			. $builder
			. "'  for attribute '"
			. $self->name
			. "'" );

}

__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Shaft::Meta::Attribute

=head1 METHODS

=over 4

=item new

=item clone_and_inherit_options

=item name

=item install_accessors

=item remove_accessors

=item interpolate_class

=item access_type

=item does

=item associated_class

=item attach_to_class

=item detach_from_class

=item reader

=item get_read_method_ref

=item writer

=item get_write_method_ref

=item default

=item predicate

=item clearer

=item reseter

=item handles 

=item type_constraint

=item trigger

=item builder

=item modifier

=item init_arg

=item getter

=item setter

=item is_required

=item is_lazy

=item is_lazy_build

=item is_weak_ref

=item is_ro

=item is_rw

=item is_private

=item is_protected

=item is_public

=item has_reader

=item has_writer

=item has_default

=item has_predicate

=item has_clearer

=item has_reseter

=item has_handles

=item has_type_constraint

=item has_trigger

=item has_builder

=item has_getter

=item has_setter

=item should_coerce

=item should_auto_deref

=item verify_against_type_constraint

=item verify_type_constraint_error

=item coerce_constraint

=item accessor_metaclass

=item associate_method

=item associated_methods

=item copy_attribute_from_parent

=item delegation_metaclass

=item documentation

=item has_documentation

=item install_delegation

=item legal_options_for_inheritance

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
