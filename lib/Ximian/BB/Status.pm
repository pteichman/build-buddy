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

package Ximian::BB::Status;

use strict 'vars';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		  status_push
		  status_pop
		  status_do_sub
		  status_do
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

my $orig = $0;
my @stack;

sub status_push {
    my $str = shift;
    $0 = "$orig [ $str ]";
    push @stack, $str;
}

sub status_pop {
    my $old = pop @stack;
    $0 = ($#stack+1 ? "$orig [ $stack[-1] ]" : $orig);
    return $old;
}

sub status_do_sub {
    my $status = shift;
    my $code = shift;
    my @args = @_;

    status_push ($status);
    my $ret = $code->(@args);
    status_pop;

    return $ret;
}

sub status_do (&;$) {
    my ($code, $status) = @_;
    return status_do_sub ($status, $code)
}

1;

__END__

=pod

=head1 NAME

Ximian::BB::Status - status information in the process table

=head1 SYNOPSIS

use Ximian::BB::Status;

status_push("building packages");

    [ build packages ]

status_pop();

status_do ("doing something", \&do_something, $arg, $arg1, ...);

=head1 DESCRIPTION

Ximian::BB::Status provides a stack of status strings to be inserted
into the process table entry of the current process.

Assuming the current process is called "bb_do":

    status_push("building packages");

        => process is called "bb_do [ building packages ]"

    status_push("building glib");

        => process is called "bb_do [ building glib ]"

    status_pop();

        => process is called "bb_do [ building packages ]"

    status_pop();

        => process is called "bb_do"

A shortcut is available for running a single function (possibly with
arguments) with a status attached to it.  The following two pieces of
code are equivalent:

The long way:

status_push ("status");
my $ret = do_something ($arg);
status_pop;

The shorthand:

my $ret = status_do ("status", \&do_something, $arg);

=head1 AUTHORS

Peter Teichman <peter@ximian.com>
Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2000-2001 Ximian, Inc. <distribution@ximian.com>.  All
rights reserved.

=cut
