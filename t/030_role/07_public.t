use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo::Role;
	use Shaft::Role;
	Public foo => ( is => 'rw', default => 1 );
	Public [qw/bar baz/] => ( is => 'ro', default => 'ro' );
	has hoge => ( is => 'rw', default => 2);
	has [qw/fuga piyo/] => ( is => 'ro', default => 'ok' );
	
	sub public : Public{ 1 };
	
	package Foo;
	use Shaft;
	
	with 'Foo::Role';

	our $VERSION = '0.01';
	
	sub attr{
		return $_[0]->foo(2);
	}
	
	sub meth{
		return $_[0]->public();
	}

	package Bar;
	use Shaft -extends => 'Foo';
	our $VERSION = '0.01';
	
	sub attr{
		return $_[0]->foo(3);
	}
	
	sub meth{
		return $_[0]->public();
	}
	
	package Baz;
	use Shaft;
	
	sub attr{
		return $_[0]->foo(4);
	}
	
	sub meth{
		return $_[0]->public();
	}
	
}


my $attr= sub{
	return $_[0]->foo(5);
};

my $meth = sub{
	return $_[0]->public();
};

my $foo = Foo->new;

can_ok('Foo',qw/public foo bar baz hoge fuga piyo/);

ok($foo->attr == 2,'Access public attribute from inside same class');
ok($foo->meth,'Call public method from inside same class');
ok(Bar::attr($foo) == 3 ,'Access public attribute from sub class');
ok(Bar::meth($foo),'Call public method from sub class');
ok(Baz::attr($foo) == 4,'Access public attribute from other class');
ok(Baz::meth($foo),'Call public method from successor class');
ok($attr->($foo) == 5,'Access public attribute from non-class');
ok($meth->($foo),'Call public method from non-class');


done_testing;