package BBLintStripped;

# Copyright 2003 Ximian, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

sub get_tests {
    return [
	    {
	     'name' => 'strip_check',
	     'description' => 'Your build is not producing stripped binaries.',
	     'dependencies' => [ 'built_check' ],
	     'type' => 'warn'
	    }
	   ];
}

use Data::Dumper;

sub do_strip_check {
    my $name = shift;
    my @failed;
    my $conf = Ximian::BB::Lint::get_conf();

    $bb_unstripped = $ENV{BB_UNSTRIPPED} || 0;
    if ($bb_unstripped or exists $conf->{build}->{default}->{unstripped}) {
	Ximian::BB::Lint::test_pass ($name, "building unstripped package");
	return;
    }
    my $distro_info = Ximian::BB::Lint::get_distro_info();

    chomp (my @files = `find dest -perm +0100 -type f`);
    s/^dest// foreach (@files);

    foreach my $file (@files) {
	chomp (my $type = `file dest/$file`);
	push @failed, $file if $type =~ /not stripped/;
    }

    if (scalar @failed) {
	my $log = "the following files are not stripped:\n";
	$log .= "  $_\n" foreach (@failed);
	Ximian::BB::Lint::test_fail ($name, $log);
    } else {
	Ximian::BB::Lint::test_pass ($name);
    }
}

1;
