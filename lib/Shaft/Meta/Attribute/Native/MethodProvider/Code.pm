package Shaft::Meta::Attribute::Native::MethodProvider::Code;
use Shaft::Role;

sub execute : method {
	my ($attr, $reader) = @_;
	return $attr->make_eval_closure("sub{
		my (\$self,\@args) = \@_;
		\$self->$reader()->(\@args);
	}");
}

sub execute_method : method {
	my ($attr, $reader) = @_;
	return $attr->make_eval_closure("sub{
		my (\$self,\@args) = \@_;
		\$self->$reader()->(\$self,\@args);
	}");
}

no Shaft::Role;
1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native::MethodProvider::Code

=head1 PROVIDE METHODS

=over 4

=item execute

=item execute_method

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut