use strict;
use warnings;
use Test::More;
use Test::Exception;

throws_ok{
	package Foo1;
	use Shaft::Role;
	
	sub foo {}
	
	sub bar {}
	
	no Shaft::Role;
	package Bar1;
	use Shaft::Role;
	
	sub bar {}
	
	no Shaft::Role;
	
	package Baz1;
	use Shaft;
	
	with 'Foo1', 'Bar1';
	
	no Shaft;
	__PACKAGE__->meta->make_immutable;
} qr/^Due to a method name conflict in roles/;


lives_ok {
	package Foo2;
	use Shaft::Role;
	
	sub foo {}
	
	sub bar {}
	
	no Shaft::Role;
	package Bar2;
	use Shaft::Role;
	
	sub bar {}
	
	no Shaft::Role;
	
	package Baz2;
	use Shaft;
	
	with 'Foo2', 'Bar2' => { -alias => { bar => 'baz' }, -excludes =>['bar'] };
	
	no Shaft;
	__PACKAGE__->meta->make_immutable;
};

can_ok('Baz2','foo');
can_ok('Baz2','bar');
can_ok('Baz2','baz');
ok(Baz2->can('baz') == Bar2->can('bar'));

{
	package Foo3;
	use Shaft::Role;
	
	sub foo {}
	
	sub bar {}
	
	no Shaft::Role;
	package Bar3;
	use Shaft::Role;
	
	sub bar {}
	
	no Shaft::Role;
	
	package Baz3;
	use Shaft;
	
	with 'Foo3', 'Bar3' => { -alias => { bar => 'baz' }, -excludes => 'bar' };
	
	no Shaft;
	__PACKAGE__->meta->make_immutable;
}

can_ok('Baz3',qw/foo bar baz/);

throws_ok {
	package Foo4;
	use Shaft::Role;
	
	sub foo {}
	
	sub bar {}
	
	sub baz {}
	
	no Shaft::Role;
	package Bar4;
	use Shaft::Role;
	
	sub foo {}
	
	sub bar {}
	
	sub baz {}
	
	no Shaft::Role;
	
	package Baz4;
	use Shaft;
	
	with 'Foo4', 'Bar4';
} qr/^Due to method name conflicts in roles 'Foo4' and 'Bar4', the methods (?:.*?) must be implemented or excluded by 'Baz4'/;

throws_ok {
	package Foo5;
	use Shaft::Role;
	
	sub foo {}
	
	no Shaft::Role;
	package Bar5;
	use Shaft::Role;
	
	sub foo {}
	
	no Shaft::Role;
	
	package Baz5;
	use Shaft;
	
	with 'Foo5', 'Bar5';
} qr/^Due to a method name conflict in roles 'Foo5' and 'Bar5', the method 'foo' must be implemented or excluded by 'Baz5'/;

lives_ok {
	package Foo6;
	use Shaft::Role;

	sub foo { 1 }

	package Bar6;
	use Shaft::Role;

	sub foo { 1 }

	package Baz6;
	use Shaft;

	with qw(Foo6 Bar6);

	sub foo { 1 }
};

done_testing;