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

package Ximian::BB::Changelog;

use Carp;

use Ximian::BB::Conf ':all';
use Ximian::Util ':all';

require Exporter;
our @ISA    = qw(Exporter);
our %EXPORT_TAGS =
    ('all' => [qw(
		  parse_changelog
                  )]);
our @EXPORT_OK   = (@{$EXPORT_TAGS{'all'}});

sub parse_changelog (%);

# Write out a new changelog file from a changelog ref.
#   Ximian::BB::Changelog::output_changelog(opt => val, ...)
#   opts are:  debug (boolean)
#              log (ref), changelog_file (to write to)

sub output_changelog (%) {
    croak "Ximian::BB::Changelog::output_changelog: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $log = $opts->{log};
    my $changelog = $opts->{changelog_file}? $opts->{changelog_file} : $changelog_file;

    require Ximian::XML::Simple;

    my $xml = eval { Ximian::XML::Simple::XMLout
			 ($log,
			  noattr => 1,
			  keyattr => [ qw(id) ],
			  rootname => 'changelog',
			  contentkey => 'cdata',
			  xmldecl => "<?xml version=\"1.0\" ?>\n\n" .
			  "<!DOCTYPE changelog SYSTEM \"changelog.dtd\">\n") };

    die "Error generating xml log data: $@"
	unless (defined $xml);

    open XMLOUT, ">$changelog";
    print XMLOUT $xml;
    print XMLOUT <<EOF;

<!--
Local Variables:
mode: xml
End:
-->
EOF

    close XMLOUT;
}

# Takes in a ref to a changelog entry hash (xml-style), and
# puts it in the right place in the log.
#   Ximian::BB::Changelog::prepend_to_changelog(opt => val, ...)
#   opts are: entry (ref), debug (boolean), version (string), log (ref)

sub prepend_to_changelog (%) {
    croak "Ximian::BB::Changelog::prepend_to_changelog: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $log = $opts->{log};
    my $idx = 0;
    my $create_new = 0;

    for $idx (0 .. $#{$log->{entry}}) {
	last if ($opts->{version} eq $log->{entry}->[$idx]->{version});
	$create_new = 1 if ($idx == $#{$log->{entry}});
    }
    if ($create_new || -1 == $#{$log->{entry}}) {
	unshift @{$log->{entry}}, $opts->{entry}->[$idx];
    } else {
	delete $opts->{entry}->[0]->{version};
	$opts->{entry}->[0]->{filter}->{i}->[0] = "$opts->{targetid}";
	push @{$log->{entry}->[$idx]->{targetset}}, $opts->{entry}->[0];
    }
    return $log;
}

# Return a new entry to a changelog, if needed.  Otherwise return 0.
#   Ximian::BB::Changelog::update_changelog(opt => val, ...)
#   opts are: log (ref), epoch, version, release, module, targetid
#   optional: debug (boolean), author, email, date, changes

sub update_changelog (%) {
    croak "Ximian::BB::Changelog::update_changelog: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $oldver = "";

    my $newver = ($opts->{epoch}? "$opts->{epoch}:" : "") .
	"$opts->{version}-$opts->{release}";

    if ($opts->{log}->{entry}) {
	my $entry = ${$opts->{log}->{entry}}[0]; # already flattened
	$oldver = ($entry->{epoch}? "$entry->{epoch}:" : "") .
	    "$entry->{version}-$entry->{release}";
    }

    unless ($oldver eq $newver) {
	local $ENV{LANG} = "C"; # we want the date in english
	my $author = $opts->{author}? $opts->{author} : 'Ximian, Inc.';
	my $email = $opts->{email}? $opts->{email} : 'distribution@ximian.com';
	chomp (my $date = $opts->{date}? $opts->{date} : `date -u`);
	my $changes = $opts->{changes}? $opts->{changes} : {h => ['New build.'],
							    p => ['New automated build.']};
	my $newentry = [{version => $opts->{version},
			 release => $opts->{release},
			 module => $opts->{module},
			 author => $author,
			 email => $email,
			 date => $date,
			 changes => $changes}];
	$newentry->[0]->{epoch} = $opts->{epoch} if ($opts->{epoch});

	return $newentry;
    }
    return 0;
}

# Merge target-specific changelog information into the default tree
#   Ximian::BB::Changelog::flatten_changelog(opt => val, ...)
#   opts are:  debug (boolean), version (string),
#              packsys (string), targetid (string), log (ref)

sub flatten_changelog (%) {
    croak "Ximian::BB::Changelog::flatten_changelog: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $myver_idx = 0;
    my $entries = $opts->{log}->{entry};

    return unless (0 <= $#$entries);

    for my $n (0 .. $#$entries) {
	$myver_idx = $n
	    if ($opts->{version} eq $entries->[$n]->{version});
	foreach my $target_section (@{$entries->[$n]->{targetset}}) {
	    if (filter_match ($opts->{packsys}, $opts->{targetid},
			      $target_section->{filter})) {
		munge_conf ($target_section, $entries->[$n]);
		$entries->[$n]->{filter} = ""; # avoid confusion
	    }
	}
    }
    @$entries = splice (@$entries, 0, $myver_idx)
	if (0 < $myver_idx);
}

# Read in a package Changelog file, and merge it for the given target.
#   Ximian::BB::Changelog::read_changelog(opt => val, ...)
#   opts are:  debug (boolean), changelog_file (string)

sub read_changelog (%) {
    croak "Ximian::BB::Changelog::read_changelog: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $log = undef;
    my $changelog = $opts->{changelog_file}? $opts->{changelog_file} : $changelog_file;

    die "Changelog file \"$changelog\" does not exist.\n" unless -f $changelog;

    require Ximian::XML::Simple;

    $log = eval { Ximian::XML::Simple::XMLin
		      ($changelog,
		       searchpath => [ qw(.) ],
		       keyattr => [ qw(id) ],
		       forcearray => [ qw(entry psdata targetset i h p) ],
		       contentkey => 'cdata') };

    die "Error loading package changelog file: $@"
	unless (defined $log);

    if ($opts->{debug}) {
	require Data::Dumper;
	print "Raw parse output:\n" . Data::Dumper::Dumper($log);
    }
    return $log;
}

# Do all the changelog magic.  This is the main entry point.
#   Ximian::BB::Changelog::parse_changelog(opt => val,...)
#   opts are: debug (bool), changelog_file (str), epoch, version, release,
#             module (str), targetid (str), packsys (str), rewrite_changelog (bool)

sub parse_changelog (%) {
    use Sys::Hostname;
    use Storable;
    croak "Ximian::BB::Changelog::parse_changelog: Options must be name => value pairs"
	if (@_ % 2);
    my $opts = { @_ };
    my $hostname = hostname;
    my $conf_file = "";
    my $conf_dir = "";
    my $changelog = $opts->{changelog_file}? $opts->{changelog_file} : $changelog_file;

    unless (-f $changelog) {
	foreach my $file (@mod_conf_files) {
	    $conf_file = $file if (-f $file);
	} # no need to test at the end, we know one exists by now

	my $real_dir = Cwd::abs_path (get_dirname (get_realpath ($conf_file)));

	output_changelog (debug => $opts->{debug},
			  log => {},
			  changelog_file => "$changelog-new-bb_do.$hostname.$$");

	system ("mv $changelog-new-bb_do.$hostname.$$ $real_dir/$changelog")
	    and die "Could not rename $changelog-new-bb_do.$hostname.$$ " .
		"to $real_dir/$changelog: $!\n";

	unless ($real_dir eq Cwd::cwd()) {
	    print "trying to symlink\n";
	    symlink "$real_dir/$changelog", $changelog
		or die "Could not link $real_dir/$changelog to $changelog";
	}
    }
    $changelog = get_realpath ($changelog);

    my $log = read_changelog (debug => $opts->{debug},
			      changelog_file => $changelog);
    my $log_backup = Storable::dclone ($log);

    flatten_changelog (debug => $opts->{debug},
		       log => $log,
		       version => $opts->{version},
		       packsys => $opts->{packsys},
		       targetid => $opts->{targetid});

    my $entry = update_changelog (debug => $opts->{debug},
				  log => $log,
				  author => $opts->{author},
				  email => $opts->{email},
				  epoch => $opts->{epoch},
				  version => $opts->{version},
				  release => $opts->{release},
				  module => $opts->{module},
				  targetid => $opts->{targetid});

    if ($entry) {
	$log = prepend_to_changelog (debug => $opts->{debug},
				     log => $log_backup,
				     entry => $entry,
				     targetid => $opts->{targetid},
				     version => $opts->{version});

	if ($opts->{rewrite_changelog}) {
	    output_changelog (debug => $opts->{debug},
			      log => $log,
			      changelog_file => "$changelog-bb_do.$hostname.$$");
	    system ("mv $changelog-bb_do.$hostname.$$ $changelog")
		and die "Could not rename $changelog-bb_do.$hostname.$$ " .
		    "to $changelog\n";
	}

	flatten_changelog (debug => $opts->{debug},
			   log => $log,
			   version => $opts->{version},
			   packsys => $opts->{packsys},
			   targetid => $opts->{targetid});
    }
    return $log;
}

1;
