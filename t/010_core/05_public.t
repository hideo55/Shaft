use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	Public foo => ( is => 'rw', default => 1 );
	Public [qw/bar baz/] => ( is => 'rw', default => 1 );
	has hoge => ( is => 'rw', default => 1 );
	has [qw/fuga piyo/] => ( is => 'ro', default => 1 );


	sub read_attr_sameclass1{
		return $_[0]->foo();
	}
	sub read_attr_sameclass2{
		return $_[0]->bar();
	}
	sub read_attr_sameclass3{
		return $_[0]->baz();
	}

	sub read_attr_sameclass4{
		return $_[0]->hoge();
	}
	sub read_attr_sameclass5{
		return $_[0]->fuga();
	}
	sub read_attr_sameclass6{
		return $_[0]->piyo();
	}
	
	sub call_method_sameclass{
		return $_[0]->public();
	}
	
	sub public : Public { 1 };
	
	package Bar;
	use Shaft -extends => 'Foo';
	our $VERSION = '0.01';
	
	sub read_attr_subclass1{
		return $_[0]->foo();
	}
	sub read_attr_subclass2{
		return $_[0]->bar();
	}
	sub read_attr_subclass3{
		return $_[0]->baz();
	}

	sub read_attr_subclass4{
		return $_[0]->hoge();
	}
	sub read_attr_subclass5{
		return $_[0]->fuga();
	}
	sub read_attr_subclass6{
		return $_[0]->piyo();
	}
	
	sub call_method_subclass{
		return $_[0]->public();
	}

	__PACKAGE__->meta->make_immutable;
	
}

can_ok('Foo',qw/foo bar baz hoge fuga piyo public/);

my $foo = Foo->new;
lives_ok{ $foo->read_attr_sameclass1 };
is $foo->read_attr_sameclass1, 1;
lives_ok{ $foo->read_attr_sameclass2 };
is $foo->read_attr_sameclass2, 1;
lives_ok{ $foo->read_attr_sameclass3 };
is $foo->read_attr_sameclass3, 1;
lives_ok{ $foo->read_attr_sameclass4 };
is $foo->read_attr_sameclass4, 1;
lives_ok{ $foo->read_attr_sameclass5 };
is $foo->read_attr_sameclass5, 1;
lives_ok{ $foo->read_attr_sameclass6 };
is $foo->read_attr_sameclass6, 1;
lives_ok{ $foo->call_method_sameclass };
is $foo->call_method_sameclass, 1;

my $bar = Bar->new;
lives_ok{ $bar->read_attr_subclass1 };
is $bar->read_attr_subclass1, 1;
lives_ok{ $bar->read_attr_subclass2 };
is $bar->read_attr_subclass2, 1;
lives_ok{ $bar->read_attr_subclass3 };
is $bar->read_attr_subclass3, 1;
lives_ok{ $bar->read_attr_subclass4 };
is $bar->read_attr_subclass4, 1;
lives_ok{ $bar->read_attr_subclass5 };
is $bar->read_attr_subclass5, 1;
lives_ok{ $bar->read_attr_subclass6 };
is $bar->read_attr_subclass6, 1;
lives_ok{ $bar->call_method_subclass };
is $bar->call_method_subclass, 1;

lives_ok{ $foo->foo };
is $foo->foo, 1;
lives_ok{ $foo->bar };
is $foo->bar, 1;
lives_ok{ $foo->baz };
is $foo->baz, 1;
lives_ok{ $foo->hoge };
is $foo->hoge, 1;
lives_ok{ $foo->fuga };
is $foo->fuga, 1;
lives_ok{ $foo->piyo };
is $foo->piyo, 1;
lives_ok{ $foo->public };
is $foo->public, 1;

done_testing;