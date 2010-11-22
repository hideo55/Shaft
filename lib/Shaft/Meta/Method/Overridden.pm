package Shaft::Meta::Method::Overridden;
use strict;
use warnings;
use Shaft::Meta::Method::Generated;
use Shaft::Util qw(throw_error throw_warn);

our @ISA = qw(Shaft::Meta::Method::Generated);

sub new {
	my ( $class, %args ) = @_;

	my $super_package = $args{package} || $args{class}->name;

	my $name = $args{name};

	my $super = $args{class}->find_next_method_by_name($name)
	  or throw_error
	  "You cannot override '$name' because it has no super method";

	my $super_body = $super->body;
	my $method     = $args{method};

	no warnings 'once';
	my $body = sub {
		local $Shaft::SUPER_PACKAGE = $super_package;
		local @Shaft::SUPER_ARGS    = @_;
		local $Shaft::SUPER_BODY    = $super_body;
		return $method->(@_);
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

Shaft::Meta::Method::Overridden - 

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
