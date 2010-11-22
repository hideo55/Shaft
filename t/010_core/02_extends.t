use strict;
use warnings;

use lib 't/lib';

use Test::More tests => 16;
use Test::Exception;

lives_ok{
	package Foo1;
	use Shaft;
	
	package Foo2;
	use Shaft;
	
	package Bar1;
	use Shaft -extends => 'Foo1';
	
	package Bar2;
	use Shaft;
	extends 'Foo2';
	
	package Baz1;
	use Shaft -extends => [qw/Foo1 Foo2/];
	
	package Baz2;
	use Shaft;
	extends qw/Foo1 Foo2/;
	
}

my $bar1 = Bar1->new;
my $bar2 = Bar2->new;
my $baz1 = Baz1->new;
my $baz2 = Baz2->new;

isa_ok($bar1->new,'Bar1');
isa_ok($bar1->new,'Foo1');
isa_ok($bar2->new,'Bar2');
isa_ok($bar2->new,'Foo2');
isa_ok($baz1->new,'Baz1');
isa_ok($baz1->new,'Foo1');
isa_ok($baz1->new,'Foo2');
isa_ok($baz2->new,'Baz2');
isa_ok($baz2->new,'Foo2');
isa_ok($baz1->new,'Foo2');

lives_ok {
	package Qux;
	our $VERSION = '0.01';
	
	package Quxx;
	use Shaft;
	extends qw(Foo1 Qux);
};
my $quxx = Quxx->new;
isa_ok($quxx,'Foo1');
isa_ok($quxx,'Qux');

lives_ok {
	package Hoge;
	use Shaft;
	extends 'NOTEXISTS';
};

dies_ok {
	package Hoge;
	use Shaft;
	
	package Fuga;
	use Shaft;
	
	extends 'LoadError';
};

__END__