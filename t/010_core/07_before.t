use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	
	Public foo => ( is => 'rw' );
	
	sub hoge {
		$_[0]->foo( $_[0]->foo . '[BODY]');
	}
	
	before hoge => sub {
		$_[0]->foo('[BEFORE]');
	};
}

ok( Foo->new->hoge eq '[BEFORE][BODY]');
isa_ok( Foo->meta->get_method('hoge'), 'Shaft::Meta::Method::Wrapped');
Foo->meta->remove_method('hoge');

throws_ok{
	package Bar;
	use Shaft;
	
	sub hoge { 1 }
	
	before sub{ 1 };
	
} qr/^You must pass in a method name/;

done_testing;
