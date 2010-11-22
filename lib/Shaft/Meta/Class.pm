package Shaft::Meta::Class;
use 5.008_001;
use strict;
use warnings;
use Scalar::Util qw(blessed);
use List::Util qw(first);
use List::MoreUtils qw(any all uniq);
use Sub::Name qw(subname);
use Shaft::Util qw(:meta throw_error throw_warn);
use Shaft::Meta::Method;
use Shaft::Meta::Method::Constructor;
use Shaft::Meta::Method::Destructor;
use Shaft::Meta::Method::Wrapped;
use Shaft::Meta::Method::Augmented;
use Shaft::Meta::Method::Overridden;

use Shaft::Object;
use Shaft::Meta::Module;
our @ISA = qw(Shaft::Object Shaft::Meta::Module);

{

	my %_meta;

	sub _reinitialize_with {
		my ( $self, $new_meta ) = @_;
		my $new_self = $new_meta->reinitialize(
			$self->name,
			attribute_metaclass => $new_meta->attribute_metaclass,
			method_metaclass    => $new_meta->method_metaclass,
		);
		$new_self->$_( $new_meta->$_ )
			for qw( constructor_class destructor_class );
		$_meta{$$self} = $_meta{$$new_self};
		$self->rebless( ref $new_self );
	}

	sub _initialize_args {
		%{ $_meta{ ${ $_[0] } }{_initialize_args} };
	}

	sub BUILDARGS {
		my $class = shift;
		my %args  = @_;

		$args{constructor_class}   ||= 'Shaft::Meta::Method::Constructor';
		$args{destructor_class}    ||= 'Shaft::Meta::Method::Destructor';
		$args{attribute_metaclass} ||= 'Shaft::Meta::Attribute';
		$args{method_metaclass}    ||= 'Shaft::Meta::Method';
		$args{wrapped_method_metaclass} ||= 'Shaft::Meta::Method::Wrapped';
		$args{role_map}                 ||= {};
		$args{mutable}                  ||= 1;
		$args{linearized_isa}           ||= [];
		$args{pkg_gen}                  ||= -1;
		$args{superclasses}
			||= do { no strict 'refs'; \@{ $args{name} . '::ISA' } };

		$args{_initialize_args} ||= \%args;

		return \%args;
	}

	sub BUILD {
		my ( $self, $args ) = @_;
		$_meta{$$self} = $args;
	}

	sub DEMOLISH {
		return if $_[1];
		my $self = shift;
		$self->destruct_meta_instance;
		delete $_meta{$$self};
	}

	sub clone {
		my $self     = shift;
		my $new_obj  = $self->SUPER::clone;
		my $new_data = Clone::clone( $_meta{$$self} );
		$_meta{$$new_obj} = $new_data;
		return $new_obj;
	}

	sub name {
		$_meta{ ${ $_[0] } }{name};
	}

	sub anon_serial_id {
		$_meta{ ${ $_[0] } }{anon_serial_id};
	}

	sub _get_method_map {
		$_meta{ ${ $_[0] } }{methods};
	}

	sub _generate_all_method_metaclass {
		my $self = shift;
		for my $class ( reverse $self->linearized_isa ) {
			my $meta = Shaft::Util::get_metaclass_by_name($class) or next;
			my $id = $$self;

			for my $name ( $meta->get_method_list ) {
				next if $_meta{$id}{methods}{$name};
				$meta->get_method($name);
			}
		}
	}

	sub get_all_methods {
		my $self = shift;
		my ( @methods, %seen );
		$self->_generate_all_method_metaclass;
		for my $class ( reverse $self->linearized_isa ) {
			my $meta = Shaft::Util::get_metaclass_by_name($class) or next;

			my $id = $$meta;

			for my $name ( keys %{ $_meta{$id}{methods} } ) {
				next if $seen{$name}++;
				push @methods, $_meta{$id}{methods}{$name};
			}
		}
		return @methods;
	}

	sub get_all_method_names {
		my $self = shift;
		uniq map { $_->name } $self->get_all_methods;
	}

	sub get_method_attribute_map {
		my $self = shift;
		$_meta{$$self}{method_attributes_map};
	}

	sub superclasses {
		my ( $self, @superclasses ) = @_;

		my $id = $$self;

		if (@superclasses) {
			no strict 'refs';
			for my $super (@superclasses) {
				my $e = do {
					local $@;
					eval { Shaft::Util::load_class($super) };
					$@;
				};
				
				if($e){
					throw_error($e) unless $e->message =~ /Can't locate .*?\.pm/;
				}
				
				${ $super . '::VERSION' } = "dummy"
					unless defined ${ $super . '::VERSION' };
			}
			@{ $_meta{$id}{superclasses} } = @superclasses;
			$self->_check_metaclass_compatibility();
		}
		return @{ $_meta{$id}{superclasses} };
	}

	sub linearized_isa {
		my $self    = shift;
		my $class   = $self->name;
		my $id      = $$self;
		my $pkg_gen = Shaft::Util::get_pkg_gen($class);
		return @{ $_meta{$id}{linearized_isa} }
			if $_meta{$id}{pkg_gen} == $pkg_gen;
		$_meta{$id}{pkg_gen}        = $pkg_gen;
		$_meta{$id}{linearized_isa} = Shaft::Util::get_linear_isa($class);
		return @{ $_meta{$id}{linearized_isa} };
	}

	sub _get_attribute_map {
		$_meta{ ${ $_[0] } }{attributes};
	}

	sub add_attribute {
		my $self = shift;
		my ( $attr, $name );

		if ( @_ == 1 && blessed( $_[0] ) ) {
			$attr = shift @_;
			$name = $attr->name;
		}
		else {
			$name = shift @_;
			my %options = ( @_ == 1 ) ? %{ $_[0] } : @_;
			defined($name)
				|| throw_error 'You must provide a name for the attribute';
			if ( $name =~ s/^\+// ) {    #Override
				my $inherited_attr = $self->find_attribute_by_name($name)
					or throw_error
					"Could't find an attribute '$name' from in inherit hierarchy";
				$attr = $inherited_attr->clone_and_inherit_options(%options);
			}
			else {
				my ( $attribute_class, @traits )
					= $self->attribute_metaclass->interpolate_class(
					\%options );
				$options{traits} = \@traits if @traits;
				$attr = $attribute_class->new( $name, %options );
			}
		}
		$_meta{$$self}{attributes}{$name} = $attr;
		$attr->attach_to_class($self);
		$attr->install_accessors;
		return $attr;
	}

	sub remove_attribute {
		my ( $self, $name ) = @_;
		my $attr = delete $_meta{$$self}{attributes}{$name};
		if ( defined $attr ) {
			$attr->remove_accessors;
			$attr->detach_from_class();
		}
		return $attr;
	}

	sub attribute_metaclass {
		my $meta = $_[0];
		$_meta{$$meta}{attribute_metaclass};
	}

	sub method_metaclass {
		my $meta = $_[0];
		$_meta{$$meta}{method_metaclass};
	}

	sub wrapped_method_metaclass {
		my $meta = $_[0];
		$_meta{$$meta}{wrapped_method_metaclass};
	}

	sub constructor_class {
		my $meta = $_[0];
		if ( @_ > 1 ) {
			$_meta{$$meta}{constructor_class} = $_[1];
		}
		else {
			$_meta{$$meta}{constructor_class};
		}
	}

	sub destructor_class {
		my $meta = $_[0];
		if ( @_ > 1 ) {
			$_meta{$$meta}{destructor_class} = $_[1];
		}
		else {
			$_meta{$$meta}{destructor_class};
		}
	}

	sub roles {
		my $self  = shift;
		my @roles = @{ $_meta{$$self}{roles} };
		return wantarray ? @roles : \@roles;
	}

	sub add_role {
		my ( $self, @roles ) = @_;
		push @{ $_meta{$$self}{roles} }, @roles;
		my $role_map = $_meta{$$self}{role_map};
		map { $role_map->{ $_->name } = 1 } @roles;
	}

	sub does_role {
		my ( $self, $role_name ) = @_;

		throw_error "You must supply a role name to look for"
			unless defined $role_name;

		return 1 if exists $_meta{$$self}{role_map}{$role_name};

		for my $class ( $self->linearized_isa ) {
			my $meta = Shaft::Util::get_metaclass_by_name($class) or next;
			next unless $meta->can('roles');
			for my $role ( @{ $meta->roles } ) {
				return 1 if $role->name eq $role_name;
			}
		}

		return;
	}

	sub is_mutable {
		$_meta{ ${ $_[0] } }{mutable};
	}

	sub make_mutable {
		my $self = shift;
		my $id   = $$self;
		my $name = $self->name;
		unless ( $_meta{$id}{mutable} ) {
			$_meta{$id}{mutable} = 1;
			$self->remove_method('new');
			$self->remove_method('DESTROY');
		}
		return 1;
	}

	sub make_immutable {
		my $self = shift;
		my %opts = @_;

		my $name = $self->name;

		my $id = $$self;

		if ( $_meta{$id}{mutable} ) {

			unless ( exists $opts{inline_constructor} ) {
				$opts{inline_constructor} = 1;
			}
			unless ( exists $opts{inline_destructor} ) {
				$opts{inline_destructor} = 1;
			}

			if ( $opts{inline_constructor} ) {
				if ( $self->has_method('new') ) {
					throw_warn <<"__WARN__";
Not inlining a constructor for $name since it defines its own constructor.";
If you are certain you don't need to inline your constructor, specify inline_constructor => 0 in your call to ${name}->meta->make_immutable
__WARN__
				}
				else {
					my $constructor = $self->constructor_class
						->generate_inlined_constructor($self);
					$self->add_method( new => $constructor );
				}

			}
			if ( $opts{inline_destructor} ) {
				if ( $self->has_method('DESTROY') ) {
					throw_warn <<"__WARN__";
Not inlining a destructor for $name since it defines its own destructor.";
If you are certain you don't need to inline your destructor, specify inline_destructor => 0 in your call to ${name}->meta->make_immutable
__WARN__
				}
				else {
					my $destructor = $self->destructor_class
						->generate_inlined_destructor($self);
					$self->add_method( DESTROY => $destructor );
				}
			}
			$_meta{$id}{mutable} = 0;
		}
		return 1;
	}

}

sub apply_method_attribute_handler {
	my $self = shift;
	for my $attrs ( $self->get_method_attributes ) {
		for my $phase (qw/BEGIN CHECK INIT/) {
			Shaft::MethodAttributes::Handler::apply_handler( $attrs, $phase );
		}
	}
}

{
	my $fetch_and_prepare_method = sub {
		my ( $self, $method_name ) = @_;
		my $wrapped_metaclass = $self->wrapped_method_metaclass;
	
		my $method = $self->get_method($method_name);
	
			unless ($method) {
	
			$method = $self->find_next_method_by_name($method_name);
	
			( defined $method )
				|| throw_error
				"The method '$method_name' was not found in the inheritance hierarchy for " . $self->name;
			$method = $wrapped_metaclass->wrap($method);
		}
		else {
			$method = $wrapped_metaclass->wrap($method)
				unless $method->isa($wrapped_metaclass);
		}
		$self->add_method( $method_name => $method );
		return $method;
	};

	sub add_before_method_modifier {
		my ( $self, $name, $code ) = @_;
		my $names = ref($name) eq 'ARRAY' ? $name : [$name];
		unless (@$names) {
			throw_error "You must pass in a method name";
		}
		for my $_name (@$names) {
			my $method = $fetch_and_prepare_method->( $self, $_name );
			$method->add_before_modifier(
				subname( $_name . ':before' => $code ) 
			);
		}
	}

	sub add_after_method_modifier {
		my ( $self, $name, $code ) = @_;
		my $names = ref($name) eq 'ARRAY' ? $name : [$name];
		unless (@$names) {
			throw_error "You must pass in a method name";
		}
		for my $_name (@$names) {
			my $method = $fetch_and_prepare_method->( $self, $_name );
			$method->add_after_modifier( 
				subname( $_name . ':after' => $code ) 
			);
		}
	}

	sub add_around_method_modifier {
		my ( $self, $name, $code ) = @_;
		my $names = ref($name) eq 'ARRAY' ? $name : [$name];
		unless (@$names) {
			throw_error "You must pass in a method name";
		}
		for my $_name (@$names) {
			my $method = $fetch_and_prepare_method->( $self, $_name );
			$method->add_around_modifier(
				subname( $_name . ':around' => $code )
			);
		}
	}
}

sub add_override_method_modifier {
	my ( $self, $name, $method, $_super_package ) = @_;

	if ( $self->has_method($name) ) {
		throw_error
			"Can't add an override method if a local method is already present";
	}

	$self->add_method(
		$name => Shaft::Meta::Method::Overridden->new(
			method  => $method,
			class   => $self,
			package => $_super_package,
			name    => $name
		)
	);
}

sub add_augment_method_modifier {
	my ( $self, $name, $method ) = @_;

	if ( $self->has_method($name) ) {
		throw_error
			"Can't add an augment method if a local method is already present";
	}

	$self->add_method(
		$name => Shaft::Meta::Method::Augmented->new(
			method => $method,
			class  => $self,
			name   => $name
		)
	);
}

sub find_attribute_by_name {
	my ( $self, $name ) = @_;
	my $attr;
	foreach my $class ( $self->linearized_isa ) {
		my $meta = Shaft::Util::get_metaclass_by_name($class) or next;
		$attr = $meta->get_attribute($name) and last;
	}
	return $attr;
}

sub find_next_method_by_name {
	my ( $self, $method_name ) = @_;
	( defined $method_name && $method_name )
		or throw_error "You must define a method name to find";
	my @isa = $self->linearized_isa;
	shift @isa;
	for my $class (@isa) {
		my $meta = $self->initialize($class);
		return $meta->get_method($method_name)
			if $meta->has_method($method_name);
	}
	return;
}

sub find_all_methods_by_name {
	my ( $self, $method_name ) = @_;
	( defined $method_name && $method_name )
		or throw_error "You must define a method name to find";
	my @methods;
	for my $class ( $self->linearized_isa ) {
		my $meta = $self->initialize($class);
		push @methods, $meta->get_method($method_name)
			if $meta->has_method($method_name);
	}
	return @methods;
}

sub _find_next_method_by_name_which_is_not_overridden {
	my ( $self, $name ) = @_;
	for my $method ( $self->find_all_methods_by_name($name) ) {
		return $method
			unless $method->isa('Shaft::Meta::Method::Overridden');
	}
	return;
}

sub get_all_attributes {
	my $self = shift;
	my %attr = map { %{ $self->initialize($_)->_get_attribute_map } }
		reverse $self->linearized_isa;
	return values %attr;
}

sub calculate_all_roles {
	my $self = shift;
	my %seen;
	grep    { !$seen{ $_->name }++ }
		map { $_->calculate_all_roles } @{ $self->roles };
}

sub excludes_role {
	my ( $self, $role_name ) = @_;
	( defined $role_name )
		|| throw_error("You must supply a role name to look for");
	foreach my $class ( $self->linearized_isa ) {
		my $meta = Shaft::Util::get_metaclass_by_name($class) or next;
		next unless $meta->can('does_role');
		foreach my $role ( @{ $meta->roles } ) {
			return 1 if $role->excludes_role($role_name);
		}
	}
	return 0;
}

sub _check_metaclass_compatibility {
	my $self = shift;

	my @supers = $self->superclasses;
	$self->_fix_metaclass_incompatibility(@supers);

	return if ref($self) eq 'Shaft::Meta::Class';

	my @class_list = $self->linearized_isa;
	shift @class_list;
	foreach my $superclass_name (@class_list) {
		my $super_meta = Shaft::Util::get_metaclass_by_name($superclass_name);
		my $super_meta_type = ref($super_meta);
		unless ( $self->isa($super_meta_type) ) {
			throw_error "Shaft::Util::class_of("
				. $self->name
				. ") => ("
				. ( ref($self) ) . ")"
				. " is not compatible with the Shaft::Util::class_of("
				. $superclass_name
				. ") => ("
				. ($super_meta_type) . ")";
		}
	}

}

sub _fix_metaclass_incompatibility {
	my $self   = shift;
	my @supers = @_;
    $self->_fix_one_incompatible_metaclass($_)
        for map { Shaft::Meta::Class->initialize($_) } @supers;
}

sub is_pristine {
	my $self = shift;
	for my $method ( map { $self->get_method($_) }
		$self->get_method_list )
	{
		return if $method->isa('Shaft::Meta::Method::Generated');
	}
	return 1;
}

sub _fix_one_incompatible_metaclass {
	my ( $self, $meta ) = @_;

	return if $self->_superclass_meta_is_compatible($meta);

	unless ( $self->is_pristine ) {
		throw_error( "Cannot attempt to reinitialize metaclass for "
				. $self->name
				. ", it isn't pristine" );
	}

	$self->_reconcile_with_superclass_meta($meta);
}

sub _superclass_meta_is_compatible {
	my ( $self, $super_meta ) = @_;
	
	my $super_meta_name = ref($super_meta);
	
	throw_error sprintf("The super metaclass '%s' isn't inherit 'Shaft::Meta::Class'", $super_meta_name) unless $super_meta->isa('Shaft::Meta::Class');
	
	return 1
		if $self->isa($super_meta_name);
}

my @MetaClassTypes = qw(
	attribute_metaclass
	method_metaclass
	wrapped_method_metaclass
	constructor_class
	destructor_class
);

sub _reconcile_with_superclass_meta {
	my ( $self, $super_meta ) = @_;

	my $super_meta_name = ref($super_meta);

	my $self_metaclass = ref $self;

	if ( $super_meta_name->isa($self_metaclass)
		&& all { $super_meta->$_->isa( $self->$_ ) } @MetaClassTypes )
	{
		$self->_reinitialize_with($super_meta);
	}
	elsif ( $self->_all_metaclasses_differ_by_roles_only($super_meta) ) {
		$self->_reconcile_role_differences($super_meta);
	}
}

sub _all_metaclasses_differ_by_roles_only {
	my ( $self, $super_meta ) = @_;

	for my $pair ( [ ref $self, ref $super_meta ],
		map { [ $self->$_, $super_meta->$_ ] } @MetaClassTypes )
	{

		next if $pair->[0] eq $pair->[1];

		my $self_meta_meta  = Shaft::Meta::Class->initialize( $pair->[0] );
		my $super_meta_meta = Shaft::Meta::Class->initialize( $pair->[1] );

		my $common_ancestor
			= _find_common_ancestor( $self_meta_meta, $super_meta_meta );

		return
			unless _is_role_only_subclass_of( $self_meta_meta,
			$common_ancestor, )
			&& _is_role_only_subclass_of( $super_meta_meta, $common_ancestor,
			);
	}

	return 1;
}

sub _find_common_ancestor {
	my ( $meta1, $meta2 ) = @_;
	my %meta1_parents = map { $_ => 1 } $meta1->linearized_isa;
	return first { $meta1_parents{$_} } $meta2->linearized_isa;
}

sub _is_role_only_subclass_of {
	my ( $meta, $ancestor ) = @_;

	return 1 if $meta->name eq $ancestor;

	my @roles = _all_roles_until( $meta, $ancestor );

	my %role_packages = map { $_->name => 1 } @roles;

	my $ancestor_meta = Shaft::Meta::Class->initialize($ancestor);

	my %shared_ancestors = map { $_ => 1 } $ancestor_meta->linearized_isa;

	for my $method ( $meta->get_all_methods() ) {
		next if $method->name eq 'meta';
		next if $method->can('associated_attribute');

		next
			if $role_packages{ $method->original_package_name }
				|| $shared_ancestors{ $method->original_package_name };

		return 0;
	}

	for my $attr ( $meta->get_all_attributes ) {
		next if $shared_ancestors{ $attr->associated_class->name };
		next if any { $_->has_attribute( $attr->name ) } @roles;
		return 0;
	}

	return 1;
}

sub _all_roles {
	my $meta = shift;
	return _all_roles_until($meta);
}

sub _all_roles_until {
	my ( $meta, $stop_at_class ) = @_;

	my @roles = $meta->calculate_all_roles;

	for my $class ( $meta->linearized_isa ) {
		last if $stop_at_class && $stop_at_class eq $class;
		my $meta = Shaft::Meta::Class->initialize($class);
		push @roles, $meta->calculate_all_roles;
	}

	return uniq @roles;
}

sub _reconcile_role_differences {
	my ( $self, $super_meta ) = @_;

	my $self_meta = $self->meta;

	my %roles;

	if ( my @roles = map { $_->name } _all_roles($self_meta) ) {
		$roles{metaclass_roles} = \@roles;
	}

	for my $thing (@MetaClassTypes) {
		my $name = $self->$thing();

		my $thing_meta = Shaft::Meta::Class->initialize($name);

		my @roles = map { $_->name } _all_roles($thing_meta)
			or next;

		$roles{ $thing . '_roles' } = \@roles;
	}

	$self->_reinitialize_with($super_meta);

	Shaft::Util::MetaRole::apply_metaclass_roles(
		for_class => $self->name,
		%roles,
	);

	return $self;
}

my $ANON_CLASS_PREFIX = 'Shaft::Meta::Class::__ANON__::';

sub is_anon_class {
	my $self = shift;
	$self->name =~ /^$ANON_CLASS_PREFIX/;
}

sub create_anon_class {
	my $self = shift;
	return $self->create( undef, @_ );
}

1;
__END__

=head1 NAME

Shaft::Meta::Class

=head1 METHODS

=over 4

=item meta

=item name

=item superclasses

=item linearized_isa

=item attribute_metaclass

=item method_metaclass

=item wrapped_method_metaclass

=item constructor_class

=item destructor_class

=item clone

=item create_anon_class

=item is_anon_class

=item anon_serial_id

=item add_attribute

=item remove_attribute

=item find_attribute_by_name

=item get_all_attributes

=item get_all_methods

=item get_all_method_names

=item find_next_method_by_name

=item find_all_methods_by_name

=item get_method_attribute_map

=item add_role

=item does_role

=item roles

=item excludes_role

=item calculate_all_roles

=item is_pristine

=item add_before_method_modifier

=item add_after_method_modifier

=item add_around_method_modifier

=item add_override_method_modifier

=item add_augment_method_modifier

=item is_mutable

=item make_mutable

=item make_immutable

=item apply_method_attribute_handler

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
