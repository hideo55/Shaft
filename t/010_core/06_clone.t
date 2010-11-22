use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	
	Public a => ( is => 'rw' );
	Public b => ( is => 'rw' );
	
	sub call{
		shift->call_hook(shift);
	}
	
}

my $f1 = Foo->new({ a => {  a => 'b', c => 'd' }, b => 2 });
$f1->add_singleton_method( c => sub{ 'f1' });
$f1->add_hook( 'foo' => sub{ 1 } );
$f1->add_hook( 'foo' => sub{ 2 } );
$f1->add_hook( 'foo' => sub{ 3 } );
my $f2 = $f1->clone;

isa_ok($f2, 'Foo');
ok($f2->b == 2);
my $a = $f2->a;
ok($a->{a} eq 'b');
ok($a->{c} eq 'd');
can_ok($f2,'c');
ok($f2->c eq 'f1');
my @res = $f2->call('foo');
is_deeply(\@res,[1,2,3]);

throws_ok {
	Foo->clone;
} qr/^clone\(\) is instance method/;

done_testing;