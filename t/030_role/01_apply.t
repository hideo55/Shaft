use strict;
use warnings;
use Test::More tests => 16;
use Test::Exception;

lives_ok {
	package A::Role;
	use Shaft::Role;
	
	package Foo;
	use Shaft;
	
	with 'A::Role';
} 'Apply one role to class';

ok(Foo->does('A::Role'));

lives_ok {
	package B::Role1;
	use Shaft::Role;

	sub foo { 1 }

	package B::Role2;
	use Shaft::Role;

	sub bar { 1 }
	
	package Bar;
	use Shaft;
	
	with qw(A::Role B::Role1 B::Role2);
} 'Apply multi roles to class';

ok(Bar->does('A::Role'));
ok(Bar->does('B::Role1'));
ok(Bar->does('B::Role2'));
my ($role) = Bar->meta->roles;
isa_ok $role, 'Shaft::Meta::Role::Composite';
$role->add_attribute( attr1 => ( is => 'rw' ) );
ok $role->get_method_body('foo') == B::Role1->meta->get_method_body('foo');

{
	package Bar2;
	use Shaft;
	extends 'Bar';
	no Shaft;
	__PACKAGE__->meta->make_immutable;
}

ok( Bar2->does('A::Role') );
ok( Bar2->does('B::Role1') );
ok( Bar2->does('B::Role2') );

{
	my $meta = Shaft::Util::get_metaclass_by_name('Bar');
	Shaft::Util::store_metaclass_by_name( 'Bar' => Baz->new() );
	ok !Bar2->does('A::Role');
	Shaft::Util::store_metaclass_by_name( 'Bar' => $meta );
}

throws_ok {
	package Baz;
	use Shaft;
	
	with 'Bar';
} qr/Could not apply role : 'Bar' is not Shaft role/;

throws_ok {
	package A::Role3;
	use Shaft::Role;
	
	has 'attr1' => ( is => 'rw' );
	
	package B::Role3;
	use Shaft::Role;
	
	has 'attr1' => ( is => 'rw' );

	package Qux;
	use Shaft;
	
	with qw(A::Role3 B::Role3);
} qr/^We have encountered an attribute conflict with 'attr1' during composition. This is fatal error and cannot be disambiguated./;

my $spec = { is => 'rw' };
lives_ok{
	package A::Role4;
	use Shaft::Role;
	__PACKAGE__->meta->add_attribute( attr => $spec );
	no Shaft::Role;

	package B::Role4;
	use Shaft::Role;
	__PACKAGE__->meta->add_attribute( attr => $spec );
	no Shaft::Role;
	
	package Quxx;
	use Shaft;

	with qw(A::Role4 B::Role4);
};
can_ok('Quxx','attr');

__END__