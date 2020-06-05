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

package DemoLogStyle;

use Ximian::Util ':all';

main::register_logstyle ("demo",
			 { job_start => \&job_start,
			   job_end => \&job_end,
			   snaps_start => \&snaps_start,
			   snaps_end => \&snaps_end, });

########################################################################

sub snaps_start {
    my @jobs = @_;
    report (2, "Snap jobs submitted:");
    foreach my $job (@jobs) {
	report (2, "\t$job->{jobid}: $job->{name}/$job->{conf}->{target}");
    }
}

sub snaps_end {
    my @jobs = @_;
    report (2, "All snap jobs finished.");
}

########################################################################

sub job_start {
    my %job = @_;
    report (2, "Job $job{jobid} started:");
    report (2, "\tName: $job{name}");
    report (2, "\tTarget: $job{conf}->{target}");
    report (2, "\tStatus: $job{status}");
}

sub job_end {
    my %job = @_;
    report (2, "Job $job{jobid} finished:");
    report (2, "\tName: $job{name}");
    report (2, "\tTarget: $job{conf}->{target}");
    report (2, "\tStatus: $job{status}");
}

1;
