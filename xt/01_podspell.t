use Test::More;
eval q{ use Test::Spelling };
plan skip_all => "Test::Spelling is not installed." if $@;
add_stopwords(map { split /[\s\:\-]/ } <DATA>);
$ENV{LANG} = 'C';
add_stopwords('deserialize','ClassData', 'metaclass', 'BUILDARGS','stacktrace','namespace','rebless');
all_pod_files_spelling_ok('lib');
__DATA__
Hideaki Ohno
hide_o_j55@gmail.com
Shaft
