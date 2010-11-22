package Shaft::Meta::TypeConstraint;
use strict;
use warnings;
use Shaft::Util qw(:meta throw_error);
use Scalar::Util qw(blessed refaddr);
use Sub::Name qw(subname);

use Shaft::Object;
our @ISA = qw(Shaft::Object);

use overload
	'bool' => sub {1},
	q{""}  => sub { shift->name },
	'|'    => sub {
	require Shaft::Util::TypeConstraints;
	Shaft::Util::TypeConstraints::find_or_create_type_constraint(
		"$_[0] | $_[1]");
	},
	fallback => 1;

my $null_constraint = sub {1};

{
	my %objects;

	sub BUILD {
		my $self = shift;
		my $args = shift;

		$objects{$$self} = $args;
		my $compiled = $self->_compile_constraint;
		$objects{$$self}->{_compiled_type_constraint} = $compiled;

		if ( $self->is_union ) {    # Union
			my @coercions;
			foreach my $type ( $self->type_constraints ) {
				if ( $type->has_coercion ) {
					push @coercions, $type;
				}
			}
			if (@coercions) {
				$objects{$$self}->{_compiled_type_coercion} = sub {
					my ($thing) = @_;
					foreach my $type (@coercions) {
						my $value = $type->coerce($thing);
						return $value if $self->check($value);
					}
					return $thing;
				};
			}
		}

		return $self;
	}

	sub DEMOLISH {
		return if $_[1];
		delete $objects{ ${ $_[0] } };
	}

	sub name { $objects{ ${ $_[0] } }{name} }

	sub package_defined_in {
		$objects{ ${ $_[0] } }{package_defined_in};
	}

	sub message { $objects{ ${ $_[0] } }{message} }

	sub has_message { defined $objects{ ${ $_[0] } }{message} }

	sub _compiled_type_constraint {
		$objects{ ${ $_[0] } }{_compiled_type_constraint};
	}

	sub constraint {
		return $objects{ ${ $_[0] } }{constraint};
	}

	sub parent {
		$objects{ ${ $_[0] } }{parent};
	}

	sub has_parent {
		defined $objects{ ${ $_[0] } }{parent};
	}

	sub optimized_type_constraint {
		$objects{ ${ $_[0] } }{optimized_type_constraint};
	}

	sub has_optimized_type_constraint {
		exists $objects{ ${ $_[0] } }{optimized_type_constraint};
	}

	sub type_constraints {
		my $self = shift;
		exists $objects{$$self}{type_constraints}
			? @{ $objects{$$self}{type_constraints} }
			: ();
	}

	sub is_union {
		$objects{ ${ $_[0] } }{union};
	}
	
	sub type_parameter {
		my $self = shift;
		$objects{$$self}{type_parameter};
	}
	
	sub is_parameterized {
		$objects{ ${ $_[0] } }{parameterized};
	}

	sub has_coercion {
		exists $objects{ ${ $_[0] } }{_compiled_type_coercion};
	}

	sub _compiled_type_coercion {
		$objects{ ${ $_[0] } }{_compiled_type_coercion};
	}

	sub _add_type_coercions {
		my $self = shift;
		my %conf = @_;

		my $coercions = ( $objects{$$self}{_coercion_map} ||= [] );
		my %has = map { $_->[0] => undef } @{$coercions};
		while ( my ( $from, $code ) = each %conf ) {
			throw_error "A coercion action already exists for '$from'"
				if exists $has{$from};

			my $type
				= Shaft::Util::TypeConstraints::find_or_create_type_constraint(
				$from)
				or throw_error
				"Could not find the type constraint ($from) to coerce from";

			push @{$coercions}, [ $type => $code ];
		}
		if ( $self->is_union ) {
			throw_error "Cannot add additional type coercions to Union types";
		}
		else {
			$objects{$$self}->{_compiled_type_coercion} = sub {
				my ($thing) = @_;
				foreach my $pair ( @{$coercions} ) {
					if ( $pair->[0]->_compiled_type_constraint->($thing) ) {
						local $_ = $thing;
						return $pair->[1]->($thing);
					}
				}
				return $thing;
			};
		}
	}
}

sub BUILDARGS {
	my $class = shift;
	my %args  = @_;
	$args{name} ||= '__ANON__';
	my $check
		= defined( $args{constraint} )
		? $args{constraint}
		: $null_constraint;

	if ( blessed($check) && $check->isa('Shaft::Meta::TypeConstraint') ) {
		$check
			= $check->has_optimized_type_constraint
			? $check->optimized_type_constraint
			: $check->constraint;
	}

	if ( ref($check) ne 'CODE' ) {
		throw_error "You must supply CODE reference as constraint";
	}
	
	$args{constraint} = $check;
	$args{package_defined_in} ||= caller(1);
	
	if ( exists $args{type_constraints} )
	{
		$args{union} = 1;
	}
	
	if( exists $args{type_parameter} ){
		$args{parameterized} = 1;
	}
	
	if ( exists $args{optimized} && defined $args{optimized} ) {
		$args{optimized_type_constraint} = delete $args{optimized};
	}
	return \%args;
}

sub check {
	my $self = shift;
	$self->_compiled_type_constraint->(@_);
}

sub coerce {
	my $self = shift;

	my $coercion = $self->_compiled_type_coercion;
	if ( !$coercion ) {
		throw_error("Cannot coerce without a type coercion");
	}

	return $_[0] if $self->_compiled_type_constraint->(@_);

	return $coercion->(@_);
}

sub get_message {
	my ( $self, $value ) = @_;
	if ( my $msg = $self->message ) {
		local $_ = $value;
		return $msg->($value);
	}
	else {
		$value = ( defined $value ? overload::StrVal($value) : 'undef' );
		return
			  "Validation failed for '"
			. $self->name
			. "' failed with value '$value'";
	}
}

sub equals {
	my ( $self, $type_or_name ) = @_;

	my $other
		= Shaft::Util::TypeConstraints::find_type_constraint($type_or_name)
		or return;

	return 1 if refaddr($self) == refaddr($other);
	
	return
		unless $self->_compiled_type_constraint == $other->_compiled_type_constraint;

	if ( $self->has_parent ) {
		return unless $other->has_parent;
		return unless $self->parent->equals( $other->parent );
	}
	else {
		return if $other->has_parent;
	}

	return 1;

}

sub is_a_type_of {
	my ( $self, $type_or_name ) = @_;

	my $other
		= Shaft::Util::TypeConstraints::find_type_constraint($type_or_name)
		or return;

	( $self->equals($other) || $self->is_subtype_of($other) );
}

sub is_subtype_of {
	my ( $self, $type_or_name ) = @_;

	my $other
		= Shaft::Util::TypeConstraints::find_type_constraint($type_or_name)
		or return;

	if ( $self->is_union ) {
		foreach my $type ( $self->type_constraints ) {
			return 1 if $type->is_a_type_of($other);
		}
	}

	my $current = $self;

	while ( my $parent = $current->parent ) {
		return 1 if $parent->equals($other);
		$current = $parent;
	}

}

sub _compile_constraint {
	my $self = shift;

	return $self->_compile_optimized_type_constraint
		if $self->has_optimized_type_constraint;

	my $check = $self->constraint;
	return $self->_compile_subtype($check) if $self->has_parent;
	return $self->_compile_type($check);
}

sub _compile_type {
	my ( $self, $check ) = @_;

	return $check if $check == $null_constraint;

	return subname(
		$self->name => sub {
			my (@args) = @_;
			local $_ = $args[0];
			$check->(@args);
		}
	);

}

sub _compile_subtype {
	my ( $self, $check ) = @_;

	my @parents;
	my $optimized_parent;
	for my $parent ( $self->_collect_all_parents ) {
		if ( $parent->has_optimized_type_constraint ) {
			push @parents => $optimized_parent
				= $parent->optimized_type_constraint;
			last;
		}
		else {
			push @parents => $parent->_compiled_type_constraint;
		}
	}

	@parents = grep { $_ != $null_constraint } reverse @parents;

	unless (@parents) {
		return $self->_compile_type($check);
	}
	elsif ( $optimized_parent and @parents == 1 ) {

		if ( $check == $null_constraint ) {
			return $optimized_parent;
		}
		else {
			return subname(
				$self->name,
				sub {
					return unless $optimized_parent->( $_[0] );
					my @args = @_;
					local $_ = $args[0];
					$check->(@args);
				}
			);
		}
	}
	else {
		my @checks = @parents;
		push @checks, $check if $check != $null_constraint;
		return subname(
			$self->name => sub {
				my (@args) = @_;
				local $_ = $args[0];
				foreach my $check (@checks) {
					return unless $check->(@args);
				}
				return 1;
			}
		);
	}

}

sub _compile_optimized_type_constraint {
	my $self = shift;

	my $type_constraint = $self->optimized_type_constraint;

	unless ( ref $type_constraint ) {
		throw_error "Optimized type constraint for "
			. $self->name
			. " is not a code reference";
	}
	return $type_constraint;
}

sub _collect_all_parents {
	my $self = shift;
	my @parents;
	my $current = $self->parent;
	while ( defined $current ) {
		push @parents, $current;
		$current = $current->parent;
	}
	return @parents;
}

sub create_child_type {
	my ( $self, %opts ) = @_;
	my $class = ref $self;
	return $class->new( %opts, parent => $self );
}

__PACKAGE__->meta->make_immutable;
__END__

=head1 NAME

Shaft::Meta::TypeConstraint - 

=head1 METHODS

=over 4

=item check

=item get_message

=item message

=item has_message

=item name

=item constraint

=item create_child_type

=item equals

=item is_a_type_of

=item is_subtype_of

=item optimized_type_constraint

=item has_optimized_type_constraint

=item parent

=item has_parent

=item coerce

=item has_coercion

=item is_union

=item type_constraints

=item package_defined_in

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
