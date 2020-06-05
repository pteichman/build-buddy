package Ximian::Web::Utils;

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

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  prettify_targets
                  internal_redirect
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

# prettify_targets
# Takes a list of target strings, and formats them for nicer (and
# compact) display, suitable for web / console output

sub prettify_targets {
    my $targets = {};
    my @targetlist;

    foreach (@_) {
	my ($distro, $rev, $arch) = split /-/;

	$targets->{$distro} = {}
	    unless defined $targets->{$distro};
	$targets->{$distro}->{$arch} = {}
	    unless defined $targets->{$distro}->{$arch};
	$targets->{$distro}->{$arch}->{$rev} = 1
	    unless defined $targets->{$distro}->{$rev};
    }
    foreach my $distro (keys %$targets) {
	foreach my $arch (keys %{$targets->{$distro}}) {
	    push @targetlist, "$distro/$arch: " .
		join ",", sort keys %{$targets->{$distro}->{$arch}};

	}
    }
    return sort @targetlist;
}

1;
