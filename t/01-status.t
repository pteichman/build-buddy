#!perl

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

#
# testing the Ximian::BB::Status module
#

use strict;
use Test;
use ExtUtils::testlib;

my (@statuses, @expected);

BEGIN {
    @statuses = ('one', 'two', 'three', 'four');
    plan tests => 3*scalar(@statuses);
}

use Ximian::BB::Status;

my $cmdline = $0;

# build a list of the strings expected in $0 as we pop them
@expected = map "$cmdline [ $_ ]", reverse @statuses;
push @expected, $cmdline;
@expected = reverse @expected;

foreach (@statuses) {
    status_push($_);
    ok($0, "$cmdline [ $_ ]");
}

foreach (reverse(0 .. $#statuses)) {
    my $str     = status_pop();

    ok($str, $statuses[$_]);  # make sure we pop the correct string
    ok($0,   $expected[$_]);  # make sure $0 is set to what we expect
}

exit;
