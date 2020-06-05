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

package Ximian::BB::DB::Node;

use base 'Ximian::BB::DB::DBI';
use Class::DBI::AbstractSearch;
use Ximian::Util ':all';
use Ximian::BB::DB::Util;
use Ximian::BB::DB::Job;

__PACKAGE__->table ('nodes', 'nodes');

__PACKAGE__->columns (Primary => qw/nodeid/);
__PACKAGE__->columns (Essential => qw/host port/);
__PACKAGE__->columns (Others => qw/free_disk total_disk last_update active deleted/);

__PACKAGE__->has_a (last_update => 'Time::Piece',
		    inflate => \&Ximian::BB::DB::Util::ts_inflate,
		    deflate => \&Ximian::BB::DB::Util::ts_deflate);
__PACKAGE__->has_many (targets => 'Ximian::BB::DB::NodeTarget', 'nodeid');
__PACKAGE__->has_many (jobs => 'Ximian::BB::DB::Job', 'nodeid');

# like 'jobs' but only return running ones
sub running_jobs {
    my ($self) = @_;
    my ($status) = Ximian::BB::DB::Status->search (name => "running");
    return Ximian::BB::DB::Job->search (nodeid => $self->nodeid,
					statusid => $status);
}

# Reverse of add_to_targets, which is provided by Class::DBI
sub delete_from_targets {
    my ($self, $search) = @_;
    Ximian::BB::DB::NodeTarget->delete
	    ({nodeid => $self->nodeid, %$search});
}

sub set_targets {
    my ($self, @targets) = @_;
    my @current = map { $_ = $_->target }
        Ximian::BB::DB::NodeTarget->search ({nodeid => $self->nodeid});
    my ($new, $old) = setdiff (\@current, \@targets);

    foreach my $tgt (@$new) {
        Ximian::BB::DB::NodeTarget->create
                ({nodeid => $self->nodeid, target => $tgt});
    }

    foreach my $tgt (@$old) {
        my $it = Ximian::BB::DB::NodeTarget->search
	    ({nodeid => $self->nodeid, target => $tgt});
	$it->delete_all;
    }

    return map {$_ = $_->target}
	Ximian::BB::DB::NodeTarget->search ({nodeid => $self->nodeid});
}

package Ximian::BB::DB::NodeTarget;

use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('node_targets', 'node_targets');
__PACKAGE__->columns (Primary => qw(nodeid target));
# If we inflate the node, we can't delete NodeTarget objects!
# # # __PACKAGE__->has_a (nodeid => 'Ximian::BB::DB::Node');

1;
