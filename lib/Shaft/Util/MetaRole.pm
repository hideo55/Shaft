package Shaft::Util::MetaRole;
use strict;
use warnings;

my @Classes = qw(constructor_class destructor_class);

sub apply_metaclass_roles {
	my %options  = @_;
	my $for      = $options{for_class};
	my $old_meta = $for->meta;
	my %old_classes
		= map { $_ => $old_meta->$_ } grep { $old_meta->can($_) } @Classes;

	my $meta = _make_new_metaclass( $for, \%options );

	for my $c ( grep { $meta->can($_) } @Classes ) {
		if ( $options{ $c . '_roles' } ) {
			my $class
				= _make_new_class( $meta->$c(), $options{ $c . '_roles' } );
			$meta->$c($class);
		}
		else {
			$meta->$c( $old_classes{$c} );
		}
	}

	return $meta;
}

sub _make_new_metaclass {
	my $for     = shift;
	my $options = shift;

	return $for->meta
		unless grep { exists $options->{ $_ . '_roles' } }
			qw(metaclass attribute_metaclass method_metaclass wrapped_method_metaclass);

	my $old_meta = $for->meta;

	my $new_metaclass
		= _make_new_class( ref $old_meta, $options->{metaclass_roles} );

	my %metaclasses = map {
		$_ => _make_new_class( $old_meta->$_(), $options->{ $_ . '_roles' } )
	} qw(attribute_metaclass method_metaclass wrapped_method_metaclass);

	return $new_metaclass->reinitialize( $for, %metaclasses );
}

sub apply_base_class_roles {
	my %options = @_;

	my $for = $options{for_class};

	my $meta = $for->meta;

	my $new_base
		= _make_new_class( $for, $options{roles}, [ $meta->superclasses() ],
		);

	$meta->superclasses($new_base)
		if $new_base ne $meta->name();
}

sub _make_new_class {
	my $class        = shift;
	my $roles        = shift;
	my $superclasses = shift || [$class];

	return $class unless $roles;

	my $meta = Shaft::Meta::Class->initialize($class);

	return $class
		if !grep { !ref($_) && !$meta->does_role($_) }
		@{$roles};

	return Shaft::Meta::Class->create_anon_class(
		superclasses => $superclasses,
		roles        => $roles,
		cache        => 1
	)->name;

}

1;
__END__

=head1 NAME

Shaft::Util::MetaRole - 

=head1 FUNCTIONS

=over 4

=item apply_base_class_roles

=item apply_metaclass_roles

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
