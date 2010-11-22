use strict;
use warnings;
use Test::More;
use Test::Exception;

throws_ok{
	package Foo1;
	use Shaft::Role;
	
	package Bar1;
	use Shaft::Role;

	excludes 'Foo1';
	
	package Hoge1;
	use Shaft;
	
	with 'Foo1','Bar1';
} qr/does the excluded role 'Foo1'/;

throws_ok {
	package Foo2;
	use Shaft::Role;
	
	package Bar2;
	use Shaft::Role;
	
	excludes 'Foo2';
	
	package Hoge2;
	use Shaft;
	
	with 'Foo2';
	
	package Fuga2;
	use Shaft -extends => 'Hoge2';
	with 'Bar2';
	
} qr/The class Fuga2 does the excluded role 'Foo2'/;


{
	package Foo3;
	use Shaft::Role;
	
	excludes 'Bar3';
	
	package Bar3;
	use Shaft::Role;
	
	package Hoge3;
	use Shaft;
	
	with 'Foo3';
}
throws_ok {	
	package Fuga3;
	use Shaft -extends => 'Hoge3';
	with 'Bar3';
	
} qr/Conflict detected: Fuga3 excludes role 'Bar3'/;

{
	package Foo4;
	use Shaft;
}

throws_ok {
	Foo4->meta->excludes_role();
} qr/^You must supply a role name to look for/;

{
	my $meta = Shaft::Util::get_metaclass_by_name('Hoge3');
	Shaft::Util::store_metaclass_by_name( 'Hoge3' => Foo4->new );
	ok !Fuga3->meta->excludes_role('Bar3');
	Shaft::Util::store_metaclass_by_name( 'Hoge3' => $meta );
}

done_testing;
