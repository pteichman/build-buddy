package BBLintInstall;

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
	     'name' => 'rpm_install_dry_run',
	     'description' => 'Package does not install.',
	     'type' => 'warn',
	     'dependencies' => [ 'built_check' ],
	     'packsys' => 'rpm'
	    },
	    {
	     'name' => 'deb_install_dry_run',
	     'description' => 'Package does not install.',
	     'type' => 'warn',
	     'dependencies' => [ 'built_check' ],
	     'packsys' => 'deb'
	    }
	   ];
}

sub rug_path {
    my $rug;
    foreach (qw(/opt/gnome/bin/rug /usr/bin/rug
                /opt/gnome/bin/rc /usr/bin/rc)) {
	if (-x $_) {
	    $rug = $_;
	    last;
	}
    }
    return undef unless $rug;
    $rug = undef if (system ("$rug ping 2>&1 >/dev/null")/256);
    return $rug;
}

sub do_rpm_install_dry_run {
    my $name = shift;
    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};
    my $archivedir = Ximian::BB::Lint::get_archivedir();
    my $rug = rug_path ();
    my $cmd =  $rug ?
	"$rug -yN install" : "rpm -U --test --replacepkgs --replacefiles";

    my @files = map("$archivedir/$_", @$packages);
    my $list = join " ", @files;

    my $log = `$cmd $list 2>&1`;

    if ($?) {
	Ximian::BB::Lint::test_fail ($name, $log);
	return;
    }
    Ximian::BB::Lint::test_pass ($name);
    return;
}

sub do_deb_install_dry_run {
    my $name = shift;
    my ($packages, $sources) = @{Ximian::BB::Lint::get_package_names()};
    my $archivedir = Ximian::BB::Lint::get_archivedir();
    my $rug = rug_path ();
    my $cmd =  $rug ?
	"$rug -yN install" : "dpkg --unpack --no-act";

    my @files = map("$archivedir/$_", @$packages);
    my $list = join " ", @files;

    # in case we're not running as root
    my $oldpath = $ENV{'PATH'};
    $ENV{'PATH'} = "/usr/local/sbin:/usr/sbin:/sbin:$oldpath";
    my $log = `$cmd $list 2>&1`;
    $ENV{'PATH'} = $oldpath;

    if ($?) {
	Ximian::BB::Lint::test_fail ($name, $log);
	return;
    }
    Ximian::BB::Lint::test_pass ($name);
    return;
}

1;

