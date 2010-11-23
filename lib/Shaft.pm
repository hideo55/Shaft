package Shaft;
use 5.008;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Shaft::Util qw/throw_error throw_warn/;
use Shaft::MethodAttributes;
use Shaft::Meta::Class;
use Shaft::Meta::Role;
use Shaft::Meta::Attribute;
use Shaft::Object ();
use Shaft::Util::TypeConstraints;
use Shaft::Util::MetaRole;

use Shaft::Meta::Attribute::Native;

use Shaft::Exporter -setup => {
	with_meta => [
		qw/extends before after around override augment has Private Protected Public with/
	],
	exports => [
		qw/super inner/,            \&Scalar::Util::blessed,
		\&Shaft::Util::throw_error, \&Shaft::Util::throw_warn
	],
};

our $VERSION = "0.01";
$VERSION = eval $VERSION;

sub init_meta {

	if ( $_[0] ne __PACKAGE__ ) {
		return __PACKAGE__->init_meta(
			for_class  => $_[0],
			base_class => $_[1],
			metaclass  => $_[2],
		);
	}

	shift;
	my %args = @_;

	my $class = $args{for_class}
		or
		throw_error("Cannot call init_meta without specifying a for_class");
	my $base_class = $args{base_class} || 'Shaft::Object';
	my $metaclass  = $args{metaclass}  || 'Shaft::Meta::Class';

	throw_error(
		"The Metaclass $metaclass must be a subclass of Shaft::Meta::Class.")
		unless $metaclass->isa('Shaft::Meta::Class');

	class_type($class)
		unless find_type_constraint($class);

	my $meta;

	if ( $meta = Shaft::Util::class_of($class) ) {
		unless ( $meta->isa('Shaft::Meta::Class') ) {
			throw_error
				"$class already has a metaclass, but it does not inherit $metaclass ($meta)";
		}
	}
	else {
		my ( undef, @isa ) = @{ $class->mro::get_linear_isa };

		for my $super (@isa) {
			my $super_meta = Shaft::Util::class_of($super) or next;
			my $super_metaclass = blessed $super_meta;
			unless ( $metaclass->isa($super_metaclass) ) {
				if ( $super_metaclass->isa($metaclass) ) {
					$metaclass = $super_metaclass;
				}
			}
		}
		$meta = $metaclass->initialize($class);
	}

	if ( $class->can('meta') ) {
		my $method_meta = $class->meta;
		unless ( blessed($method_meta)
			&& $method_meta->isa('Shaft::Meta::Class') )
		{
			throw_error
				"$class already has a &meta function, but it does not return a Shaft::Meta::Class ($method_meta)";
		}
		$meta = $method_meta;
	}

	unless ( $meta->has_method('meta') ) {
		$meta->add_method(
			'meta' => sub { $metaclass->initialize( ref( $_[0] ) || $_[0] ) }
		);
	}

	$meta->superclasses($base_class)
		unless $meta->superclasses;

	return $meta;
}

sub extends {
	shift->superclasses(@_);
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
	my $meta = shift;
	my $name = shift;
	if ( ref $name ) {
		$meta->add_attribute( $_ => @_ ) foreach @$name;
	}
	else {
		$meta->add_attribute( $name => @_ );
	}
}

sub with {
	Shaft::Util::apply_all_roles( shift, @_ );
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

our $SUPER_PACKAGE;
our $SUPER_BODY;
our @SUPER_ARGS;

sub super {
	return if defined $SUPER_PACKAGE && $SUPER_PACKAGE ne caller();
	return unless $SUPER_BODY;
	$SUPER_BODY->(@SUPER_ARGS);
}

sub override {
	shift->add_override_method_modifier(@_);
}

sub inner {
	my $pkg = caller();
	our ( %INNER_BODY, %INNER_ARGS );

	if ( my $body = $INNER_BODY{$pkg} ) {
		my @args = @{ $INNER_ARGS{$pkg} };
		local $INNER_ARGS{$pkg};
		local $INNER_BODY{$pkg};
		return $body->(@args);
	}
	else {
		return;
	}
}

sub augment {
	shift->add_augment_method_modifier(@_);
}

1;
__END__

=head1 NAME

Shaft - yet another class builder that using inside-out object technique

=head1 SYNOPSIS

  package Foo;
  use Shaft;

  Public foo => ( is => 'ro' );
  Protected bar => ( is => 'ro' );
  Private baz => ( is => 'rw' );

  sub hoge : Protected {
      q{HOGE};
  }
  __PACKAGE__->meta->make_immutable;

  package Foo::Role;
  use Shaft::Role;

  requires 'hoge';

  package Qux;
  use Shaft -extends => 'Foo';

  with 'Foo::Role';

  sub quxx {
      print shift->hoge;
  }
  __PACKAGE__->meta->make_immutable;

=head1 DESCRIPTION

Shaft is yet another class builder that using inside-out object technique

=head1 EXPORTED FUNCTIONS

=over 4

=item extends => ...

=item Private $name => %options

=item Protected $name => %options

=item Public $name => %options

=item has $name => %options

=item with ($name, ... )

=item before $name => sub { }

=item after $name => sub { }

=item around $name => sub { }

=item override $name => sub { }

=item super()

=item augment $name => sub { }

=item inner()

=item init_meta ( for_class => ... , base_class => ... , metaclass => ... )

=item throw_error

=item throw_warn

=back

=head1 METHODS

=over 4

=item new

=item clone

=item DESTROY

=item add_method( $name => sub { } )

=item remove_method $name

=item add_hook( $hook_point => sub {} )

=item call_hook( $hook_point )

=item call_hook_reverse( $hook_point )

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
