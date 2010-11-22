package MethodAttributeError2;
use Shaft;
	
my $sub = sub : METHOD_ATTR {
	1;
};

Shaft::MethodAttributes::Handler::phase_handler('CHECK');

1;
__END__