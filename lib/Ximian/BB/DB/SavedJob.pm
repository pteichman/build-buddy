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

package Ximian::BB::DB::SavedJob;

use base 'Ximian::BB::DB::DBI';
use Class::DBI::AbstractSearch;

__PACKAGE__->table ('saved_jobs', 'saved_jobs');
__PACKAGE__->sequence ('saved_jobs_sjid_seq');
__PACKAGE__->columns (Primary => qw/sjid/);
__PACKAGE__->columns (Others => qw/build_id snapshot run_snap
				   create_tarballs remove_jail
                                   uid name debug
				   ignore_submission_errors
				   ignore_build_errors
				   cvsroot cvsmodule cvsversion
				   channel pipeline_channel node
				   rcserver min_disk max_jobs
				   rcd_mcookie rcd_partnernet/);

__PACKAGE__->has_a (uid => 'Ximian::BB::DB::User');
__PACKAGE__->has_many (targets => 'Ximian::BB::DB::SavedJobTarget', 'sjid');
__PACKAGE__->has_many (submit_targets => 'Ximian::BB::DB::SavedJobSubmitTarget', 'sjid');
__PACKAGE__->has_many (envvars => 'Ximian::BB::DB::SavedJobEnvVar', 'sjid');
__PACKAGE__->has_many (rcdvars => 'Ximian::BB::DB::SavedJobRCDVar', 'sjid');
__PACKAGE__->has_many (rcdsubs => 'Ximian::BB::DB::SavedJobRCDSub', 'sjid');
__PACKAGE__->has_many (rcdsvcs => 'Ximian::BB::DB::SavedJobRCDSvc', 'sjid');
__PACKAGE__->has_many (rcdacts => 'Ximian::BB::DB::SavedJobRCDAct', 'sjid');
__PACKAGE__->has_many (modules => 'Ximian::BB::DB::SavedJobModule', 'sjid');
__PACKAGE__->has_many (queries => 'Ximian::BB::DB::SavedJobQuery', 'sjid');
__PACKAGE__->has_many (extra_deps => 'Ximian::BB::DB::SavedJobExtraDep', 'sjid');
__PACKAGE__->has_many (shared_users => 'Ximian::BB::DB::SavedJobSharedUser', 'sjid');
#__PACKAGE__->might_have (nodeid => 'Ximian::BB::DB::Node');


package Ximian::BB::DB::SavedJobTarget;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_targets', 'saved_job_targets');
__PACKAGE__->columns (Primary => qw/sjid target/);


package Ximian::BB::DB::SavedJobSubmitTarget;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_submit_targets',
		    'saved_job_submit_targets');
__PACKAGE__->columns (Primary => qw/sjid target/);


package Ximian::BB::DB::SavedJobEnvVar;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_env_vars', 'saved_job_env_vars');
__PACKAGE__->columns (Primary => qw/sjid name/);
__PACKAGE__->columns (Others => qw/value/);


package Ximian::BB::DB::SavedJobRCDVar;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_rcd_vars', 'saved_job_rcd_vars');
__PACKAGE__->columns (Primary => qw/sjid name/);
__PACKAGE__->columns (Others => qw/value/);


package Ximian::BB::DB::SavedJobRCDSub;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_rcd_subscriptions', 'saved_job_rcd_subscriptions');
__PACKAGE__->columns (Primary => qw/sjid name/);
__PACKAGE__->columns (Others => qw/update_channel/);


package Ximian::BB::DB::SavedJobRCDSvc;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_rcd_services', 'saved_job_rcd_services');
__PACKAGE__->sequence ('saved_job_rcd_services_sid_seq');
__PACKAGE__->columns (Primary => qw/sid/);
__PACKAGE__->columns (Other => qw/sjid url/);

package Ximian::BB::DB::SavedJobRCDAct;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_rcd_activations', 'saved_job_rcd_activations');
__PACKAGE__->sequence ('saved_job_rcd_activations_aid_seq');
__PACKAGE__->columns (Primary => qw/aid/);
__PACKAGE__->columns (Other => qw/sjid sid rce_key email/);


package Ximian::BB::DB::SavedJobModule;
use base 'Ximian::BB::DB::DBI';
use Class::DBI::AbstractSearch;

__PACKAGE__->table ('saved_job_modules', 'saved_job_modules');
__PACKAGE__->columns (Primary => qw/sjid index/);
__PACKAGE__->columns (Other => qw/name build_id snapshot
                                  cvsroot cvsmodule cvsversion
                                  channel pipeline_channel/);

package Ximian::BB::DB::SavedJobQuery;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_jail_grep_queries',
		    'saved_job_jail_grep_queries');
__PACKAGE__->columns (Primary => qw/sjid index/);
__PACKAGE__->columns (Other => qw/metadata_id grep_key xpath text/);

package Ximian::BB::DB::SavedJobExtraDep;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_extra_deps',
		    'saved_job_extra_deps');
__PACKAGE__->columns (Primary => qw/sjid dep/);

package Ximian::BB::DB::SavedJobSharedUser;
use base 'Ximian::BB::DB::DBI';

__PACKAGE__->table ('saved_job_shared_users',
		    'saved_job_shared_users');
__PACKAGE__->columns (Primary => qw/sjid uid/);
#__PACKAGE__->has_a (uid => 'Ximian::BB::DB::User');


########################################################################

package Ximian::BB::DB::SavedJob;

use Ximian::Util ':all';

# Loading and saving routines

sub load_saved_job {
    my ($sjid) = @_;
    my $job = Ximian::BB::DB::SavedJob->retrieve ($sjid)
	or die "could not retrieve job \"$sjid\"";

    my $jobinfo = {};
    $jobinfo->{modules} = [];

    $jobinfo->{sjid} = $job->sjid;
    $jobinfo->{name} = $job->name;
    $jobinfo->{node} = $job->node;
    $jobinfo->{rcserver} = $job->rcserver;
    $jobinfo->{debug} = $job->debug;
    $jobinfo->{build_id} = $job->build_id;
    $jobinfo->{snapshot} = $job->snapshot;
    $jobinfo->{create_tarballs} = $job->create_tarballs;
    $jobinfo->{remove_jail} = $job->remove_jail;
    $jobinfo->{ignore_submission_errors} = $job->ignore_submission_errors;
    $jobinfo->{ignore_build_errors} = $job->ignore_build_errors;
    $jobinfo->{cvsroot} = $job->cvsroot;
    $jobinfo->{cvsmodule} = $job->cvsmodule;
    $jobinfo->{cvsversion} = $job->cvsversion;
    $jobinfo->{min_disk} = $job->min_disk;
    $jobinfo->{max_jobs} = $job->max_jobs;
    $jobinfo->{channel} = $job->channel;
    $jobinfo->{pipeline_channel} = $job->pipeline_channel;
    $jobinfo->{rcd_mcookie} = $job->rcd_mcookie;
    $jobinfo->{rcd_partnernet} = $job->rcd_partnernet;

    foreach my $module ($job->modules) {
	my $new = {};
	$new->{name} = $module->name if $module->name;
	$new->{build_id} = $module->build_id if $module->build_id;
	$new->{snapshot} = $module->snapshot if $module->snapshot;
	$new->{cvsroot} = $module->cvsroot if $module->cvsroot;
	$new->{cvsmodule} = $module->cvsmodule if $module->cvsmodule;
	$new->{cvsversion} = $module->cvsversion if $module->cvsversion;
	$new->{channel} = $module->channel if $module->channel;
	$new->{pipeline_channel} = $module->pipeline_channel
	    if $module->pipeline_channel;
	push @{$jobinfo->{modules}}, $new;
    }

    foreach my $var ($job->envvars) {
	$jobinfo->{env}->{var}->{$var->name} = $var->value;
    }

    foreach my $var ($job->rcdvars) {
	$jobinfo->{rcd}->{var}->{$var->name} = $var->value;
    }

    my @acts = $job->rcdacts;
    $jobinfo->{rcd}->{services} = [];
    foreach my $svc ($job->rcdsvcs) {
	my $activations;
	foreach my $act (grep { $_->sid eq $svc->sid } @acts) {
	    $activations->{$act->email} = []
		unless exists $activations->{$act->email};
	    push @{$activations->{$act->email}}, $act->rce_key;
	}
	push @{$jobinfo->{rcd}->{services}},
	    { url => $svc->url, activations => $activations };
    }

    $jobinfo->{rcd}->{subscribe} = [];
    foreach my $sub ($job->rcdsubs) {
	push @{$jobinfo->{rcd}->{subscribe}},
	    { name => $sub->name,
	      update => $sub->update_channel };
    }

    $jobinfo->{jail_grep_queries} = [];
    foreach my $q ($job->queries) {
	my $foo = { metadata_id => $q->metadata_id,
		    text => $q->text };
	$foo->{key} = $q->grep_key if $q->grep_key;
	$foo->{xpath} = $q->xpath if $q->xpath;
	push @{$jobinfo->{jail_grep_queries}}, $foo;
    }

    $jobinfo->{extra_deps} = [];
    foreach my $dep ($job->extra_deps) {
	push @{$jobinfo->{extra_deps}}, $dep->dep;
    }

    $jobinfo->{shared_users} = [];
    foreach my $uid (map { $_->uid } $job->shared_users) {
	my $user = Ximian::BB::DB::User->retrieve ($uid);
	push @{$jobinfo->{shared_users}}, $user->login;
    }

    $jobinfo->{submit_targets} = [];
    foreach my $tgt ($job->submit_targets) {
	push @{$jobinfo->{submit_targets}}, $tgt->target;
    }

    my @targets;
    push @targets, $_->target foreach ($job->targets);
    $jobinfo->{target} = join ",", @targets;

    return $jobinfo;
}

sub update_saved_job {
    my ($sjid, $data) = @_;

    my $job = Ximian::BB::DB::SavedJob->retrieve ($sjid)
	or die "saved job \"$sjid\" not found.";

    # Base settings
    $job->debug ($data->{debug}) if $data->{debug};
    $job->node ($data->{node}) if $data->{node};
    $job->rcserver ($data->{rcserver}) if $data->{rcserver};
    $job->build_id ($data->{build_id}) if $data->{build_id};
    $job->cvsroot ($data->{cvsroot}) if $data->{cvsroot};
    $job->cvsmodule ($data->{cvsmodule}) if $data->{cvsmodule};
    $job->cvsversion ("$data->{cvsversion}");
    $job->snapshot ($data->{snapshot}? "t" : "f");
    $job->create_tarballs ($data->{create_tarballs}? "t" : "f");
    $job->remove_jail ($data->{remove_jail}? "t" : "f");
    $job->ignore_submission_errors ($data->{ignore_submission_errors}? "t" : "f");
    $job->ignore_build_errors ($data->{ignore_build_errors}? "t" : "f");
    $job->min_disk ($data->{min_disk}) if $data->{min_disk};
    $job->max_jobs ($data->{max_jobs}) if $data->{max_jobs};
    $job->channel ($data->{channel}) if $data->{channel};
    $job->pipeline_channel ($data->{pipeline_channel})
	if $data->{pipeline_channel};
    $job->rcd_mcookie ($data->{rcd_mcookie}) if $data->{rcd_mcookie};
    $job->rcd_partnernet ($data->{rcd_partnernet})
	if $data->{rcd_partnernet};

    $job->update if $job->is_changed;

    my $tmp;

    # Target list
    $tmp = Ximian::BB::DB::SavedJobTarget->search (sjid => $job->sjid);
    $tmp->delete_all;

    foreach (split /[,\s]+/, $data->{target}) {
	Ximian::BB::DB::SavedJobTarget->create
		({sjid => $job->sjid, target => $_});
    }

    # Env vars
    $tmp = Ximian::BB::DB::SavedJobEnvVar->search (sjid => $job->sjid);
    $tmp->delete_all;

    while (my ($name, $value) = each %{$data->{env}->{var}}) {
	Ximian::BB::DB::SavedJobEnvVar->create
		({sjid => $job->sjid, name => $name, value => $value});
    }

    # RCD vars
    $tmp = Ximian::BB::DB::SavedJobRCDVar->search (sjid => $job->sjid);
    $tmp->delete_all;
    while (my ($name, $value) = each %{$data->{rcd}->{var}}) {
	Ximian::BB::DB::SavedJobRCDVar->create
		({sjid => $job->sjid, name => $name, value => $value});
    }

    # RCD Services & Activations
    $tmp = Ximian::BB::DB::SavedJobRCDSvc->search (sjid => $job->sjid);
    $tmp->delete_all;
    $tmp = Ximian::BB::DB::SavedJobRCDAct->search (sjid => $job->sjid);
    $tmp->delete_all;

    foreach my $service (@{$data->{rcd}->{services}}) {
	my $svc = Ximian::BB::DB::SavedJobRCDSvc->create
	    ({sjid => $job->sjid, url => $service->{url}});
	while (my ($user, $list) = each %{$service->{activations}}) {
	    foreach my $key (@$list) {
		Ximian::BB::DB::SavedJobRCDAct->create
			({sjid => $job->sjid, sid => $svc->sid,
			  email => $user, rce_key => $key});
	    }
	}
    }

    # RCD subs
    $tmp = Ximian::BB::DB::SavedJobRCDSub->search (sjid => $job->sjid);
    $tmp->delete_all;

    foreach my $ch (@{$data->{rcd}->{subscribe}}) {
	Ximian::BB::DB::SavedJobRCDSub->create
		({sjid => $job->sjid, name => $ch->{name},
		  update_channel => $ch->{update}});
    }

    # Jail Grep Queries
    $tmp = Ximian::BB::DB::SavedJobQuery->search (sjid => $job->sjid);
    $tmp->delete_all;

    my $index = 0;
    foreach my $q (@{$data->{jail_grep_queries}}) {
	my $foo = { sjid => $job->sjid,
		    index => $index++,
		    metadata_id => $q->{metadata_id},
		    text => $q->{text} };
	$foo->{grep_key} = $q->{key} if $q->{key};
	$foo->{xpath} = $q->{xpath} if $q->{xpath};
	Ximian::BB::DB::SavedJobQuery->create ($foo);
    }

    # Extra Deps
    $tmp = Ximian::BB::DB::SavedJobExtraDep->search (sjid => $job->sjid);
    $tmp->delete_all;

    foreach my $dep (@{$data->{extra_deps}}) {
	Ximian::BB::DB::SavedJobExtraDep->create ({sjid => $job->sjid,
						    dep => $dep});
    }

    # Shared Users
    $tmp = Ximian::BB::DB::SavedJobSharedUser->search (sjid => $job->sjid);
    $tmp->delete_all;

    foreach my $login (@{$data->{shared_users}}) {
	my ($user) = Ximian::BB::DB::User->search (login => $login);
	Ximian::BB::DB::SavedJobSharedUser->create ({sjid => $job->sjid,
						     uid => $user->uid});
    }

    # Submit Targets
    $tmp = Ximian::BB::DB::SavedJobSubmitTarget->search (sjid => $job->sjid);
    $tmp->delete_all;

    foreach my $tgt (@{$data->{submit_targets}}) {
	Ximian::BB::DB::SavedJobSubmitTarget->create ({sjid => $job->sjid,
							target => $tgt});
    }

    # Module list
    $tmp = Ximian::BB::DB::SavedJobModule->search (sjid => $job->sjid);
    $tmp->delete_all;

    my $foo = sub { return $_[0]? "$_[0]" : "" };

    my @modules = @{$data->{modules}};
    for (0 .. $#modules) {
 	my $new = {sjid => $job->sjid,
 		   index => $_,
 		   name => $foo->($modules[$_]->{name}),
 		   snapshot => $modules[$_]->{snapshot}? "t" : "f",
 		   build_id => $foo->($modules[$_]->{build_id}),
 		   cvsroot => $foo->($modules[$_]->{cvsroot}),
 		   cvsmodule => $foo->($modules[$_]->{cvsmodule}),
 		   cvsversion => $foo->($modules[$_]->{cvsversion}),
 		   channel => $foo->($modules[$_]->{channel}),
 		   pipeline_channel => $foo->($modules[$_]->{pipeline_channel})};
 	Ximian::BB::DB::SavedJobModule->create ($new);
    }
    $job->update if $job->is_changed;
}

sub save_job {
    my ($uid, $save_name, $data) = @_;
    my $job = Ximian::BB::DB::SavedJob->create ({uid => $uid,
						 name => $save_name});
    update_saved_job ("$job", $data);
    return $job;
}

1;
