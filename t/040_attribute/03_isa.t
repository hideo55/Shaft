use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	use Shaft::Util::TypeConstraints;

	has foo1 => ( is => 'ro', isa => 'ArrayRef', default => sub{ [] } );
	has foo2 => ( is => 'rw', isa => 'HashRef', lazy => 1, default => sub{ +{} } );
	has foo3 => ( is => 'ro', isa => find_type_constraint('ArrayRef'), builder => 'build_foo3' );
	has foo4 => ( is => 'rw', isa => 'Bool', lazy => 1, builder => 'build_foo4' );
	has foo5 => ( is => 'rw', isa => 'HashRef[Str]', pbp_style => 1 );
	has foo6 => ( is => 'rw', isa => 'ArrayRef[Int]' );
	has foo7 => ( is => 'rw', isa => 'Maybe[Int]');
	has foo8 => ( is => 'rw' );

	sub build_foo3 {
		[]
	}

	sub build_foo4 {
		1
	}

}

my $foo = Foo->new(
	foo1 => [qw/foo/],
	foo2 => { foo => 1 },
	foo3 => [qw/foo/],
	foo4 => 0,
	foo5 => { foo => 1 },
	foo6 => [1..5],
	foo7 => undef,
);

is_deeply $foo->foo1, [qw/foo/];
is_deeply $foo->foo2, { foo => 1 };
is_deeply $foo->foo3, [qw/foo/];
is $foo->foo4, 0;
is_deeply $foo->get_foo5, { foo => 1 };
is_deeply $foo->foo6, [1..5];
is_deeply $foo->foo7, undef;

$foo->foo2({ bar => 1 });
$foo->foo4(1);
$foo->set_foo5({ bar => 1 });
$foo->foo6([0..10]);
$foo->foo7(10);

is_deeply $foo->foo2, { bar => 1 };
is $foo->foo4,1;
is_deeply $foo->get_foo5, { bar => 1 };

$foo = Foo->new();

is_deeply $foo->foo1, [];
is_deeply $foo->foo2, {};
is_deeply $foo->foo3, [];
is $foo->foo4, 1;
is $foo->get_foo5, undef;

dies_ok {
	Foo->new(
		foo1 => 1,
	);
};

Foo->meta->make_immutable;

$foo = Foo->new(
	foo1 => [qw/foo/],
	foo2 => { foo => 1 },
	foo3 => [qw/foo/],
	foo4 => 1,
	foo5 => { foo => 1 },
);

is_deeply $foo->foo1, [qw/foo/];
is_deeply $foo->foo2, { foo => 1 };
is_deeply $foo->foo3, [qw/foo/];
is $foo->foo4, 1;
is_deeply $foo->get_foo5, { foo => 1 };

dies_ok {
	Foo->new( foo2 => [] );
};

throws_ok {
	$foo->foo2(1);
} qr/^Attribute \(foo2\) does not pass the type constraint because:/;

throws_ok {
	$foo->foo4('foo');
} qr/^Attribute \(foo4\) does not pass the type constraint because:/;

throws_ok {
	$foo->set_foo5(1);
} qr/^Attribute \(foo5\) does not pass the type constraint because:/;

throws_ok {
	$foo->foo6(1);
} qr/^Attribute \(foo6\) does not pass the type constraint because:/;

throws_ok {
	$foo->foo7('foo');
} qr/^Attribute \(foo7\) does not pass the type constraint because:/;

ok $foo->meta->get_attribute('foo8')->verify_against_type_constraint(),'no type constraint';

lives_ok {
	package Bar;
	use Shaft;
	
	Public bar1 => ( is => 'ro', isa => 'HashRef', default => 1 );
	Public bar2 => ( is => 'rw', isa => 'ArrayRef', default => 'ARRAY' );

	Public bar3 => ( is => 'ro', isa => 'HashRef', lazy => 1 , default => 1 );
	Public bar4 => ( is => 'rw', isa => 'ArrayRef', lazy =>1, default => 'ARRAY' );

};

throws_ok {
	Bar->new;
} qr/^Attribute \(.*?\) does not pass the type constraint because:/;

my $bar;
lives_ok {
	$bar = Bar->new(
		bar1 => {},
		bar2 => [],
	);
};

throws_ok {
	$bar->bar3;
} qr/^Attribute \(bar3\) does not pass the type constraint because:/;

throws_ok {
	$bar->bar4;
} qr/^Attribute \(bar4\) does not pass the type constraint because:/;

throws_ok {

	package Quxx1;
	use Shaft;

	has quxx => ( isa => 'Foo[Int]' );
}
qr/Got isa => Foo\[Int\], but Shaft does not yet support parameterized types for containers other than ArrayRef, HashRef, and Maybe/;

{
	package Quxx2;
	use Shaft;
	
	has quxx => ( is => 'rw', isa => 'ArrayRef', default => sub{ +{} } );
}

throws_ok {
	Quxx2->new();
} qr/^Attribute \(quxx\) does not pass the type constraint because: Validation failed for 'ArrayRef' failed with value /;

lives_ok {
	package Hoge1;
	use Shaft;
	has hoge1 => ( is => 'rw', isa => 'Fuga' );
};
my $fuga_tc = Shaft::Util::TypeConstraints::find_type_constraint('Fuga');
ok $fuga_tc;
ok $fuga_tc->is_subtype_of('Object');

throws_ok {
	package Hoge2;
	use Shaft;
	has hoge2 => ( is => 'rw', isa => $foo );
} qr/contains invalid characters for a type name/;

done_testing;
