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

package EmailLogStyle;

use Mail::Sendmail;
use Ximian::Util ':all';
use Ximian::SimpleTable ':all';

main::register_logstyle ("email",
			 { job_start => \&job_start,
			   job_end => \&job_end,
			   snaps_start => \&snaps_start,
			   snaps_end => \&snaps_end, });

my %args;
parse_args
    (\%args,
     [
      {names => ["logstyle_to"], type => "=s", default => ""},
      {names => ["logstyle_from"], type => "=s",
       default => "release\@ximian.com"},
      {names => ["logstyle_subject"], type => "=s",
       default => "BB Snapshots Submission Log"},
     ]);

########################################################################

sub mail {
    my ($addr, $msg) = @_;
    sendmail ( To => $addr, From => $args{logstyle_from},
	       Subject => $args{logstyle_subject},
	       Message => $msg )
	or die $Mail::Sendmail::error;
}

sub render_summary {
    my %jobs_by_name = @_;
    my $msg;

    while (my ($name, $jobs) = each %jobs_by_name) {
	my @succeeded = grep { $_->{status} eq "succeeded"} @$jobs;
	my $succ = scalar @succeeded;
	my $tot = scalar @$jobs;
	$msg .= "$name: ($succ / $tot)\n";
    }
    return $msg;
}

sub render_jobs {
    my %jobs_by_name = @_;
    my $msg;

    my @labels = ("Jobid", "Target", "Status");
    while (my ($name, $jobs) = each %jobs_by_name) {
	my @rows;
	push @rows, [$_->{jobid}, $_->{conf}->{target}, $_->{status}]
	    foreach (sort {$a->{status} cmp $b->{status}} @$jobs);
	my $table = format_table (\@labels, \@rows);
	$msg .= "$name:\n$table\n\n";
    }
    return $msg;
}

########################################################################

sub snaps_start {
    my @jobs = @_;
}

sub snaps_end {
    my @jobs = @_;

    if ($args{logstyle_to}) {
	# This'll work remotely (no local DB)

	my %by_name;
	foreach my $job (@jobs) {
	    eval {
		$job->{status} = $main::master->call ("job_status", $job{jobid});
	    };
	    if (my $e = $@) {
		$job->{status} = "unknown";
	    }

	    $by_name{$job->{name}} = []
		unless exists $by_name{$job->{name}};
	    push @{$by_name{$job->{name}}}, $job;
	}
	my $msg = "Snapshot Summary:\n\n";
	$msg .= "Values are (succeeded / total)\n\n";
	$msg .= render_summary (%by_name);
	$msg .= "\nSnapshot Details:\n\n";
	$msg .= render_jobs (%by_name);
	mail ($args{logstyle_to}, $msg);
    } else {
	# This needs to run on the master

	my %by_email;
	foreach my $job (@jobs) {
	    require Ximian::BB::DB::Job;

	    eval {
		my $dbjob = Ximian::BB::DB::Job->retrieve ($job->{jobid});
		$job->{status} = $dbjob? $dbjob->statusid->name : "unknown";
	    };
	    if (my $e = $@) {
		$job->{status} = "unknown";
	    }

	    # FIXME: uh..
	    my $dbsaved = Ximian::BB::DB::SavedJob->retrieve ($job->{sjid});
	    my $email = $dbsaved? $dbsaved->uid->email : "thunder\@ximian.com";

	    report (3, "Warning: could not retrieve saved job, " .
		    "sending email to thunder\@ximian.com") unless $dbsaved;

	    $by_email{$email} = {}
		unless exists $by_email{$email};
	    $by_email{$email}->{$job->{name}} = []
		unless exists $by_email{$email}->{$job->{name}};

	    push @{$by_email{$email}->{$job->{name}}}, $job;
	}

	while (my ($addr, $by_name) = each %by_email) {
	    my $msg = "Snapshot Summary:\n\n";
	    $msg .= "Values are (succeeded / total)\n\n";
	    $msg .= render_summary (%$by_name);
	    $msg .= "\nSnapshot Details:\n\n";
	    $msg .= render_jobs (%$by_name);
	    mail ($addr, $msg);
	}
    }
}

########################################################################
# NOTE: These get called in a forked process

sub job_start {
    my %job = @_;
}

sub job_end {
    my %job = @_;
}

1;
