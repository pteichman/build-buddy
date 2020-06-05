package Ximian::BB::DB::DBI;

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

use base 'Class::DBI';

__PACKAGE__->set_db ('Main', 'dbi:Pg:dbname=build', '', '',
		     {AutoCommit => 1});

# From the Class::DBI perldoc:
sub do_transaction {
    my ($class, $code) = @_;

    # Turn off AutoCommit for this scope.
    # A commit will occur at the exit of this block automatically,
    # when the local AutoCommit goes out of scope.
    local $class->db_Main->{ AutoCommit };

    # Execute the required code inside the transaction.
    eval { $code->() };
    if ( $@ ) {
	my $commit_error = $@;
	eval { $class->dbi_rollback }; # might also die!
	die $commit_error;
    }
}

1;
