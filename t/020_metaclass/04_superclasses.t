use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	
	package Bar;
	use Shaft;

	package Baz;
	use Shaft;

	package Qux;
	use Shaft;
}

lives_ok { Foo->meta->superclasses('Bar') };
isa_ok(Foo->new,'Bar');
ok(eq_array([Foo->meta->superclasses], ['Bar']));
lives_ok{ Qux->meta->superclasses(qw/Foo Baz/) };
isa_ok('Qux','Foo');
isa_ok('Qux','Bar');
isa_ok('Qux','Baz');
is_deeply([ Qux->meta->superclasses ], [qw/Foo Baz/]  );
is_deeply([ Qux->meta->linearized_isa],[qw/Qux Foo Bar Shaft::Object Baz/]);

done_testing;