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

# $Id: BasicBBOper.pm 3072 2005-12-22 19:58:58Z v_thunder $

#------------------------------------------------------------------------------
# Basic operations
#------------------------------------------------------------------------------

package BasicBBOper;

use Ximian::Util ':all';
use Ximian::BB::Module ':all';

Ximian::BB::Plugin::register
    (name => "basic",
     group => "operations",
     operations =>
     [
      { name => "noop",
        description => "Does nothing.",
        module => \&noop },
      { name => "info:packages",
        description => "Lists the package names for all of the modules in the product",
        module => \&info_packages },
      { name => "info:patches",
        description => "Lists the patches for all of the modules in the product",
        module => \&info_patches },
      ]);

#------------------------------------------------------------------------------

sub noop {
    my ($module, $data) = @_;
    reportline (2, "bb_build (noop): Doing absolutely nothing on: $module->{name}");
    return 0;
}

sub info_packages {
    my ($module, $data) = @_;
    foreach $package (package_names ($module->{conf})) {
	reportline (2, "$module->{name} ($module->{conf}->{fullversion}): $package");
    }
    return 0;
}

sub info_patches {
    my ($module, $data) = @_;
    my $conf = $module->{conf};

    reportline (2, "$module->{name} is not patched")
        unless exists $conf->{patch}->{i};

    foreach $patch (@{$conf->{patch}->{i}}) {
        reportline (2, "$module->{name}: $patch");
    }
    return 0;
}


1;
