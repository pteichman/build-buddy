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

package TinderLogStyle;

main::register_logstyle ("tinderbox",
			 { start => \&log_start,
			   end => \&log_end, });

########################################################################

sub log_start {
    my ($job_info) = @_;
    require Ximian::Tinderbox;
    Ximian::Tinderbox::status_start ($job_info);
}

sub log_end {
    my ($job_info) = @_;
    require Ximian::Tinderbox;
    Ximian::Tinderbox::status_end ($job_info);
}

1;
