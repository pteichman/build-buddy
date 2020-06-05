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

package RelBBOper;

use Ximian::Run ':all';
use Ximian::Util ':all';
#use Ximian::Packsys ':all';
use Ximian::BB::Snapshot ':all';
use Cwd;

my %args;
parse_args (\%args,
	    [
	     {names => ["channel"],     type => "=s", default => ""},
	     {names => ["description"], type => "=s", default => "No Description"},
	     {names => ["importance"],  type => "=s", default => "suggested"},
	     {names => ["rce_server"],  type => "=s", default => "distro\@pipeline"},
	     {names => ["rce_user"],    type => "=s", default => ""},
	     {names => ["rce_pass"],    type => "=s", default => ""},
	     {names => ["ssh_cmd"],     type => "=s", default => "bb_ssh"},
	     {names => ["scp_cmd"],     type => "=s", default => "bb_scp"},
	     {names => ["submit_targets"], type => "=s", default => ""},
	     {names => ["ximian"],      default => 0},
	    ]);

sub get_operations {
    return [
	    { name => "submit:channel",
	      description => "Submit a package to a Red Carpet channel.",
	      run => [ 0 , 'channel_submit', 0 ] },
	    { name => "submit:qa",
	      description => "Submit a package to QA through the Ximian Release Pipeline.",
	      run => [ 0 , 'qa_submit', 0 ] },
	    { name => "submit:ximian-push",
	      description => "Trigger a package sync in the Ximian Release Pipeline.",
	      run => [ 0 , 'ximian_push', 0 ] },
	   ];
}

sub channel_submit {
    my ($module, $conf, $data) = @_;

    # Munge version in $conf if this is a snapshot run
    # It might be best to move this to bb_build..
    # Copied from InstallBBOper.pm
    if ($module->{snapshot}) {
	$conf->{version} = snapshot_cvs_version ($module, $conf,
						 $data->{timestamp}, $data->{packsys});
	return 1 unless (defined $conf->{version});
    }
    my @pkgs = @{get_package_files ($conf, $data->{target}, undef, $module->{snapshot})};
    my @files = map {"$data->{archivedir}/$_"} @pkgs;

    $args{submit_targets} = $data->{target} unless $args{submit_targets};

    my $ssh = $args{ssh_cmd};
    my $description = quotemeta(quotemeta($args{description}));
    my $dir = `$ssh $args{rce_server} 'mktemp -d /var/tmp/RelBBOper.XXXXXX'`;
    chomp $dir;

    eval {
	foreach (@files) {
	    run_cmd ("$args{scp_cmd} $_ $args{rce_server}:$dir/.")
		&& die "Could not scp package to $args{rce_server}";
	}
        if ($args{ximian}) {
	    foreach my $tgt (split /,/, $args{submit_targets}) {
		my $cmd = "$ssh $args{rce_server} 'rel-add-packages -c $args{channel} " .
		    "-t $tgt -i $args{importance} -d $description $dir/*'";
		print "Running: $cmd\n";
		run_cmd ($cmd) && die "Could not add packages to pipeline";
	    }
        } else {
            my $cmd = "$ssh $args{rce_server} 'rcman channel-addpkg " .
                "--user=$args{rce_user} " .
                "--password=$args{rce_pass} " .
                "--targets=$args{submit_targets} " .
                "--desc=$description " .
                "--importance=$args{importance} " .
                "$args{channel} $dir/*'";
            print "Running: $cmd\n";
            run_cmd ($cmd) && die "Could not add packages to server";
        }
    };
    if ($@) {
	print "$@\n";
	run_cmd ("$ssh $args{rce_server} 'rm -rf $dir'");
	return 1;
    }
    run_cmd ("$ssh $args{rce_server} 'rm -rf $dir'");
    return 0;
}

sub ximian_push {
    my ($module, $conf, $data) = @_;
    my $ssh = $args{ssh_cmd};
    eval {
        my $r = run_cmd ("$ssh $args{rce_server} rel-stage-to-real $args{channel}");

        # check if it's not a public channel
        if    (2 == $r) { die "not a public channel"; }
        elsif ($r) { die "Error running rel-stage-to-real"; }

        run_cmd ("$ssh $args{rce_server} rel-push")
            && die "Could not run rel-push on pipeline";
    };
    if ($@) {
        # ignore the 'not a public channel' exception
        die $@ unless ($@ =~ /not a public channel/);
    }
    return 0;
}

sub qa_submit {
    my ($module, $conf, $data) = @_;
    my $description = quotemeta($args{description});
    my $bug;

    unless ($args{channel}) {
	print "You must specify a channel for package submission\n";
	return 1;
    }

    open BUILD, "rel-build-submit -u release --build-daemon -d $description |";
    while (<BUILD>) {
	print;
	if (m/id=(\d+)$/) {
	    $bug = $1;
	}
    }
    close BUILD;

    if ($?) {
	print "rel-build-submit failed\n";
	return 1;
    }

    unless ($bug) {
	print "Couldn't determine bug from rel-build-submit output\n";
	return 1;
    }


    $args{submit_targets} = $data->{target} unless $args{submit_targets};
    my $timestamp = $data->{timestamp}? "--timestamp $data->{timestamp}" : "";
    my $cmd = "rel-qa-submit -t $args{submit_targets} -u release --build-daemon -d $description -b $bug -c $args{channel} $timestamp";
    print "Running: $cmd\n";
    return run_cmd ($cmd);
}

1;
