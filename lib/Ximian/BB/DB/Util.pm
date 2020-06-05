# Routines that are useful for all cdbi classes

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

package Ximian::BB::DB::Util;


sub ts_inflate {
    my $ts = shift;
    $ts =~ s/-\d+$//;
    Time::Piece->strptime ($ts, "%Y-%m-%d %T");
}

sub ts_deflate {
    my $t = shift;
    $t->strftime ("%Y-%m-%d %T");
}

1;
