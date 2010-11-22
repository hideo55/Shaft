package Shaft::Meta::Role::Composite;
use Shaft::Util qw(throw_error);
use Scalar::Util qw(blessed);
use Shaft::Meta::Role;
our @ISA = qw(Shaft::Meta::Role);

{
	my %meta;

	sub BUILD {
		my ( $self, $args ) = @_;
		$meta{$$self} = {
			composed_roles_by_method => {},
			conflicting_methods      => {},
			methods					 => {},
			override_method_modifier => {},
		};
	}
	
	sub DESTROY {
		return if $_[1];
		my $self = shift;
		delete $meta{$$self};
	}
	
	sub get_method_list {
		my $self = shift;
		return keys %{ $meta{$$self}{methods} };
	}

	sub add_method {
		my ( $self, $method_name, $code, $role ) = @_;
		
		my $code_ref = blessed $code ? $code->body : $code;
		my $existing = $meta{$$self}{methods}{$method_name};
		$existing = $existing ? $existing->body : 0;
		if ( $existing == $code_ref ) {
			# This role already has the same method.
			return;
		}

		if ( $method_name ne 'meta' ) {
			my $roles = $meta{$$self}{composed_roles_by_method}{$method_name}
				||= [];
			push @{$roles}, $role;
			if ( @{$roles} > 1 ) {
				$meta{$$self}{conflicting_methods}{$method_name}++;
			}
			$meta{$$self}{methods}{$method_name} = $code;
		}else{
			$self->SUPER::add_method( $method_name => $code );
		}
		# no need to add a subroutine to the stash
		return;
	}
	
	sub get_method {
		my ($self, $name) = @_;
		return $meta{$$self}{methods}{$name};
	}
	
	sub get_method_body {
		my ($self, $name) = @_;
		my $method = $meta{$$self}{methods}{$name};
		return $method ? $method->body : undef;
	}

	sub _check_required_methods {
		my ( $role, $consumer, $args ) = @_;
		if ( $args->{_to} eq 'role' ) {
			$consumer->add_required_methods(
				$role->get_required_method_list );
		}
		else {
			my $consumer_class_name = $consumer->name;
			my @missing;
			for my $name ( $role->get_required_method_list ) {
				next if $meta{$$role}{methods}{$name};
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

	sub has_method {

		# my($self, $method_name) = @_;
		return 0;    # to fool _apply_methods() in combine()
	}

	sub has_attribute {

		# my($self, $method_name) = @_;
		return 0;    # to fool _appply_attributes() in combine()
	}

	sub has_override_method_modifier {

		# my($self, $method_name) = @_;
		return 0;    # to fool _apply_modifiers() in combine()
	}

	sub add_attribute {
		my $self      = shift;
		my $attr_name = shift;
		my $spec      = ( @_ == 1 ? $_[0] : {@_} );
		my $existing = $self->get_attribute($attr_name);
		if ( $existing && $existing != $spec ) {
			throw_error(
				"We have encountered an attribute conflict with '$attr_name' "
					. "during composition. This is fatal error and cannot be disambiguated."
			);
		}
		$self->SUPER::add_attribute( $attr_name, $spec );
		return;
	}

	sub add_override_method_modifier {
		my ( $self, $method_name, $code ) = @_;

		my $existing = $self->get_override_method_modifier($method_name);
		if ( $existing && $existing != $code ) {
			throw_error(
				"We have encountered an 'override' method conflict with '$method_name' during "
					. "composition (Two 'override' methods of the same name encountered). "
					. "This is fatal error." );
		}
		$self->SUPER::add_override_method_modifier( $method_name, $code );
		return;
	}

	# components of apply()

	sub _apply_methods {
		my ( $self, $consumer, $args ) = @_;

		if ( scalar( keys %{$meta{$$self}{conflicting_methods}} ) ) {
			my $consumer_class_name = $consumer->name;

			my @conflicting = grep { !$consumer_class_name->can($_) }
				keys %{ $meta{$$self}{conflicting_methods} };

			if ( @conflicting == 1 ) {
				my $method_name = $conflicting[0];
				my $roles       = Shaft::Util::quoted_english_list(
					map { $_->name } @{
						$meta{$$self}{composed_roles_by_method}{$method_name}
						}
				);
				throw_error(
					sprintf
						q{Due to a method name conflict in roles %s, the method '%s' must be implemented or excluded by '%s'},
					$roles, $method_name, $consumer_class_name );
			}
			elsif( @conflicting > 1 ){
				my %seen;
				my $roles = Shaft::Util::quoted_english_list(
					grep    { !$seen{$_}++ }    # uniq
						map { $_->name }
						map { @{$_} }
						@{ $meta{$$self}{composed_roles_by_method} }
						{@conflicting}
				);

				throw_error(
					sprintf
						q{Due to method name conflicts in roles %s, the methods %s must be implemented or excluded by '%s'}
					,
					$roles,
					Shaft::Util::quoted_english_list(@conflicting),
					$consumer_class_name
				);
			}
		}

		$self->SUPER::_apply_methods( $consumer, $args );
		return;
	}
}
1;
__END__

=head1 NAME

Shaft::Meta::Role::Composite

=head1 METHODS

=over 4

=item add_method

=item get_method

=item get_method_body

=item get_method_list

=item has_method

=item add_attribute

=item has_attribute

=item add_override_method_modifier

=item has_override_method_modifier

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut