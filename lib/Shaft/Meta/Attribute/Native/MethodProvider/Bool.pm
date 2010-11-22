package Shaft::Meta::Attribute::Native::MethodProvider::Bool;
use Shaft::Role;

sub set : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure("sub { \$_[0]->$writer(1) }");
}

sub unset : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure("sub { \$_[0]->$writer(0) }");
}

sub toggle : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer(!\$_[0]->$reader() ) }");
}

sub not : method {
	my ( $attr, $reader ) = @_;
	return return $attr->make_eval_closure("sub { !\$_[0]->$reader()   }");
}

no Shaft::Role;
1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native::MethodProvider::Bool

=head1 PROVIDE METHODS

=over 4

=item set

=item unset

=item toggle

=item not

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut