package Shaft::Meta::Method::Wrapped;
use strict;
use warnings;
use Shaft::Meta::Method;
use Scalar::Util qw(blessed);
use Shaft::Util qw(throw_error);
use Data::Util ();

our @ISA = qw(Shaft::Meta::Method);

sub new {
	goto &wrap;
}

{

	my %_meta;
	
	my $build_modifiers = sub {
		my ( $self, $type, $code ) = @_;
		my $method = $_meta{$$self}{modifier_table}{cache};
		if ( !Data::Util::subroutine_modifier($method) ) {
			$_meta{$$self}{modifier_table}{cache}
				= Data::Util::modify_subroutine( $method, $type => [$code] );
		}
		else {
			Data::Util::subroutine_modifier( $method, $type => $code );
		}
	};

	sub wrap {
		my ( $class, $code, %params ) = @_;

		unless ( blessed($code) && $code->isa('Shaft::Meta::Method') ) {
			throw_error "Can only wrap blessed CODE";
		}

		my $table = {
			orig   => $code,
			cache  => $code->body,
		};

		my $method = $class->SUPER::wrap(
			sub {
				$table->{cache}->(@_);
			},
			package_name => $params{package_name} || $code->package_name,
			name         => $params{name}         || $code->name,
		);

		$_meta{$$method} = { modifier_table => $table, };

		return $method;
	}

	sub clone {
		my $self  = shift;
		my $clone = $self->next::method(@_);
		$_meta{$$clone} = Clone::clone($_meta{$$self});
		return $clone;
	}

	sub DEMOLISH {
		return if $_[1];
		delete $_meta{ ${ $_[0] } };
	}

	sub add_before_modifier {
		my ( $self, $code ) = @_;
		$build_modifiers->( $self, 'before', $code );
	}

	sub add_after_modifier {
		my ( $self, $code ) = @_;
		$build_modifiers->( $self, 'after', $code );
	}

	sub add_around_modifier {
		my ( $self, $code ) = @_;
		$build_modifiers->( $self, 'around', $code );
	}

	sub original_method {
		return $_meta{ ${ $_[0] } }{modifier_table}{orig};
	}

}
1;
__END__

=head1 NAME

Shaft::Meta::Method::Wrapped - 

=head1 METHODS

=over 4

=item new

=item add_before_modifier

=item add_after_modifier

=item add_around_modifier

=item clone

=item original_method

=item wrap

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
