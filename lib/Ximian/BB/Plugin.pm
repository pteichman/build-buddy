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

package Ximian::BB::Plugin;

use strict;
use Carp;

use Ximian::Util ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  load_plugins
                  get_plugins
                  get_plugin
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

my %plugins;

sub load_plugins {
    my $pluginsdir = shift;
    foreach my $dir (dirgrep {-d "$pluginsdir/$_" and /^[^.]+.*$/} $pluginsdir) {
        reportline ({level=>4,nline=>0}, "Populating \"$dir\" plugins: ");
        my $first = 1;
        foreach my $file (dirgrep {/^[^.]+.*\.pm$/} "$pluginsdir/$dir") {
            report (4, ", ") unless $first;
            $first = 0;
            require "$pluginsdir/$dir/$file";
        }
        report (4, ".\n\n");
    }
    return %plugins;
}

sub register {
    my $plugin = {@_};
    reportline (2, "Warning: redefining plugin \"$plugin->{name}\".")
        if exists $plugins{$plugin->{group}}->{$plugin->{name}};
    $plugins{$plugin->{group}}->{$plugin->{name}} = $plugin;
    report (4, "$plugin->{name}");
}

sub get_plugins {
    return %plugins;
}

sub get_plugin {
    my ($group, $name) = @_;
    return undef unless $group and $name;
    if (exists $plugins{$group} and exists $plugins{$group}->{$name}) {
        return $plugins{$group}->{$name};
    }
    return undef;
}

1;
