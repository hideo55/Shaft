package Shaft::Meta::Attribute::Native;
use strict;
use warnings;
our $VERSION = '0.01';
$VERSION = eval $VERSION;

my @trait_names = qw(Bool Counter Number String Array Hash Code);

for my $trait_name (@trait_names) {
    my $trait_class = "Shaft::Meta::Attribute::Native::Trait::$trait_name";
    my $meta = Shaft::Meta::Role->initialize(
        "Shaft::Meta::Attribute::Custom::Trait::$trait_name"
    );
    if ($meta->get_method('register_implementation')) {
        my $class = $meta->name->register_implementation;
        throw_error(
            "An implementation for $trait_name already exists " .
            "(found '$class' when trying to register '$trait_class')"
        );
    }
    $meta->add_method(register_implementation => sub {
        Shaft::Util::load_class($trait_class);
        return $trait_class;
    });
}

1;
__END__

=pod

=head1 NAME

Shaft::Meta::Attribute::Native - 

=head1 AUTHOR

Hideaki Ohno E<lt>hide.o.j55 {at} gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut