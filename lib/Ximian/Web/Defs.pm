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

package Ximian::Web::Defs;

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

{
    package HTML::Mason::Commands;
    # Modules loaded here will be available from mason components

    use strict;
    use Carp;
    use vars qw($r $m);
    use Cache::FileCache;

    use Ximian::Util ':all';
    use Ximian::BB::AuthClient;
    use Ximian::BB::DB::Job ();
    use Ximian::BB::DB::Node ();
    use Ximian::BB::DB::User ();

    $BBWeb::cache_root = "/srv/www/mason/cache";
#    $BBWeb::master = "build-master";
    $BBWeb::master = "localhost";
    $BBWeb::outputdir = "/srv/build-daemon";
#    $BBWeb::webui_comp_root = "/srv/www/htdocs";
    $BBWeb::webui_comp_root = "/mnt/hgfs/Shared/sources/forge-bb-cvs/bb/trunk-devel/web/webroot";

    # Extended warnings (tracebacks)
    $SIG{__WARN__} = \&Carp::cluck;
}

1;
