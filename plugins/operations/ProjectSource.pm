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

package ProjectSource;

use Ximian::Util ':all';
use Ximian::BB::Conf ':all';
use Ximian::BB::Globals;
use Ximian::BB::Macros ':all';
use Ximian::BB::Plugin ':all';

Ximian::BB::Plugin::register
    (name => "project-sources",
     group => "operations",
     operations =>
     [
      { name => "project:source",
        description => "Gets or updates the project-wide sources.",
        pre => \&update_project_sources,
        module => \&update_module_sources
      },
      ]);

########################################################################

sub update_project_sources {
    my ($pconf, $data) = @_;

    my $h;
    my $loc = get_dir ("checkoutdir");
    if (-d $loc and $pconf->{source}) {
        $h = confsrc_find ($pconf, "update");
    } elsif (not -d $loc and $pconf->{source}) {
        $h = confsrc_find ($pconf, "get");
    } else {
        return 0;
    }
    return 1 unless $h;
    return ! $h->($pconf, $loc);
}

sub update_module_sources {
    my ($module, $data) = @_;
    my $h;
    my $loc = $module->{dir}->{moduledir};
    if (-d $loc and $module->{source}) {
        $h = confsrc_find ($module, "update");
    } elsif (not -d $loc and $module->{source}) {
        $h = confsrc_find ($module, "get");
    } else {
        return 0;
    }
    return 1 unless $h;
    return ! $h->($module, $loc);
}

sub confsrc_find {
    my ($module, $op) = @_;
    my $plugin = get_plugin ("confsrc", $module->{source}->{type});
    my $handler = $plugin->{$op};
    unless ($handler) {
        reportline (1, "Could not find handler for module \"$module->{name}\"");
        return "";
    }
    return $handler;
}

1;
