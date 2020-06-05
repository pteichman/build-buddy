package Ximian::Render::HTML;

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

require Ximian::Render;

our @ISA = qw(Ximian::Render);

sub new {
    return bless({}, shift);
}

sub render_group_pre {
    my ($self, $items, $columns, $group, $all_columns, $user_data) = @_;
    return "<table>\n";
}

sub render_group_post {
    return "</table>\n";
}

sub render_no_group_pre {
    my ($self, $items, $columns) = @_;

    my $ret = "<table>\n<thead><tr>";
    foreach my $column (@$columns) {
	$ret .= "<td>$column</td>";
    }
    $ret .= "</tr></thead>\n";

    return $ret;
}

sub render_no_group_post {
    my ($self, $items, $columns) = @_;
    return "</table>\n";
}

sub render_item_pre {
    return "<tr>";
}

sub render_item_post {
    return "</tr>\n";
}

sub render_cell_pre {
    return "<td>";
}

sub render_cell_post {
    return "</td>";
}

1;
