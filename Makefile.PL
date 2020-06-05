use ExtUtils::MakeMaker;

WriteMakefile (
	       NAME         => 'build-buddy',
	       VERSION_FROM => "BB.pm",
	       EXE_FILES    => [
                                'scripts/bb_build',
                                'scripts/bb_client',
                                'scripts/bb_do',
                                'scripts/bb_jail',
                                'scripts/bb_jail_convert',
                                'scripts/bb_jail_manager',
                                'scripts/bb_jail_meta',
                                'scripts/bb_lint',
                                'scripts/bb_lndir',
                                'scripts/bb_macro',
                                'scripts/bb_node',
                                'scripts/bb_node_http',
                                'scripts/bb_redo',
                                'scripts/bb_regenerate',
                                'scripts/bb_scp',
                                'scripts/bb_shell',
                                'scripts/bb_snapshot',
                                'scripts/bb_ssh',
                                'scripts/bb_submit',
                                'scripts/bb_tag',
                                'scripts/bb_targetid',
                                'scripts/bb_unpack',
                                'scripts/bb_xmlgen'
			       ],
               dist => { PREOP => "rm -f build-buddy*.tar.gz" }
	      );
