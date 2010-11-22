package Shaft::Meta::Method;
use strict;
use warnings;
use Shaft::Util qw/:meta throw_error/;
use Scalar::Util qw/refaddr weaken/;

use Shaft::Object;
our @ISA = qw(Shaft::Object);

use overload '&{}' => sub { $_[0]->body }, fallback => 1;

{
	my %_meta;

	sub new {
		goto &wrap;
	}

	sub wrap {
		my ( $class, @args ) = @_;

		unshift @args, 'body' if @args % 2 == 1;

		my %params = @args;
		my $code   = $params{body};
		if ( ref($code) ne 'CODE' ) {
			throw_error "You must supply a CODE reference to bless, not ("
				. ( $code || 'undef' ) . ")";
		}

		( $params{package_name} && $params{name} )
			|| throw_error
			"You must supply the package_name and name parameters";

		my $self = $class->_new( \%params );

		weaken( $_meta{$$self}{associated_metaclass} )
			if $_meta{$$self}{associated_metaclass};

		return $self;
	}

	sub _new {
		my $class = shift;
		$class = ref($class) if ref($class);
		my $params = @_ > 1 ? {@_} : $_[0];

		my $self = $class->Shaft::Object::new_object();

		$_meta{$$self} = +{
			name                 => $params->{name},
			package_name         => $params->{package_name},
			associated_metaclass => $params->{associated_metaclass},
			body                 => $params->{body},
			original_method      => $params->{original_method},
		};

		return $self;
	}

	sub DEMOLISH {
		return if $_[1];
		delete $_meta{${$_[0]}};
	}

	sub name {
		$_meta{ ${ $_[0] } }{name};
	}

	sub package_name {
		$_meta{ ${ $_[0] } }{package_name};
	}

	sub body {
		$_meta{ ${ $_[0] } }{body};
	}

	sub associated_metaclass {
		$_meta{ ${ $_[0] } }{associated_metaclass};
	}

	sub clone {
		my $self = shift;
		my %params = ( %{ $_meta{$$self} }, @_ );
		$params{original_method} = $self;
		return $self->_new(%params);
	}

	sub attach_to_class {
		weaken( $_meta{ ${ $_[0] } }{associated_metaclass} = $_[1] );
	}

	sub detach_from_class {
		my $self = shift;
		delete $_meta{$$self}{associated_metaclass};
	}

	sub original_method {
		my $self = shift;
		$_meta{$$self}{original_method};
	}

}

sub fully_qualified_name {
	my $self = shift;
	$self->package_name . '::' . $self->name;
}

sub original_package_name {
	my $self = shift;
	$self->original_method
		? $self->original_method->original_package_name
		: $self->package_name;
}

sub original_name {
	my $self = shift;
	$self->original_method
		? $self->original_method->original_name
		: $self->name;
}

sub original_fully_qualified_name {
	my $self = shift;
	$self->original_method
		? $self->original_method->original_fully_qualified_name
		: $self->fully_qualified_name;
}

sub execute {
	my $self = shift;
	$self->body->(@_);
}

1;
__END__

=head1 NAME

Shaft::Meta::Method - 

=head1 METHODS

=over 4

=item new

=item wrap

=item associated_metaclass()

=item attach_to_class

=item body

=item clone

=item detach_from_class

=item execute

=item fully_qualified_name

=item name

=item package_name

=item original_fully_qualified_name

=item original_method

=item original_name

=item original_package_name

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
