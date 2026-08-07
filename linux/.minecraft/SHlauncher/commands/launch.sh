# shellcheck disable=SC2154
# shellcheck disable=SC2016 # non bro, c'est prévu
cd "$MCdir" || return
touch .lastLaunchedGame

substitute_arg() {
	local arg="$1"

	if [ "$arg" == "" ]; then
		printf "${YELLOW_BOLD}[BUG] function substituteArg require 1 entry argument, but none were ever passed${RESET}\n" >&2
		return 1
	fi
	arg=$(trimCr "$arg")

	arg="${arg//'${natives_directory}'/$nativesDir}"
	arg="${arg//'${library_directory}'/"./libraries"}"
	arg="${arg//'${classpath_separator}'/":"}" # à remplacer sur linux par un ":"
	arg="${arg//'${version_name}'/"${modloader}-${fullModLoaderVers}"}" # en gros c'est <ModlName>-<Modlvers>

	arg="${arg//'${launcher_name}'/$SHlname}"
	arg="${arg//'${launcher_version}'/$SHlvers}"
	arg="${arg//'${classpath}'/$classpath}"
	arg="${arg//'${path}'/$log4jconf}"
	arg="${arg//'${mainClass}'/$mainClass}"

	arg="${arg//'${auth_player_name}'/$launchProf}"
	arg="${arg//'${version_name}'/$version}"
	arg="${arg//'${game_directory}'/$gameDir}"
	arg="${arg//'${assets_root}'/$assetsDir}"
	arg="${arg//'${game_assets}'/$assetsDir}"
	arg="${arg//'${assets_index_name}'/$assetIndex}"
	arg="${arg//'${auth_uuid}'/$tuuid}"
	arg="${arg//'${auth_access_token}'/0}"
	arg="${arg//'${clientid}'/0}"
	arg="${arg//'${auth_xuid}'/0}"
	arg="${arg//'${user_type}'/msa}"
	arg="${arg//'${version_type}'/$versionType}"

	printf '%s\n' "$arg"
}

function launch() {
	launchProf=$1
	launchInst=$2
	# shellcheck disable=SC2194 # comparaison inversé 
	case "" in
		"$launchProf" | "$launchInst")
			printf "${YELLOW_BOLD}[BUG] Function launch require 2 arguments but some are missing\n" >&2
			printf "launchProf: %s\n" "$launchProf" >&2
			printf "launchInst: %s${RESET}\n" "$launchInst" >&2
	esac
	printf "${BLUE_BOLD}Building command...${RESET}\n"
	
	jsonInstance=$(jq -r '.versionProfile' "$SHdir/instances/$launchInst.json")

	modloader=$(jq -r '.modloader' "$SHdir/versions/$jsonInstance.json")
	if [ "$modloader" == "" ]; then modloader="vanilla"; fi

	if [ "$modloader" == "vanilla" ]; then
		IFS='|' read -r version versionType runtime assetIndex mainClass nativesDir log4jconf classpath < \
			<(jq -r '"\(.name)|\(.versionType)|\(.runtime)|\(.assetIndexId)|\(.mainClass)|\(.nativesDir)|\(.log4jconf)|\(.classpath)"' "$SHdir/versions/$jsonInstance.json")
		mapfile -t gameArgs < <(jq -r '.gameArgs[]' "$SHdir/versions/$jsonInstance.json")
		mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$jsonInstance.json")

		IFS='|' read -r gameDir assetsDir java MinRam MaxRam < \
			<(jq -r '"\(.gameDir)|\(.assetsDir)|\(.java)|\(.MinRam)|\(.MaxRam)"' "$SHdir/instances/$launchInst.json")
		mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$SHdir/instances/$launchInst.json")
		mapfile -t additionalJvmArgs < <(jq -r '.additionalJvmArgs[]' "$SHdir/instances/$launchInst.json")
	elif [ "$modloader" == "neoforge" ]; then
		IFS='|' read -r version inheritance versionType mainClass classpath < \
			<(jq -r '"\(.name)|\(.inheritsFrom)|\(.versionType)|\(.mainClass)|\(.moddedCp)"' "$SHdir/versions/$jsonInstance.json")
		mapfile -t moddedGameArgs < <(jq -r '.moddedGameArgs[]' "$SHdir/versions/$jsonInstance.json")
		mapfile -t moddedJvmArgs < <(jq -r '.moddedJvmArgs[]' "$SHdir/versions/$jsonInstance.json")

		IFS='|' read -r runtime assetIndex assetRoot nativesDir log4jconf < \
			<(jq -r '"\(.runtime)|\(.assetIndexId)|\(.assetRoot)|\(.nativesDir)|\(.log4jconf)"' "./SHlauncher/versions/$inheritance.json")
		mapfile -t gameArgs < <(jq -r '.gameArgs[]' "$SHdir/versions/$inheritance.json")
		mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$inheritance.json")

		IFS='|' read -r gameDir assetsDir java MinRam MaxRam < \
			<(jq -r '"\(.gameDir)|\(.assetsDir)|\(.java)|\(.MinRam)|\(.MaxRam)"' "$SHdir/instances/$launchInst.json")
		mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$SHdir/instances/$launchInst.json")
		mapfile -t additionalJvmArgs < <(jq -r '.additionalJvmArgs[]' "$SHdir/instances/$launchInst.json")
	fi

	for Fprof in ./SHlauncher/profiles/*.json; do
		if [ "$(jq -r '.name' "$Fprof")" == "$launchProf" ]; then
			tuuid=$(jq -r '.tuuid' "$Fprof")
		fi
	done
	if [ "$java" == "default" ]; then
		java="$SHdir/java/$runtime/bin/java"
	fi

	MinRam=$(trimCr "$MinRam")
	MaxRam=$(trimCr "$MaxRam")
	jvmArgs+=("${additionalJvmArgs[@]}")
	if [ "$modloader" != "vanilla" ]; then jvmArgs+=("${moddedJvmArgs[@]}"); fi
	finalJvmArgs=("-Xms$MinRam" "-Xmx$MaxRam" "-Xdiag")
	for arg in "${jvmArgs[@]}"; do
		finalJvmArgs+=("$(substitute_arg "$arg")")
	done

	finalGameArgs=()
	if [ "$modloader" != "vanilla" ]; then gameArgs+=("${moddedGameArgs[@]}"); fi
	for arg in "${gameArgs[@]}"; do
		finalGameArgs+=("$(substitute_arg "$arg")")
	done
	finalGameArgs+=("${customGameArgs[@]}")
	
	printf "${BLUE_BOLD}Finished building command, launching game...${RESET}\n"
	if ! "$java" -version &>/dev/null; then
		printf "${YELLOW}The required java version is not installed, please install java $runtime using \"java install $runtime\"${RESET}\n"
		return 1
	fi

	# IT'S BOOTING (WE ARE BO-BO-BO-BOOOOTIIIIIIIIIIIING)

	if echo "${finalJvmArgs[@]}" | grep -q "$mainClass"; then
		echo "${java}" "${finalJvmArgs[@]}" "${finalGameArgs[@]}" > .lastLaunchedGame
		"${java}" "${finalJvmArgs[@]}" "${finalGameArgs[@]}"
	else
		echo "${java}" "${finalJvmArgs[@]}" "$mainClass" "${finalGameArgs[@]}" > .lastLaunchedGame
		"${java}" "${finalJvmArgs[@]}" "$mainClass" "${finalGameArgs[@]}" 
	fi
	exitCode=$?

	unset -v modloader

	if [ "$exitCode" -ne 0 ]; then
		echo ""
		printf "${RED_BOLD}The game crashed or did not returned successfully (exit code %s)! Check the crash-report or the log file for more info${RESET}\n" "$exitCode"
		return 1
	else
		printf "${GREEN_BOLD}Game returned without issues (exit code 0)${RESET}\n"
	fi
}

function helpPage() {
	printf "${CYAN}Usage${RESET} : launch [-p/-i]\n"
	printf "launches the game using the provided instance and profile, require both to be set\n"
	printf "${CYAN}Argument list${RESET} :\n"
	printf " - help : display this help"
	printf " - \"-p\" | \"--profile\" : specify a custom profile to override the selected one\n"
	printf " - \"-i\" | \"--instance\" : specify a custom instance to override the selected one\n"
}

function argHandler() {
	case $1 in
		"-p" | "--profile")
			usrn=$2
			isDone=false
			if [ "$usrn" == "" ]; then printf "${RED_BOLD}\"-p\" require the username of a created profile${RESET}\n"; return 1; fi
			for Fprof in "$dir"/.minecraft/SHlauncher/profiles/*.json; do
				if [ "$usrn" == "$(jq -r '.name' "$Fprof")" ]; then
					launchProf=$usrn
					customLaunchProf=true
					isDone=true
				fi
			done
			if ! $isDone; then printf "${RED_BOLD}The entered profile \"$usrn\" does not exist${RESET}\n"; return 1; fi
			shift 2
			argHandler "$@"
		;;
		"-i" | "--instance")
			inst=$2
			if [ "$inst" == "" ]; then printf "${RED_BOLD}\"-i\" require the name of a created instance${RESET}\n"; return 1; fi
			if ! [[ -f "./SHlauncher/instances/$inst.json" ]]; then printf "${RED_BOLD}The entered instance does not exist${RESET}\n"; return 1; fi
			launchInst=$inst
			customLaunchInst=true
			shift 2
			argHandler "$@"
		;;
		"help")
			helpPage
		;;
		"")
			if ! $customLaunchProf; then launchProf=$(jq -r '.name' "$SHdir/profiles/${Sett[SelectedProfile]}.json"); fi
			if ! $customLaunchInst; then launchInst=${Sett[SelectedInstance]}; fi
			if [ "${Sett[SelectedProfile]}" == "None" ] || [ "${Sett[SelectedInstance]}" == "None" ]; then
				printf "${RED_BOLD}The profile or the instance is missing, cannot launch${RESET}\n"
				printf "${RED}Entered profile : %s\n" "$launchProf"
				printf "Entered instance : %s${RESET}\n" "$launchInst"
				return 1
			fi
			launch "$launchProf" "$launchInst"
		;;
		*)
			echo "Unknown argument : $1"
	esac
}

customLaunchProf=false
customLaunchInst=false

argHandler "$@"