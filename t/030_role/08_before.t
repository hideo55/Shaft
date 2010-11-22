use strict;
use warnings;
use Test::More;
use Test::Exception;

{
	package Foo::Role;
	use Shaft::Role;
	
	before hoge => sub {
		$_[0]->foo( $_[0]->foo . '[BEFORE]');
	};

	__PACKAGE__->meta->add_before_method_modifier(
		hoge => sub{ $_[0]->foo( $_[0]->foo . '[BEFORE2]') }
	);
	
	package Foo;
	use Shaft;
	
	with 'Foo::Role';
	
	Public foo => ( is => 'rw', default => '' );
	
	sub hoge {
		$_[0]->foo( $_[0]->foo . '[BODY]');
	}

}

is( Foo->new->hoge,'[BEFORE2][BEFORE][BODY]');
isa_ok( Foo->meta->get_method('hoge'), 'Shaft::Meta::Method::Wrapped');

my @modifiers = Foo::Role->meta->get_before_method_modifier('hoge');
is scalar(@modifiers), 2;

Foo->meta->remove_method('hoge');

@modifiers = Foo::Role->meta->get_before_method_modifier('fuga');
is scalar(@modifiers), 0;

done_testing;