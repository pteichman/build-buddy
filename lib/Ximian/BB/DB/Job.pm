package Ximian::BB::DB::Job;

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

use base 'Ximian::BB::DB::DBI';
use Class::DBI::AbstractSearch;
use Ximian::BB::DB::Util;

__PACKAGE__->table ('jobs', 'jobs');
__PACKAGE__->sequence ('jobs_jobid_seq');
__PACKAGE__->columns (Primary => qw/jobid/);
__PACKAGE__->columns (Others => qw/uid nodeid jailid target modules
                                   start_time end_time statusid/);

__PACKAGE__->has_a (uid => 'Ximian::BB::DB::User');
__PACKAGE__->has_a (nodeid => 'Ximian::BB::DB::Node');
__PACKAGE__->has_a (statusid => 'Ximian::BB::DB::Status');
__PACKAGE__->has_a (start_time => 'Time::Piece',
		    inflate => \&Ximian::BB::DB::Util::ts_inflate,
		    deflate => \&Ximian::BB::DB::Util::ts_deflate);
__PACKAGE__->has_a (end_time => 'Time::Piece',
		    inflate => \&Ximian::BB::DB::Util::ts_inflate,
		    deflate => \&Ximian::BB::DB::Util::ts_deflate);

package Ximian::BB::DB::Status;

use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('status');
__PACKAGE__->columns (All => qw(statusid name));

1;
