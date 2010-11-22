use strict;
use warnings;
use Test::More tests => 3;

my %seen;

{
	package Foo;
	use Shaft;
	
	sub foo {
		::BAIL_OUT('Foo::foo called twice') if $main::seen{'Foo::foo'}++;
		return 'a';
	}
	
	sub bar{
		::BAIL_OUT('Foo::bar called twice') if $main::seen{'Foo::bar'}++;
		return 'a';
	}
	
	sub baz{
		::BAIL_OUT('Foo::baz called twice') if $main::seen{'Foo::baz'}++;
		return 'a';
	}
}

{
	package Bar;
	use Shaft;
	extends qw(Foo);
	
	sub foo {
		::BAIL_OUT('Bar::foo called twice') if $main::seen{'Bar::foo'}++;
		return 'b' . super();
	}
	
	sub bar{
		::BAIL_OUT('Bar::bar called twice') if $main::seen{'Bar::bar'}++;
		return 'b' . ( super() || '' );
	}
	
	override baz => sub{
		::BAIL_OUT('Bar::baz called twice') if $main::seen{'Bar::baz'}++;
		return 'b' . super();
	};
	
}

{
	package Baz;
	use Shaft;
	extends qw(Bar);
	
	sub foo { return 'c' . ( super() || '' ) }
	
	override bar  => sub {
		::BAILOUT('Bazbar called twice') if $main::seen{'Bazbar'}++;
		return 'c' . super();
	};
	
	override baz => sub {
		::BAIL_OUT('Bazbaz called twice') if $main::seen{'Bazbaz'}++;
		return 'c' .super();
	};
}

is( Baz->new->foo, 'c' );
is( Baz->new->bar, 'cb' );
is( Baz->new->baz, 'cba' );

Bar->meta->remove_method('baz');
Baz->meta->remove_method($_) for qw/bar baz/;

__END__
