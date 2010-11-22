use strict;
use warnings;
use Test::More;
use Test::Exception;
{

	package Foo;
	use Shaft;

	has 'foo'  => ( is => 'rw', clearer => 'clear_foo' );
	has 'bar'  => ( is => 'rw', clear   => 1 );
	has '_baz' => ( is => 'rw', clear   => 1 );
	has 'qux'  => ( is => 'rw', clear   => 1, clearer => '_clear_qux' );
	
	Private 'hoge' => ( is => 'rw', clear => 1 );
	Protected 'fuga' => ( is => 'rw', clear => 1 );
	
	sub private{
		shift->clear_hoge;
	}
	
	package Bar;
	use Shaft -extends => 'Foo';
	
	sub protected {
		shift->clear_fuga;
	}
	
}

my $foo = Foo->new;
can_ok $foo, 'clear_foo';
$foo->foo(100);
is $foo->foo, 100;
$foo->clear_foo;
is $foo->foo, undef;

can_ok( 'Foo', qw/clear_foo clear_bar _clear_baz _clear_qux clear_hoge clear_fuga/ );

lives_ok {
	$foo->private;
};

lives_ok {
	Bar->new->protected;
};

throws_ok {
	$foo->clear_hoge;
} qr/^clear_hoge\(\) is private method/;

throws_ok {
	$foo->clear_fuga;
} qr/^clear_fuga\(\) is protected method/;

done_testing;
