use strict;
use warnings;

use lib 't/lib';
require EmptyClass;

use Test::More;
use Test::Exception;
use Test::Warn qw(warning_is);
use List::MoreUtils qw(all);
use Shaft::Util ':all';
{
	package Foo;
	use Shaft;
	use namespace::clean -except => [qw/meta throw_error throw_warn/];
	
	use Shaft::Util ':all';
	
	package Bar::Role;
	use Shaft::Role;
	
	package Bar;
	use Shaft;
	with 'Bar::Role';
	
	package Baz;
	use Shaft;
	
}

my @exports = qw/meta find_meta does_role is_class_loaded load_class
	load_first_existing_class  throw_error throw_warn  
	get_all_metaclass is_valid_method_name english_list/;
my $exports = '(?:' . join('|',@exports) . ')';
my $pattern = qr/$exports/;

ok(all { /$pattern/ } Foo->meta->get_method_list);

my $meta = find_meta('Foo');
isa_ok($meta,'Shaft::Meta::Class');
is $meta->name, 'Foo';

isa_ok Shaft::Util::meta('Foo'), 'Shaft::Meta::Class';
isa_ok Shaft::Util::meta('Bar::Role'), 'Shaft::Meta::Role';
isa_ok Shaft::Util::meta(Foo->new), 'Shaft::Meta::Class';

throws_ok{ 
	Shaft::Util::meta();
} qr/^You must pass a package name and it cannot be blessed/;

isa_ok( Shaft::Util::class_of('Foo') , 'Shaft::Meta::Class');
isa_ok( Shaft::Util::class_of(Foo->new), 'Shaft::Meta::Class');

ok( does_role('Bar','Bar::Role') );
ok(! does_role('Foo','Bar::Role') );
ok ! does_role();
throws_ok { does_role('Foo') } qr/^You must supply a role name to look for/;

{
	my $meta = Shaft::Util::get_metaclass_by_name('Bar');
	Shaft::Util::store_metaclass_by_name( 'Bar' => Baz->new() );
	ok !does_role('Bar','Bar::Role');
	Shaft::Util::store_metaclass_by_name( 'Bar' => $meta );
}

throws_ok { Shaft::Util::does('Foo') } qr/^You much supply a role name to does\(\)/;
ok !Shaft::Util::does('Hoge', 'Bar::Role');

ok is_class_loaded('Foo');
ok is_class_loaded('::');
ok is_class_loaded('main');
ok is_class_loaded('EmptyClass');
ok !is_class_loaded('Hoge');

lives_ok{ load_class('Shaft::Util::MetaRole') };
lives_ok{ load_class('CGI') };
throws_ok { load_class('Fuga') } qr/^Could not load class \(Fuga\) because : Can't locate/;
throws_ok { load_class('Foo!') } qr/^Invalid class name/;

is load_first_existing_class('Fuga','Foo'),'Foo';
is load_first_existing_class(), undef;
throws_ok { load_first_existing_class('Hoge','Fuga') } qr/Could not load class \(Hoge\) because : .*?Could not load class \(Fuga\)/sm;
throws_ok { load_first_existing_class('Foo!') } qr/^Invalid class name \(Foo!\)/;
throws_ok { load_first_existing_class(undef) } qr/^Invalid class name \(undef\)/;
throws_ok { load_first_existing_class({}) } qr/^Invalid class name/;
throws_ok { load_first_existing_class('') } qr/^Invalid class name/;


dies_ok { Shaft::Util::apply_all_roles('Foo','Qux') };

ok is_valid_method_name('test');
ok !is_valid_method_name(1);

ok Shaft::Util::is_a_metaclass(Foo->meta);
ok !Shaft::Util::is_a_metaclass(Bar::Role->meta);
ok !Shaft::Util::is_a_metaclass('Foo');

ok Shaft::Util::is_a_metarole(Bar::Role->meta);
ok !Shaft::Util::is_a_metarole(Foo->meta);
ok !Shaft::Util::is_a_metarole('Bar::Role');

require Shaft::Util::TypeConstraints;
ok Shaft::Util::is_a_type_constraint(Shaft::Util::TypeConstraints::find_type_constraint('Int'));
ok !Shaft::Util::is_a_type_constraint(Bar::Role->meta);
ok !Shaft::Util::is_a_type_constraint(Foo->meta);
ok !Shaft::Util::is_a_type_constraint('Int');

throws_ok { throw_error("Testing") } qr/^Testing/;

warning_is { throw_warn "warning" } "warning";

{
	package Foo::Meta;
	{
		package Shaft::Meta::Class::Custom::Foo;
		
		sub register_implementation {
			"Foo::Meta";
		}
	}
	use Shaft -extends => 'Shaft::Meta::Class';
	
	package Shaft::Meta::Class::Custom::Bar;
	use Shaft -extends => 'Shaft::Meta::Class';
}

is Shaft::Util::resolve_metaclass_alias('Class','Foo'), 'Foo::Meta';
is Shaft::Util::resolve_metaclass_alias('Class','Bar'), 'Shaft::Meta::Class::Custom::Bar';


{
	package Foo::Meta::Trait;
	{
		package Shaft::Meta::Class::Custom::Trait::Foo;
		
		sub register_implementation {
			"Foo::Meta::Trait";
		}
	}
	use Shaft::Role;
	
	package Shaft::Meta::Class::Custom::Trait::Bar;
	use Shaft::Role;
}

is Shaft::Util::resolve_metatrait_alias('Class','Foo'), 'Foo::Meta::Trait';
is Shaft::Util::resolve_metatrait_alias('Class','Bar'), 'Shaft::Meta::Class::Custom::Trait::Bar';

is english_list("foo"), "foo";
is english_list(qw/foo bar/), "foo and bar";
is english_list(qw/foo bar baz/),"foo, bar, and baz";
is quoted_english_list("foo"), "'foo'";
is quoted_english_list(qw/foo bar/), "'foo' and 'bar'";
is quoted_english_list(qw/foo bar baz/),"'foo', 'bar', and 'baz'";

done_testing;
