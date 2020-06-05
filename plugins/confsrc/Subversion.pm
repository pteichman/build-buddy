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

package SubversionConfSource;

use strict;

use Ximian::Util ':all';
use Ximian::Run ':all';
use Ximian::BB::Macros ':all';

Ximian::BB::Plugin::register (name => "svn",
                              group => "confsrc",
                              get => \&get,
                              update => \&update);

########################################################################

sub get {
    my ($conf, $location) = @_;
    my $tmp = make_temp_dir ".";
    pushd $tmp;
    my $cmd = "svn checkout $conf->{source}->{url}";
    reportline (2, "Running: $cmd");
    if (run_cmd ($cmd)) {
	reportline (1, "Error running $cmd: $!");
        popd;
        run_cmd ("rm -rf $tmp");
        return 0;
    }
    popd;
    run_cmd ("mv $tmp/* $location"); # hmm a bit sloppy
    run_cmd ("rm -rf $tmp");
    return 1;
}

sub update {
    my ($conf, $location) = @_;
    pushd $location;
    my $cmd = "svn update";
    reportline (2, "Running: $cmd");
    if (run_cmd ($cmd)) {
	reportline (1, "Error running $cmd: $!");
        popd;
        return 0;
    }
    popd;
    return 1;
}

1;
