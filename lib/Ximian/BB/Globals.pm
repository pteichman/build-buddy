package Ximian::BB::Globals;

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

######################################################################

# Variables used in various modules
# These are usually set by the main program, modules should generally
# not set them.

$Ximian::BB::Globals::packsys = "unknown";
$Ximian::BB::Globals::target = "unknown";

# This variable contains a list of directories to look in for BB
# configuration files.  It defaults to ** BBCONFS **, which gets
# substituted at compile-time.  In the case where BB is checked out
# from cvs/svn, BB is able to find the libraries that come with it,
# without using this library.

# At runtime, this variable can be set to other values, and other
# functions (particularly in the Ximian::BB::Conf module) will use
# this value as a default search path for configuration files.

# If you don't see the ** BBCONFS ** below, then this file probably
# came from a packaged version of BB, and it's already substituted.

@Ximian::BB::Globals::confdirs = ("**BBCONFS**");

# These are confs (bb, os, module), used for macro_replace mostly.

$Ximian::BB::Globals::confs = [];

# This one *is* set by a module (Ximian::Util).  It is used by the
# report() subroutine to determine when to output/supress messages.

$Ximian::Globals::verbosity = 0;

1;

__END__
