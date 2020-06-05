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

# $Id: Util.pm 3080 2006-01-05 01:10:21Z v_thunder $

package Ximian::Util;

use strict;
use Carp;
use POSIX;
use File::Spec::Functions 'rel2abs';
use Getopt::Long;
use Sys::Hostname;

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		  daemonize
		  lock_acquire
		  lock_acquire_spin
		  lock_release
		  parse_args
		  parse_args_set
                  parse_args_full
		  get_dirname
		  get_basename
                  get_realpath
		  mkdirs
		  make_temp_dir
                  ishash
                  isarray
                  iscode
		  pushd
		  popd
		  push_count
		  touch
                  report
                  reportline
		  easydump
		  human_readable_num
		  line_up
                  next_logid
                  dirgrep
                  twogrep
		  non_empty
		  first_defined
                  member_str
                  setdiff
                  remove_undefs
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

######################################################################
# Locking on nfs for fun and profit
######################################################################

sub touch {
    my $file = shift;
    open LOCKFILE, ">>$file"
	or croak "Could not open lockfile \"$file\".\n";
    print LOCKFILE '';  # shut up, perl
    close LOCKFILE;
}

sub lock_acquire {
    my $filename = shift;
    my $no_pid = shift;
    my $lockfile = "$filename." . hostname;
    $lockfile .= ".$$" unless $no_pid;

    touch("$filename.lock");
    if (not link "$filename.lock", $lockfile) {
	return 0;
    }

    my @tmp = stat ($lockfile);
    return 1 if ($tmp[3] == 2);  # check nlink
    unlink ($lockfile);
    return 0;
}

sub lock_release {
    my $filename = shift;
    my $no_pid = shift;
    my $lockfile = "$filename." . hostname;
    $lockfile .= ".$$" unless $no_pid;
    unlink ("$filename.lock");
    unlink ($lockfile);
}

sub lock_acquire_spin {
    my $filename = shift;
    my $timeout  = shift || 5;
    my $no_pid = shift;
    sleep $timeout until lock_acquire($filename, $no_pid);
    return 1;
}

######################################################################
# Goodness
######################################################################

sub get_dirname {
    my $file = shift;
    $file = "./$file" if ($file !~ /^\//);
    $file =~ /^(.*)\/[^\/]*$/;
    return $1;
}

sub get_basename {
    my $file = shift;
    $file = "./$file" if ($file !~ /^\//);
    $file =~ /^.*\/([^\/]*)$/;
    return $1;
}

sub get_realpath {
    my $file = shift;

    $file = readlink($file) while (-l $file);

    my $filename = get_basename ($file);
    my $dirname  = get_dirname  ($file);

    return rel2abs ($dirname) . "/$filename";
}

sub mkdirs {
    my $path = shift;
    return if -d $path;

    my $leading = "";
    $leading = "/" if $path =~ s{^/}{};
    $path =~ s{/$}{};

    my @pieces = split ('/', $path);
    unshift @pieces, $leading if ($leading);
    mkdirs_rec (@pieces);
    croak "Could not create \"$leading$path\"" unless -d "$leading$path";
}

sub mkdirs_rec {
    my ($path, @rest) = @_;
    unless (-d $path) {
	mkdir $path or croak "Could not mkdir \"$path\": $!";
    }
    return unless @rest;
    my $next = "/" . shift @rest;
    $next = $path . $next unless $path eq "/";
    mkdirs_rec ($next, @rest);
}

sub make_temp_dir {
    my $basedir = (shift || "/tmp");
    my $tmp = `mktemp -d $basedir/bb_tmp_dir.XXXXXX`;
    croak "Could not make temp dir: $!\n" if ($? >> 8);
    chomp $tmp;
    return $tmp;
}

######################################################################
# Data structures
######################################################################

sub ishash {
    my $ref = shift;
    return 1 if ref $ref eq "HASH";
    return 0;
}

sub isarray {
    my $ref = shift;
    return 1 if ref $ref eq "ARRAY";
    return 0;
}

sub iscode {
    my $ref = shift;
    return 1 if ref $ref eq "CODE";
    return 0;
}

######################################################################
# Reporting / debugging
######################################################################

sub report {
    my ($info, @msgs) = @_;
    my %args;

    if (ishash $info) {
	%args = %$info;
	$args{level} = 0 unless defined $args{level};
	$args{nline} = 0 unless defined $args{nline};
	$args{tstamp} = 0 unless defined $args{tstamp};
    } else {
	$args{level} = $info;
	$args{nline} = 0;
	$args{tstamp} = 0;
    }

    if ($Ximian::Globals::verbosity >= $args{level}) {
	foreach my $msg (@msgs) {
            my ($sec, $min, $hour, $mday,
                $mon, $year, $wday, $yday, $isdst) = localtime (time);
            my $ts = sprintf ("[%02d:%02d:%02d]", $hour, $min, $sec);

	    if (ref $msg or not defined $msg) {
		require Data::Dumper;
                print "$ts\n" if $args{tstamp};
		print Data::Dumper::Dumper($msg);
	    } else {
		chomp $msg;
                print "$ts " if $args{tstamp};
		if ($args{nline}) {
		    print "$msg\n";
		} else {
		    print "$msg";
		}
	    }
	}
    }
}

sub reportline {
    my ($info, @msgs) = @_;
    my %args;
    if (ishash $info) {
	%args = %$info;
	$args{level} = 0 unless defined $args{level};
	$args{nline} = 1 unless defined $args{nline};
	$args{tstamp} = 1 unless defined $args{tstamp};
    } else {
	$args{level} = $info;
	$args{nline} = 1;
	$args{tstamp} = 1;
    }
    return report (\%args, @msgs);
}

sub easydump {
    require Data::Dumper;
    print "Data dump:\n" . Data::Dumper::Dumper (shift);
}

######################################################################
# Argument parsing
######################################################################

my @default_getopt_config = ("permute", "pass_through", "bundling",
			     "no_auto_abbrev", "no_ignore_case");

sub getopt_arg_from_desc {
    my ($desc) = @_;
    my $names = $desc->{names};
    my $getopt_str = $names->[0];
    $getopt_str .= "|$_" foreach (@$names[1 .. $#$names]);
    $getopt_str .= $desc->{type} if defined ($desc->{type});
    return $getopt_str;
}

sub attach_user_functions {
    my ($args, $desc) = @_;

    $args->{$desc->{names}->[0]} = $desc->{run}
	if ($desc->{run} && !defined ($args->{$desc->{names}->[0]}));
}

sub get_getopt_args {
    my ($args, $desc_set) = @_;
    my @getopt_args = ();

    foreach my $desc (@$desc_set) {
	croak "You must supply at least one name for your option\n"
	    unless defined ($desc->{names});
	croak "The \"names\" option must be an arrayref (use \"[ ]\").\n"
	    unless (isarray $desc->{names});

	push @getopt_args, getopt_arg_from_desc ($desc);
	attach_user_functions ($args, $desc);
    }
    return @getopt_args;
}

sub check_defaults {
    my ($args, $desc_set) = @_;

    foreach my $desc (@$desc_set) {
	croak "You must supply a default value for option \"$desc->{names}->[0]\".\n"
	    unless (defined ($desc->{default}) ||
		    defined ($desc->{nodefault}) ||
		    defined ($desc->{run}));
	$args->{$desc->{names}->[0]} = $desc->{default}
	    unless (defined ($desc->{nodefault}) ||
		    defined ($args->{$desc->{names}->[0]}));
    }
}

sub parse_args {
    my ($ret, $desc_set) = @_;

    croak "First argument to parse_args must be a hash ref.\n"
	unless (ishash $ret);

    @Ximian::Util::original_argv = @ARGV;

    Getopt::Long::Configure (@default_getopt_config);
    GetOptions ($ret, get_getopt_args ($ret, $desc_set));
    check_defaults ($ret, $desc_set);
}

sub parse_args_set {
    my ($args, @sets) = @_;
    foreach my $set (@sets) {
	if ("full" eq $set) {
	    push @sets, ("base", "userpass");
	} elsif ("base" eq $set) {
	    parse_args
		($args,
		 [
		  { names	=> ["verbosity",  "v"],
		    type	=> "=i",
		    default	=> 2 },
		  { names	=> ["target",     "t"],
		    type	=> "=s",
		    default	=> ($ENV{TARGET} || "") },
		 ]);
	    if ($args->{verbosity} >= 5 && !defined ($args->{debug})) {
		$args->{debug} = 1;
		require Data::Dumper;
	    }
	    $Ximian::Globals::verbosity = $args->{verbosity}; # see report()
        } elsif ("userpass" eq $set) {
            parse_args
                ($args,
                 [
                  { names	=> ["user", "u"],	type => "=s",
                    default	=> getpwuid($>)
                  },
                  { names	=> ["password",	"p"],	type => "=s",
                    default	=> ""
                  },
                 ]);
	} else {
            reportline (1, "Command-line parsing: Unknown set \"$set\"");
        }
    }
}

######################################################################
# pushd / popd
######################################################################

{
    my $push_count = 0;
    my @dir_stack;

    sub pushd {
	my $dir = rel2abs shift();
        # We only warn, so push it anyway for popd to be balanced on the caller's side
        push @dir_stack, getcwd;
        $push_count++;
        if (-d $dir) {
            chdir $dir;
            reportline (4, "Directory change.  Cwd: $dir");
            reportline (5, "Directory stack ($push_count): [@dir_stack]");
        } else {
            reportline (3, "Attempted to chdir, but path does not exist: \"$dir\"");
        }
    }

    sub popd {
	my $cur = getcwd;
        my $dir = pop @dir_stack;
        if ($dir) {
            chdir $dir;
            $push_count-- if $push_count;
            reportline (4, "Directory change.  Cwd: $dir");
        }
        reportline (5, "Directory stack ($push_count): [@dir_stack]");
	return $cur;
    }

    sub push_count {
	return $push_count;
    }

    sub do_in_dir (&;$) {
	my ($code, $dir) = @_;
	pushd $dir;
	$code->();
	popd;
    }
}

######################################################################
# Process daemonization
######################################################################

sub daemonize {
    my $logfile = shift;
    my ($pid);

    # We don't want the child to become a zombie, so we ignore
    # sigchld.  But we set it to the default in the child, since that
    # is the expected behavior.

    $SIG{CHLD} = "IGNORE";
    exit 0 if ($pid = fork);

    $SIG{CHLD} = "DEFAULT";
    POSIX::setsid();

    chdir "/";
    umask 0;

    # close file descriptors
    foreach my $fd (0 .. POSIX::sysconf(&POSIX::_SC_OPEN_MAX)) {
	POSIX::close($fd);
    }

    # reopen stdout, stderr, and stdin
    open (STDIN,  "+>/dev/null");
    open (STDOUT, "+>$logfile");
    open (STDERR, "+>&STDOUT");
    return $pid;
}

######################################################################
# Re-exec under sudo safely
######################################################################

sub sudo_reexec {
    my ($progname, @saved_argv) = @_;
    if ($> != 0) {
	croak "Unable to aquire root permission.  ",
	    "Exiting to prevent infinite loop."
		if $ENV{BB_LOOPTEST};
	$ENV{BB_LOOPTEST} = 1;
	$ENV{REAL_USER} = $ENV{USER};
	exec 'sudo', $progname, map{"$_"} @saved_argv;
	die "Error running sudo";
    }
}

######################################################################
# String formatting
######################################################################

sub human_readable_num {
    my $num = shift;
    my $precision = (shift || "3");
    if ($num >= 1099511627776) {
	return sprintf "%.3fT", $num / 1099511627776;
    } elsif ($num >= 1073741824) {
	return sprintf "%.${precision}fG", $num / 1073741824;
    } elsif ($num >= 1000000) {
	return sprintf "%.${precision}fM", $num / 1048576;
    } elsif ($num >= 1024) {
	return sprintf "%.${precision}fK", $num / 1024;
    } else {
	return $num;
    }
}

sub line_up {
    my ($foo, $bar, $spaces) = @_;
    $spaces = 20 unless $spaces;
    my $ret = $foo;
    $ret .= " " x ($spaces - length $foo);
    $ret .= $bar;
    return $ret;
}

######################################################################
# Logging counters
######################################################################

sub next_logid {
    my ($dir) = @_;
    my $n = 0;
    croak "Argument must be a directory" unless -d $dir;
    return -1 unless lock_acquire "$dir/.count";

    if (open COUNT, "$dir/.count") {
        $n = <COUNT>;
        chomp ($n);
        close COUNT;
    }

    open COUNT, ">$dir/.count" or reportline (0, "Logging error: $!");
    seek COUNT, 0, 0;
    print COUNT $n + 1;
    close COUNT;

    lock_release "$dir/.count";
    return sprintf "%03d", $n;
}

######################################################################
# Grep-like functions
######################################################################

# Use like:
# my @files = dirgrep { /^[^.]/ } $dir;
# Note that you can modify the filenames too:
# my @files = dirgrep { /^[^.]/ or return; $_ = "$dir/$_" } $dir;

sub dirgrep (&;$) {
    my ($code, $dir) = @_;
    opendir DIR, $dir or return;
    my @files = grep { $code->(); } readdir DIR;
    closedir DIR;
    return @files;
}

sub twogrep (&;@) {
    my $code = shift;
    my (@matched, @notmatched);
    foreach (@_) {
	if ($code->()) {
	    push @matched, $_;
	} else {
	    push @notmatched, $_;
	}
    }
    return (\@matched, \@notmatched);
}

######################################################################
# Misc
######################################################################

sub non_empty ($) {
    my $value = shift;
    return 1 if defined $value and not ref $value and $value ne '';
    return 0;
}

sub first_defined (@) {
    my (@values) = @_;
    foreach my $val (@values) {
        return $val if defined $val;
    }
    return undef;
}

sub member_str {
    my $item = shift;
    return scalar grep {$_ eq $item} @_;
}

sub setdiff {
    my ($set1, $set2) = @_;
    my @notin1 = grep { ! member_str ($_, @$set1) } @$set2;
    my @notin2 = grep { ! member_str ($_, @$set2) } @$set1;
    my @inboth = grep { member_str ($_, @$set2) } @$set1;
    return \@notin1, \@notin2, \@inboth;
}

sub remove_undefs {
    my $thing = shift;
    if (isarray $thing) {
	for (0 .. $#$thing) {
	    $thing->[$_] = remove_undefs ($thing->[$_]);
	}
	return $thing;
    } elsif (ishash $thing) {
	while (my ($key, $val) = each %$thing) {
	    $thing->{$key} = remove_undefs ($val);
	}
	return $thing;
    } else {
	return defined $thing? $thing : "";
    }
}

1;
