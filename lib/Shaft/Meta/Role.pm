package Shaft::Meta::Role;
use strict;
use warnings;
use Scalar::Util qw(blessed);

use Data::Util qw(install_subroutine get_code_ref get_code_info);
use Sub::Name qw(subname);
use Shaft::Util qw(:meta throw_error);
use Shaft::Meta::Class;
use Shaft::Meta::Role::Method;

use Shaft::Object;
use Shaft::Meta::Module;
our @ISA = qw(Shaft::Object Shaft::Meta::Module);

{
	my %_meta;

	sub _initialize_args {
		%{ $_meta{ ${ $_[0] } }{_initialize_args} };
	}

	sub BUILDARGS {
		my $class = shift;
		my %args  = @_;

		$args{method_metaclass} ||= 'Shaft::Meta::Role::Method';
		$args{required_methods}   ||= [];
		$args{excluded_roles_map} ||= {};

		for my $type (qw/before after around override/) {
			$args{"${type}_method_modifier"} ||= {};
		}

		$args{_initialize_args} = \%args;

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

	sub name {
		return $_meta{ ${ $_[0] } }{name};
	}

	sub anon_serial_id {
		$_meta{ ${ $_[0] } }{anon_serial_id};
	}

	sub method_metaclass {
		$_meta{ ${ $_[0] } }{method_metaclass};
	}

	sub _get_method_map {
		$_meta{ ${ $_[0] } }{methods};
	}
	
	sub _get_attribute_map {
		$_meta{ ${ $_[0] } }{attributes};
	}

	sub add_attribute {
		my $self = shift;
		my $name = shift;
		$_meta{$$self}{attributes}{$name} = ( @_ == 1 ) ? $_[0] : {@_};
	}

	sub remove_attribute {
		delete $_meta{ ${ $_[0] } }{attributes}{ $_[1] };
	}

	sub get_excluded_roles_map {
		$_meta{ ${ $_[0] } }{excluded_roles_map};
	}

	sub get_required_method_list {
		my @requires = @{ $_meta{ ${ $_[0] } }{required_methods} };
		return wantarray ? @requires : \@requires;
	}

	sub add_required_methods {
		my $self = shift;
		push @{ $_meta{$$self}{required_methods} }, @_;
	}

	sub roles {
		my @roles = @{ $_meta{ ${ $_[0] } }{roles} };
		return wantarray ? @roles : \@roles;
	}

	sub add_role {
		my ( $self, @roles ) = @_;
		push @{ $_meta{$$self}{roles} }, @roles;
	}

	sub does_role {
		my ( $self, $role_name ) = @_;

		throw_error "You must supply a role name to look for"
			unless defined $role_name;

		return 1 if $role_name eq $self->name;

		for my $role ( @{ $_meta{$$self}{roles} } ) {
			return 1 if $role->does_role($role_name);
		}
		return;
	}

	sub get_method_attribute_map {
		$_meta{ ${ $_[0] } }{method_attributes_map};
	}

	for my $type (qw/before after around/) {
		my $add = sub {
			my ( $self, $name, $code ) = @_;
			my $id = $$self;
			my $names = ref($name) eq 'ARRAY' ? $name : [$name];
			for my $method_name (@$names) {
				$_meta{$id}{"${type}_method_modifier"}->{$method_name} ||= [];
				push @{ $_meta{$id}{"${type}_method_modifier"}
						->{$method_name} },
					$code;
			}
		};
		my $name = __PACKAGE__ . "::add_${type}_method_modifier";
		$add = subname $name => $add;
		install_subroutine( __PACKAGE__,
			"add_${type}_method_modifier" => $add );

		my $get = sub {
			my ( $self, $method_name ) = @_;
			return
				@{ $_meta{$$self}{"${type}_method_modifier"}->{$method_name}
					|| [] };
		};

		$name = __PACKAGE__ . "::get_${type}_method_modifier";
		$get = subname $name => $get;
		install_subroutine( __PACKAGE__,
			"get_${type}_method_modifier" => $get );

		my $map = sub {
			$_meta{ ${ $_[0] } }{"${type}_method_modifier"};
		};
		$name = __PACKAGE__ . "::${type}_method_modifier";
		$map = subname $name => $map;
		install_subroutine( __PACKAGE__, "${type}_method_modifier" => $map );
	}

	sub add_override_method_modifier {
		my ( $self, $name, $code ) = @_;
		if ( $self->has_method($name) ) {
			throw_error
				"Can't add an override of method '$name' because there is a local version of '$name'";
		}
		my $id = $$self;
		$_meta{$id}{override_method_modifier}->{$name}
			= $code;
	}

	sub get_override_method_modifier {
		my ( $self, $name ) = @_;
		return $_meta{$$self}{override_method_modifier}->{$name};
	}
	
	sub has_override_method_modifier {
		my ($self, $method_name ) = @_;
		exists $_meta{ $$self }{override_method_modifier}{$method_name};
	}

	sub override_method_modifier {
		$_meta{ ${ $_[0] } }{override_method_modifier};
	}

}

sub add_excluded_roles {
	my ( $self, @values ) = @_;
	$self->get_excluded_roles_map->{$_} = undef foreach @values;
}

sub get_excluded_roles_list {
	keys %{ $_[0]->get_excluded_roles_map };
}

sub excludes_role {
	exists $_[0]->get_excluded_roles_map->{ $_[1] };
}

sub _check_role_exclusions {
	my ( $self, $consumer ) = @_;
	my $role = $self->name;
	if ( $consumer->excludes_role($role) ) {
		throw_error( "Conflict detected: "
				. $consumer->name
				. " excludes role '"
				. $role
				. "'" );
	}
	foreach my $excluded_role_name ( $self->get_excluded_roles_list ) {
		if ( $consumer->does_role($excluded_role_name) ) {
			throw_error( "The class "
					. $consumer->name
					. " does the excluded role '$excluded_role_name'" );
		}
	}
}

sub _check_required_methods {
	my ( $role, $consumer, $args ) = @_;
	if ( $args->{_to} eq 'role' ) {
		$consumer->add_required_methods( $role->get_required_method_list );
	}
	else {
		my $consumer_class_name = $consumer->name;
		my @missing;
		for my $name ( $role->get_required_method_list ) {
			next if exists $args->{aliased_methods}{$name};
			next if $role->has_method($name);
			next if $consumer_class_name->can($name);
			push @missing, $name;
		}
		if (@missing) {
			throw_error sprintf(
				"The role '%s' requires the methods %s to be implemented by '%s'",
				$role->name, Shaft::Util::quoted_english_list(@missing),
				$consumer_class_name
			);
		}
	}
}

sub _apply_attributes {
	my ( $role, $consumer, $args ) = @_;
	for my $name ( $role->get_attribute_list ) {
		next if $consumer->has_attribute($name);
		my $spec = $role->get_attribute($name);
		$consumer->add_attribute( $name, $spec );
	}
	return;
}

sub _apply_methods {
	my ( $role, $consumer, $args ) = @_;
	my $alias    = $args->{-alias};
	my $excludes = $args->{-excludes};

	my $consumer_class_name = $consumer->name;

	foreach my $name ( $role->get_method_list ) {
		next if $name eq 'meta';
		my @names;
		if ( !exists $excludes->{$name} ) {
			if( !$consumer->has_method($name)){
				push @names, $name;
			}
		}
		if ( exists $alias->{$name} ) {
			my $dst_name = $alias->{$name};
			my $code = $role->get_method_body($name);
			my $dst_code = $consumer->get_method_body($dst_name);
			if( defined($dst_code) && $dst_code != $code ){
				throw_error("Can't create a method alias if a local method of the same name exists");
			}
			else{
				push @names, $alias->{$name};
			}
		}
		my $code = $role->get_method($name);
		$consumer->add_method( $_ => $code, $role ) for @names;
	}

	return;
}

sub _apply_modifiers {
	my ( $role, $consumer, $args ) = @_;

	my $modifier = $role->override_method_modifier;
	for my $method ( keys %$modifier ) {
		$consumer->add_override_method_modifier( $method, $modifier->{$method} );
	}

	for my $type (qw/before after around/) {
		my $get_modifier = "${type}_method_modifier";
		my $add_method   = "add_${type}_method_modifier";
		my $modifier     = $role->$get_modifier;
		for my $method ( keys %$modifier ) {
			for my $code ( @{ $modifier->{$method} } ) {
				$consumer->$add_method( $method => $code );
			}
		}
	}
	return;
}

sub _apply_method_attributes {
	my ( $role, $consumer, $args ) = @_;
	$consumer->copy_method_attributes_from($role);
	if ( $args->{_to} eq 'class' ) {
		$consumer->apply_method_attribute_handler;
	}
}

sub _append_role {
	my ( $role, $consumer, $args ) = @_;
	for my $r ( $role, @{ $role->roles } ) {
		if ( !$consumer->does_role( $r->name ) ) {
			$consumer->add_role($r);
		}
	}
}

sub apply {
	my $role     = shift;
	my $consumer = shift;

	my %args = @_ == 1 ? %{ $_[0] } : @_;

	if ( Shaft::Util::is_a_metaclass($consumer) ) {
		$args{_to} = 'class';
	}
	else {
		$args{_to} = 'role';
	}

	if ( my $alias = $args{-alias} ) {
		@{ $args{aliased_methods} }{ values %$alias } = ();
	}
	if ( $args{-excludes} ) {
		my $excludes = $args{-excludes};
		$args{-excludes} = {};
		if ( ref($excludes) eq 'ARRAY' ) {
			%{ $args{-excludes} } = ( map { $_ => undef } @$excludes );
		}
		else {
			$args{-excludes}{$excludes} = undef;
		}
	}

	$role->_check_role_exclusions( $consumer, \%args );
	$role->_check_required_methods( $consumer, \%args );
	$role->_apply_methods( $consumer, \%args );
	$role->_apply_attributes( $consumer, \%args );
	$role->_apply_modifiers( $consumer, \%args );
	$role->_apply_method_attributes( $consumer, \%args );
	$role->_append_role( $consumer, \%args );
}

sub combine {
	my ( $role_class, @role_specs ) = @_;
	require Shaft::Meta::Role::Composite;
	my $composite = Shaft::Meta::Role::Composite->create_anon_role;
	foreach my $spec (@role_specs) {
		my ( $role_name, $args ) = @$spec;
		$role_name->meta->apply( $composite, $args );
	}
	return $composite;
}

sub calculate_all_roles {
	my $self = shift;
	my %seen;
	grep { !$seen{ $_->name }++ }
		( $self, map { $_->calculate_all_roles } @{ $self->roles } );
}

my $ANON_ROLE_PREFIX = 'Shaft::Meta::Role::__ANON__::';

sub is_anon_role {
	my $self = shift;
	$self->name =~ /^$ANON_ROLE_PREFIX/;
}

sub create_anon_role {
	my $role = shift;
	return $role->create( undef, @_ );
}

__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Shaft::Meta::Role

=head1 METHODS

=over 4

=item name

=item create_anon_role

=item is_anon_role

=item anon_serial_id

=item add_attribute

=item remove_attribute

=item get_method_map

=item get_method_attribute_map

=item before_method_modifier

=item after_method_modifier

=item around_method_modifier

=item override_method_modifier

=item add_before_method_modifier

=item add_after_method_modifier

=item add_around_method_modifier

=item add_override_method_modifier

=item get_before_method_modifier

=item get_after_method_modifier

=item get_around_method_modifier

=item get_override_method_modifier

=item has_override_method_modifier

=item add_role

=item does_role

=item roles

=item apply

=item combine

=item calculate_all_roles

=item method_metaclass

=item add_required_methods

=item get_required_method_list

=item add_excluded_roles

=item excludes_role

=item get_excluded_roles_list

=item get_excluded_roles_map

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
