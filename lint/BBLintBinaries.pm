package BBLintBinaries;

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
	     'name' => '64bit_check',
	     'description' => 'Your compiler is not producing 64bit binaries.',
	     'dependencies' => [ 'built_check' ],
	     'type' => 'warn',
	     'target' => 'solaris'
	    }
	   ];
}

sub do_64bit_check {
    my $name = shift;
    my @failed;

    my $distro_info = Ximian::BB::Lint::get_distro_info();
    my $cc = $distro_info->{path}->{cc}->{cdata};

    if ($cc !~ /arch=v9/) {
	Ximian::BB::Lint::test_pass ($name, "building 32-bit binaries");
	return;
    }

    chomp (my @files = `find dest -perm +0100 -type f`);
    s/^dest// foreach (@files);

    foreach my $file (@files) {
	chomp (my $type = `file dest/$file`);
	push @failed, $file if $type =~ /32-bit/;
    }

    if (scalar @failed) {
	my $log = "the following files are 32-bit:\n";
	$log .= "  $_\n" foreach (@failed);
	Ximian::BB::Lint::test_fail ($name, $log);
    } else {
	Ximian::BB::Lint::test_pass ($name);
    }
}

1;
