use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;
use Shaft::Util qw/throw_error/;

throws_ok { throw_error "TEST" } qr/^TEST/;

ok( defined $@ );
my $e = $@;
is $e->message, 'TEST';
ok( $e->stacktrace );
ok( defined( $e->frames ) && ref( $e->frames ) eq 'ARRAY' );
my $as_string = "$e";
is $as_string, $e->as_string;

throws_ok {throw_error} qr/^Died/;

throws_ok { Shaft::Exception::throw($e) } qr/^TEST/;

throws_ok{
	goto &Shaft::Exception::throw;
} qr/^Died/;

dies_ok { Shaft::Exception::throw( {} ) };

{

	package Exception::Test;
	our @ISA = qw(Shaft::Exception);
}

throws_ok { Exception::Test->throw('test') } qr/^test/;
$e = $@;
is $e->message, 'test';
ok( $e->stacktrace );
ok( defined( $e->frames ) && ref( $e->frames ) eq 'ARRAY' );
$as_string = "$e";
is $as_string, $e->as_string;

__END__