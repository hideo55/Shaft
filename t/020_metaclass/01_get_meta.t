use strict;
use warnings;
use Test::More;
use Scalar::Util qw/refaddr isweak weaken/;
use List::MoreUtils qw/all/;

{
	package Foo;
	use Shaft;
	
	sub get_metaclasses {
		return Shaft::Util::get_all_metaclass_instances();
	}
	
	package Bar;
	use Shaft;
	
	package Baz;
	use Shaft;
	
}

ok( Shaft::Util->get_all_metaclass_instances );
ok( Shaft::Util->get_all_metaclass_names );

can_ok('Foo','meta');
isa_ok(Foo->meta,'Shaft::Meta::Class');
cmp_ok( refaddr(Foo->meta),'==', refaddr(Shaft::Meta::Class->initialize('Foo')), 'Singleton');
my $meta = Shaft::Util::get_metaclass_by_name('Foo');
ok( $meta->name eq 'Foo' );
ok( Shaft::Util::does_metaclass_exist('Foo') );
ok( Shaft::Util::remove_metaclass_by_name('Foo') );
ok( ! Shaft::Util::does_metaclass_exist('Foo') );
ok( Shaft::Util::store_metaclass_by_name('Foo',$meta) );
ok( ! defined Shaft::Util::weaken_metaclass('Foo') );
ok( Shaft::Util::does_metaclass_exist('Foo') );

ok all { $_->isa('Shaft::Meta::Class') || $_->isa('Shaft::Meta::Role') } Foo->get_metaclasses;

my $clone = $meta->clone();
is $meta->name,$clone->name;

undef $meta;
undef $clone;

done_testing;