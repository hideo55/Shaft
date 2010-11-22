use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;
{
	package Foo;
	use Shaft::Role;
}

ok find_type_constraint('Foo');

Shaft::Meta::Role->create('Bar');
Shaft::Meta::Role->create('Bazz');

ok !find_type_constraint('Bar');

Shaft::Meta::Class->create('BarClass', superclasses => [qw/Shaft::Object/], roles => [qw/Bar/]);
Shaft::Meta::Class->create('BazClass', superclasses => [qw/BarClass/], roles => [qw/Bazz/]);

lives_ok { role_type 'Bar';};
lives_ok { role_type 'Baz' => { role => 'Bazz' } };

my $bar = BarClass->new;
my $baz = BazClass->new;

my $bartype = find_type_constraint('Bar');
ok $bartype->check($bar);
ok !$bartype->check('Bar');
ok $bartype->check($baz);

my $baztype = find_type_constraint('Baz');
ok $baztype->check($baz);
ok !$baztype->check('Baz');
ok !$baztype->check($bar);

my $anon_role = Foo->meta->create_anon_role();
ok !find_type_constraint($anon_role->name);
my $anon_type =Shaft::Util::TypeConstraints::find_or_create_type_constraint($anon_role->name);
is $anon_type->name, $anon_role->name;

{
	package Qux;
	use Shaft;
	with( $anon_role->name );
}

ok $anon_type->check(Qux->new);

my $alias = role_type 'BarRole' => { role => 'Bar' };
ok $alias->equals($bartype);

throws_ok { 
	role_type();
} qr/You must define a role name/;

done_testing;