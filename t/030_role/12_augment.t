use strict;
use warnings;
use Test::More;
use Test::Exception;

throws_ok{
	package Foo::Role;
	use Shaft::Role;
	
	augment foo => sub {
		"test";
	};
	
	package Foo;
	use Shaft;
	
	with 'Foo::Role';
	
	sub foo {
		inner();
	}
	
} qr/Roles cannot support 'augment'/;

{
	package Bar::Role;
	use Shaft::Role;
	
	sub bar {
		inner();
	}
	
	package Bar;
	use Shaft;
	with 'Bar::Role';
} 

my $bar = Bar->new;
throws_ok{ $bar->bar } qr/Roles cannot support 'inner'/;

done_testing;
