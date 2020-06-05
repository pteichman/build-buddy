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

package BirdmanEmailLogStyle;

use Mail::Sendmail;
use Ximian::Util ':all';
use Ximian::Render::HTML2;
use Ximian::BB::Conf ':all';

my ($bb_info) = get_os_info ();
my $render = Ximian::Render::HTML2->new;

main::register_logstyle ("birdman_email",
			 { job_start => \&job_start,
			   job_end => \&job_end,
			   snaps_start => \&snaps_start,
			   snaps_end => \&snaps_end, });

my %args;
parse_args
    (\%args,
     [
      {names => ["birdman_email_logstyle_to"], type => "=s", default => ""},
      {names => ["birdman_email_logstyle_from"], type => "=s",
       default => "release\@ximian.com"},
      {names => ["birdman_email_logstyle_subject"], type => "=s",
       default => "BB Snapshots Submission Log"},
      {names => ["birdman_email_logstyle_errorsubject"], type => "=s",
       default => "BB Snapshots Submission Error Log"},
     ]);

########################################################################

sub mail {
    my ($addr, $msg) = @_;
    sendmail ( To => $addr, From => $args{birdman_email_logstyle_from},
	       Subject => $args{birdman_email_logstyle_subject},
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
    my $with_name = shift;
    my %jobs_by_name = @_;

    my @labels = ("Jobid", "Target", "Status");
    unshift @labels, "Name" if $with_name;
    my @rows;
    while (my ($name, $jobs) = each %jobs_by_name) {
	foreach my $j (sort {$a->{status} cmp $b->{status}} @$jobs) {
	    my $master = $bb_info->{daemon}->{master};
	    my $path = "/report/jobinfo.html?jobid=$j->{jobid}";
	    my $link = "<a href=\"http://$master$path\">$j->{jobid}</a>";
	    push @rows, {Name => $name,
			 Jobid => $link,
			 Target => $j->{conf}->{target},
			 Status => $j->{status}}
	}
    }
    my $table = $render->render (\@rows, \@labels);
    return $table;
}

sub render_msg {
    my %jobs = @_;
    my %client_u;
    my %server_u;
    my %client;
    my %server;
    my %other;
    while (my ($name, $jobs) = each %jobs) {
	if ($name =~ /client.*unified/i) {
	    $client_u{$name} = $jobs;
	} elsif ($name =~ /server.*unified/i) {
	    $server_u{$name} = $jobs;
	} elsif ($name =~ /^zmd/i) {
	    $client{$name} = $jobs;
	} elsif ($name =~ /^zlm/i) {
	    $server{$name} = $jobs;
	} else {
	    $other{$name} = $jobs;
	}
    }
    my $tbl_client_u = render_jobs (undef, %client_u);
    my $tbl_server_u = render_jobs (undef, %server_u);
    my $tbl_client = render_jobs ("with_name", %client);
    my $tbl_server = render_jobs ("with_name", %server);
    my $tbl_other = render_jobs ("with_name", %other);
    my $msg = <<MSG_END;
<html>
<h3>Unified Builds</h3>
<p><b>Client:</b><br />
$tbl_client_u</p>
<b><b>Server:</b><br />
$tbl_server_u</p>
<h3>Non-Unified Builds</h3>
<p><b>Client:</b><br />
$tbl_client</p>
<p><b>Server:</b><br />
$tbl_server</p>
<h3>Other Jobs:</h3>
$tbl_other
</html>
MSG_END
    return $msg;
}

########################################################################

sub snaps_start {
    my @jobs = @_;
    my @labels = ("Name", "Target", "Error");
    my @rows;

    foreach my $job (@jobs) {
	if ($job->{status} eq "submit_error") {
	    push @rows, {Name => $job->{name},
			 Target => $job->{conf}->{target},
			 Error => $job->{submit_error}};
	}
    }
    if (scalar @rows) {
	my $table = $render->render (\@rows, \@labels);
	my $msg = <<MSG_END;
<html>
<h3>Submission Errors</h3>
<p>$table</p>
</html>
MSG_END
        mail ("thunder\@ximian.com", $msg);
    }
}

sub snaps_end {
    my @jobs = @_;

    report (4, "Snaps finished, sending Birdman-style HTML mail for " . scalar @jobs . " snaps");

    if ($args{birdman_email_logstyle_to}) {
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
        mail ($args{birdman_email_logstyle_to}, $msg);
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
