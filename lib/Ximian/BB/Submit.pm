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

package Ximian::BB::Submit;

use strict;
use Storable qw/dclone/;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
                  split_job_targets
                  job_from_xml
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################

sub split_targets {
    my ($job) = @_;
    my @newjobs;
    my @targets = split /[,\s]+/, $job->{target};

    foreach my $tgt (@targets) {
	my $newjob = dclone ($job);
	$newjob->{target} = $tgt;
	push @newjobs, $newjob;
    }
    return @newjobs;
}

# Convert from typical XML::Simple output to what the xml-rpc layer
# wants

sub merge_from_bb_conf {
    my ($job_info, $bb_info) = @_;

    if (exists $bb_info->{daemon}->{rcd}) {
	my $rcd = $bb_info->{daemon}->{rcd};
	$job_info->{rcd} = {};

	if (exists $rcd->{var}) {
	    while (my ($var, $val) = each %{$rcd->{var}}) {
		$job_info->{rcd}->{var}->{$var} = $val->{cdata};
	    }
	}

	if (exists $rcd->{activate}) {
	    my $new = {};
	    while (my ($user, $i) = each %{$rcd->{activate}}) {
		$new->{$user} = \@{$i->{i}};
	    }
	    $job_info->{rcd}->{activate} = $new;
	}

	if (exists $rcd->{subscribe} and exists $rcd->{subscribe}->{i}) {
	    $job_info->{rcd}->{subscribe} = [];
	    foreach my $channel (@{$rcd->{subscribe}->{i}}) {

		# Deal with silly XML::Simple inconsistencies
		my ($name, $update);
		if (ref $channel eq 'HASH') {
		    $name = $channel->{cdata};
		    $update = $channel->{update};
		} else {
		    $name = $channel;
		    $update = 0;
		}
		push @{$job_info->{rcd}->{subscribe}},
		    { name => $name, update => $update };
	    }
	}
    }
    if (exists $bb_info->{daemon}->{env}) {
	while (my ($var, $val) = each %{$bb_info->{daemon}->{env}->{var}}) {
	    $job_info->{env}->{var}->{$var} = $val->{cdata};
	}
    }
}

sub job_from_xml {
    my %args = @_;

#    return undef if (not defined $args{xml}->{targets}
#                     or not defined $args{xml}->{modules}->{module});

    report (4, "Unparsed snap job:", $args{xml});

    my $job = dclone ($args{xml});
    $job->{modules} = $job->{modules}->{module};
    merge_from_bb_conf ($job, $args{bb_info});

    report (4, "Parsed snap job:", $job);

    return $job;
}

=pod

most of this went into job_from_xml, and then promptly deleted.  It's
here in case I want to look at it later.

sub run_snap_conf {
    my ($snap) = @_;

    return undef if (not defined $snap->{targets}
                     or not defined $snap->{modules}->{module});

    my $job_info = {id => $snap->{id},
		    modules => $snap->{modules}->{module},
                    debug => $args{debug}
		    jail_grep_queries => [{key => "tainted",
					   text => "no"}]};

    # Take info from bb.conf and put it in the job
    Ximian::BB::Submit::merge_from_bb_conf ($job_info, $bb_info);

    foreach (("admin", "logdir", "logurl", "logmail", "push")) {
        $job_info->{$_} = $snap->{$_} if defined $snap->{$_};
    }
    foreach my $module (@{$job_info->{modules}}) {
	$module->{snapshot} = 1 unless exists $module->{snapshot};
        foreach (qw(pipeline_channel channel cvsroot cvsmodule cvsversion)) {
	    if (defined $snap->{$_}) {
		$module->{$_} = $snap->{$_} unless exists $module->{$_};
	    }
	    $module->{$_} = '' if (ref $module->{$_}); # stupid XML::Simple
        }
	if ($module->{snapshot} and $module->{pipeline_channel}) {
	    print "Snapshot-mode and pipeline submission are incompatible.\n"
		. "Disabling snapshot-mode for module \"$module->{name}\"\n";
	    $module->{snapshot} = 0;
	}
    }

    report (4, "Parsed job_info:", $job_info);

    my @children;
    foreach my $target (@{$snap->{targets}->{i}}) {
        my $pid = fork;
        if ($pid) {
            push @children, $pid;
        } else {
            $job_info->{target} = $target;
            my $ret = build ($job_info);
            exit $ret;
        }
    }
    return \@children;
}

=cut

1;
