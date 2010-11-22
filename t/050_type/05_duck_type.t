use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;

duck_type 'Serializable' => qw/serialize deserialize dump/;
duck_type 'Serializable2' => [qw/serialize deserialize dump/];
my $foo1 = duck_type 'Foo1' => 'foo1';
isa_ok $foo1, 'Shaft::Meta::TypeConstraint';

my $cache = duck_type 'Cache' => [qw/get set remove/];

my $anon_duck = duck_type [qw/serialize deserialize dump/];

{
	package Foo;
	use Shaft;
	
	sub serialize{
	}
	
	sub deserialize{
	}
	
	sub dump{
	}
	
	__PACKAGE__->meta->make_immutable;
}

my $duck = find_type_constraint('Serializable');
ok $duck;
isa_ok $duck,'Shaft::Meta::TypeConstraint';

ok $anon_duck;
isa_ok $anon_duck,'Shaft::Meta::TypeConstraint';

ok $duck->equals('Serializable2');
ok $duck->is_a_type_of('Serializable2');

ok $anon_duck->equals('Serializable');
is "$anon_duck", '__ANON__';

ok !$cache->is_a_type_of($duck);

my $foo = Foo->new;
ok $duck->check($foo);
ok !$duck->check('foo');
ok !$duck->check(qr/aaa/);

$foo->meta->remove_method('serialize');
ok !$duck->check($foo);
is $duck->get_message($foo), "Foo is missing methods 'serialize'";
$foo->meta->remove_method('deserialize');
ok !$duck->check($foo);
is $duck->get_message($foo), "Foo is missing methods 'serialize' and 'deserialize'";
$foo->meta->remove_method('dump');
ok !$duck->check($foo);
is $duck->get_message($foo), "Foo is missing methods 'serialize', 'deserialize', and 'dump'";

ok $duck->get_message(undef) =~ /^Validation failed for 'Serializable' failed with value 'undef'/;
ok $duck->get_message('defined') =~ /^Validation failed for 'Serializable' failed with value 'defined'/;
ok $duck->get_message(qr/aaa/) =~ /^Validation failed for 'Serializable' failed with value /;

throws_ok {
	duck_type 'ERROR' => [];
} qr/^\QYou must supply method name(s) which want to predicate\E/;

throws_ok {
	duck_type [];
} qr/^\QYou must supply method name(s) which want to predicate\E/;

throws_ok{
	duck_type [], [qw/foo/];
} qr/contains invalid characters for a type name/;

done_testing;