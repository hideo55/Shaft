package Shaft::Meta::Attribute::Native::MethodProvider::Number;
use Shaft::Role;

sub set : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure("sub { \$_[0]->$writer( \$_[1] ) }");
}

sub add : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer( \$_[0]->$reader() + \$_[1] ) }");
}

sub sub : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer( \$_[0]->$reader() - \$_[1] ) }");
}

sub mul : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer( \$_[0]->$reader() * \$_[1] ) }");
}

sub div : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer( \$_[0]->$reader() / \$_[1] ) }");
}

sub mod {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer( \$_[0]->$reader() % \$_[1] ) }");
}

sub abs {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer( abs \$_[0]->$reader() ) }");
}

no Shaft::Role;
1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native::MethodProvider::Number

=head1 PROVIDE METHODS

=over 4

=item set($value)

=item add($value)

=item sub($value)

=item mul($value)

=item div($value)

=item mod($value)

=item abs

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut