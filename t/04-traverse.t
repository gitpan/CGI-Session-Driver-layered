use strict;
use warnings;
use CGI::Session;
use File::Path qw(remove_tree);

use Test::More tests => 11;

my $tmpdir = 'tmp';
mkdir($tmpdir) || die "Couldn't make tmp dir";

END {
	remove_tree($tmpdir);
}

my $args = { 
	Layers => [
	   {
	     Driver    => 'file',
	     Directory => $tmpdir,
	   },
	   {
	     Driver => 'db_file',
	     FileName  => "$tmpdir/sessions.db",
	   }
	]
};

#
# make a few sessions
#
my %ids;
my $driver;
for (1..10) {
	my $s = CGI::Session->new("driver:layered", undef, $args);
	$ids{$s->id} = 1;
	$driver ||= $s->_driver;
}



my $count = 0;

$driver->traverse( sub {
	my ($id) = @_;

	$count++;

	$ids{$id} ? pass() : fail();
});

is($count, 10);

