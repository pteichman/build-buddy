# This really needs to be more configurable

install-friends:
	find ${DESTDIR} -type f -name .packlist |xargs -r rm -f
	find ${DESTDIR} -type f -name perllocal.pod |xargs -r rm -f
	find ${DESTDIR} -type d -empty |xargs -r rmdir -p --ignore-fail-on-non-empty || true
	mkdir -p ${DESTDIR}/usr/share/build-buddy \
		${DESTDIR}/usr/share/doc/build-buddy \
		${DESTDIR}/etc/init.d
	cp -r conf lint plugins logstyles packsys ${DESTDIR}/usr/share/build-buddy
	cp scripts/*.guess ${DESTDIR}/usr/bin
	cp init.d/bb_utils ${DESTDIR}/etc/init.d
	cp init.d/bb_node ${DESTDIR}/etc/init.d
	chmod 755 ${DESTDIR}/etc/init.d/bb_node
	cp doc/* ${DESTDIR}/usr/share/doc/build-buddy
