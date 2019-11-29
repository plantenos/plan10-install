#!@BINDIR@/bash
# 
# This file is part of Plan10. It is subject to the license terms in
# the LICENSE file found in the top-level directory of this
# distribution.
# This file may not be copied, modified, propagated, or distributed
# except according to the terms contained in the LICENSE file.

## 		Define hostname

define_hostname(){
	
	local _hostname
	
	dg_action _hostname input "Define Hostname" "\nEnter the hostname" "${HOSTNAME}"
	if (( $? ));then
		return 0
	fi
		
	sed -i "s,HOSTNAME=.*$,HOSTNAME=\"$_hostname\",g" "${CONFIG}"
	
	unset _hostname
}

##		Define locale

define_locale(){
	
	local loc list
	
	list=$(grep -s "#[a-z]" ${NEWROOT}/etc/locale.gen|sed 's:#::g')
	DG_ITEMS_OPTS=""
	dg_action loc menu "Define Locale" "\nDefine your main locale" ${list[@]}
	if (( $? )); then
		DG_ITEMS_OPTS="--no-items"
		return 0
	fi
	DG_ITEMS_OPTS="--no-items"
	if [[ -z "${loc}" ]]; then
		dg_info "Define Locale" "\nLocale is not set, pick en_US.UTF-8 by default"
		loc="en_US.UTF-8"
	fi
	dg_yesno "Define Locale" "Do you want to generate other locale?"
	if (( ! $? )); then
		sed -i "s:^#${loc}:${loc}:g" "${NEWROOT}"/etc/locale.gen
		dg_info "Define Locale" "\nDefine your locale by uncomment the desired lines"
		tput cnorm
		"$EDITOR" "${NEWROOT}"/etc/locale.gen
	fi
	
	sed -i "s,LOCALE=.*$,LOCALE=\"$loc\",g" "${CONFIG}"

	unset list loc 
}

##		Define localtime

define_localtime(){
	
	local list where zone subzone
	
	list=$(awk '/\// { print $3 }' ${NEWROOT}/${LOCALTIME}/zone.tab|sort)
	
	dg_action where menu "Define Localtime" "\nSelect your country/department"	${list[@]}	
	if (( $? )); then
		return 0
	fi
	zone="${where%%/*}"
	subzone="${where#*/}"
	
	sed -i "s,^ZONE=.*$,ZONE=\"$zone\"," "${CONFIG}"
	sed -i "s,^SUBZONE=.*$,SUBZONE=\"$subzone\"," "${CONFIG}"
	
	unset zone subzone list
}

##		Define keymap

define_keymap(){
	
	local _keymap
	
	local key_list="$(find /usr/share/kbd/keymaps -name '*.map.gz' | awk '{gsub(/\.map\.gz|.*\//, ""); print $1 }' | sort)"

	dg_action _keymap menu "Keyboard layout" "\nChoose the keymap to use on console environment\n" $key_list

	if (( $? )); then
		return 0
	fi
	
	sed -i "s,^KEYMAP=.*$,KEYMAP=\"$_keymap\"," "${CONFIG}"
	
	unset _keymap key_list
}

##		Define xkeymap

define_xkeymap(){
	
	local xkeymap 
	declare -a list=(
af Afghani		al Albanian		am Armenian		ara Arabic		at German 
au English		az Azerbaijani	ba Bosnian		bd Bangla		be Belgian 
'bg' Bulgarian	br Portuguese	bt Dzongkha		bw Tswana		by Belarusian 
ca French		'cd' French		ch German		cm English		cn Chinese 
cz Czech		de German		dk Danish		dz Berber		ee Estonian 
epo Esperanto	es Spanish		et Amharic		'fi' Finnish	fo Faroese 
fr French		gb English		ge Georgian		gh English		gn French
gr Greek		hr Croatian		hu Hungarian	id Indonesian	ie Irish 
il Hebrew		'in' Indian		iq Iraqi		ir Persian		is Icelandic 
it Italian		jp Japanese		ke Swahili		kg Kyrgyz		kh Khmer 
kr Korean		kz Kazakh		la Lao			latam Spanish	lk Sinhala 
lt Lithuanian	lv Latvian		ma Arabic		mao Maori		md Moldavian 
me Montenegrin	mk Macedonian	ml Bambara		mm Burmese		mn Mongolian
mt Maltese		'mv' Dhivehi	my Malay		ng English		nl Dutch 
no Norwegian	np Nepali		ph Filipino		pk Urdu			pl Polish 
pt Portuguese	ro Romanian		rs Serbian		ru Russian		se Swedish 
si Slovenian	sk Slovak		sn Wolof		sy Arabic		tg French 
th Thai			tj Tajik		tm Turkmen		tr Turkish		tw Taiwanese 
tz Swahili		ua Ukrainian	us English		uz Uzbek		vn Vietnamese 
za English)
 
	DG_ITEMS_OPTS=""
	dg_action xkeymap menu "Keyboard layout" "\nChoose the keymap to use on X environment" ${list[@]}
	if (( $? )); then
		DG_ITEMS_OPTS="--no-items"
		return 0
	fi
	DG_ITEMS_OPTS="--no-items"
	
	sed -i "s,XKEYMAP=.*$,XKEYMAP=\"$xkeymap\"," "${CONFIG}"
	
	unset xkeymap
}

##		Define a new user

define_user(){
	
	local _newuser f fail
	local -a user_exist
	
	while : ;do
		fail=0
		dg_action _newuser input "Define User" "\nEnter the user name" "${NEWUSER}"
		if (( $? ));then
			return 0
		fi
		user_exist=$(grep "$_newuser" ${NEWROOT}/etc/passwd | awk -F":" '{print $1}')
	
		for f in ${user_exist[@]}; do
			if [[ $f == $_newuser ]]; then			
				dg_info "Define User" "$_newuser already exit, please enter an another name"
				continue
			fi
		done
	
		# firt pass, _newuser can not be :
		#	empty  
		#	higher than 16 character 
		#   beginning by other character than lowercase or underscore
		if [[ "${#_newuser}" -eq 0 ]] || [[ "${#_newuser}" -eq 17 ]] || ! [[ "${_newuser}" =~ ^[a-z]|^[_] ]]; then
			dg_info "Define User" "Invalid user name $_newuser, please retry"
			continue
		else
			# second pass, invalid other choice than lowercase, underscore,dash, digit
			# except for the last character
			for ((c=0; c<${#_newuser}; c++));do
				if [[ $((c+1)) == "${#_newuser}" ]]; then
					# useradd accepted $ as last character, so allow it
					if [[ "${_newuser:$c:1}" != @([a-z]|[_]|[-]|[0-9]|$) ]];then
						dg_info "Define User" "Invalid user name $_newuser, please retry"
						fail=1
						break
					fi
				elif [[ "${_newuser:$c:1}" != @([a-z]|[_]|[-]|[0-9]) ]];then
					dg_info "Define User" "Invalid user name $_newuser, please retry"
					fail=1
					break
				fi 
			done
			if (( "${fail}" )); then
				continue
			fi
		fi
		break
	done
	sed -i "s,NEWUSER=.*$,NEWUSER=\"$_newuser\",g" "${CONFIG}"
	
	unset _newuser user_exist f fail
}

##		Define root user

define_root(){
	
	local pass_exist
	local force="${1}"
	pass_exist=$(grep "root" $NEWROOT/etc/shadow | awk -F':' '{print $2}')
	
	if [[ ! $(grep "root::" $NEWROOT/etc/shadow) ]]; then
		out_action "Create root user on $NEWROOT"
		usermod -R "$NEWROOT" -s /usr/bin/zsh root
	fi
	
	mkdir -p -m 0700 "$NEWROOT/root"
	
	if [[ -z "${pass_exist}" || (( "${force}" )) ]]; then
		config_password "root" || die "unable to set the root password" "clean_install"
	fi
			
	unset pass_exist force
}
