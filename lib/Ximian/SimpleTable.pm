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

package Ximian::SimpleTable;

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  format_table
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

sub format_row {
    my ($elts, $widths, $sep) = @_;
    $sep =" | " unless defined $sep;

    my @row;
    for my $i (0 .. $#$elts) {
	# need to pad
	my $padnum = $widths->[$i] - length $elts->[$i];
        push @row, $elts->[$i] . " " x $padnum;
    }
    return join $sep, @row;
}

sub format_separator {
    my ($widths) = @_;
    my $elts;
    push @$elts, "-" x $_ foreach (@$widths);
    return format_row ($elts, $widths, "-+-");
}

sub format_table {
    my ($labels, $rows) = @_;
    my $widths;
    push @$widths, length $_ foreach (@$labels);

    foreach my $row (@$rows) {
	if (defined $row) {
	    for my $i (0 .. $#$row) {
		$widths->[$i] = length $row->[$i]
		    if length $row->[$i] > $widths->[$i];
	    }
	}
    }

    my $table = [];
    my $row = format_row ($labels, $widths);
    $row =~ s/\s+^//;
    push @$table, $row;
    push @$table, format_separator($widths);

    foreach my $row (@$rows) {
	if (defined $row) {
	    my $foo = format_row($row, $widths);
	    $foo =~ s/\s^//;
	    push @$table, $foo;
	} else {
	    push @$table, format_separator($widths);
	}
    }

    return join "\n", @$table;
}

1;

