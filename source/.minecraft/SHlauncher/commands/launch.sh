# shellcheck disable=SC2154
# launch.sh is too chaotic. So I renovated it

cd "$MCdir" || return 255
touch .lastLaunchedGame


function substituteArg() {
	# this function is the reason launching takes 10s on windows
	local arg="$1"
	local oldArg=$arg
	if [ "$arg" == "" ]; then
		printf "${YELLOW_BOLD}[BUG] function substituteArg require 1 entry argument, but none were ever passed${RESET}\n" >&2
		log "ERROR" "launch.sh:substituteArg" "BUG : Some argument are missing. Expected argument: arg \"$arg\""
		return 1
	fi

	log "DEBUG" "launch.sh:substituteArg" "Resolving \"$oldArg\""

	arg="${arg//'${natives_directory}'/$nativesDir}"
	arg="${arg//'${library_directory}'/"$MCdir/libraries"}"
	arg="${arg//'${root_directory}'/"$MCdir"}" # .minecraft (does not exist natively)
	arg="${arg//'${classpath_separator}'/"$cmdSeparator"}"
	[ "$modloader" != "vanilla" ] && arg="${arg//'${version_name}'/"${modloader}-${fullModLoaderVers}"}"

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

	log "DEBUG" "launch.sh:substituteArg" "Resolved \"$oldArg\" into \"$arg\""
	printf '%s\n' "$arg"
}

function clientArgumentParser() {
	# this function treats the variables to be able to launch the game
	jvmArgs+=("${additionalJvmArgs[@]}")
	if [ "$modloader" != "vanilla" ]; then jvmArgs+=("${moddedJvmArgs[@]}"); fi
	finalJvmArgs=("-Xms$MinRam" "-Xmx$MaxRam")
	for arg in "${jvmArgs[@]}"; do
		finalJvmArgs+=("$(substituteArg "$arg")")
	done
	log "DEBUG" "launch.sh:launch" "finalJVMArgs : ${finalJvmArgs[*]}"

	finalGameArgs=()
	if [ "$modloader" != "vanilla" ]; then gameArgs+=("${moddedGameArgs[@]}"); fi

  	for arg in "${gameArgs[@]}"; do
		finalGameArgs+=("$(substituteArg "$arg")")
	done

	finalGameArgs+=("${customGameArgs[@]}")
	log "DEBUG" "launch.sh:launch" "finalGameArgs : ${finalGameArgs[*]}"
}

function checkJava() {
	if [ "$java" == "default" ]; then
		java="$SHdir/java/$runtime/bin/java"
	fi

	if ! exceptionCatch "launch.sh:prepareLaunch" "$java" -version &>/dev/null; then
		printf "${YELLOW}The required java version is not installed, please install java $runtime using \"java install $runtime\"${RESET}\n"
		log "ERROR" "launch.sh:launch" "Failed to launch the game, required java version \"$runtime\" is not or incorrectly installed"
		return 1
	fi
}


function launchClientVanilla() {
	IFS='|' read -r version versionType runtime assetIndex mainClass nativesDir log4jconf classpath < \
		<(jq -r '"\(.name)|\(.versionType)|\(.runtime)|\(.assetIndexId)|\(.mainClass)|\(.nativesDir)|\(.log4jconf)|\(.classpath)"' "$SHdir/versions/$versionProfile.json")
	mapfile -t gameArgs < <(jq -r '.gameArgs[]' "$SHdir/versions/$versionProfile.json")
	mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$versionProfile.json")

	checkJava || return
	clientArgumentParser
}

function launchClientNeoforge() {
	IFS='|' read -r side version inheritance versionType mainClass classpath < \
		<(jq -r '"\(.side)|\(.name)|\(.inheritsFrom)|\(.versionType)|\(.mainClass)|\(.moddedCp)"' "$SHdir/versions/$versionProfile.json")
	mapfile -t moddedGameArgs < <(jq -r '.moddedGameArgs[]' "$SHdir/versions/$versionProfile.json")
	mapfile -t moddedJvmArgs < <(jq -r '.moddedJvmArgs[]' "$SHdir/versions/$versionProfile.json")

	# after getting the inheritance, we can get the others info which are vanilla only
	IFS='|' read -r runtime assetIndex assetRoot nativesDir log4jconf < \
		<(jq -r '"\(.runtime)|\(.assetIndexId)|\(.assetRoot)|\(.nativesDir)|\(.log4jconf)"' "$SHdir/versions/$inheritance.json")
	mapfile -t gameArgs < <(jq -r '.gameArgs[]' "$SHdir/versions/$inheritance.json")
	mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$inheritance.json")

	checkJava || return
	clientArgumentParser
}

function launchClientFabric() {
	IFS='|' read -r side version inheritance versionType mainClass classpath < \
		<(jq -r '"\(.side)|\(.name)|\(.inheritsFrom)|\(.versionType)|\(.mainClass)|\(.moddedCp)"' "$SHdir/versions/$versionProfile.json")
	mapfile -t moddedGameArgs < <(jq -r '.moddedGameArgs[]' "$SHdir/versions/$versionProfile.json")
	mapfile -t moddedJvmArgs < <(jq -r '.moddedJvmArgs[]' "$SHdir/versions/$versionProfile.json")
	
	# same there
	IFS='|' read -r runtime assetIndex assetRoot nativesDir log4jconf < \
		<(jq -r '"\(.runtime)|\(.assetIndexId)|\(.assetRoot)|\(.nativesDir)|\(.log4jconf)"' "$SHdir/versions/$inheritance.json")
	mapfile -t gameArgs < <(jq -r '.gameArgs[]' "$SHdir/versions/$inheritance.json")
	mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$inheritance.json")

	checkJava || return
	clientArgumentParser
}


function launchServerVanilla() {
	IFS='|' read -r runtime < \
		<(jq -r '"\(.runtime)"' "$SHdir/versions/$versionProfile-server.json")
	gameArgs=() # useless so empty (arg can still be specified with instances)
	mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$versionProfile-server.json")

	checkJava || return

	jvmArgs+=("${additionalJvmArgs[@]}")
	finalJvmArgs=("-Xms$MinRam" "-Xmx$MaxRam")
	for arg in "${jvmArgs[@]}"; do
		finalJvmArgs+=("$(substituteArg "$arg")")
	done

	finalGameArgs=()
	for arg in "${gameArgs[@]}"; do
		finalGameArgs+=("$(substituteArg "$arg")")
	done

	finalGameArgs+=("${customGameArgs[@]}")

	if ${Sett[NoguiOnServer]}; then
		[[ "${finalGameArgs[*]}" =~ "--nogui" ]] || finalGameArgs+=("--nogui") # precise --nogui if it's not already there
	fi

	log "DEBUG" "launch.sh:launch" "finalJVMArgs : ${finalJvmArgs[*]}"
	log "DEBUG" "launch.sh:launch" "finalGameArgs : ${finalGameArgs[*]}"
}

function launchServerNeoforge() {
	IFS='|' read -r runtime < \
		<(jq -r '"\(.runtime)"' "$SHdir/versions/$versionProfile-server.json")
	gameArgs=()
	mapfile -t launchArgs < <(jq -r '.launchArgs[]' "$SHdir/versions/$versionProfile-server.json")

	checkJava || return

	finalLaunchArgs=("-Xms$MinRam" "-Xmx$MaxRam")
	finalLaunchArgs+=("${additionalJvmArgs[@]}")
	for arg in "${launchArgs[@]}"; do
		finalLaunchArgs+=("$(substituteArg "$arg")")
	done
	finalLaunchArgs+=("${customGameArgs[@]}")
	if ${Sett[NoguiOnServer]}; then
		[[ "${finalLaunchArgs[*]}" =~ "--nogui" ]] || finalLaunchArgs+=("--nogui")
	fi
	log "DEBUG" "launch.sh:launch" "finalLaunchArgs : ${finalLaunchArgs[*]}"
}

function launchServerFabric() {
	finalJvmArgs=("-Xms$MinRam" "-Xmx$MaxRam")
	finalJvmArgs+=("${additionalJvmArgs[@]}")

	IFS='|' read -r classpath inheritance mainClass < \
		<(jq -r '"\(.moddedCp)|\(.inheritsFrom)|\(.mainClass)"' "$SHdir/versions/$versionProfile-server.json")
	mapfile -t moddedGameArgs < <(jq -r '.moddedGameArgs[]' "$SHdir/versions/$versionProfile-server.json")
	mapfile -t moddedJvmArgs < <(jq -r '.moddedJvmArgs[]' "$SHdir/versions/$versionProfile-server.json")
	
	IFS='|' read -r runtime < \
		<(jq -r '"\(.runtime)"' "$SHdir/versions/$inheritance.json")
	checkJava || return

	finalJvmArgs+=("-cp" "$(substituteArg "${classpath}")")

	for arg in "${moddedJvmArgs[@]}"; do
		finalJvmArgs+=("$(substituteArg "$arg")")
	done

	if ${Sett[NoguiOnServer]}; then
		[[ "${finalGameArgs[*]}" =~ "--nogui" ]] || finalGameArgs+=("--nogui")
	fi

	finalGameArgs+=("${moddedGameArgs[@]}")

	log "DEBUG" "launch.sh:launch" "finalJvmArgs : ${finalJvmArgs[*]}"
	log "DEBUG" "launch.sh:launch" "finalGameArgs : ${finalGameArgs[*]}"
}


function prepareLaunch() {
	launchProf=$1
	launchInst=$2
	if ! $customLaunchProf; then launchProf=$(jq -r '.name' "$SHdir/profiles/${Sett[SelectedProfile]}.json" 2>/dev/null \
		|| { log "ERROR" "launch.sh" "Failed to get profile linked to \"${Sett[SelectedProfile]}\""; echo "None"; }); fi # "echo" so, even if the initial command fails, we get something

	if [ -z "$launchInst" ]; then
		printf "${YELLOW_BOLD}[BUG] Function launch require 2 arguments but some are missing! Check the log file for more info\n" >&2
		log "ERROR" "launch.sh:launch" "BUG : Some argument are missing. Expected argument: launchProf \"$launchProf\", launchInst \"$launchInst\""
		return 2
	fi
	log "INFO" "launch.sh:launch" "Preparing game launch with profile \"$launchProf\" and instance \"$launchInst\""
	printf "${BLUE_BOLD}Building command...${RESET}\n"

	# getting some vars ready (the version profile, modloader and side)
	versionProfile=$(jq -r '.versionProfile' "$SHdir/instances/$launchInst.json") # old name : versionProfile

	modloader=$(jq -r '.modloader' "$SHdir/instances/$launchInst.json")
	side=$(jq -r '.side' "$SHdir/instances/$launchInst.json") # checking side in the instance, risky!

	if [ "$modloader" == "" ] || [ "$modloader" == null ]; then modloader="vanilla"; fi
	if [ "$side" == "" ] || [ "$side" == null ]; then side="client"; fi
	
	if [ "$side" = "client" ] && [ "$launchProf" == "None" ]; then
		log "ERROR" "launch.sh:launch" "Cannot launch, no profile were specified."
		printf "${RED_BOLD}Cannot launch the game. The profile is missing (create it with \"profile create <usrn>\")${RESET}\n"
		return 2
	fi

	case "$side" in
		"client")
			# get info from instance
			IFS='|' read -r gameDir assetsDir java MinRam MaxRam < \
				<(jq -r '"\(.gameDir)|\(.assetsDir)|\(.java)|\(.MinRam)|\(.MaxRam)"' "$SHdir/instances/$launchInst.json")
			mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$SHdir/instances/$launchInst.json")
			mapfile -t additionalJvmArgs < <(jq -r '.additionalJvmArgs[]' "$SHdir/instances/$launchInst.json")
			
			for Fprof in ./SHlauncher/profiles/*.json; do
				if [ "$(jq -r '.name' "$Fprof")" == "$launchProf" ]; then
					tuuid=$(jq -r '.tuuid' "$Fprof") # get the tuuid
					log "DEBUG" "launch.sh:launch" "profile's truncated UUID is \"$tuuid\""
				fi
			done

			case "$modloader" in
				"vanilla")
					launchClientVanilla "$launchProf" "$launchInst"
				;;
				"neoforge")
					launchClientNeoforge "$launchProf" "$launchInst"
				;;
				"fabric")
					launchClientFabric "$launchProf" "$launchInst"
				;;
				*)
					log "ERROR" "launch.sh:prepareLaunch" "Unrecognized modloader \"$modloader\", cannot continue launch"
					printf "${RED_BOLD}The modloader \"%s\" is unknown or unsupported by SHlauncher, cannot continue${RESET}\n" "$modloader"
					printf "${RED}If you modified the instance, consider reverting your changes${RESET}\n"
					return 2
			esac

			printf "${BLUE_BOLD}Finished building command, launching game...${RESET}\n"
			log "INFO" "launch.sh:launch" "All check completed, launching game!"

			if echo "${finalJvmArgs[@]}" | grep -q "$mainClass"; then # check if the JVM args already have a main class (for old minecraft version)
				# if yes, don't specify it
				echo "${java}" "${finalJvmArgs[@]}" "${finalGameArgs[@]}" > "$MCdir/.lastLaunchedGame"
				"${java}" "${finalJvmArgs[@]}" "${finalGameArgs[@]}"
			else
				echo "${java}" "${finalJvmArgs[@]}" "$mainClass" "${finalGameArgs[@]}" > "$MCdir/.lastLaunchedGame"
				"${java}" "${finalJvmArgs[@]}" "$mainClass" "${finalGameArgs[@]}" 
			fi
			exitCode=$?
		;;
		"server")
			# same here, but slightly different instructions
			IFS='|' read -r gameDir java MinRam MaxRam < \
				<(jq -r '"\(.gameDir)|\(.java)|\(.MinRam)|\(.MaxRam)"' "$SHdir/instances/$launchInst.json")
			mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$SHdir/instances/$launchInst.json")
			mapfile -t additionalJvmArgs < <(jq -r '.additionalJvmArgs[]' "$SHdir/instances/$launchInst.json")
			
			if ! cat "$MCdir/eula.txt" | grep -q "eula=true"; then # check eula before the modloader (bc it's hard after)
				printf "${CYAN}To launch this server, you need to agree to Mojang's EULA (https://aka.ms/MinecraftEULA)${RESET}\n"
				read -rp "Do you agree to the minecraft EULA ? (y/n)>" yn
					if [ "$yn" = "y" ] || [ "$yn" = "yes" ]; then
					echo "To revoke your agreement, set the eula value to false (located in .minecraft/eula.txt)"
					printf "# By changing this setting to true, you are agreeing to Mojang's End User License Agreement (https://aka.ms/MinecraftEULA)\neula=true" > "$MCdir/eula.txt"
					sleep 2
				else
					echo "aborting launch"
					return
				fi
			fi

			cd "$gameDir" || return 255 # I don't like using cd but here we kinda don't have the choice
			# Minecraft servers uses the working directory to read server.properties. So we need change it

			case "$modloader" in
				"vanilla")
					launchServerVanilla "$launchProf" "$launchInst"
					
					printf "${BLUE_BOLD}Finished building command, launching server...${RESET}\n"
					echo "${java}" "${finalJvmArgs[@]}" -jar "$MCdir/versions/$versionProfile/$versionProfile-server.jar" "${finalGameArgs[@]}" > "$MCdir/.lastLaunchedGame"
					"${java}" "${finalJvmArgs[@]}" -jar "$MCdir/versions/$versionProfile/$versionProfile-server.jar" "${finalGameArgs[@]}"
					exitCode=$?
				;;
				"neoforge")
					launchServerNeoforge "$launchProf" "$launchInst"

					printf "${BLUE_BOLD}Finished building command, launching server...${RESET}\n"
					echo "${java}" "${finalLaunchArgs[@]}" > "$MCdir/.lastLaunchedGame"
					"${java}" @<(printf -- "%s\n" "${finalLaunchArgs[@]}") # Yes, that actually works
					exitCode=$?
				;;
				"fabric")
					launchServerFabric "$launchProf" "$launchInst"

					printf "${BLUE_BOLD}Finished building command, launching server...${RESET}\n"
					echo "${java}" "${finalJvmArgs[@]}" "${mainClass}" "${gameArgs[@]}" > "$MCdir/.lastLaunchedGame"
					"${java}" "${finalJvmArgs[@]}" "${mainClass}" "${gameArgs[@]}"
					exitCode=$?
				;;
				*)
					log "ERROR" "launch.sh:prepareLaunch" "Unrecognized modloader \"$modloader\", cannot continue launch"
					printf "${RED_BOLD}The modloader \"%s\" is unknown or unsupported by SHlauncher, cannot continue${RESET}\n" "$modloader"
					printf "${RED}If you modified the instance, consider reverting your changes${RESET}\n"
					return 2
			esac
		;;
		*)
			log "ERROR" "launch.sh:prepareLaunch" "Unrecognized side \"$side\", cannot continue launch"
			printf "${RED_BOLD}The side \"%s\" is unknown by SHlauncher, cannot continue${RESET}\n" "$side"
			printf "${RED}If you modified the instance, consider reverting your changes${RESET}\n"
			return 2
	esac

	log "INFO" "launch.sh:launch" "Game returned with exit code $exitCode"
	if [ "${exitCode:=256}" -ne 0 ]; then
		echo ""
		printf "${RED_BOLD}The game crashed or did not returned successfully (exit code %s)! Check the crash-report or the minecraft log file for more info${RESET}\n" "$exitCode"
		return "$exitCode"
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
			if [ "$usrn" == "" ]; then printf "${RED_BOLD}\"-p\" require the username of a created profile${RESET}\n"; return 2; fi
			for Fprof in "$SHdir"/profiles/*.json; do
				if [ "$usrn" == "$(jq -r '.name' "$Fprof")" ]; then
					launchProf=$usrn
					customLaunchProf=true
					isDone=true
				fi
			done
			if ! $isDone; then printf "${RED_BOLD}The entered profile \"$usrn\" does not exist${RESET}\n"; return 2; fi
			shift 2
			argHandler "$@"
		;;
		"-i" | "--instance")
			inst=$2
			if [ "$inst" == "" ]; then printf "${RED_BOLD}\"-i\" require the name of a created instance${RESET}\n"; return 2; fi
			if ! [[ -f "./SHlauncher/instances/$inst.json" ]]; then printf "${RED_BOLD}The entered instance does not exist${RESET}\n"; return 2; fi
			launchInst=$inst
			customLaunchInst=true
			shift 2
			argHandler "$@"
		;;
		"help")
			helpPage
		;;
		"")
			if ! $customLaunchInst; then launchInst=${Sett[SelectedInstance]}; fi
			if [ "$launchInst" == "None" ]; then
				printf "${RED_BOLD}The profile or the instance is missing, cannot launch${RESET}\n"
				printf "Entered instance : %s${RESET}\n" "$launchInst"
				log "ERROR" "launch.sh" "Failed to launch the game : some required parameters are missing"
				return 2
			fi
			prepareLaunch "$launchProf" "$launchInst"
		;;
		*)
			echo "Unknown argument : $1"
			return 2
	esac
}

customLaunchProf=false
customLaunchInst=false

log "INFO" "launch.sh" "launch.sh called with instructions ${instructions[*]}"
argHandler "$@"