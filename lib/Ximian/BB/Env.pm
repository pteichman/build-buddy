package Ximian::BB::Env;

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

# $Id: $

use strict;
use Carp;

use Ximian::Util ':all';
use Ximian::BB::Macros ':all';
use Ximian::BB::XMLUtil ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  env_cleanup
                  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

# Environment variable cleanup

sub env_cleanup {
    my $tmp = shift() || $Ximian::BB::Globals::confs;

    my @confs = reverse @$tmp;
    my $merged = {};
    xml_merge ($_, $merged) foreach (@confs);

    # Run through the list once to find what we need to set/passthru

    my @passthru;
    my @unset;
    my %set;
    while (my ($var, $val) = each %{$merged->{env}}) {
        if (ref $val and $val->{passthru}) {
            push @passthru, $var;
            next;
        }
        if (ref $val and not exists $val->{content}) {
            push @unset, $var;
            next;
        }
        $val = $val->{content} if ref $val;
        $set{$var} = macro_replace ($val);
    }

    # Now clean up

    reportline (3, "Env Cleanup");
    foreach my $var (keys %ENV) {
        delete $ENV{$var} unless grep (/^$var$/, @passthru);
    }
    reportline (3, "Env Passthru: $_") foreach @passthru;

    # And set the desired ones

    while (my ($var, $val) = each %set) {
        reportline (3, "Env $var = $val");
        $ENV{$var} = $val;
    }
}

1;

__END__
