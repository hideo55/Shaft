use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	Private foo => ( is => 'rw', default => 1 );
	Private [qw/bar baz/] => ( is => 'ro', default => 1 );

	our $VERSION = '0.01';
	
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
		return $_[0]->private();
	}
	
	sub private : Private { 1 };
	
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
		return $_[0]->private();
	}

	__PACKAGE__->meta->make_immutable;
	
}


my $attr= sub{
	eval{
		$_[0]->foo;
	};
	return $@ ? 1 : 0;
};

my $meth = sub{
	eval{ $_[0]->private() };
	return $@ ? 1 : 0;
};

can_ok('Foo',qw/foo bar baz private/);

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
throws_ok{ $bar->read_attr_subclass1 } qr/^\Qfoo() is a private method of Foo\E/;
throws_ok{ $bar->read_attr_subclass2 }qr/^\Qbar() is a private method of Foo\E/;
throws_ok{ $bar->read_attr_subclass3 }qr/^\Qbaz() is a private method of Foo\E/;
throws_ok{ $bar->call_method_subclass }qr/^\Qprivate() is a private method of Foo\E/;

throws_ok{ $foo->foo } qr/^\Qfoo() is a private method of Foo\E/;
throws_ok{ $foo->bar }qr/^\Qbar() is a private method of Foo\E/;
throws_ok{ $foo->baz }qr/^\Qbaz() is a private method of Foo\E/;
throws_ok{ $foo->private }qr/^\Qprivate() is a private method of Foo\E/;


done_testing;