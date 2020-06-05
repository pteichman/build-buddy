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

package Ximian::BB::DB::User;

use base 'Ximian::BB::DB::DBI';
use Ximian::BB::DB::Util;

__PACKAGE__->table ('users', 'users');
__PACKAGE__->sequence ('users_uid_seq');
__PACKAGE__->columns (Primary => qw/uid/);
__PACKAGE__->columns (Others => qw/login password
                                   auth_key auth_timestamp email/);

__PACKAGE__->has_a (auth_timestamp => 'Time::Piece',
		    inflate => \&Ximian::BB::DB::Util::ts_inflate,
		    deflate => \&Ximian::BB::DB::Util::ts_deflate);

__PACKAGE__->set_sql (capabilities => qq{
    SELECT user_capabilities.capid, user_capabilities.enabled
      FROM user_capabilities, users
     WHERE user_capabilities.uid = users.uid
});

__PACKAGE__->set_sql (enable_capability => qq{
    UPDATE user_capabilities
       SET enabled = 'true'
     WHERE user_capabilities.uid = users.uid -- FIXME --
});

sub capabilities {
    my ($self, $newcaps) = @_;
    if ($newcaps) {
	my $sth = $self->sql_update_capabilities;
	
    } else {
	my $sth = $self->sql_capabilities;
	$sth->execute;
	return $sth->fetchall_arrayref;
    }
}


package Ximian::BB::DB::Capability;

use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('capabilities', 'capabilities');
__PACKAGE__->sequence ('capabilities_capid_seq');
__PACKAGE__->columns (Primary => qw/capid/);
__PACKAGE__->columns (Others => qw/name default_value/);


package Ximian::BB::DB::UserCapability;

use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('user_capabilities', 'user_capabilities');
__PACKAGE__->columns (Primary => qw/uid capid/);
__PACKAGE__->columns (Others => qw/enabled/);


1;
