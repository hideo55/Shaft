use strict;
use warnings;
use Test::More;
use Test::Exception;

{			
	package Foo;
	use Shaft;
	
	Public foo => ( is => 'rw' );
	
	sub hoge {
		$_[0]->foo('[BODY]');
		inner();
		$_[0]->foo( $_[0]->foo . '[BODY]');
	}
	
	sub piyo {
		my $data;
		$data = "1";
		$data .= inner();
		$data .= "3";
		return $data;
	}
	
	package Bar;
	use Shaft;
	extends 'Foo';
	
	augment hoge => sub {
		my $self = shift;
		$self->foo( $self->foo . '[INNER]');
	};
	
	override piyo => sub {
		my $data = super();
		return "0${data}4";
	};
	
	sub fuga {
		inner();
	}
	
	package Baz;
	use Shaft;
	extends 'Bar';
	
	augment piyo => sub {
		return "2";
	};
	
}

ok( Foo->new->hoge eq '[BODY][BODY]' );
ok( Bar->new->hoge eq '[BODY][INNER][BODY]');
isa_ok( Bar->meta->get_method('hoge'),'Shaft::Meta::Method::Augmented');
ok( ! defined( Bar->fuga ));

is( Baz->new->piyo,'01234' );

Bar->meta->remove_method('hoge');
Baz->meta->remove_method('piyo');
Bar->meta->remove_method('piyo');
Foo->meta->remove_attribute('foo');

throws_ok{
	package Baz;
	use Shaft;
	
	augment 'baz' => sub {
		1;
	};
	
} qr/^You cannot augment 'baz' because it has no super method/;

throws_ok{
	package Qux;
	use Shaft;
	
	sub qux { 1 }
	
	augment 'qux' => sub {
		1;
	};
	
} qr/^Can't add an augment method if a local method is already present/;

done_testing;
