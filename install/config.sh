#!@BINDIR@/bash
# 
# This file is part of Plan10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.

config_custofile(){
	
	custo_once config_hostname
	custo_once config_locale
	custo_once config_localetime
	custo_once config_user
	custo_once config_keymap
	custo_once config_xkeymap
	custo_once config_pac_sync
	custo_once config_pacopts
}

config_hostname(){
	
	if [[ "$HOSTNAME" != "" ]]; then
		sed -i 's/ .*$//' "${NEWROOT}"/etc/hosts
	fi
	
	sed -i "s/HOSTNAME=.*$/HOSTNAME=$HOSTNAME/g" "${NEWROOT}"/etc/66/boot.conf
		
	echo "$HOSTNAME" > "${NEWROOT}"/etc/hostname
	sed -i '/127.0.0.1/s/$/ '$HOSTNAME'/' "${NEWROOT}"/etc/hosts
	sed -i '/::1/s/$/ '$HOSTNAME'/' "${NEWROOT}"/etc/hosts
	
	out_valid "hostname was configured successfully"
}

config_locale(){
	
	local _locale
	
	# make sure the variable LOCALE is not empty before launch locale-gen
	_locale="${LOCALE:-en_US.UTF-8}"
	sed -i "s:^#${_locale}:${_locale}:g" "${NEWROOT}"/etc/locale.gen
	
	chroot "${NEWROOT}" locale-gen
	
	echo LANG="$LOCALE" > "${NEWROOT}"/etc/locale.conf
    echo LC_COLLATE=C >> "${NEWROOT}"/etc/locale.conf
	
	out_valid "Locale was created successfully"
	
	unset _locale
}

config_localetime(){
	
	if [[ -n "$SUBZONE" ]]; then
		chroot "${NEWROOT}" ln -sf ${LOCALTIME}/$ZONE/$SUBZONE /etc/localtime
		sed -i "s/TZ=.*$/TZ=$ZONE\/$SUBZONE/g" "${NEWROOT}"/etc/66/boot.conf
	else
		chroot "${NEWROOT}" ln -sf ${LOCALTIME}/$ZONE /etc/localtime
		sed -i "s/TZ=.*$/TZ=$ZONE/g" "${NEWROOT}"/etc/66/boot.conf
	fi
	
	out_valid "Localetime was configured successfully"
}

config_user(){
	
	chroot "$NEWROOT" useradd -m -G "audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel,video,users" -s /usr/bin/zsh "$NEWUSER"
	
	config_password "${NEWUSER}"
	
	out_valid "User $NEWUSER was created successfully" 
}

config_keymap(){
	
	sed -i "s,KEYMAP=.*$,KEYMAP=$KEYMAP,g" "${NEWROOT}"/etc/66/boot.conf
	
	out_valid "Console keymap was configured successfully"
}

config_xkeymap(){
	
	if [[ -e "${NEWROOT}/etc/X11/xorg.conf.d/00-keyboard.conf" ]]; then
		out_action "Define keymap for X server in /etc/X11/xorg.conf.d/00-keyboard.conf"
		sed -i 's:Option "XkbLayout"\ .*$:Option "XkbLayout" "'$XKEYMAP'":g' "${NEWROOT}"/etc/X11/xorg.conf.d/00-keyboard.conf
		out_valid "Desktop xkeymap was configured successfully"
	fi
}

config_mirrorlist(){
	out_action "Copy mirroirlist from the host"
	cp -af /etc/pacman.d/mirrorlist "${NEWROOT}"/etc/pacman.d/mirrorlist
}

config_pac_sync(){
	out_action "Synchronize database..."
	if [[ ! -d "${NEWROOT}"/var/lib/pacman/sync ]]; then 
		pacman -r "${NEWROOT}" -Syy --dbpath "$NEWROOT/var/lib/pacman"
	else
		pacman -r "${NEWROOT}" -Sy --dbpath "$NEWROOT/var/lib/pacman"
	fi
}

config_gpg(){
	
	out_action "Check if gpg key exist"	
	chroot "${NEWROOT}" pacman-key -u &>/dev/null
	
	if (( $? ));then
		out_notvalid "Gpg doesn't exist, create it..."
		out_action "Start pacman-key"
		chroot "${NEWROOT}" haveged -w 1024
		chroot "${NEWROOT}" pacman-key --init ${gpg_opts}
	
		for named in archlinux plan10;do
			out_action "populate $named"
			chroot "${NEWROOT}" pacman-key --populate "$named" 
		done
	else
		out_valid "Gpg key exist, Refresh it..."
		pacman-key -u 
	fi
}

config_pacopts(){
	out_action "Launch applysys program"
	chroot "${NEWROOT}" applysys "$(ls ${NEWROOT}/usr/lib/sysusers.d/)"
}

config_virtualbox(){
	if [[ -n $(grep "VirtualBox" /sys/class/dmi/id/product_name) ]]; then
		dg_yesno "Virtualbox Configuration" "\nThis is a VirtualBox machine. Do you want to install virtualbox guest modules?"
		if (( ! $? )); then
			pacman -r "$NEWROOT" -S virtualbox-guest-modules-arch virtualbox-guest-utils --config "$GENERAL_DIR/$CONFIG_DIR/pacman.conf" --cachedir "$CACHE_DIR" --noconfirm --dbpath "$NEWROOT/var/lib/pacman" || die " Failed to install virtualbox packages" "clean_install"
		fi
	fi
}

config_bootloader() {
	
	local boot="${BOOTLOADER}"
	dg_yesno "Bootloader Install" "\nDo you want to install the ${boot} bootloader?"
	if (( ! $? )); then
	
		if [[ "${boot}" == "EFISTUB" ]]; then
			boot="efibootmgr"
		fi
		
		# Check if package is already installed
		pacman --root $NEWROOT --query --info ${boot,,} &> /dev/null
		if [[ $? == 1 ]]; then
			# Install if it is not
			pacman --root $NEWROOT --sync ${boot,,} --needed --config $GENERAL_DIR/$CONFIG_DIR/pacman.conf --cachedir $CACHE_DIR --noconfirm --dbpath $NEWROOT/var/lib/pacman || die "Failed to install ${_boot,,} package" "clean_install"
		fi
		# Call the corresponding menu
		if [[ "${boot}" == "Syslinux" ]]; then
			syslinux_install
		elif [[ "${boot}" == "GRUB" ]]; then
			grub_install
		elif [[ "${boot}" == "efibootmgr" ]]; then
			efistub_install
		fi
	fi
	unset boot
	return 0
}
	
config_password(){
	
	local user="${1}" pass pass1
	
	while [[ -z "${pass}" ]] || [[ "${pass}" != "${pass1}" ]]; do 
		dg_run pass --title "Password Configuration" --insecure --passwordbox "\nEnter the password for the ${DG_COLOR_BOLD}${user}${DG_COLOR_RESET} user" 0 0
		if (( $? ));then
			return 1
		fi
		dg_run pass1 --title "Password Configuration" --insecure --passwordbox "\nEnter ${DG_COLOR_BOLD}again${DG_COLOR_RESET} the same password" 0 0
		if (( $? ));then
			return 1
		fi
		if [[ -z "${pass}" ]] || [[ "${pass}" != "${pass1}" ]]; then
			dg_info "Password Configuration" "\nPassword ${DG_COLOR_ERROR}mismatch${DG_COLOR_RESET}, please retry."
		fi
	done
	
	printf "%b\n" "${pass}\n${pass1}" | passwd -R "${NEWROOT}" "${user}" || die "unable to set the ${user} password" "clean_install"
	
	unset pass pass1 user
}
