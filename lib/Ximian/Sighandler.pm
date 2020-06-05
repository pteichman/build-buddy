package Ximian::Sighandler;

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
no strict 'vars'; # see comment below
use File::Basename;
use FindBin;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

########################################################################
# Signal handlers
########################################################################

# These were taken out from bb_do when run_cmd moved to Ximian::Run
# (and later renamed _system). Both bb_do and Ximian::Run access
# Ximian::Sighandler::* directly.

# Global variables needed by signal handlers.  (These would ideally be
# lexicals, except that accessing lexical variables isn't reentrant in
# non-threaded perl.  See perlipc(1) for info.)  Instead, use a hash
# with the same name as the sub to which it would be "local".

$_system{pid} = 0;
$progname = basename $0;

# Standard SIGQUIT/SIGTERM handler.

sub std_exit_handler {
    my $sig = shift;
    print STDERR "\n$progname received SIG${sig}.  Exiting.\n";
    exit 1;
}

# Used by Ximian::Run::_system to clean up background process groups,
# since they don't get terminal-generated signals.

sub pgrp_cleanup_exit_handler {
    my $sig = shift;

    # Our child may or may not be a process group leader (yay race
    # conditions).  Pass the signal on to the hypothetical process
    # group, ignoring errors.  It's still in our pgrp, but won't
    # necessarily get the signal if it was sent to us via kill(1) or
    # suchlike.  So pass on the signal.

    kill $sig, $_system{pid};
    kill $sig, -$_system{pid};
    waitpid $_system{pid}, 0;

    std_exit_handler ($sig);
}

1;
