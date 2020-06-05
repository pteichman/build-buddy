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

package HTMLEmailLogStyle;

use Mail::Sendmail;
use Ximian::Util ':all';
use Ximian::Render::HTML2;
use Ximian::BB::Conf ':all';

my ($bb_info) = get_os_info ();
my $render = Ximian::Render::HTML2->new;

main::register_logstyle ("html_email",
			 { job_start => \&job_start,
			   job_end => \&job_end,
			   snaps_start => \&snaps_start,
			   snaps_end => \&snaps_end, });

my %args;
parse_args
    (\%args,
     [
      {names => ["html_email_logstyle_to"], type => "=s", default => ""},
      {names => ["html_email_logstyle_from"], type => "=s",
       default => "release\@ximian.com"},
      {names => ["html_email_logstyle_subject"], type => "=s",
       default => "BB Snapshots Submission Log"},
     ]);

########################################################################

sub mail {
    my ($addr, $msg) = @_;
    sendmail ( To => $addr, From => $args{html_email_logstyle_from},
	       Subject => $args{html_email_logstyle_subject},
	       'content-type' => 'text/html; charset="iso-8859-1"',
	       Message => $msg )
	or die $Mail::Sendmail::error;
}

sub render_summary {
    my %jobs_by_name = @_;

    my @labels = ("Name", "Succeeded", "Total");
    my @rows;
    while (my ($name, $jobs) = each %jobs_by_name) {
	my @succeeded = grep { $_->{status} eq "succeeded"} @$jobs;
	my $succ = scalar @succeeded;
	my $tot = scalar @$jobs;
	push @rows, {Name => $name,
		     Succeeded => $succ,
		     Total => $tot};
    }
    my $table = $render->render (\@rows, \@labels);
    return $table;
}

sub render_jobs {
    my %jobs_by_name = @_;
    my $msg;

    my @labels = ("Jobid", "Target", "Status");
    while (my ($name, $jobs) = each %jobs_by_name) {
	my @rows;
	foreach my $j (sort {$a->{status} cmp $b->{status}} @$jobs) {
	    my $master = $bb_info->{daemon}->{master};
	    my $path = "/report/jobinfo.html?jobid=$j->{jobid}";
	    my $link = "<a href=\"http://$master$path\">$j->{jobid}</a>";
	    push @rows, {Jobid => $link,
			 Target => $j->{conf}->{target},
			 Status => $j->{status}}
	}
	my $table = $render->render (\@rows, \@labels);
	$msg .= "<p><b>$name:</b><br />$table</p>";
    }
    return $msg;
}

sub render_msg {
    my $summary = render_summary (@_);
    my $details = render_jobs (@_);
    my $msg = <<MSG_END;
<html>
<h3>Snapshot Summary:</h3>
<p>$summary</p>
<h3>Snapshot Details:</h3>
$details
</html>
MSG_END
    return $msg;
}

########################################################################

sub snaps_start {
    my @jobs = @_;
}

sub snaps_end {
    my @jobs = @_;

    report (4, "Snaps finished, sending HTML mail for " . scalar @jobs . " snaps");

    if ($args{html_email_logstyle_to}) {
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

	my $msg = render_msg (%by_name);
        mail ($args{html_email_logstyle_to}, $msg);
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
	    my $msg = render_msg (%$by_name);
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
