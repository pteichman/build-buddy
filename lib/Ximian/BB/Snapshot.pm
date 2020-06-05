# Collection of misc snapshot-related functions

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

package Ximian::BB::Snapshot;

use strict;
use Ximian::BB::Conf ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		  snapshot_timestamp
		  snapshot_cvs_version
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

#------------------------------------------------------------------------------

sub snapshot_timestamp {
    my ($packsys, $timestamp) = @_;
    my ($sec, $min, $hour, $mday, $mon, $year) = gmtime ($timestamp);

    $year += 1900;
    $mon++;

    if ($packsys eq "dpkg") {
	return sprintf ("%04d.%02d.%02d.%02d.%02d",
			$year, $mon, $mday, $hour, $min);
    }
    return sprintf ("%04d%02d%02d%02d%02d",
		    $year, $mon, $mday, $hour, $min);
}

sub snapshot_cvs_version {
    my ($module, $conf, $timestamp, $packsys) = @_;
    $timestamp = snapshot_timestamp ($packsys, $timestamp);
    my $srcname = $conf->{srcname} || $conf->{name} || $module;
    my $resrcname = quotemeta ($srcname);
    my @tarballs = glob ("$srcname*.{tar.gz,tgz,tar.bz2}");

    foreach (@tarballs) {
        if (/$resrcname-(.*).(tar.gz|tgz|tar.bz2)/) {
	    print "Using CVS version: $1.0.$timestamp\n";
            return "$1.0.$timestamp";
        }
    }
    foreach (@tarballs) {
        if (/$resrcname\.(.*).(tar.gz|tgz|tar.bz2)/) {
	    print "Using CVS version: $1.0.$timestamp\n";
            return "$1.0.$timestamp";
        }
    }
    print "Error: Could not find CVS version of module \"$conf->{name}\".\n";
    return undef;
}

1;
