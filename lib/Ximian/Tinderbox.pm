package Ximian::Tinderbox;

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

use strict;
use FindBin;
use Ximian::BB::Conf ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################
# Mail an update to a tinderbox web frontend
######################################################################

# Inform the tinderbox server that we are starting a build

sub status_start {
    my ($job_info) = @_;
    $job_info->{start_time} = time();
    $job_info->{status} = "building";
    mail_update ($job_info);
    return $job_info;
}

# Inform the tinderbox server that we finished a build

sub status_end {
    my ($job_info) = @_;
    my ($bb_info) = get_os_info ();

    # tinder wants "busted" instead of "failed"
    $job_info->{status} = "busted" if ($job_info->{status} eq "failure");

    my $job = $job_info->{jobid};
    my $tmpdir = `mktemp -d /tmp/bb-$job-logs-XXXXXX`;
    chomp $tmpdir;

    wash_logs ("$bb_info->{daemon}->{outputdir}/$job/logs",
               $tmpdir, "$job_info->{logurl}/$job");
    system ("chmod a+rx $tmpdir >/dev/null 2>&1");
    system ("scp -r $tmpdir $job_info->{logdir}/$job >/dev/null 2>&1")
        && die "Error copying logs.";

    my @index = `cat $tmpdir/index.txt`;
    mail_update ($job_info, \@index);

    system ("rm -rf $tmpdir");
}

# Handy function for firing off a mail to the tinderbox server

sub mail_update {
    my ($job_info, $log) = @_;
    $log = [] unless defined $log;

    my $time = time();
    my $localtime = localtime($time);
    my $start_time = $job_info->{start_time} or return undef;
    my $local_start_time = localtime ($start_time);

    my $tree	= ($job_info->{tree} || "gnome2-snap");
    my $build	= ($job_info->{target} || "default-build");
    my $status	= ($job_info->{status} || "busted");
    my $admin	= ($job_info->{admin} || "tinderbox\@ximian.com");
    my $logmail	= ($job_info->{logmail} || "tinderbox_builds\@cvs.gnome.org");
    my $errorparser = ($job_info->{errorparser} || "unix");

    open MAIL, "|mail -s \"Tinderbox Build Update\" $logmail";
    print MAIL <<EOF;


tinderbox: tree: $tree
tinderbox: buildname: $build
tinderbox: starttime: $start_time
tinderbox: localstarttime: $local_start_time
tinderbox: timenow: $time
tinderbox: localtimenow: $localtime
tinderbox: errorparser: $errorparser
tinderbox: status: $status
tinderbox: administrator: $admin
tinderbox: END


@$log


EOF
    close MAIL;
}

sub wash_logs {
    my ($logdir, $outputdir, $logurl) = @_;
    my @logs;

    system ("mkdir -p $outputdir")
        && die "Could not make output dir \"$outputdir\".\n";

    opendir (LOGS, $logdir) or die "Cannot open log dir \"$logdir\": $!\n";
    my $count = 0;
    foreach (sort grep {m/^\d+-bb_build/} readdir LOGS) {
	next if m/lint:[^:]+$/;
	next if m/bb_do:dist$/;
	next if m/module:(install-deps|clean)$/;

	my $file = $_;
	s/^\d+-bb_build://;
	s/module:unpack$/generate-tarball/;
	s/module:install$/package-install/;
	s/:bb_do//;
	s/^/sprintf ("%03d-", $count++)/e;

	system ("cp $logdir/$file $outputdir/$_");
	push @logs, $_;
    }
    closedir LOGS;

    open INDEX, ">$outputdir/index.html";
    print INDEX <<EOF;
<html>
<head><title>Snapshot Build Logs</title></head>
<body>
<h1>Snapshot Build Logs</h1><br />
EOF
    print INDEX "<a href=\"$logurl/$_\">$_</a><br />\n" foreach (@logs);
    print INDEX "</body>\n</html>";
    close INDEX;

    open TXTINDEX, ">$outputdir/index.txt";
    print TXTINDEX <<EOF;
Snapshot Build Logs

Please visit the html-ified log.  It is available at
$logurl

----------------------------------------------------------------------

Individual log sections:

EOF
    print TXTINDEX "$logurl/$_\n" foreach (@logs);
    close TXTINDEX;
}

1;
