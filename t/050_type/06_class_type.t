use strict;
use warnings;
use Test::More;
use Test::Exception;
use Shaft::Util::TypeConstraints;
{
	package Foo;
	use Shaft;
}

ok find_type_constraint('Foo');

Shaft::Meta::Class->create('Bar', superclasses => [qw/Shaft::Object/] );
Shaft::Meta::Class->create('Bar::Baz', superclasses => [qw/Bar/]);

ok !find_type_constraint('Bar');

lives_ok { class_type 'Bar';};
lives_ok { class_type 'Baz' => { class => 'Bar::Baz' } };

my $bar = Bar->new;
my $baz = Bar::Baz->new;

my $bartype = find_type_constraint('Bar');
ok $bartype->check($bar);
ok !$bartype->check('Bar');
ok $bartype->check($baz);

my $baztype = find_type_constraint('Baz');
ok $baztype->check($baz);
ok !$baztype->check('Baz');
ok !$baztype->check($bar);

my $anon_class = Foo->meta->create_anon_class( superclasses => [qw/Foo/] );
ok !find_type_constraint($anon_class->name);
my $anon_type =Shaft::Util::TypeConstraints::find_or_create_type_constraint($anon_class->name);
is $anon_type->name, $anon_class->name;
ok $anon_type->check($anon_class->name->new);

my $alias = class_type 'BarClass' => { class => 'Bar' };
ok $alias->equals($bartype);

throws_ok {
	class_type();
} qr/You must define a class name/;

done_testing;