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

package Ximian::Run;

=head1 NAME

B<Ximian::Run> - Run system commands

=head1 DESCRIPTION

This package provides various routines for running system commands.
There are both synchronous and asynchronous versions of the routines.
The async version uses the SIGALRM signal, so it is unsafe to use this
module with sleep on some (many) systems.

This package is not object-oriented, because it is not possible to
have $SIG{ALRM} set to two subroutines at the same time.  Thus, only
one instance would be able to exist if it were object-oriented.

=head1 SYNOPSIS

    use Ximian::Run ':all';

    $Ximian::Run::log_step = 5;

    run_cmd_async ({ logging_cb => sub { shift; print @_ } },
                   "really_slow_command", "-option", "-option2");

=cut

use strict;
use Carp;
use POSIX;
use File::Basename;
use IO::Pipe;
use Sys::Syslog;

use Ximian::Util ':all';
use Ximian::Sighandler;
use Ximian::BB::Status ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		  run_cmd
		  get_cmd_output
		  run_cmd_async
		  run_or_die
                  safe_sleep
                  lock_acquire_safe_spin
		 )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

########################################################################

# FIXME: to_syslog should be part of a better-integrated logging effort

sub to_syslog {
    my ($message) = @_;
    openlog "Pid: $$, BB", "", "user";
    syslog "warning", $message;
    closelog;
}

######################################################################

my %args;
parse_args
    (\%args,
     [
      {names => ["interactive"    ], type => "!", default => 0},
      {names => ["ignore_errors"  ], type => "!", default => 0},
     ]);

my $progname = basename $0;
my $doit = 1;

if ($args{interactive}) {
    eval { require IO::Pty; import IO::Pty; };
    if ($@) {
	print STDERR <<EOF;
$progname: The --interactive flag requires the IO::Pty perl module to
be installed, but $progname was unable to load it.  Exiting.
EOF
	exit 1;
    }
    eval { require 'sys/ioctl.ph'; };
    if ($@) {
	print STDERR <<EOF;
$progname: The --interactive flag requires the perl header file
sys/ioctl.ph to be installed, but $progname was unable to load it.  See
the h2ph(1) manpage for more information on system perl header files.
Exiting.
EOF
	exit 1;
    }
}

# Replacement for system() which handles interactive I/O properly,
# either by trapping it and dying, or by running the subcommand under
# a pty to make it fully loggable.

sub _system (@) {
    my @command = @_;
    local %SIG;  # Inherited in functions called from this block,
                 # restored on return.

    if ($doit) {
	if ($args{interactive}) {

	    # In this case, we allow interactive I/O, but we want it
	    # logged.  So, we run the subcommand under a pty.

	    my $ptym = new IO::Pty;
	    die "Error assigning pty device: $!\n"
		unless $ptym;
	    $ptym->autoflush(1);

	    my $pid = fork;
	    die "Error creating new process: $!\n"
		unless (defined $pid);

	    if ($pid) {
		# parent

		my $ptyfd = $ptym->fileno();

		while(1) {
		    my ($rin, $rout, $bytes, $buf);

		    vec ($rin, $ptyfd, 1) = 1;
		    vec ($rin, STDIN_FILENO, 1) = 1;

		    my $nfound = select ($rout = $rin, undef, undef, undef);

		    last unless $nfound;

		    if (vec $rout, $ptyfd, 1) {
			$bytes = sysread $ptym, $buf, 8192;
			reportline (6, "Read $bytes bytes from pty");
			unless (defined $bytes) {
			    print STDERR "$progname: read from \"$command[0]\": $!";
			    exit 1;
			}
			if ($bytes) {
			    print $buf;
			} else {
			    $ptym->close();
			}
		    }

		    if (vec $rout, STDIN_FILENO, 1) {
			# Technically, we probably shouldn't call
			# sysread() on STDIN, but we've made sure to
			# make it unbuffered, select() doesn't
			# interact well with read(), and we're not
			# reading from STDIN anywhere else.

			$bytes = sysread STDIN, $buf, 8192;
			unless (defined $bytes) {
			    print STDERR "$progname: read from STDIN: $!";
			    exit 1;
			}
			if ($bytes) {
			    syswrite $ptym, $buf;
			}
		    }
		}

	    } else {
		# child
		$Ximian::Run::subprocess_flag = 1;
		my $ptys = $ptym->slave();
		close $ptym;

		my $sid = POSIX::setsid() or die "setsid returns $!\n";
		my $ttyfd = $ptys->fileno();
		$ptys->autoflush(1);

		close STDIN;
		close STDOUT;
		open(STDIN,"<&". $ttyfd)
		    or die "Couldn't reopen tty for reading: $!\n"; # $ttyname ?
		open(STDOUT,">&". $ttyfd)
		    or die "Couldn't reopen tty for writing: $!\n"; # $ttyname ?
		close STDERR; # put that here or we would never see those die's above...
		open(STDERR,">&". $ttyfd) or exit 1;

		# BSDish systems need the TIOCSCTTY ioctl to allocate
		# a controlling terminal for a session; SysVish ones
		# do it automagically on the first open() of a tty
		# device.

		ioctl $ptys, &TIOCSCTTY, (my $dummy = undef)
		    or die "$progname: Error allocating controlling terminal: $!\n"
			if (defined &TIOCSCTTY);

		exec @command;
		die "$progname: Error executing \"$command[0]\": $!\n";
	    }

	} else {           # !$args{interactive}

	    # If we're not interactive, we don't allow terminal input.
	    # Handle this like a shell -- put the child into a
	    # background process group, and if it gets stopped with
	    # SIGTTIN, kill it.

	    local $SIG{INT} = local $SIG{TERM} = \&Ximian::Sighandler::pgrp_cleanup_exit_handler;

	    if (-t STDOUT) {
		my $termios = POSIX::Termios->new;
		$termios->getattr (1);
		my $c_lflag = $termios->getlflag;
		$termios->setlflag ($c_lflag & ~(&POSIX::TOSTOP));
		$termios->setattr (1, &POSIX::TCSANOW);
	    }

	    if (-t STDERR) {
		my $termios = POSIX::Termios->new;
		$termios->getattr (2);
		my $c_lflag = $termios->getlflag;
		$termios->setlflag ($c_lflag & ~(&POSIX::TOSTOP));
		$termios->setattr (2, &POSIX::TCSANOW);
	    }

	    $Ximian::Sighandler::_system{pid} = fork;
	    die "Error creating new process: $!\n"
		unless (defined $Ximian::Sighandler::_system{pid});

	    if ($Ximian::Sighandler::_system{pid}) {
		# parent

		while(1) {
		    my $kid = waitpid ($Ximian::Sighandler::_system{pid}, WUNTRACED);
		    my $status = $?;

		    last if $kid < 0;
		    last if (WIFEXITED($status) or WIFSIGNALED($status));

		    if (WIFSTOPPED($status)) {
			my $sig = WSTOPSIG($status);
			if ($sig == SIGTTIN or $sig == SIGTTOU) {
			    print STDERR
				"Error: \"$command[0]\" attempted interactive"
				    . "I/O and interactive flag not set\n";
			    kill SIGKILL, $kid;
			    waitpid ($Ximian::Sighandler::_system{pid}, 0);
			    exit 1;
			}
		    }
		}

		# Clean up the whole pgrp if necessary.
		kill WTERMSIG($?), -$Ximian::Sighandler::_system{pid}
		    if (WIFSIGNALED($?));

	    } else {
		# child

		$Ximian::Run::subprocess_flag = 1;

=pod

		# Redirect STDERR to STDOUT for better logging.
                close STDERR;
                open STDERR, '>&', STDOUT
                    or to_syslog "Could not open STDERR: $!\n";

=cut

                STDOUT->autoflush (1);
                STDERR->autoflush (1);

		# Put myself into a new backgrounded process group, so
		# I get a SIGTTIN on an attempted read() from the tty.

		# XXX This will still allow writes directly to
		# /dev/tty to bypass redirection-based logging
		# attempts.  We can get around this by running the
		# whole mess under a pty, but that hasn't proven
		# necessary yet.

		POSIX::setpgid(0,0);

		exec @command;
		die "$progname: Error executing \"$command[0]\": $!\n";
	    }
	}

	return $? >> 8;

    } else {     # !$doit
	reportline (2, "$progname: WOULD run: \"", join (' ', @command), "\"");
	return 0;
    }
}

# Wrapper for run_cmd which will exit if the process died abnormally
# and $args{ignore_errors} is not set.

sub run_or_die (@) {
    my $status = _system(@_);

    return 0 unless $status;

    my $cmdname = $_[0];
    my $exit = 0;

    ($cmdname) = split /\s+/, $cmdname, 2;

    if (WIFEXITED($status)) {
	$exit = WEXITSTATUS($status);
	reportline (1, "$progname: $cmdname exited with status $exit...");
    } elsif (WIFSIGNALED($status)) {
	$exit = 1;
	reportline (1, "$progname: $cmdname killed with signal @{[WTERMSIG($status)]}...");
    } else {
	$exit = 1;
	reportline (1, "$progname: $cmdname exited abnormally...");
    }

    if ($args{ignore_errors}) {
	reportline (1, " continuing");
	return $status;
    } else {
	reportline (1, " quitting");
	exit $exit;
    }
}

########################################################################

=head1 PACKAGE VARIABLES

=over 4

=item $Ximian::Run::log_step

How often (in seconds) to call logging_cb.

=item $Ximian::Run::default_logging_cb

Subroutine reference for a logging routine to use when none was
supplied in the run_cmd call.  By default, this points to a simple
logging routine that just prints the subprocess output (if any).  For
an example of a more verbose logging callback, set it to
\&Ximian::Run::alternate_logging_cb

=item $Ximian::Run::subprocess_flag

If set to true (nonzero), current process is a child, which will exit
when the command exits.  Destructors in all classes should check this
variable before making any changes to disk/sockets/anything of the
sort.

=back

=cut

$Ximian::Run::log_step = 1;
$Ximian::Run::default_logging_cb = \&Ximian::Run::logging_cb;
$Ximian::Run::subprocess_flag = 0;
$Ximian::Run::num_subprocesses = 0;
my @contexts;
my @paused_contexts;

########################################################################

# Here we pass along the child's output, in chunks as defined by
# the log_step, checking to see if the process has finished every
# second.  If it has, we pass along any last output and return.

sub process_reaper {
    my %opts = @_;

    # Don't look at processes we already reaped, or processes
    # that haven't been set up yet
    return $opts{context} if $opts{context}->{reaped}
	or $opts{context}->{not_ready};

    # Don't look at processes that haven't started yet
    return unless $opts{context}->{pid};

    # Check the exit status of the process
    my $status = waitpid ($opts{context}->{pid}, WNOHANG);
    $opts{context}->{run_status} = $status;

    # If the process exited, get its info
    if ($status) {
	$opts{context}->{exit_status_orig} = $?;
	$opts{context}->{failure_message} = $!;
	$opts{context}->{exit_status} = $? >> 8;
    }

    # Get any output and deal with it
    my @lines = $opts{context}->{pipe}->getlines;
    chomp (@lines);
    if (($#lines or $status)) {
	if ($opts{context}->{logging_cb}) {
	    eval {
		$opts{context}->{logging_cb}->($opts{context}, @lines);
	    };
	    if (my $e = $@) {
		reportline (0, "Error running logging cb: $e");
	    }
	    $opts{context}->{first_cb} = 0;
	} else {
	    push @{$opts{context}->{lines}}, @lines;
	}
    }

    # Finally, close the pipe if we're done, and mark it as reaped
    if ($status) {
	$opts{context}->{pipe}->close;
	$opts{context}->{reaped} = 1;
    }
}

sub sigalrm_handler {
    # If we weren't called by sigalrm, we don't want it firing now
    alarm 0; 
    reportline (6, "SIGALRM handler running");

    # reap/get output from all the subprocesses we're managing,
    # and remove the reaped procs from the @contexts list
    process_reaper (context => $_) foreach (@contexts);
    @contexts = grep { not $_->{reaped} } @contexts;
    $Ximian::Run::num_subprocesses = scalar @contexts;

    # reset the alarm
    alarm ($Ximian::Run::log_step || 10) if scalar @contexts;
};

sub pause_handler {
    alarm 0;
    $SIG{ALRM} = 'DEFAULT';
    push @paused_contexts, @contexts;
    @contexts = ();
}

sub resume_handler {
    push @contexts, @paused_contexts;
    @paused_contexts = ();
    if (scalar @contexts) {
	$SIG{ALRM} = \&sigalrm_handler;
	alarm ($Ximian::Run::log_step || 1);
    }
}

########################################################################

=head1 EXPORTED SUBROUTINES

=head2 run_cmd (@command)

Runs a command, blocks until it has finished, and then returns a data
structure with information about the process, including its return
value, and its output, if any.

=head2 run_cmd_async ({key => value, ...}, @command)

Runs a command, but doesn't block.  Takes two arguments, an option
hash and a list to pass to Ximian::Run::run_cmd() (and in turn to
system()).  The options hash uses the following keys:

=over 4

=item data

Anything here will get sent in the context hash for both callbacks (in
the key "data").  For example, you could send $self here to refer to
it later in the callback.

=item pre_run_cb

Function reference to run *after* forking, but *before* running the
command.  It is called after setting up STDOUT/STDERR, however.

=item logging_cb

Function reference to call to relay command output (stdout/stderr).
See also log_step.  This option can be ommitted, see the
default_logging_cb package variable also.

=back

=head1 CALLBACKS

All callbacks take as their first argument a 'context' hashref, which
has information about the current state of the forked subprocess.  The
easiest way to see everything that is available is to use
Data::Dumper.  However, the following keys are currently used:

=over 4

=item pid

PID of the subprocess.

=item first_cb

If true, this is the first time this callback is called.  This is
useful to, for example, print out a heading in a log to inform a new
command has been started.

=item run_status

This is set to 0 if the process is currently still running.  See
waitpid for more information.

=item exit_status

Once the process has exited, this is set to the exit code of the
program.

=back

=cut

sub _run_cmd {
    my ($opts, @cmd) = @_;
    reportline (6, "run_cmd running, args follow:", $opts, "command: @cmd");

    # not ready tells the reaper not to look at this context,
    # first_cb lets the cb routines know when they are first called
    my $context = {not_ready => 1, first_cb => 1};

    # Save the full command for the logger routine
    $context->{command} = [ @cmd ];

    # We allow the caller to give us arbitrary data,
    # for us to give back with the callbacks
    $context->{data} = $opts->{data} if exists $opts->{data};

    # Set up the logging callback
    # In the "sync logging" case, the handler saves the log until the
    # child process exits, and then returns it with the context.
    unless ($opts->{sync_logging}) {
	$context->{logging_cb} = ($opts->{logging_cb} || $Ximian::Run::default_logging_cb);
    }

    # Mark this as a sync process if it is one
    $context->{sync} = 1 if $opts->{sync};

    # The signal handler will need the pipe to get program output
    $context->{pipe} = IO::Pipe->new;

    push @contexts, $context;
    $Ximian::Run::num_subprocesses = scalar @contexts;

    $context->{pid} = fork;
    if ($context->{pid}) { # parent
	$context->{pipe}->reader;
	$context->{pipe}->blocking (0);

	# Ok, we're ready now ($context->{pipe} can be read from)
	$context->{not_ready} = 0;

	# This is how we will collect output / reap processes
	$SIG{ALRM} = \&sigalrm_handler;
	$SIG{CHLD} = \&sigalrm_handler;

	alarm ($Ximian::Run::log_step || 1);

	# In the async case, we just return
	return $context->{pid} unless $opts->{sync};

	# In the sync case,
	# *we depend on the async reaper to reap our child*,
	# But we must wait until it's done, for more info, see:
	# http://www.si.hhs.nl/~bertn/gnu_libc/libc_379.html#SEC379
	# http://search.cpan.org/~nwclark/perl-5.8.4/ext/POSIX/POSIX.pod

	my $mask = POSIX::SigSet->new;
	my $oldmask = POSIX::SigSet->new;
	$mask->addset (&POSIX::SIGALRM);
	$mask->addset (&POSIX::SIGCHLD);

	sigprocmask (SIG_BLOCK, $mask, $oldmask);
	sigsuspend ($oldmask)
	    until $context->{reaped};
	sigprocmask (SIG_UNBLOCK, $mask);

	return $context;
    } else {
	alarm 0;
	local $SIG{ALRM} = 'DEFAULT';
	@contexts = (); # we don't want subprocesses using those
	$Ximian::Run::subprocess_flag = 1;

	$context->{pipe}->writer;

	# close file descriptors
	foreach my $fd (0 .. POSIX::sysconf (&POSIX::_SC_OPEN_MAX)) {
	    POSIX::close ($fd) unless $fd == fileno $context->{pipe};
	}

	open STDOUT, '>&=', fileno $context->{pipe} or to_syslog "Could not open STDOUT: $!\n";
	open STDERR, '>&', STDOUT or to_syslog "Could not dup STDOUT to STDERR: $!\n";
	STDERR->autoflush (1);
	STDOUT->autoflush (1);

	if ($opts->{pre_run_cb}) {
	    $opts->{pre_run_cb}->($context);
	}

	if ($opts->{run_cb}) {
	    my $ret;
	    eval {
		$ret = $opts->{run_cb}->($context);
		$ret = 0 unless defined $ret;
	    };
	    if (my $e = $@) {
		print "$e";
		$ret = 1 unless defined $ret;
	    }
	    exit $ret;
	} else {
	    # TODO:  _system should probably be placed in here, there
	    # is little need to have it be a separate function.

	    # Since we don't call exec directly, we'll have a couple
	    # of extra perl processes running.  But, it's worth it for
	    # _system's interactive command protection.

	    eval {
		my $ret = _system (@cmd);
		exit $ret;
	    };
	    if ($@) {
		print "Error: $@\n";
		exit 1;
	    }
	}
    }
    to_syslog "major error - we shouldn't reach this point!\n";
}

sub run_cmd {
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @cmd = @_;

    $opts{sync} = 1; # we enforce that
    my $context = _run_cmd (\%opts, @_);
    return $context->{exit_status};
}

sub get_cmd_output {
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    my @cmd = @_;

    $opts{sync} = 1; # we enforce that
    $opts{sync_logging} = 1; # and that
    my $context = _run_cmd (\%opts, @_);
    my @lines = @{$context->{lines}};

    if ($context->{exit_status} and ! $opts{ignore_errors}) {
	reportline (2, "Subprocess returned error code: $context->{exit_status}");
	reportline (2, "Subprocess failure msg: $context->{failure_message}");
	reportline (2, "Subprocess output follows:");
	reportline (2, $_) foreach (@lines);
	die "Subprocess returned error code: $context->{exit_status}";
    }
    return @lines;
}

# async is mostly just _run_cmd with a nicer name

sub run_cmd_async {
    my %opts = %{shift()} if (ref $_[0] eq "HASH");
    return _run_cmd (\%opts, @_);
}

########################################################################

=head2 safe_sleep ($secs)

Sleep for at least $secs seconds.  Unlike its perl cousin, it does not
sleep indefinitely if $secs is undefined.  Instead, it sleeps for 1
second.

Safe for use with Ximian::Run, since it runs sleep() in a subprocess
and uses the standard sigalrm handler to wait for completion.

It's even less exact than the usual sleep().  Deal with it.

=head2 lock_acquire_safe_spin ($filename, $timeout)

Ximian::Run-safe version of Ximian::Util::lock_acquire_spin

=cut

sub safe_sleep {
    my $secs = shift;
    $secs = 1 unless defined $secs;
    return get_cmd_output ("sleep $secs");
}

sub lock_acquire_safe_spin {
    my $filename = shift;
    my $timeout  = shift || 5;
    my $no_pid = shift;
    safe_sleep $timeout until lock_acquire($filename, $no_pid);
    return 1;
}

########################################################################

=head1 CONVENIENCE SUBROUTINES

head2 logging_cb

A logging callback suitable for most simple cases.  If the logging_cb
option is not supplied, this callback will be used automatically.  To
prevent this and disable logging (not recommended!), see the
no_logging option.

=head2 alternate_logging_cb

Another example for a logging callback.  This one prints some extra
information, such as the process name, and its PID.  To use it by
default, run:

$Ximian::Run::default_logging_cb = \&Ximian::Run::alternate_logging_cb;

Or, to use it with a particular command, see the logging_cb option to
run_cmd and run_cmd_async.

=cut

sub logging_cb {
    my $context = shift;
    my @lines = @_;
    print $_, $/ foreach (@lines);
}

sub alternate_logging_cb {
    my $context = shift;
    my @lines = @_;
    my $command = (join (" ", @{$context->{command}})
		   || "No command name (inline function)");

    if ($context->{first_cb}) {
	print "Starting PID $context->{pid}: $command\n";
    }

    print "$context->{pid} $_$/" foreach (@lines);

    if ($context->{run_status}) {
	if ($context->{exit_status_orig} == -1) {
	    print "PID $context->{pid} failed to execute: " .
		"$context->{failure_message}\n";
	} else {
	    print "PID $context->{pid} exited with code " .
		"$context->{exit_status}.\n";
	}
    }
}

1;

__END__

=head1 AUTHOR

Dan Mills <thunder@ximian.com>

=head1 COPYRIGHT

Copyright 2004 Novell, Inc. <distribution@ximian.com>.  All rights
reserved.

=cut
