package Shaft::Meta::Attribute::Native::MethodProvider::Counter;
use Shaft::Role;

sub set : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure("sub { \$_[0]->$writer( \$_[1] ) }");
}


sub reset : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub {
			\$_[0]->$writer(\$attr->default(\$_[0]));
		}"
	);
}

sub inc : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub {
			\$_[0]->$writer(
				\$_[0]->$reader() + ( defined(\$_[1]) ? \$_[1] : 1 ) 
			);
		}"
	);
}

sub dec : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub {
			\$_[0] ->$writer( \$_[0]->$reader - ( defined(\$_[1]) ? \$_[1] : 1 ) );
		}"
	);
}

no Shaft::Role;
1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native::MethodProvider::Counter

=head1 PROVIDE METHODS

=over 4

=item set($value)

=item reset

=item inc($value)

=item dec($value)

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut