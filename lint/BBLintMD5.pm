package BBLintMD5;

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
	     'name' => 'rpm_md5_check',
	     'description' => 'Package md5sums do not verify.  You probably need to rebuild.',
	     'dependencies' => [ 'built_check' ],
	     'packsys' => 'rpm'
	    },
	    {
	     'name' => 'deb_md5_check',
	     'description' => 'Package md5sums do not verify.  You probably need to rebuild.',
	     'dependencies' => [ 'built_check' ],
	     'packsys' => 'deb'
	    }

	   ];
}

sub checksum_rpm {
    my $package = shift;

    my $distro_info = Ximian::BB::Lint::get_distro_info();

    my $command;
    if (exists $distro_info->{data}->{rpmbuild_cmd}
	and $distro_info->{data}->{rpmbuild_cmd}->{cdata} eq 'rpmbuild') {
	$command = "rpm --checksig --nosignature";
    } else {
	$command = "rpm --checksig --nogpg";
    }

    if (system ("$command $package >/dev/null 2>&1")) {
	return 1;
    }
    return 0;
}

sub do_rpm_md5_check {
    my $name = shift;
    my $archivedir = Ximian::BB::Lint::get_archivedir();
    my @failed;

    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};

    foreach my $file (@$packages, @$sources) {
	push @failed, $file if checksum_rpm ("$archivedir/$file");
    }

    if (scalar @failed) {
	my $log = "failed packages:\n";
	$log .= join("\n", @failed);
	Ximian::BB::Lint::test_fail ($name, $log);
    } else {
	Ximian::BB::Lint::test_pass ($name);
    }
    return;
}

sub checksum_deb {
    my $package  = shift;
    my $checksum = shift;

    chomp (my $md5val = `md5sum $package`);
    $md5val =~ s/\s*([0-9a-f]+)\s*.*/$1/;

    if ($md5val ne $checksum) {
	return 1;
    }
    return 0;
}

sub do_deb_md5_check {
    my $name = shift;
    my $archivedir = Ximian::BB::Lint::get_archivedir();
    my @failed;

    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};

    # check that the deb files are intact. I think we can just use
    # dpkg -c for this, as it seems to error only when the deb is
    # corrupt

    foreach my $package (@$packages) {
	my $ret = system ("dpkg -c $archivedir/$package >/dev/null 2>&1");
	push @failed, $package;
    }

    # check the md5sums on the source packages
    my %checksums;

    my @dscs = grep {$_ =~ /dsc$/} @$sources;
    my $dsc = $dscs[0];

    open DSC, "$archivedir/$dsc" || die "can't open $archivedir/$dsc";
    while (<DSC>) {
	next if not m/^\s+([0-9a-f]+)\s+\d+\s+(\S+)\s*$/;
	$checksums{$2} = $1;
    }
    close DSC;

    foreach (keys %checksums) {
	push @failed, $_ if checksum_deb("$archivedir/$_", $checksums{$_});
    }

    if (scalar @failed) {
	my $log = "failed packages:\n";
	$log .= join("\n", @failed);
	Ximian::BB::Lint::test_fail ($name, $log);
    } else {
	Ximian::BB::Lint::test_pass ($name);
    }
    return;
}

1;

