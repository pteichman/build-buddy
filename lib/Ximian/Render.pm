package Ximian::Render;

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

sub resolve_groups {
    my $bugs      = shift;

    # we don't pull $groupref straight from $args, because that's a
    # reference to the original.
    my $groupref     = shift || [];
    my $groupargsref = shift || [];
    my $args         = shift;

    return $bugs if not defined $groupref or not scalar @{$groupref};

    # copy the groups, so we can shift () without destructing the
    # original ref
    my @groups = @{$groupref};
    my @groupargs = @{$groupargsref};

    my $groupfunc = shift (@groups);
    my $grouparg = shift (@groupargs);

    my @sortfuncs;
    if (exists $args->{sort}) {
	@sortfuncs = reverse @{$args->{sort}};
    }

    my $tmp = {};
    foreach my $bug (@{$bugs}) {
	my $key = &{$groupfunc} ($bug, $grouparg);

	$tmp->{$key} = [] if (not exists $tmp->{$key});
	push @{$tmp->{$key}}, $bug;
    }

    if (scalar @groups) {
	foreach (keys %$tmp) {
	    $tmp->{$_} = resolve_groups ($tmp->{$_}, \@groups, \@groupargs, $args);
	}
    } else {
	foreach my $group (keys %$tmp) {
	    foreach my $func (@sortfuncs) {
		my @tmp = sort $func @{$tmp->{$group}};
		$tmp->{$group} = \@tmp;
	    }
	}
    }
    return $tmp;
}

sub render_groups {
    my ($context, $groups, $columns, $groupsort, $group_name, $user_data) = @_;

    my $ret;
    if (ref $groups eq 'HASH') {
	# we have groups

	my @grouplist = keys %$groups;

	if (defined $groupsort and scalar @{$groupsort}) {
	    my $func = shift (@{$groupsort});
	    @grouplist = sort $func @grouplist;
	}

	foreach my $group (@grouplist) {
	    $ret .= $context->render_group_pre ($groups->{$group}, $columns,
						$group, $context->{columns},
						$user_data);
	    $ret .=
		render_groups ($context, $groups->{$group}, $columns,
			      $groupsort, $group, $user_data);
	    $ret .= $context->render_group_post ($groups->{$group}, $columns,
						 $group, $context->{columns},
						 $user_data);
	}
    } else {
	# we have an array, just cells
	foreach my $item (@$groups) {
	    $ret .= $context->render_item_pre ($item, $columns,
					       $group_name, $user_data);
	    $ret .= $context->render_item ($item, $columns,
					   $group_name, $user_data);
	    $ret .= $context->render_item_post ($item, $columns,
						$group_name, $user_data);
	}
    }
    return $ret;
}

sub render {
    my ($context, $items, $columns, $args, $user_data) = @_;

    my $grouping_function;
    if (defined $args->{group}) {
	$grouping_function = $args->{group};
    }

    my $renderitems = resolve_groups ($items, $grouping_function,
				      $args->{grouparg}, $ args);

    my @groupsort = @{$args->{groupsort}} if exists $args->{groupsort};

    if (ref $renderitems eq 'ARRAY') {
	my $ret = "";
	$ret .= $context->render_no_group_pre ($renderitems, $columns,
					       $context->{columns},
					       $user_data);
	$ret .= render_groups ($context, $renderitems, $columns,
			      \@groupsort, undef, $user_data);
	$ret .= $context->render_no_group_post ($renderitems, $columns,
						$context->{columns},
						$user_data);
	return $ret;
    } else {
	return render_groups ($context, $renderitems, $columns,
			     \@groupsort, undef, $user_data);
    }
}

sub render_group_pre {
    my ($self, $items, $columns, $group, $all_columns, $user_data) = @_;
    return "";
}

sub render_group_post {
    my ($self, $items, $columns, $group, $all_columns, $user_data) = @_;
    return "";
}

sub render_no_group_pre {
    my ($self, $items, $columns, $all_columns, $user_data);
    return "";
}

sub render_no_group_post {
    my ($self, $items, $columns, $all_columns, $user_data);
    return "";
}

sub render_item {
    my ($self, $item, $columns, $group_name, $user_data) = @_;

    my $ret = "";

    foreach my $column (@$columns) {
	$ret .= $self->render_cell_pre ($item, $column);
	$ret .= $self->render_cell ($item, $column);
	$ret .= $self->render_cell_post ($item, $column);
    }

    return $ret;
}

sub render_item_pre {
    my ($self, $item, $columns, $group_name, $user_data) = @_;
    return "";
}

sub render_item_post {
    my ($self, $item, $columns, $group_name, $user_data) = @_;
    return "";
}

sub render_cell {
    my ($self, $item, $column) = @_;

    if (exists $self->{render}->{$column}) {
	return &{$self->{render}->{$column}}($item, $column);
    } else {
	return $item->{$column};
    }
}

sub render_cell_pre {
    my ($self, $item, $column) = @_;
    return "";
}

sub render_cell_post {
    my ($self, $item, $column) = @_;
}

1;
