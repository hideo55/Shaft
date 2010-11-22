use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warn;

{
	package Foo;
	use Shaft;
	use Shaft::Util::TypeConstraints;

	Public default     => ( is => 'rw', default => 10 );
	Public default_sub => ( is => 'rw', default => sub { { test => 1 } } );
	Public builder     => ( is => 'rw', builder => 'builder_test' );
	Public lazy        => ( is => 'rw', lazy    => 1, default => 1 );
	Public lazy_builder =>
		( is => 'rw', lazy => 1, builder => 'builder_test' );
	Public lazy_build => ( is => 'rw', lazy_build => 1 );
	Public _foo       => ( is => 'rw', lazy_build => 1 );
	Public lazy_build2 => (
		is         => 'rw',
		clearer    => 'clearer2',
		predicate  => 'predicate2',
		builder    => '_build__lazy_build2',
		lazy_build => 1,
	);
	Public _lazy_build2 => (
		is         => 'rw',
		clearer    => '_clearer2',
		predicate  => '_predicate2',
		lazy_build => 1
	);
	
	has lazy_ro => ( is => 'ro', lazy => 1, default => 1 );
	has lazy_ro_code => ( is => 'ro', lazy => 1, default => sub{ 1 } );
	
	has lazy_builder_ro => ( is => 'ro', lazy => 1, builder => '_build_lazy_build' );
	
	has lazy_build_ro => ( is => 'ro', isa => 'HashRef', lazy_build => 1 , coerce => 1 );

	Public default_undef => ( is => 'rw', default => undef );

	Public default_num => ( is => 'rw', default => -1.1 );

	coerce 'HashRef' => from 'ArrayRef' => via {
		+{ map { $_ => 1 } @{$_} };
	};
	Public lazy_coerce => (
		is      => 'rw',
		isa     => 'HashRef',
		default => sub { [qw/foo bar/] },
		coerce  => 1
	);

	sub builder_test {
		return { test => 1 };
	}

	sub _build_lazy_build {
		return { test => 1 };
	}

	sub _build__foo {
		return { test => 1 };
	}
	
	sub _build_lazy_build2 {
		1;
	}
	
	sub _build__lazy_build2 {
		1;
	}
	
	sub _build_lazy_build_ro {
		[qw/foo bar baz/];
	}

}

my $foo = Foo->new( ro => 1 );

is $foo->default, 10;
is $foo->default_sub->{test}, 1;
is $foo->builder->{test},     1;
is $foo->lazy, 1;
is $foo->lazy_builder->{test}, 1;
is $foo->lazy_build->{test},   1;
is $foo->default_undef, undef;
is $foo->default_num,   -1.1;
is_deeply( $foo->lazy_coerce, { foo => 1, bar => 1 } );
is $foo->lazy_ro, 1;
is $foo->lazy_ro_code, 1;
is_deeply($foo->lazy_builder_ro,{ test => 1 });
is_deeply($foo->lazy_build_ro,{ foo => 1, bar => 1, baz => 1 });

ok $foo->meta->get_attribute('default')->has_default;
ok $foo->meta->get_attribute('builder')->has_builder;
ok $foo->meta->get_attribute('lazy')->is_lazy;
ok $foo->meta->get_attribute('lazy_builder')->has_builder;
ok $foo->meta->get_attribute('lazy_builder')->is_lazy;
ok $foo->meta->get_attribute('lazy_build')->has_builder;
ok $foo->meta->get_attribute('lazy_build')->is_lazy;
ok $foo->meta->get_attribute('lazy_build')->has_clearer;
is $foo->meta->get_attribute('lazy_build')->clearer, 'clear_lazy_build';
ok $foo->meta->get_attribute('lazy_build')->has_predicate;
is $foo->meta->get_attribute('lazy_build')->predicate, 'has_lazy_build';
ok $foo->meta->get_attribute('_foo')->is_lazy;
ok $foo->meta->get_attribute('_foo')->has_clearer;
is $foo->meta->get_attribute('_foo')->clearer, '_clear_foo';
ok $foo->meta->get_attribute('_foo')->has_predicate;
is $foo->meta->get_attribute('_foo')->predicate,        '_has_foo';
is $foo->meta->get_attribute('lazy_build2')->clearer,   'clearer2';
is $foo->meta->get_attribute('lazy_build2')->predicate, 'predicate2';
is $foo->meta->get_attribute('_lazy_build2')->clearer,  '_clearer2';
is $foo->meta->get_attribute('_lazy_build2')->predicate,
	'_predicate2';

Foo->meta->make_immutable;
lives_ok { Foo->new };
my $foo2 = Foo->new;
ok( $foo2->default == 10 );
ok( $foo2->default_sub->{test} == 1 );
ok( $foo2->builder->{test} == 1 );
ok( $foo2->lazy == 1 );
ok( $foo2->lazy_builder->{test} == 1 );
ok( $foo2->lazy_build->{test} == 1 );

throws_ok {

	package Bar;
	use Shaft;

	has bar => ( lazy_build => 1, default => sub {1} );
}
qr/^Can't use option 'lazy_build' and 'defult' for same attribute /;

throws_ok {

	package Baz;
	use Shaft;

	has baz => ( is => 'ro', lazy => 1 );
}
qr/^Can't use 'lazy' option for attribute \(baz\) without default value\('default' or 'builder'\)/;

warning_like{

	package Qux;
	use Shaft;

	has qux  => ( default => [] );
	has qux2 => ( builder => 'build_qux2' );

} qr/^References are not recomanded as default values. Should be wrap the defaut of 'qux' in a CODE reference \(ex: sub { \[\] } \)/;

throws_ok {
	Qux->new;
}
qr/^Qux does not support builder method 'build_qux2'  for attribute 'qux2'/;

done_testing;
