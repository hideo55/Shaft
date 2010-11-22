use strict;
use warnings;
use Test::More;
use Test::Warn;

warning_like 
{
	package Foo;
	use Shaft;

	Public foo => ( ia => 'ro', iss => 'Int', process => 1 );
} qr/Found unknown argument\(s\) passed to 'foo' attribute constructor in 'Shaft::Meta::Attribute'/;

warning_is {
	package Shaft::Meta::Attribute::Custom::BarAttr;
	use Shaft -extends => 'Shaft::Meta::Attribute';

	Public bar => ( is => 'ro' );

	package Bar;
	use Shaft;

	Public bar => ( is => 'ro', bar => 1, metaclass => 'BarAttr' );
} undef;

done_testing;