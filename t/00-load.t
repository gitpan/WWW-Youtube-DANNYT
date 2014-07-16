#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'WWW::Youtube' ) || print "Bail out!\n";
}

diag( "Testing WWW::Youtube $WWW::Youtube::VERSION, Perl $], $^X" );
