use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo;
	use Shaft;
	no Shaft;
	__PACKAGE__->meta->make_immutable;
}

my $foo = Foo->new;
$foo->add_singleton_method( foo => sub{ 'foo' });
can_ok $foo, 'foo';
is $foo->foo,'foo';

my $foo2 = Foo->new;
ok !$foo2->can('foo');

{
	my $bar = 10;
	$foo->add_singleton_method( bar => sub{ $bar });
	is $foo->bar,10;
}

my $foo3 = $foo->clone;
can_ok $foo3,'foo','bar';
is $foo3->bar, 10;
my $bar = 0;
is $foo3->bar, 10;
my $foo4 = $foo->clone;
is $foo4->bar,10;

$foo->remove_singleton_method('foo');
ok !$foo->can('foo');
throws_ok { $foo->foo } qr/^Can't locate/;
can_ok $foo3, 'foo';
lives_ok {
	$foo->remove_singleton_method('foo')
};

ok !UNIVERSAL::can();

throws_ok {
	Foo->add_singleton_method();
} qr/^add_singleton_method\(\) is instance method./;

throws_ok {
	$foo->add_singleton_method();
} qr/^\$obj->add_singleton_method\( name => sub{...} \)/;

throws_ok {
	$foo->add_singleton_method( baz => {} );
} qr/^\$obj->add_singleton_method\( name => sub{...} \)/;

throws_ok {
	Foo->remove_singleton_method();
} qr/^remove_singleton_method\(\) is instance method./;

done_testing;