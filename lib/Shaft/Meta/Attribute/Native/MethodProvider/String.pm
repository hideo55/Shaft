package Shaft::Meta::Attribute::Native::MethodProvider::String;
use Shaft::Role;

sub append : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer( \$_[0]->$reader() . \$_[1] ) }");
}

sub prepend : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub { \$_[0]->$writer( \$_[1] . \$_[0]->$reader() ) }");
}

sub replace : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub {
			my \$data = \$_[0]->$reader();
			( ref \$_[2] || '' ) eq 'CODE'
			 ? \$data =~ s/\$_[1]/\$_[2]->()/e
			 : \$data =~ s/\$_[1]/\$_[2]/;
			 \$_[0]->$writer(\$data);
		}"
	);
}

sub match : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure("sub { \$_[0]->$reader() =~ \$_[1] }");
}

sub chop : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub {
			my \$data = \$_[0]->$reader();
			chop \$data;
			\$_[0]->$writer(\$data);
		}"
	);
}

sub chomp : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub {
			my \$data = \$_[0]->$reader();
			chomp \$data;
			\$_[0]->$writer(\$data);
		}"
	);
}

sub inc : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure(
		"sub {
			my \$data = \$_[0]->$reader();
			\$data++;
			\$_[0]->$writer(\$data);
		}"
	);
}

sub clear : method {
	my ( $attr, $reader, $writer ) = @_;
	return $attr->make_eval_closure("sub { \$_[0]->$writer('') }");
}

sub length : method {
	my ($attr, $reader) = @_;
	return $attr->make_eval_closure("
		sub { 
			my \$v = \$_[0]->$reader();
			return CORE::length(\$v);
		}"
	);
}

sub substr : method {
	my ($attr, $reader, $writer) = @_;
	return $attr->make_eval_closure("
		sub { 
			my \$self = shift;
			my \$v = \$self->$reader();

			my \$offset      = defined \$_[0] ? shift : 0;
			my \$length      = defined \$_[0] ? shift : CORE::length(\$v);
			my \$replacement = defined \$_[0] ? shift : undef;

			my \$ret;
			if ( defined \$replacement ) {
				\$ret = CORE::substr( \$v, \$offset, \$length, \$replacement );
				\$self->$writer( \$v );
			}
			else {
				\$ret = CORE::substr( \$v, \$offset, \$length );
			}

			return \$ret;
		}"
	);
}

no Shaft::Role;
1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native::MethodProvider::String

=head1 PROVIDE METHODS

=over 4

=item inc

=item append($string)

=item prepend($string)

=item replace($patternm$replacement)

=item match($pattern)

=item chop

=item chomp

=item clear

=item length

=item substr

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut