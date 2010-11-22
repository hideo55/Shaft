use inc::Module::Install;
name 'Shaft';
all_from 'lib/Shaft.pm';

requires 'Carp';
requires 'Scalar::Util' => '1.14';
requires 'Data::Util' => 0;
requires 'Clone' => 0;
requires 'MRO::Compat' => 0;
requires 'Sub::Name' => 0;
requires 'List::MoreUtils' => 0;
requires 'namespace::clean' => 0;

test_requires 'Test::More' => 0.88;
test_requires 'Test::Exception';
test_requires 'Test::Warn';

tests 't/*.t t/*/*.t';
if( $Module::Install::AUTHOR ){
	#author_tests 'xt';
}

auto_include;
auto_install;
WriteAll;
