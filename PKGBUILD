# Copyright (c) 2019 Plan 10 <plantenos@protonmail.com>
# All rights reserved.
# 
# This file is part of Plan 10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
#
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.
#
# Maintainer: Plan 10-install scripts <plantenos@protonmail.com>
# DO NOT EDIT this PKGBUILD if you don't know what you do

pkgname=plan10-install

pkgdesc="Script for automatic installation"

pkgver=23536df
pkgrel=1

url="file:///var/lib/plan10/$pkgname/update_package/$pkgname"

source=("$pkgname::git+file:///var/lib/plan10/$pkgname/update_package/$pkgname")

#--------------------------------------| BUILD PREPARATION |------------------------------------

pkgver() {
	cd "${pkgname}"
	
	git describe --tags | sed -e 's:-:+:g;s:^v::'
}

#-------------------------------------------| PACKAGE |-----------------------------------------

package() {
	cd "${pkgname}"

	make DESTDIR="$pkgdir" install
}

#------------------------------------| INSTALL CONFIGURATION |----------------------------------

arch=(x86_64)

backup=('etc/plan10/install.conf')

depends=(
	'arch-install-scripts'
	'expac'
	'rsync'
	'mc'
	'git'
	'pacman'
	'pacman-contrib'
	'cower'
	'plan10-libs'
	'plan10-install-themes'
	'dialog'
	'parted'
	'gptfdisk')

#-------------------------------------| SECURITY AND LICENCE |----------------------------------

md5sums=('SKIP')
license=(ISC)
