package BBLintConf;

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
    return
	[
	 { name => "package_name_check",
	   description =>
"All packages in the conf file need a non-empty <name> tag.",
	   groups => [ 'prebuild' ] },
	 { name => "rev_check",
	   description =>
"All new versions of packages need a non-empty <rev> tag
in their conf file",
	   type => "warn",
	   groups => [ 'prebuild' ] },
	 { name => "builddep_check",
	   description =>
"All modules need a <builddep> section within their <build>.",
	   type => "warn",
	   groups => [ 'prebuild' ] }
	];
}

sub do_package_name_check {
    my $name = shift;
    my $conf = Ximian::BB::Lint::get_conf();

    foreach my $build (values %{$conf->{build}}) {
        foreach my $pkg_conf (values %{$build->{package}}) {
            if (defined $pkg_conf->{name} or not keys %$pkg_conf) {
                Ximian::BB::Lint::test_pass($name);
            } else {
                Ximian::BB::Lint::test_fail($name);
            }
        }
    }
}

sub do_rev_check {
    my $name = shift;
    my $conf = Ximian::BB::Lint::get_conf();

    if (defined $conf->{rev} and not ref $conf->{rev}) {
	Ximian::BB::Lint::test_pass($name);
    } else {
	Ximian::BB::Lint::test_fail($name);
    }
}

sub do_builddep_check {
    my $name = shift;
    my $conf = Ximian::BB::Lint::get_conf();

    if (exists $conf->{build}
	and exists $conf->{build}->{default}
	and exists $conf->{build}->{default}->{builddep}
	and %{$conf->{build}->{default}->{builddep}}) {
	Ximian::BB::Lint::test_pass($name);
    } else {
	Ximian::BB::Lint::test_fail($name);
    }
}

1;
