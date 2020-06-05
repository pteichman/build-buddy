package Ximian::Dep;

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

# $Id: Dep.pm 3068 2005-12-22 03:41:13Z v_thunder $

use strict;
use Carp;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  resolve_dependencies
                  mark_all
                  mark_dependencies
                  mark_dependents
		  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################
#
# Routines for linearizing a dependency graph into an array, such that
# any given node depends *only* on nodes before it. These functions
# perform the dependency resolution for the bb_build command.  They
# are generic enough that can be used for other tools as well,
# however.
#
# To use the engine, all that is needed is a hashref containing
# noderefs as values.  The keys don't matter, but setting them to the
# node name is recommended.
#
# A node is a hash that defines the following keys:
#
# name -> the name of this node (as a string).
# dependency_names -> an array containing the names (strings) of
#                     the other nodes that this one depends on.
#
# You must provide the above information.
#
# Once the engine has finished, each node will contain the above,
# plus:
#
# depth -> node depth (integer).
#
# sparse_dependencies,
# sparse_dependents -> array of refs to nodes that this node depends
#                      on / depend on this node.
#
# deep_dependencies,
# deep_dependents -> array of refs to all the nodes that, in one way
#                    or another, this node depends on / depend on this
#                    node.
#
# Also, the resolve_dependencies function (the main entry point
# into the engine) returns an array of sorted noderefs.
#
######################################################################

# Connect, resolve, and flatten the dependency graph.

sub resolve_dependencies {
    my ($depgraph) = @_;

    connect_sparse_dependencies ($depgraph);
    my $nodes_by_depth = connect_depgraph ($depgraph);
    my $flattened_modules = flatten_graph ($nodes_by_depth);

    return $flattened_modules;
}

# Prepare the dependency graph for later use by
# filling in the sparse dependencies (and dependents).
# Note that $depgraph will be changed by this function.

sub connect_sparse_dependencies {
    my $depgraph = shift;
    foreach my $node (values %$depgraph) {
	foreach my $dep (@{$node->{dependency_names}}) {
	    die "Could not find dependency '$dep' referenced by $node->{name}\n"
		unless exists $depgraph->{$dep};
	    $node->{sparse_dependencies}->{$dep} = $depgraph->{$dep};
	    $depgraph->{$dep}->{sparse_dependents}->{$node->{name}} = $node;
	}
    }
    return $depgraph;
}

# Connect the dependencies/dependents (densely), find out the depth
# of each node.  In the process, also check for cycles in the graph.
# Note that $depgraph will be changed by this function.

sub connect_depgraph {
    my ($depgraph) = @_;
    my %nodes_by_depth;
    my $pass_num = 0;

    # Set depth of all nodes to 0 initially
    $_->{depth} = 0 foreach (values %$depgraph);

    foreach my $node (values %$depgraph) {
	connect_depgraph_for_node (depgraph => $depgraph,
				   initial_node => $node,
				   cur_node =>$node,
				   pass => $pass_num++,
				   nodes_by_depth => \%nodes_by_depth);
    }
    return \%nodes_by_depth;
}

# Helper function for connect_depgraph.
#   Ximian::Dep::connect_depgraph_for_node(opt => val,...)
#   opts are: depgraph, initial_node, cur_node, pass, nodes_by_depth

sub connect_depgraph_for_node {
    croak "Ximian::Dep::connect_depgraph_for_node: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $node = $opts->{cur_node};
    my $pass = $opts->{pass};

    if (exists $node->{"cycle-check"}) {
	return $node->{depth};
    }

    if ($node->{"cycle-check-$pass"}) {
	print STDERR "Cycle found in the dependency graph.\n";
	print STDERR "The offending cycle: ";
	print_cycle ($opts->{initial_node}, $node);
	print STDERR "\n";
	exit (1);
    }
    $node->{"cycle-check-$pass"} = 1;

    foreach my $child (values %{$node->{sparse_dependencies}}) {
	$node->{depth} +=
	    connect_depgraph_for_node (depgraph => $opts->{depgraph},
				       initial_node => $opts->{initial_node},
				       cur_node => $child,
				       pass => $pass,
				       nodes_by_depth => $opts->{nodes_by_depth});

	foreach (keys %{$child->{dense_dependencies}}) {
	    $node->{dense_dependencies}->{$_} = $opts->{depgraph}->{$_};
	    $opts->{depgraph}->{$_}->{dense_dependents}->{$node->{name}} = $node;
	}
	$child->{dense_dependents}->{$node->{name}} = $node;
	$node->{dense_dependencies}->{$child->{name}} = $child;
    }

    $node->{"cycle-check"} = 1;

    push @{$opts->{nodes_by_depth}->{$node->{depth}}}, $node;
    return $node->{depth};
}

# Flatten the dependency graph, for use in building
#   Ximian::Dep::flatten_graph($nodes_by_depth)
#   opts are: nodes_by_depth (ref to a hash containing lists of nodes)
#   returns: ref of array of nodes

sub flatten_graph {
    my $nodes_by_depth = shift;
    my @module_list;

    foreach (sort { $a <=> $b } keys %$nodes_by_depth) {
	push @module_list, @{$nodes_by_depth->{$_}}
    }
    return \@module_list;
}

# Print a cycle in the dependency graph

sub print_cycle {
    my ($base_node, $cur_node) = shift;
    my $ret;

    foreach my $child (values %{$cur_node->{sparse_dependencies}}) {
	if ($child == $base_node) {
	    print STDERR "$child->{name} $cur_node->{name} ";
	    return 1;
	} else {
	    $ret = print_cycle ($base_node, $child);
	    if ($ret == 1) {
		print STDERR "$cur_node->{name} ";
		return 1;
	    }
	}
    }
    return 0;
}

######################################################################
# Dependency graph manipulation

sub mark_all {
    my ($graph, $attribute, $value) = @_;

    foreach my $node (values %$graph) {
	$node->{$attribute} = $value;
    }
}

sub mark_dependencies {
    my ($graph, $node, $attribute, $value) = @_;

    foreach my $dep (keys %{$node->{dense_dependencies}}) {
	$graph->{$dep}->{$attribute} = $value;
    }
}

sub mark_dependents {
    my ($graph, $node, $attribute, $value) = @_;

    foreach my $dep (keys %{$node->{dense_dependents}}) {
	$graph->{$dep}->{$attribute} = $value;
    }
}

######################################################################


######################################################################

# Returns 1 if the second argument depends on the first, 0 otherwise.

sub depends_on {
    my ($first, $second) = @_;
    return 1 if exists $first->{dense_dependents}->{$second->{name}};
    return 0;
}

1;
