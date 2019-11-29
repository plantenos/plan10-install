# Makefile for plan10-install

VERSION = $$(git describe --tags| sed 's/-.*//g;s/^v//;')
PKGNAME = plan10-install

BINDIR = /usr/bin

FILES = $$(find install/ -type f)
SCRIPTS = 	plan10-install.in \
			install.sh
			
install:
	
	for i in $(SCRIPTS) $(FILES); do \
		sed -i 's,@BINDIR@,$(BINDIR),' $$i; \
	done
	
	install -Dm755 plan10-install.in $(DESTDIR)/$(BINDIR)/plan10-install
	install -Dm755 install.sh $(DESTDIR)/usr/lib/plan10/install.sh
	
	for i in $(FILES); do \
		install -Dm755 $$i $(DESTDIR)/usr/lib/plan10/$$i; \
	done
	
	install -Dm644 install.conf	$(DESTDIR)/etc/plan10/install.conf
	
	install -Dm644 dialog.conf	$(DESTDIR)/etc/plan10/dialog.conf
	
	install -Dm644 PKGBUILD $(DESTDIR)/var/lib/plan10/plan10-install/update_package/PKGBUILD

	install -dm755 $(DESTDIR)/var/lib/plan10/plan10-install/config
	
	install -Dm644 LICENSE $(DESTDIR)/usr/share/licenses/$(PKGNAME)/LICENSE

version:
	@echo $(VERSION)
	
.PHONY: install version
