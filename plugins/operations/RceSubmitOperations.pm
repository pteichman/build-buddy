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

package RceSubmitOperations;

use Ximian::Run ':all';
use Ximian::Util ':all';
use Ximian::BB::Globals;
use Ximian::BB::Module ':all';
use Ximian::BB::Macros ':all';

Ximian::BB::Plugin::register
    (name => "rce-submit",
     group => "operations",
     operations =>
     [
      { name => "rce:submit",
        description => "Submits module's packages to an RCE server, using ssh/scp and rcman.",
        pre => \&init,
        module => \&submit },
      ]);

########################################################################

my $g_server;
my $g_user;
my $g_pass;
my @g_channels;
my @g_targets;
my %modules;

sub init {
    my ($pconf, $data) = @_;
    if ($pconf->{rce_submit}) {
        my $c = $pconf->{rce_submit};
        $g_server = $c->{server} if $c->{server} and not ishash $c->{server};
        $g_user = $c->{user} if $c->{user} and not ishash $c->{user};
        $g_pass = $c->{pass} if $c->{pass} and not ishash $c->{pass};
        @g_channels = @{$c->{channel}->{i}} if $c->{channel} and $c->{channel}->{i};
        @g_targets = @{$c->{target}->{i}} if $c->{target} and $c->{target}->{i};
    }
    while (my ($name, $module) = each %{$pconf->{module}}) {
        $modules{$name} = $module->{rce_submit} if $module->{rce_submit};
    }
}

sub submit {
    my ($module, $data) = @_;
    my $server = $g_server;
    my $user = $g_user;
    my $pass = $g_pass;
    my @channels = @g_channels;
    my @targets = @g_targets;

    if (exists $modules{$module->{name}}) {
        my $m = $modules{$module->{name}};
        return 0 unless keys %$m; # submit disabled for this module

        $server = $m->{server} if $m->{server} and not ishash $m->{server};
        $user = $m->{user} if $m->{user} and not ishash $m->{user};
        $pass = $m->{pass} if $m->{pass} and not ishash $m->{pass};
        @channels = @{$m->{channel}->{i}} if $m->{channel} and $m->{channel}->{i};
        @targets = @{$m->{target}->{i}} if $m->{target} and $m->{target}->{i};
    }

    my @files = map {"$data->{archivedir}/$_"} module_files ($module->{conf});
    return 0 unless @files;

    my $ssh = get_dir ("bb_exec") . "/bb_ssh";
    my $scp = get_dir ("bb_exec") . "/bb_scp";
    my $dir = `$ssh $args{rce_server} 'mktemp -d /var/tmp/RelBBOper.XXXXXX'`;
    chomp $dir;

    eval {
        run_cmd ("$scp @files $server:$dir/.") && die "Couldn't scp files to $server";
        my $cmd = "$ssh $server 'rcman channel-addpkg -U $user -P $pass " .
            "--targets=@{[join ',', @targets]}" .
            "--desc='$description' " .
            "--importance=$args{importance} " .
            "$args{channel} $dir/*'";
        print "Running: $cmd\n";
        run_cmd ($cmd) && die "Could not add packages to server";
    };
    if (my $e = $@) {
	print "$e\n";
	run_cmd ("$ssh $server 'rm -rf $dir'");
	return 1;
    }
    run_cmd ("$ssh $server 'rm -rf $dir'");
    return 0;
}

1;
