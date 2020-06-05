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

package RSSLogStyle;

use XML::RSS;
use Ximian::Util ':all';
use Ximian::BB::Conf ':all';

my ($bb_info) = get_os_info ();

main::register_logstyle ("rss",
			 { job_start => \&job_start,
			   job_end => \&job_end,
			   snaps_start => \&snaps_start,
			   snaps_end => \&snaps_end, });

my %args;
parse_args
    (\%args,
     [
      {names => ["logstyle_rss_outfile"], type => "=s",
       default => ($bb_info->{snaps_rss}->{outfile} || "bb_snaps.rdf")},

      {names => ["logstyle_rss_xsl_stylesheet"], type => "=s",
       default => ($bb_info->{snaps_rss}->{xsl_stylesheet} || "")},

      {names => ["logstyle_rss_css_stylesheet"], type => "=s",
       default => ($bb_info->{snaps_rss}->{css_stylesheet} || "")},

      {names => ["logstyle_rss_title"], type => "=s",
       default => ($bb_info->{snaps_rss}->{title} || "Build Buddy Snapshots")},

      {names => ["logstyle_rss_link"], type => "=s",
       default => ($bb_info->{snaps_rss}->{link} || "http://build-buddy.org/")},

      {names => ["logstyle_rss_desc"], type => "=s",
       default => ($bb_info->{snaps_rss}->{description} ||
		   "At-a-glance status of automatic build jobs " .
		   "submitted to Build Buddy.")},

      {names => ["logstyle_rss_img_title"], type => "=s",
       default => ($bb_info->{snaps_rss}->{img_title} || "Build Buddy")},

      {names => ["logstyle_rss_img_link"], type => "=s",
       default => ($bb_info->{snaps_rss}->{img_link} ||
		   "http://build-buddy.org/")},

      {names => ["logstyle_rss_img_url"], type => "=s",
       default => ($bb_info->{snaps_rss}->{img_url} ||
                   "http://build-buddy.org/images/rss_image.jpg")},
     ]);

########################################################################



########################################################################

sub snaps_start {
    my @jobs = @_;
}

sub snaps_end {
    my @jobs = @_;

    my $rss = new XML::RSS (version => '1.0');
    $rss->channel(title        => $args{logstyle_rss_title},
		  link         => $args{logstyle_rss_link},
		  description  => $args{logstyle_rss_desc},
#		  dc => {date       => '2000-08-23T07:00+00:00',
#			 subject    => "Linux Software",
#			 creator    => 'distro@build-buddy.org',
#			 publisher  => 'distro@build-buddy.org',
#			 rights     => 'Copyright 2004, Novell, inc.',
#			 language   => 'en-us'},
		  syn => {updatePeriod     => "hourly",
			  updateFrequency  => "1",
			  updateBase       => "1901-01-01T00:00+00:00"});


    $rss->image (title	=> $args{logstyle_rss_img_title},
		 url	=> $args{logstyle_rss_img_url},
		 link	=> $args{logstyle_rss_img_link});

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
	my $dbsaved = Ximian::BB::DB::Job->retrieve ($job->{sjid});
	my $email = $dbsaved? $dbsaved->uid->email : "thunder@ximian.com";

	$by_email{$email} = {}
	    unless exists $by_email{$email};
	$by_email{$email}->{$job->{name}} = []
	    unless exists $by_email{$email}->{$job->{name}};

	push @{$by_email{$email}->{$job->{name}}}, $job;
    }

    while (my ($addr, $by_name) = each %by_email) {
	while (my ($name, $jobs) = each %$by_name) {
	    my $msg;
	    foreach my $job (@$jobs) {
		my $jobid = "<a href=\"$args{logstyle_rss_link}report/jobinfo.html?" .
		    "jobid=$job->{jobid}\">$job->{jobid}</a>";
		my $target = $job->{conf}->{target};
		my $status = $job->{status};
		$msg .= "Job $jobid ($target): $status<br />\n";
	    }
	    $rss->add_item (title => $name,
			    link => "$args{logstyle_rss_link}/report/all_jobs.html",
			    description => $msg,
			    dc => {subject => "BB Snaps",
				   creator => $addr});
	}
    }

    # hack: add the xsl stylesheet and css stylesheet manually :-/
    # we could, perhaps, do this pore efficiently... but whatever.

    my @feed = split $/, $rss->as_string;
    my $xml_decl = shift @feed;
    if ($args{logstyle_rss_xsl_stylesheet}) {
	my $href = "href=\"$args{logstyle_rss_css_stylesheet}\"";
	my $type = 'type="text/css"';
	my $media = 'media="screen"';
	unshift @feed, "<?xml-stylesheet $href $type $media ?>\n";
    }
    if ($args{logstyle_rss_xsl_stylesheet}) {
	my $href = "href=\"$args{logstyle_rss_xsl_stylesheet}\"";
	my $type = 'type="text/xsl"';
	my $media = 'media="screen"';
	unshift @feed, "<?xml-stylesheet $href $type $media ?>\n";
    }
    unshift @feed, $/;
    unshift @feed, $xml_decl;

    open RSS, ">$args{logstyle_rss_outfile}" or
	die "Could not open \"$args{logstyle_rss_outfile}\" for writing.";
    print RSS $_ foreach (@feed);
    close RSS;
}

########################################################################

sub job_start {
    my %job = @_;
}

sub job_end {
    my %job = @_;
}

1;
