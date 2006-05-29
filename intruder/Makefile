default:
	./makewrapper $@

*:
	./makewrapper $@

%:
	./makewrapper $@

.PHONY: *

all.global: beautify

distclean.global:
	./makewrapper $@
	for d in models textures sound; do chmod 755 ../$$d/CVS && chmod 755 ../$$d || true; done
	cd ..; rm -rf EclipseBuild

