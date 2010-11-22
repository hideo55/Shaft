use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Bar;
	use Shaft::Role;
	
	Protected bar => (is => 'rw', default => 1 );
	Protected [qw/baz qux/] => ( is => 'ro' => default => 'ok' );
	
	sub hoge : Protected {
		'ok';
	}
	
	package Foo;
	use Shaft;

	with 'Bar';
	
	sub call_method_sameclass {
		$_[0]->hoge;
	}
	
	sub read_attr_sameclass1 {
		$_[0]->bar;
	}

	sub read_attr_sameclass2 {
		$_[0]->baz;
	}

	sub read_attr_sameclass3 {
		$_[0]->qux;
	}
	
	package Baz;
	
	use Shaft -extends => 'Foo';
	
	sub call_method_subclass {
		$_[0]->hoge;
	}
	
	sub read_attr_subclass1 {
		$_[0]->bar;
	}

	sub read_attr_subclass2 {
		$_[0]->baz;
	}

	sub read_attr_subclass3 {
		$_[0]->qux;
	}
	
}

can_ok('Foo',qw/bar baz qux hoge/);

my $foo = Foo->new;
is $foo->call_method_sameclass, 'ok';
is $foo->read_attr_sameclass1, 1;
is $foo->read_attr_sameclass2, 'ok';
is $foo->read_attr_sameclass3, 'ok';

my $baz = Baz->new;
is $baz->call_method_subclass, 'ok';
is $baz->read_attr_subclass1, 1;
is $baz->read_attr_subclass2, 'ok';
is $baz->read_attr_subclass3, 'ok';

throws_ok{ $baz->hoge } qr/^\Qhoge() is a protected method of Foo\E/;
throws_ok{ $baz->bar } qr/^\Qbar() is a protected method of Foo\E/;
throws_ok{ $baz->baz } qr/^\Qbaz() is a protected method of Foo\E/;
throws_ok{ $baz->qux } qr/^\Qqux() is a protected method of Foo\E/;

done_testing;