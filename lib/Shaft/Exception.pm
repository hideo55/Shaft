package Shaft::Exception;
use strict;
use warnings;
use overload (
	q{""}    => sub { $_[0]->as_string },
	fallback => 1
);

sub new {
	my ( $class, $message ) = @_;
	$message ||= 'Died';
	require Devel::StackTrace;
	my $stack = Devel::StackTrace->new(
		ignore_package   => ['Shaft::Exception'],
		no_refs          => 1,
		respect_overload => 1
	);
	my $self = {
		message    => $message,
		stacktrace => $stack->as_string,
		frames     => [ $stack->frames ],
	};
	bless $self, $class;
	return $self;
}

sub message {
	shift->{message};
}

sub stacktrace {
	shift->{stacktrace};
}

sub frames {
	shift->{frames};
}

sub throw {
	my ($class, $message) = @_;
	if( !defined $message ){
		$message = $class;
		$class = 'Shaft::Exception';
	}
	my $exception;
	if ( ref($message) && $message->isa('Shaft::Exception') ) {
		$exception = $message;
	}
	else {
		$exception = $class->new($message);
	}
	die $exception;
}

sub as_string {
	my $self   = shift;
	my $caller = scalar(@{$self->frames}) > 1 ? $self->frames->[1] : $self->frames->[0];
	sprintf( "%s at %s line %s\n",
		$self->message, $caller->filename, $caller->line );
}

1;
__END__

=head1 NAME

Shaft::Exception - Exception class for Shaft

=head1 EXPORTED FUNCTIONS

=over 4

=item throw

=back

=head1 METHODS

=over 4

=item new

=item as_string

=item message

=item stacktrace

=item frames

=item create_exception_class

=back

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
