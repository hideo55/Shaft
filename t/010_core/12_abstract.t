use strict;
use warnings;
use Test::More;
use Test::Exception;
{
	package Foo;
	use Shaft;
	use namespace::clean -except => 'meta';
	
	sub foo : Abstract;
	
	sub bar : Abstract;
	
	package Bar;
	use Shaft -extends => qw/Foo/;
	
	sub bar {
		1;
	}
}

my $bar = Bar->new;

lives_ok{ $bar->bar };
dies_ok { $bar->foo };

done_testing;
