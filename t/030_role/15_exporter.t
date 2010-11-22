use Test::More;
use Test::Exception;

throws_ok {
	package Foo;
	require Shaft::Role;
	Shaft::Role->import( -extends => 'Fooo' );
} qr/Role dose not support '-extends' command/;

done_testing;