package Shaft::Meta::Method::Augmented;
use strict;
use warnings;
use Shaft::Meta::Method::Generated;
use Shaft::Util qw(throw_error throw_warn);

our @ISA = qw(Shaft::Meta::Method::Generated);

sub new {
	my ( $class, %args ) = @_;
	my $name = $args{name};
	my $meta = $args{class};

	my $super = $meta->find_next_method_by_name($name);

	( defined $super )
	  or throw_error
	  "You cannot augment '$name' because it has no super method";

	my $_super_package = $super->package_name;

	if ( $super->isa('Shaft::Meta::Method::Overridden') ) {
		my $real_super =
		  $meta->_find_next_method_by_name_which_is_not_overridden($name);
		$_super_package = $real_super->package_name;
	}

	my $super_body = $super->body;

	my $method = $args{method};

	no warnings 'once';
	my $body = sub {
		local $Shaft::INNER_ARGS{$_super_package} = [@_];
		local $Shaft::INNER_BODY{$_super_package} = $method;
		$super_body->(@_);
	};
	
	$class->wrap(
		$body,
		package_name => $args{class}->name,
		name         => $name
	);
}

1;
__END__

=head1 NAME

Shaft::Meta::Method::Augmented - 

=head1 METHODS

=over 4

=item new

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
