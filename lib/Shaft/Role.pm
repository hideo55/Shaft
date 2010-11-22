package Shaft::Role;
use strict;
use warnings;
use Scalar::Util qw(blessed);
use Shaft::MethodAttributes;
use Shaft::Meta::Role;
use Shaft::Util qw(throw_error throw_warn);
use Shaft::Util::TypeConstraints;
use Shaft::Exporter -setup => {
	with_meta => [
		qw/before after around override  augment has Private Protected Public with excludes requires/
	],
	exports => [
		qw/super inner/,            \&Scalar::Util::blessed,
		\&Shaft::Util::throw_error, \&Shaft::Util::throw_warn
	],
};

sub with {
	Shaft::Util::apply_all_roles( shift, @_ );
}

sub excludes {
	shift->add_excluded_roles(@_);
}

sub requires {
	shift->add_required_methods(@_);
}

sub Private {
	my ( $meta, $name, %options ) = @_;
	$options{modifier} = 'Private';
	if ( ref $name ) {
		$meta->add_attribute( $_ => \%options ) foreach @$name;
	}
	else {
		$meta->add_attribute( $name => \%options );
	}
}

sub Protected {
	my ( $meta, $name, %options ) = @_;
	$options{modifier} = 'Protected';
	if ( ref $name ) {
		$meta->add_attribute( $_ => \%options ) foreach @$name;
	}
	else {
		$meta->add_attribute( $name => \%options );
	}
}

sub Public {
	my ( $meta, $name, %options ) = @_;
	$options{modifier} = 'Public';
	if ( ref $name ) {
		$meta->add_attribute( $_ => \%options ) foreach @$name;
	}
	else {
		$meta->add_attribute( $name => \%options );
	}
}

sub has {
	my ( $meta, $name, %options ) = @_;
	if ( ref $name ) {
		$meta->add_attribute( $_ => \%options ) foreach @$name;
	}
	else {
		$meta->add_attribute( $name => \%options );
	}
}

sub before {
	my $code = pop;
	shift->add_before_method_modifier( [@_], $code );
}

sub after {
	my $code = pop;
	shift->add_after_method_modifier( [@_], $code );
}

sub around {
	my $code = pop;
	shift->add_around_method_modifier( [@_], $code );
}

sub super {
	return unless $Shaft::SUPER_BODY;
	$Shaft::SUPER_BODY->(@Shaft::SUPER_ARGS);
}

sub override {
	shift->add_override_method_modifier(@_);
}

sub inner {
	throw_error "Roles cannot support 'inner'";
}

sub augment {
	throw_error "Roles cannot support 'augment'";
}

sub init_meta {
	shift;
	my %args = @_;

	my $role = $args{for_class};

	unless ($role) {
		throw_error "Can't call init_meta without specifying a for_class";
	}

	my $metaclass = $args{metaclass} || "Shaft::Meta::Role";

	role_type $role unless find_type_constraint($role);

	my $meta;

	if ( $role->can('meta') ) {
		my $meta = $role->meta;
		unless ( blessed($meta) && $meta->isa('Shaft::Meta::Role') ) {
			throw_error(
				"You already have a &meta function, but it does not return a Shaft::Meta::Role"
			);
		}
	}
	else {
		$meta = $metaclass->initialize($role);
		$meta->add_method(
			meta => sub { $metaclass->initialize( ref( $_[0] ) || $_[0] ) } );
	}

	return $meta;
}

1;
__END__

=head1 NAME

Shaft::Role - define a role in Shaft

=head1 EXPORTED FUNCTIONS

=over 9

=item init_meta

=item Private $name => %options

=item Protected $name => %options

=item Public $name => %options

=item has $name => %options

=item with ($name, ... )

=item excludes ($name, ...);

=item requires ($name, ... )

=item before $name => sub { }

=item after $name => sub { }

=item around $name => sub { }

=item override $name => sub { }

=item super()

=item augment()

=item inner()

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
