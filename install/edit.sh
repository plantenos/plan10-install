#!@BINDIR@/bash
# 
# This file is part of Plan10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.

## 		Edit pacman.conf

edit_pacman(){
	check_editor
	tput cnorm
	edit_file "pacman.conf" "$GENERAL_DIR/$CONFIG_DIR" "$EDITOR"	
}

##		Edit 66.conf

edit_conf(){
	
	tput cnorm
	edit_file "boot.conf" "${NEWROOT}/etc/66" "$EDITOR"
}

## 		Edit customizeChroot file

edit_customize_chroot(){
	check_editor
	tput cnorm
	edit_file "customizeChroot" "$GENERAL_DIR/$CONFIG_DIR" "$EDITOR" || die " File customizeChroot not exist" "clean_install"
	if [[ -d "$NEWROOT/etc" ]]; then
		out_action "Copying customizeChroot to $NEWROOT/etc/customizeChroot"
		cp -f "$GENERAL_DIR/$CONFIG_DIR/customizeChroot" "$NEWROOT/etc/customizeChroot" 
	fi
}

##		Select packages list

edit_pkg_list(){
	local -a list del_list
	local file 
	check_editor
	tput cnorm
	make_list() {
		list=( $(find "$GENERAL_DIR"/"$CONFIG_DIR"/package_list/ -type f -printf "%f\n") )
		list+=( "---Separator---" )
		list+=( "Create" )
		list+=( "Delete" )
	}
	make_list
	msg_delete="\n
Select the file to delete.\n\n
${DG_COLOR_BOLD}Note${DG_COLOR_RESET}: Deletes the ${DG_COLOR_BOLD}'base'${DG_COLOR_RESET} file is not ${DG_COLOR_WARN}allowed${DG_COLOR_RESET}"

	while : ;do
		dg_run file --cancel-label 'Done' --ok-label 'Edit' --title " Package List " --menu "$dgm_edit_pkg_list" 0 0 ${#list[@]} ${list[@]}
		if (( $? )); then
			break
		fi
		
		if [[ "$file" == "---Separator---" ]];then
			continue
		elif [[ "$file" == "Create" ]];then
			dg_action file input "Package List" "\nEnter the name of the file to create." "my_file"
			if (( $? )); then
				continue
			fi
			tput cnorm
			edit_file "$file" "$GENERAL_DIR/$CONFIG_DIR/package_list" "$EDITOR"
			make_list
		elif [[ "$file" == "Delete" ]];then
			del_list=( $(find "$GENERAL_DIR"/"$CONFIG_DIR"/package_list/ -type f -printf "%f\n") )
			dg_action file menu "Package List" "${msg_delete}" ${del_list[@]}
			if (( $? )); then
				continue
			fi
			if [[ "${file}" == "base" ]];then
				continue
			else
				rm -f "$GENERAL_DIR"/"$CONFIG_DIR"/package_list/$file
				make_list
			fi
		else
			tput cnorm
			edit_file "$file" "$GENERAL_DIR/$CONFIG_DIR/package_list" "$EDITOR"
		fi
	done
	
	unset list del_list file
}
