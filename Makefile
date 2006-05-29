# automatically generate configuration files from templates
%: %.template
	touch autoclean
	test -r $@ || cp $< $@
	touch $@
sinclude make.config

# the directory inside the AA source we use to make the debug config, make targets and binaries known
ECLIPSEBUILD=EclipseBuild
INTRUDER=$(AAPATH)/$(ECLIPSEBUILD)

make.config: preconfig sysprofile/profile.config

# register this build in the intruding directory ( so the .global make targets work )
register: $(INTRUDER)/tag
	$(MAKE) unregister
	echo $$(pwd) >> $(INTRUDER)/register
	touch $@

unregister: $(INTRUDER)/tag
	touch $(INTRUDER)/register
	mv $(INTRUDER)/register $(INTRUDER)/register.old
	grep -v "^$$(pwd)$$" < $(INTRUDER)/register.old > $(INTRUDER)/register || true
	rm -f register

$(INTRUDER)/tag:
	# create top level directories inside main project
	test -d $(INTRUDER) || mkdir $(INTRUDER)
	touch $@

# global make targets
%.global: register
	for build in $$(cat $(INTRUDER)/register); do $(MAKE) -C $$build "$*"; done

# combined make targets
client: client_optimize client_debug
server: server_optimize server_debug
optimize: client_optimize server_optimize
debug: client_debug server_debug
all: client server

# just make configuration files and exit
initialize: make.config
	echo "Configuration files created."

# automatically clean project if configuration changed
# uncomment autoclean include in make.config to activate ( note: can be annoying )
autoclean: preconfig make.config Makefile configure confmake $(AAPATH)/configure $(AAPATH)/Makefile.am
	touch autoclean
	make clean

$(AAPATH)/configure: $(AAPATH)/configure.*
	cd $(AAPATH); sh ./bootstrap.sh

$(AAPATH)/config.h.in: $(AAPATH)/configure

# standard targets
clean:
	# delete contents of build, but keep varfiles
	for f in build/*; do if test -d $$f/var; then mv $$f/var varback; rm -rf $$f/* $$f/.cvsfiles; mv varback $$f/var; else rm -rf $$f; fi; done
	# done

distclean: unregister
	# remove everything
	rm -rf build
	rm -f autoclean make.config preconfig sysprofile/profile.config
	rm -rf 

# selects this build as the default build
select: $(INTRUDER)
	# install redirection
	TARGET="$$(pwd)"; cd $(INTRUDER) && echo "$$TARGET" > redirect

	# create lower level directories
	for DIR in maketargets maketargets/*; do \
		test -d $(INTRUDER)/$$DIR || mkdir $(INTRUDER)/$$DIR; \
	done
	rm -rf $(INTRUDER)/maketargets/CVS

	# link output directories
	for TYPE in client server; do\
		for BUILD in optimize debug; do\
			ln -sf $$(pwd)/build/$${TYPE}_$${BUILD} $(INTRUDER)/;\
		done;\
	done

	# link debug configurations
	for TYPE in Client Server; do\
		ln -sf $$(pwd)/intruder/Debug_$$TYPE.launch.template $(INTRUDER)/Debug_$$TYPE.launch;\
	done

	# link make wrapper and make it executable
	ln -sf $$(pwd)/intruder/makewrapper $(INTRUDER)/
	chmod 755 intruder/makewrapper

	# install fake makefile
	ln -sf $$(pwd)/intruder/Makefile $(INTRUDER)/

	# write protect textures, models and sounds
	#for DIR in models textures sound; do\
	#	chmod 555 $(AAPATH)/$$DIR/CVS;\
	#	chmod 555 $(AAPATH)/$$DIR;\
	#done

	echo -e "\nBuild configuration has been selected as the default.\nDon't forget to refresh the AA project!\n"

# all targets should be remade every time
# .PHONY: client_optimize server_optimize client_debug server_debug

client_optimize: register $(AAPATH)/configure
	AAPATH=$(AAPATH) MAKEFLAGS="${MAKEFLAGS}" MAKE=$(MAKE) DEBUGLEVEL=0 CODELEVEL=$(CODELEVEL) CXXFLAGS="$(CXXFLAGS_OPTIMIZE) $(CXXFLAGS_CLIENT) $(CXXFLAGS_CLIENT_OPTIMIZE)" bash ./confmake $@

server_optimize: register $(AAPATH)/configure
	AAPATH=$(AAPATH) MAKEFLAGS="${MAKEFLAGS}" MAKE=$(MAKE) DEBUGLEVEL=0 CODELEVEL=$(CODELEVEL) CXXFLAGS="$(CXXFLAGS_OPTIMIZE)  $(CXXFLAGS_SERVER) $(CXXFLAGS_SERVER_OPTIMIZE)" bash ./confmake $@ --disable-glout

client_debug: register $(AAPATH)/configure
	AAPATH=$(AAPATH) MAKEFLAGS="${MAKEFLAGS}" MAKE=$(MAKE) DEBUGLEVEL=$(DEBUGLEVEL) CODELEVEL=$(CODELEVEL) CXXFLAGS="$(CXXFLAGS_DEBUG) $(CXXFLAGS_CLIENT) $(CXXFLAGS_CLIENT_DEBUG)" bash ./confmake $@

server_debug: register $(AAPATH)/configure
	AAPATH=$(AAPATH) MAKEFLAGS="${MAKEFLAGS}" MAKE=$(MAKE) DEBUGLEVEL=$(DEBUGLEVEL) CODELEVEL=$(CODELEVEL) CXXFLAGS="$(CXXFLAGS_DEBUG) $(CXXFLAGS_SERVER) $(CXXFLAGS_SERVER_DEBUG)" bash ./confmake $@ --disable-glout

beautify: $(AAPATH)/configure
	AAPATH=$(AAPATH) MAKEFLAGS="${MAKEFLAGS}" MAKE=$(MAKE) DEBUGLEVEL=$(DEBUGLEVEL) CODELEVEL=$(CODELEVEL) CXXFLAGS="$(CXXFLAGS_OPTIMIZE) $(CXXFLAGS_SERVER) $(CXXFLAGS_SERVER_OPTIMIZE)" bash ./configure server --disable-glout
	$(MAKE) -C build/server rebeautify 

# run checks before committing to CVS
cvscheck_single.%: %
	$(MAKE) -C build/$* cvscheck
cvscheck: cvscheck_single.client_debug cvscheck_single.client_optimize cvscheck_single.server_debug cvscheck_single.server_optimize

# tests distribution
distcheck_fake_single.%: %
	ARMAGETRONAD_FAKERELEASE=true $(MAKE) -C build/$* distcheck
distcheck_single.%: %
	$(MAKE) -C build/$* distcheck
distcheck_fake: distcheck_fake_single.client_debug distcheck_fake_single.server_debug
distcheck: distcheck_single.client_debug
distcheck_full: distcheck_single.client_debug distcheck_single.server_debug distcheck_single.client_optimize distcheck_single.server_optimize

fullcheck: cvscheck distcheck_full

