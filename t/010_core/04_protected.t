use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	our $VERSION = '0.01';

	Protected foo => ( is => 'rw', default => 1 );
	Protected [qw/bar baz/] => ( is => 'ro', default => 1 );
	
	sub read_attr_sameclass1{
		return $_[0]->foo();
	}
	sub read_attr_sameclass2{
		return $_[0]->bar();
	}
	sub read_attr_sameclass3{
		return $_[0]->baz();
	}
	
	sub call_method_sameclass{
		return $_[0]->protected();
	}
	
	sub protected : Protected { 1 };
	
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
	
	sub call_method_subclass{
		return $_[0]->protected();
	}

	__PACKAGE__->meta->make_immutable;
	
	
}


can_ok('Foo',qw/foo bar baz protected/);

my $foo = Foo->new;
lives_ok{ $foo->read_attr_sameclass1 };
is $foo->read_attr_sameclass1, 1;
lives_ok{ $foo->read_attr_sameclass2 };
is $foo->read_attr_sameclass2, 1;
lives_ok{ $foo->read_attr_sameclass3 };
is $foo->read_attr_sameclass3, 1;
lives_ok{ $foo->call_method_sameclass };
is $foo->call_method_sameclass, 1;

my $bar = Bar->new;
lives_ok{ $bar->read_attr_subclass1 };
is $bar->read_attr_subclass1, 1;
lives_ok{ $bar->read_attr_subclass2 };
is $bar->read_attr_subclass2, 1;
lives_ok{ $bar->read_attr_subclass3 };
is $bar->read_attr_subclass3, 1;
lives_ok{ $bar->call_method_subclass };
is $bar->call_method_subclass, 1;

throws_ok{ $foo->foo } qr/^\Qfoo() is a protected method of Foo\E/;
throws_ok{ $foo->bar }qr/^\Qbar() is a protected method of Foo\E/;
throws_ok{ $foo->baz }qr/^\Qbaz() is a protected method of Foo\E/;
throws_ok{ $foo->protected }qr/^\Qprotected() is a protected method of Foo\E/;

done_testing;