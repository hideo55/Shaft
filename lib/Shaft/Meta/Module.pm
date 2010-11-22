package Shaft::Meta::Module;
use strict;
use warnings;
use Shaft::Util qw(:meta throw_error);
use Scalar::Util qw(blessed);
use Sub::Name qw(subname);
use Data::Util
	qw(get_code_ref get_code_info get_stash install_subroutine uninstall_subroutine);

my %METAS;

sub _class_of {
	my ($class_or_instance) = @_;
	return unless defined $class_or_instance;
	return $METAS{ ref($class_or_instance) || $class_or_instance };
}

sub _get_metaclass_by_name { $METAS{ $_[0] } }

sub _get_all_metaclass_instances { values %METAS }

sub _get_all_metaclass_names { keys %METAS }

sub _store_metaclass_by_name { $METAS{ $_[0] } = $_[1] }

sub _weaken_metaclass { Scalar::Util::weaken( $METAS{ $_[0] } ) }

sub _does_metaclass_exist { defined $METAS{ $_[0] } }

sub _remove_metaclass_by_name { delete $METAS{ $_[0] } }

sub version   { no strict 'refs'; ${ shift->name . '::VERSION' } }
sub authority { no strict 'refs'; ${ shift->name . '::AUTHORITY' } }

sub identifier {
	my $self = shift;
	return
		join '-' => grep{ defined }( $self->name, $self->version, $self->authority);
}

sub namespace {
	my $self = shift;
	my $name = $self->name;
	no strict 'refs';
	my $stash = \%{ $name . '::' };
	return wantarray ? keys %$stash : $stash;
}

sub initialize {
	my ( $class, $package_name, %args ) = @_;

	( $package_name && !ref($package_name) )
		|| throw_error
		"You must pass a package name and it cannot be blessed";

	unless ( $METAS{$package_name} ) {
		$args{method_attributes_map} ||= {};
		$args{methods}               ||= {};
		$args{attributes}            ||= {};
		$args{roles}                 ||= [];
		$METAS{$package_name} = $class->new( name => $package_name, %args );
	}

	return $METAS{$package_name};
}

sub reinitialize {
	my ( $class, $package_name, %args ) = @_;

	( $package_name && !ref($package_name) )
		|| throw_error
		"You must pass a package name and it cannot be blessed";
	my $old_meta = delete $METAS{$package_name};
	if ( !$old_meta ) {
		throw_error "The '$package_name' is not initialized yet";
	}
	%args = ( $old_meta->_initialize_args, %args );
	my $old_obj_data = $old_meta->_serialize;
	my $new_meta = $class->initialize( $package_name, %args );
	$new_meta->_deserialize($old_obj_data);
	return $new_meta;
}

sub add_method {
	my ( $self, $name, $method ) = @_;

	throw_error
		"Can't use '$name' for method name because it's contain invalid character"
		unless Shaft::Util::is_valid_method_name($name);

	my $class = $self->name;

	my $body;
	if ( blessed $method ) {
		$body = $method->body;
		if ( $method->package_name ne $class ) {
			$method = $method->clone( package_name => $class, name => $name );
		}
	}
	else {
		$body   = $method;
		$method = $self->method_metaclass->wrap(
			$body,
			package_name => $class,
			name         => $name
		);
	}

	$method->attach_to_class($self);
	$self->_get_method_map->{$name} = $method;

	my ( $cur_package, $cur_name ) = get_code_info($body);

	if ( !defined($cur_name) || $cur_name eq '__ANON__' ) {
		my $full_method_name = $class . '::' . $name;
		$body = subname $full_method_name => $body;
	}

	no warnings 'redefine';
	install_subroutine( $class, $name => $body );
}

sub remove_method {
	my ( $self, $name ) = @_;
	return unless $self->has_method($name);
	my $class          = $self->name;
	my $removed_method = delete $self->_get_method_map->{$name};
	$removed_method->detach_from_class;
	uninstall_subroutine( $class => $name );
	return $removed_method;
}

sub get_method_body {
	my ( $self, $name ) = @_;
	my $method = $self->get_method($name);
	return $method ? $method->body : undef;
}

sub _code_is_mine {
	my $self = shift;
	my $code = shift;
	my ( $code_package, $code_name ) = get_code_info($code);
	return unless defined($code_package);
	return $code_package eq $self->name || ( $code_package eq 'constant' && $code_name eq '__ANON__' );
}

sub has_method {
	my ( $self, $name ) = @_;
	return defined( $self->_get_method_map->{$name} )
		|| defined( $self->get_method($name) );
}

sub get_method_list {
	my $self = shift;
	return grep { $self->has_method($_) } $self->namespace;
}

sub get_method {
	my $self = shift;
	my $name = shift;
	my $map  = $self->_get_method_map;
	unless ( exists( $map->{$name} ) ) {
		return unless Shaft::Util::is_valid_method_name($name);
		my $code = get_code_ref( $self->name => $name );
		return unless $code && $self->_code_is_mine($code);
		$map->{$name} = $self->method_metaclass->wrap(
			$code,
			package_name         => $self->name,
			name                 => $name,
			associated_metaclass => $self
		);
	}
	return $map->{$name};
}

sub register_method_attributes {
	my ( $self, $attr ) = @_;
	my $code = $attr->[1];
	$self->get_method_attribute_map->{$code} ||= [];
	push @{ $self->get_method_attribute_map->{$code} }, $attr;
	return;
}

sub get_method_attributes {
	my $self = shift;
	return map { @{$_} } values %{ $self->get_method_attribute_map };
}

sub get_methods_by_method_attribute_name {
	my ( $self, $attr_name ) = @_;
	return map { $_->[1] }
		grep { $_->[2] eq $attr_name } $self->get_method_attributes;
}

sub copy_method_attributes_from {
	my ( $self, $from ) = @_;
	my $new_package = $self->name;
	for my $attr ( $from->get_method_attributes ) {
		my $new_attr = [@$attr];
		splice @$new_attr, 0, 1, $new_package;
		$self->register_method_attributes(
			Shaft::MethodAttributes::Spec->new($new_attr) );
	}
}

sub get_method_attributes_by_method {
	my ( $self, $method ) = @_;
	my $code = $self->get_method_body($method);
	return () unless $code;
	return @{ $self->get_method_attribute_map->{$code} || [] };
}

sub get_method_attributes_by_methodref {
	my ( $self, $code ) = @_;
	return () unless $code;
	return @{ $self->get_method_attribute_map->{$code} || [] };
}

sub get_attribute_list {
	return keys %{ $_[0]->_get_attribute_map };
}

sub has_attribute {
	exists $_[0]->_get_attribute_map->{ $_[1] };
}

sub get_attribute {
	return $_[0]->_get_attribute_map->{ $_[1] };
}

{

	my $ANON_SERIAL = 0;
	my %_CACHE;

	sub create {
		my ( $self, $package_name, %options ) = @_;
		throw_error 'You must pass a package name' if @_ < 2;

		my $superclasses;
		if ( exists $options{superclasses} ) {
			if ( $self->can('create_anon_role') ) {
				delete $options{superclasses};
			}
			else {
				$superclasses = delete $options{superclasses};
				( ref $superclasses eq 'ARRAY' )
					|| throw_error
					"You must pass an ARRAY ref of superclasses";
			}
		}

		my $attributes = delete $options{attributes};
		if ( defined $attributes ) {
			( ref $attributes eq 'ARRAY' || ref $attributes eq 'HASH' )
				|| throw_error(
				"You must pass an ARRAY or HASH ref of attributes");
		}
		my $methods = delete $options{methods};
		if ( defined $methods ) {
			( ref $methods eq 'HASH' )
				|| throw_error("You must pass a HASH ref of methods");
		}
		
		my $roles = delete $options{roles};
		if( defined $roles ){
			( ref($roles) eq 'ARRAY' )
				|| throw_error("You must pass an ARRAY ref of roles");
		}

		my $mortal;
		my $cache_key;

		if ( !defined $package_name ) {
			$mortal = !$options{cache};
			if ( !$mortal ) {
				$cache_key = join '=' => (
					join( '|', @{ $superclasses || [] } ),
					join( '|', sort @{ $roles   || [] } ),
				);
				return $_CACHE{$cache_key} if exists $_CACHE{$cache_key};
			}
			$options{anon_serial_id} = ++$ANON_SERIAL;
			my $class = ref($self) || $self;
			$package_name
				= $class . '::__ANON__::' . $options{anon_serial_id};
		}

		do {
			my $code = "package ${package_name};";
			$code
				.= "\$$package_name\:\:VERSION = '" . $options{version} . "';"
				if exists $options{version};
			$code
				.= "\$$package_name\:\:AUTHORITY = '"
				. $options{authority} . "';"
				if exists $options{authority};
			eval $code;    ## no critic
			throw_error "creation of ${package_name} failed : $@" if $@;
		};

		my %initialize_options = %options;
		delete @initialize_options{
			qw(
				package
				version
				authority
				cache
				)
			};

		my $meta = $self->initialize( $package_name => %initialize_options );

		Scalar::Util::weaken( $METAS{$package_name} ) if $mortal;

		$meta->add_method( 
			meta => sub { $self->initialize( ref( $_[0] ) || $_[0] ) }
		);
		
		if ( defined $superclasses ) {
			$meta->superclasses(@$superclasses);
		}

		if ( defined $attributes ) {
			if ( ref($attributes) eq 'ARRAY' ) {
				for my $attr (@$attributes) {
					$meta->add_attribute($attr);
				}
			}
			else {
				while ( my ( $name, $attr ) = each %{$attributes} ) {
					$meta->add_attribute( $name => %$attr );
				}
			}
		}

		if ( defined $methods ) {
			while ( my ( $name, $body ) = each %$methods ) {
				$meta->add_method( $name => $body );
			}
		}

		if ( defined $roles ) {
			Shaft::Util::apply_all_roles( $package_name, @$roles );
		}

		if ($cache_key) {
			$_CACHE{$cache_key} = $meta;
		}

		return $meta;
	}

	sub destruct_meta_instance {
		my $self = shift;
		my $serial_id;
		$serial_id = $self->anon_serial_id;
		return if !$serial_id;

		%{ $self->namespace } = ();
		my $name = $self->name;
		delete $METAS{$name};

		$name =~ s/ $serial_id \z//xms;

		no strict 'refs';
		delete ${$name}{ $serial_id . '::' };

		return;
	}
}

1;
__END__

=head1 NAME

Shaft::Meta::Module

=head1 METHODS

=over 4

=item version

=item authority

=item identifier

=item namespace

=item initialize

=item reinitialize

=item create

=item destruct_meta_instance

=item get_all_attributes

=item get_attribute

=item get_attribute_list

=item has_attribute

=item add_method

=item remove_method

=item get_method_list

=item has_method

=item get_method

=item get_method_body

=item get_all_methods

=item get_all_method_names

=item register_method_attributes

=item get_method_attributes_by_method

=item get_method_attributes_by_methodref

=item get_method_attributes

=item get_methods_by_method_attribute_name

=item copy_method_attributes_from

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

