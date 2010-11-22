use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo::Role;
	use Shaft::Role;

	after hoge => sub {
		$_[0]->foo( $_[0]->foo . '[AFTER]' );
	};
				
	package Foo;
	use Shaft;
	
	with 'Foo::Role';
	
	Public foo => ( is => 'rw' );
	
	sub hoge {
		$_[0]->foo('[BODY]');
	}
	
}

my $foo = Foo->new;
$foo->hoge;

ok( $foo->foo eq '[BODY][AFTER]');
isa_ok( Foo->meta->get_method('hoge'), 'Shaft::Meta::Method::Wrapped');
Foo->meta->remove_method('hoge');

done_testing;