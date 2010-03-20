# $Id$

SCRIPTS=	PortIndex2MySQL

edit = sed \
	-e 's,@macports_tcl_dir@,$(macports_tcl_dir),g'


include ../../Mk/macports.autoconf.mk


all: ${SCRIPTS}

PortIndex2MySQL: PortIndex2MySQL.tcl
	${edit} $< > $@
	chmod 755 $@

clean:
	rm -f ${SCRIPTS}

distclean: clean
