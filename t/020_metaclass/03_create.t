use strict;
use warnings;
use Test::More;
use Test::Exception;
{
	package Foo;
	use Shaft;

	package Foo::Role;
	use Shaft::Role;
}

my $meta = Foo->meta;

my $attr1 = Shaft::Meta::Attribute->new( 'attr1', is => 'rw' );
my $attr2 = Shaft::Meta::Attribute->new( 'attr2', is => 'rw' );

my $bar_meta = $meta->create('Bar',
	version => '0.01',
	authority => 'foo',
	superclasses => [qw/Foo/],
	roles => [qw/Foo::Role/],
	methods => {
		bar1 => sub { 1 },
		bar2 => sub{ 'bar' },
	},
	attributes => [$attr1,$attr2],
);

isa_ok $bar_meta, 'Shaft::Meta::Class';
is $bar_meta, Bar->meta;
is $bar_meta->name, 'Bar';
ok !$bar_meta->is_anon_class;
can_ok($bar_meta->name,qw/bar1 bar2 attr1 attr2/);
isa_ok $bar_meta->name,'Foo';
is $bar_meta->version,'0.01';
is $bar_meta->authority,'foo';
is $bar_meta->identifier,'Bar-0.01-foo';
isa_ok $bar_meta->meta, 'Shaft::Meta::Class';

my $anon = $meta->create_anon_class(
	version => '0.01',
	authority => 'foo',
	superclasses => [qw/Foo/],
	roles => [qw/Foo::Role/],
	methods => {
		bar1 => sub { 1 },
		bar2 => sub{ 'bar' },
	},
	attributes => [$attr1,$attr2],
);

isa_ok $anon, 'Shaft::Meta::Class';
my $anon_class = $anon->name;
is $anon, $anon_class->meta;
ok $anon->is_anon_class;
can_ok($anon->name,qw/bar1 bar2 attr1 attr2/);
is $anon->version,'0.01';
is $anon->authority,'foo';
ok $anon->meta;

my $anon2 = $meta->create(undef, cache => 1 );
ok $anon2->meta;

throws_ok {
	$meta->create();
} qr/^You must pass a package name/;


throws_ok {
	$meta->create('Baz', superclasses => {} );
} qr/^You must pass an ARRAY ref of superclasses/;

throws_ok {
	$meta->create('Baz', attributes => 1 );
} qr/^You must pass an ARRAY or HASH ref of attributes/;

throws_ok {
	$meta->create('Baz', methods => [] );
} qr/^You must pass a HASH ref of methods/;

throws_ok {
	$meta->create('Baz', roles => {} );
} qr/^You must pass an ARRAY ref of roles/;

throws_ok {
	$meta->create(':::')
} qr/^creation of .*? failed : /;

done_testing;