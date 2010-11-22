use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Bar;
	use Shaft::Role;
	
	requires 'foo';

	Private bar => ( is => 'rw', default => 10 );
	Private [qw/baz qux/] => ( is => 'ro', default => 'ok' );
	
	sub hoge : Private {
		'ok';
	}
	
	package Foo;
	use Shaft;

	Public foo => (is => 'rw' );

	with 'Bar';
		
	sub test1{
		shift->hoge;
	}

	sub test2{
		shift->bar;
	}

	sub test3{
		shift->baz;
	}

	sub test4{
		shift->qux;
	}
	
	
	package Baz;
	use Shaft -extends => 'Foo';
	
	sub test5{
		shift->hoge;
	}

	sub test6{
		shift->bar;
	}

	sub test7{
		shift->baz;
	}

	sub test8{
		shift->qux;
	}
	
}

my $baz = Baz->new;
lives_ok{ $baz->test1 };
is $baz->test1, 'ok';
lives_ok{ $baz->test2 };
is $baz->test2, 10;
lives_ok{ $baz->test3 };
is $baz->test3, 'ok';
lives_ok{ $baz->test4 };
is $baz->test4, 'ok';
throws_ok{ $baz->test5 } qr/^\Qhoge() is a private method of Foo\E/;
throws_ok{ $baz->test6 } qr/^\Qbar() is a private method of Foo\E/;
throws_ok{ $baz->test7 } qr/^\Qbaz() is a private method of Foo\E/;
throws_ok{ $baz->test8 } qr/^\Qqux() is a private method of Foo\E/;

can_ok('Foo',qw/foo bar baz qux hoge/);

done_testing;