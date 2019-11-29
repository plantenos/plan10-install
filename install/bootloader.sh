#!@BINDIR@/bash
# 
# This file is part of Plan10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.

# The disk that's being used as string: "sdx"
DEVICE=$(findmnt --noheadings --output SOURCE $NEWROOT)
if [[ "${DEVICE}" = /dev/nvme* ]]; then
       DEVICE=${DEVICE%%p[0-9]*}
else
       DEVICE=${DEVICE%%[0-9]*}
fi

# The partition table of $DEVICE, used to test for type, most probably: "gpt" or "dos":
PTABLE=$(blkid --match-tag PTTYPE --output value $DEVICE)
# Returns the ESP block device as /dev/sdxY or an empty string, used for mount point and to test for existence:
ESP=$(lsblk --paths --noheadings --output PARTTYPE,NAME $DEVICE | grep 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' | tail --bytes 10)
# The full path of the mounted ESP including $NEWROOT
ESPMOUNT=$(lsblk --noheadings --output MOUNTPOINT $ESP)

boot_partition_select(){

	local list

	list=$(lsblk -lno TYPE,NAME,MOUNTPOINT | awk '/part/  {if ($3=="") { $3="-" };print "/dev/" $2 " " $3}')
	# Prompt user to select boot partition
	msg="\nPlease select your ${DG_COLOR_BOLD}boot${DG_COLOR_RESET} partition - If you did not create one choose root"
	
	if [[ $FIRMWARE == "UEFI" ]]; then
		msg="\nPlease select your boot partition"
	fi
	DG_ITEMS_OPTS=""
	dg_action BOOTPART menu "Boot Partition Selection" "${msg}" ${list[@]} 
	if (( $? )); then
		DG_ITEMS_OPTS="--no-items"
		return 1
	fi
	DG_ITEMS_OPTS="--no-items"
	
	# Use findmnt to store the complete mount point of sdxY
	BOOTPARTMOUNT=$(findmnt --noheadings --output TARGET $BOOTPART)
	BOOTPARTNUMBER=$(part_find_partnumber ${BOOTPART})
	unset list
}

check_boot_mountpoint(){
	
	local _a _b

	msg_uefi="\n
${DG_COLOR_ERROR}ERROR${DG_COLOR_RESET}: Your EFI system partition is not mounted at /boot!\n\n
EFISTUB and Syslinux on UEFI require the ESP to be mounted at /boot."
	
	msg_bios="\n
${DG_COLOR_ERROR}ERROR${DG_COLOR_RESET}: Your boot partition is not mounted at /boot neither is it root!\n\n
EXTLINUX requires a separate boot partition to be mounted at /boot."

	msg_to_peon="\n
Please correct your mount points accordingly.\n\n
Make sure to backup any existing kernel images before mounting to boot.\n\n
Exit the script now?"

	# Check if the boot partition mount point is /boot, offer to exit if it's not
	[[ $FIRMWARE == "UEFI" && $BOOTPARTMOUNT != $NEWROOT/boot ]] && local _a=$?
	[[ $FIRMWARE == "BIOS" && $BOOTPARTMOUNT != $NEWROOT/boot && $BOOTPARTMOUNT != $NEWROOT ]] && local _b=$?
	if [[ $_a || $_b ]]; then
		if [[ $FIRMWARE == "UEFI" ]]; then
			dg_info "Boot Mountpoint" "$msg_uefi"
		else
			dg_info "Boot Mountpoint" "$msg_bios"
		fi
		dg_yesno "Boot Mountpoint" "$msg_to_peon"
		if (( ! $? )); then
			die "" "clean_install"
		fi
	fi

	unset _a _b
}

syslinux_install(){

	local title="Syslinux Installation"
	# Set bootloader name and paths acoording to installation method
	[[ $FIRMWARE == "UEFI" ]] && local _loadername="Syslinux" || local _loadername="EXTLINUX"
	local _uefipath=$NEWROOT/boot/EFI/plan10
	local _biospath=$NEWROOT/boot/plan10
	local _rootpart=$(findmnt --noheadings --output SOURCE $NEWROOT)
	local _rootpartuuid=$(findmnt --noheadings --output UUID --mountpoint $NEWROOT)
	if [[ "${_rootpart}" = /dev/nvme* ]]; then
		_rootpart=${_rootpart%%p[0-9]*}
	else
		_rootpart=${_rootpart%%[0-9]*}
	fi
	# Prompt for boot partition and run a post check for compatibility
	if ! boot_partition_select; then
		dg_info "${title}" "\nBootloader cannot be installed without knowing the boot partition.\n${BOOTLOADER} will ${DG_COLOR_WARN}not${DG_COLOR_RESET} be installed."
		return 0
	fi
	check_boot_mountpoint
	dg_info "${title}" "\nInstalling $_loadername bootloader for ${FIRMWARE} on a ${PTABLE^^} partition table" 1

	msg_uefi_logic="\n
If you loose your NVRAM entry due to bad firmware you will have to recreate it.\n\n
See efibootmgr(8) and https://wiki.archlinux.org/index.php/syslinux#UEFI_Systems."

	# UEFI INSTALL LOGIC
	if [[ $FIRMWARE == "UEFI" ]]; then
		dg_info "${title}" "\nCreate $_loadername directory at $_uefipath" 1
		mkdir --parents $_uefipath || die "unable to create $_uefipath directory" "clean_install"
		
		dg_info "${title}" "\nCopy $_loadername module files" 1
		cp --recursive "${NEWROOT}"/usr/lib/syslinux/efi64/* $_uefipath || die "unable to copy $NEWROOT/usr/lib/syslinux/efi64/* to $_uefipath" "clean_install"
		cp "${NEWROOT}"/boot/syslinux/splash.png $_uefipath || die "unable to copy ${NEWROOT}/boot/syslinux/splash.png to $_uefipath" "clean_install" 
		
		dg_info "${title}" "\nCopy configuration files" 1
		cp "${NEWROOT}"/boot/syslinux/syslinux.cfg $_uefipath/syslx64.cfg || die "unable to copy ${NEWROOT}/boot/syslinux/syslinux.cfg to $_uefipath/syslx64.cfg" "clean_install" 
		
		dg_info "${title}" "\nCreate NVRAM entry to point to $_loadername EFI application" 1
		efibootmgr --quiet --create --disk $DEVICE --part ${BOOTPARTNUMBER} --label "Plan10" \
		--loader "/EFI/plan10/syslinux.efi" -u "root=UUID=${_rootpartuuid}" || die "Create NVRAM entry to point to $_loadername EFI application" "clean_install"
		
		# Warn the user about possible corruption
		dg_info "${title}" "$msg_uefi_logic"

	# BIOS INSTALL LOGIC
	else
		# Installation to /boot - It does not matter if this is a separate partition or not
		# If someone made a boot partition and mounted it to a different directory it will be ignored
		# Syslinux/EXTLINUX can not cross reference other partitions (yet)
		# In order to access the kernel it has to be on the same partition as the kernel (root or /boot)
		dg_info "${title}" "\nCreate directory $_biospath" 1
		mkdir --parents $_biospath || die "unable to make directory $_biospath" "clean_install"
		
		dg_info "${title}" "\nCopy $_loadername module files" 1
		cp $NEWROOT/usr/lib/syslinux/bios/*.c32 $_biospath || die "unable to copy $_loadername module files" "clean_install"
		
		dg_info "${title}" "\nCopy Syslinux configuration files to $_biospath" 1
		cp "${NEWROOT}"/boot/syslinux/splash.png $_biospath || die "unable to copy ${NEWROOT}/boot/syslinux/splash.png to $_biospath" "clean_install"
		cp "${NEWROOT}"/boot/syslinux/syslinux.cfg $_biospath/extlinux.conf || die "unable to copy ${NEWROOT}/boot/syslinux/syslinux.cfg to $_biospath/extlinux.conf" "clean_install"
				
		dg_info "${title}" "\nExecs extlinux at $_biospath" 1
		extlinux --install $_biospath || die "unable to execute extlinux install" "clean_install"
				
		# for MBR:
		if [[ $PTABLE == "dos" ]]; then
			# Activate the boot flag, Linux does not care about this, it is legacy Windows compatibility
			sfdisk --quiet --no-reread --no-tell-kernel --activate $DEVICE ${BOOTPARTNUMBER}
			# Install the Master Boot Record
			dd bs=440 count=1 conv=notrunc status=none if=$NEWROOT/usr/lib/syslinux/bios/mbr.bin of=$DEVICE
		# for GPT:
		else
			# Set attribute bit 2 "LegacyBIOSbootable" for the boot partition, again compatibility only
			sgdisk $DEVICE --attributes=${BOOTPARTNUMBER}:set:2
			# Install the Master Boot Record
			dd bs=440 count=1 conv=notrunc status=none if=$NEWROOT/usr/lib/syslinux/bios/gptmbr.bin of=$DEVICE
		fi
	fi
	
	# Clean up. This is a bit hacky since the syslinux directory shouldn't get installed before anyways
	[[ -d $NEWROOT/boot/syslinux ]] && rm --recursive --force $NEWROOT/boot/syslinux
	
	dg_info "${title}" "\nSuccessfully installed $_loadername" 1

	# Automatically adjust the config file from the live ISO to reflect installation environment
	if [[ $FIRMWARE == "UEFI" ]]; then
		sed --in-place "s|root=/dev/....|root=UUID=${_rootpartuuid}|g" $_uefipath/syslx64.cfg
		sed --in-place "s|\ ../|\ ../../|g" $_uefipath/syslx64.cfg
		# Offer the user to edit the EXTLINUX configuration file
		dg_yesno "${title}" "\nDo you want to manually edit syslx64.cfg?"
		if (( ! $? )); then
			check_editor
			tput cnorm
			$EDITOR $_uefipath/syslx64.cfg
		fi
	else
		sed --in-place "s|root=/dev/....|root=UUID=${_rootpartuuid}|g" $_biospath/extlinux.conf
		# Offer the user to edit the EXTLINUX configuration file
		dg_yesno "${title}" "\nDo you want to manually edit extlinux.conf?"
		if (( ! $? )); then
			check_editor
			tput cnorm
			$EDITOR $_biospath/extlinux.conf
		fi
	fi
	
	dg_info "${title}" "\nSyslinux installation complete" 1
	
	unset  _loadername _uefipath _biospath _rootpart  _rootpartuuid title
}

grub_install() {
	
	local title="GRUB Installation" grub_opts="" boot_device=""
	
	if ! boot_partition_select; then
		dg_info "${title}" "\nBootloader cannot be installed without knowing the boot partition.\n${BOOTLOADER} will ${DG_COLOR_WARN}not${DG_COLOR_RESET} be installed."
		return 0
	fi
	if [[ "${BOOTPART}" = /dev/nvme* ]]; then
		boot_device=${BOOTPART%%p[0-9]*}
	else
		boot_device=${BOOTPART%%[0-9]*}
	fi
	# Check if firmware is set to UEFI and install accordingly
	if [[ $FIRMWARE == "UEFI" ]]; then
		# Provide access to efivars for chroot
		mount --bind /sys/firmware/efi/efivars $NEWROOT/sys/firmware/efi/efivars

		# Offer to install for removable media
		dg_yesno "${title}" "Is the installation medium a removable media like a USB flash drive?"
	
		if (( ! $? )); then
			grub_opts="--removable"
		fi
		dg_info "${title}" "Installing bootloader" 1
		# UEFI specific GRUB command for removable media; Will create esp/EFI/obraun directory; This is standard for major Linux distros and makes multi booting easier
		chroot $NEWROOT grub-install "${grub_opts}" --target=x86_64-efi --efi-directory=${ESPMOUNT/$NEWROOT} --bootloader-id=plan10 || die "Failed to install GRUB bootloader" "clean_install"
		chroot $NEWROOT grub-mkconfig -o /boot/grub/grub.cfg || die "Failed to install GRUB bootloader" "clean_install"
	else
		dg_info "${title}" "Installing bootloader" 1
		# BIOS specific GRUB command
		chroot $NEWROOT grub-install --force "${boot_device}" || die "Failed to install GRUB bootloader" "clean_install"
		chroot $NEWROOT grub-mkconfig -o /boot/grub/grub.cfg || die "Failed to configure GRUB bootloader" "clean_install"
		if [[ $PTABLE == "dos" ]]; then
			# Activate the boot flag, Linux does not care about this, it is legacy Windows compatibility
			sfdisk --quiet --no-reread --no-tell-kernel --activate "${boot_device}" ${BOOTPARTNUMBER}
		# for GPT:
		else
			# Set attribute bit 2 "LegacyBIOSbootable" for the boot partition, again compatibility only
			sgdisk "${boot_device}" --attributes=${BOOTPARTNUMBER}:set:2
			# Usually a "BIOS boot partition" without Filesystem and GUID 21686148-6449-6E6F-744E-656564454649 is recommended to use with GRUB on BIOS/GPT
			# GRUB will throw an informative warning by itself for this
		fi

	fi
	
	# Mount / with ro permissions
	sed -i "s:\ rw\ :\ ro\ :g" $NEWROOT/boot/grub/grub.cfg
	
	# Replace the default "Arch" label in GRUB
	sed --in-place "s|Arch\ Linux|Plan10|g" $NEWROOT/boot/grub/grub.cfg
	dg_info "${title}" "\nSuccessfully installed GRUB" 1

	# Offer to edit the default GRUB configuration file
	dg_yesno "${title}" "\nDo you want to manually edit grub.cfg?"
	if (( ! $? )); then
		check_editor
		tput cnorm
		$EDITOR $NEWROOT/boot/grub/grub.cfg
	fi

	dg_info "${title}" "\nGRUB installation complete" 1
	
	unset title grub_opts boot_device
}

efistub_install() {
	
	local title="EFISTUB Installation"
	
	if ! boot_partition_select; then
		dg_info "${title}" "\nBootloader cannot be installed without knowing the boot partition.\n${BOOTLOADER} will ${DG_COLOR_WARN}not${DG_COLOR_RESET} be installed."
		return 0
	fi
	check_boot_mountpoint

	local _partnumber _rootpartuuid _microcode="" _kernelparams=""
	_partnumber=$(part_find_partnumber $ESP)
	_rootpartuuid=$(findmnt --noheadings --output UUID --mountpoint $NEWROOT)

	# Offer to provide additional kernel parameters
	dg_yesno "${title}" "\nAdd custom kernel parameters?"
	if (( ! $? )); then
		dg_action _kernelparams input "EFISTUB Installation" "\nWrite out any kernel parameter you wish to include in your entry - Separate with spaces"
		if (( $? ));then
			_kernelparams=""
		fi
	fi
	
	DG_ITEMS_OPTS=""
	# Offer to add microcode
	dg_yesno "${title}" "\nInstall CPU microcode?"
	if (( ! $? )); then
		dg_action _microcode menu "EFISTUB Installation" "\nSelect your architecture" "Intel AMD"
		if (( $? ));then
			_microcode=""
		else
			## Install corresponding microcode package
			pacman --root $NEWROOT --sync ${_microcode,,}'-ucode' --needed --config $GENERAL_DIR/$CONFIG_DIR/pacman.conf --cachedir $CACHE_DIR --noconfirm --dbpath $NEWROOT/var/lib/pacman || die "Failed to install ${_microcode,,}-ucode package" "clean_install"
			_microcode='initrd=\'${_microcode,,}'-ucode.img'
			_kernelparams+=($_microcode)
		fi
	fi
	DG_ITEMS_OPTS="--no-items"
	
	# Create the NVRAM entry
	dg_info "${title}" "\nCreating NVRAM entry..." 1
	efibootmgr --quiet --create --disk $DEVICE --part $_partnumber --label 'Plan10' --loader \vmlinuz-linux --unicode 'root=UUID='"${_rootpartuuid}"' ro '"${_kernelparams[*]}"' initrd=\initramfs-linux.img' || die "Failed to create NVRAM entry." "clean_install"
	dg_info "${title}" "\nSuccessfully created NVRAM entry to boot with EFISTUB." 1

	msg_to_peon="\n
Changes in microcode architecture and kernel parameters require manual recreation.\n
If you loose your NVRAM entry due to bad firmware you will also have to recreate it.\n
See efibootmgr(8) and https://wiki.archlinux.org/index.php/EFISTUB#efibootmgr."
	
	dg_info "${title}" "$msg_to_peon"
	
	dg_info "${title}" "\nEFISTUB installation complete" 1
	
	unset ESP _partnumber _rootpartuuid _microcode _kernelparams title
}
