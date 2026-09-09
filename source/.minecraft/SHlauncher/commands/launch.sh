# shellcheck disable=SC2154
# shellcheck disable=SC2016
cd "$MCdir" || return 255
touch .lastLaunchedGame

substituteArg() {
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
	arg="${arg//'${library_directory}'/"libraries"}"
	arg="${arg//'${classpath_separator}'/"$cmdSeparator"}"
	arg="${arg//'${version_name}'/"${modloader}-${fullModLoaderVers}"}"

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

function launch() {
	launchProf=$1
	launchInst=$2
	case "" in
		"$launchProf" | "$launchInst")
			printf "${YELLOW_BOLD}[BUG] Function launch require 2 arguments but some are missing! Check the log file for more info\n" >&2
			log "ERROR" "launch.sh:launch" "BUG : Some argument are missing. Expected argument: launchProf \"$launchProf\", launchInst \"$launchInst\""
			return 2
		;;
		*)
			true
	esac
	log "INFO" "launch.sh:launch" "Launching game with profile \"$launchProf\" and instance \"$launchInst\""
	printf "${BLUE_BOLD}Building command...${RESET}\n"
	
	jsonInstance=$(jq -r '.versionProfile' "$SHdir/instances/$launchInst.json")
	side=$(jq -r '.side' "$SHdir/instances/$launchInst.json") # checking side in the instance, risky!
  
  if [ "$side" == "" ] || [ "$side" == null ]; then side="client"; fi
  
	# get a lot of info from json files
  if [ "$side" = "client" ]; then
    modloader=$(jq -r '.modloader' "$SHdir/versions/$jsonInstance.json")
	  if [ "$modloader" == "" ] || [ "$modloader" == null ]; then modloader="vanilla"; fi
  
	  if [ "$modloader" == "vanilla" ]; then
		  IFS='|' read -r version versionType runtime assetIndex mainClass nativesDir log4jconf classpath < \
			  <(jq -r '"\(.name)|\(.versionType)|\(.runtime)|\(.assetIndexId)|\(.mainClass)|\(.nativesDir)|\(.log4jconf)|\(.classpath)"' "$SHdir/versions/$jsonInstance.json")
		  mapfile -t gameArgs < <(jq -r '.gameArgs[]' "$SHdir/versions/$jsonInstance.json")
		  mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$jsonInstance.json")
	
	  elif [ "$modloader" == "neoforge" ]; then
		  IFS='|' read -r side version inheritance versionType mainClass classpath < \
			  <(jq -r '"\(.side)|\(.name)|\(.inheritsFrom)|\(.versionType)|\(.mainClass)|\(.moddedCp)"' "$SHdir/versions/$jsonInstance.json")
		  mapfile -t moddedGameArgs < <(jq -r '.moddedGameArgs[]' "$SHdir/versions/$jsonInstance.json")
		  mapfile -t moddedJvmArgs < <(jq -r '.moddedJvmArgs[]' "$SHdir/versions/$jsonInstance.json")

		  IFS='|' read -r runtime assetIndex assetRoot nativesDir log4jconf < \
			  <(jq -r '"\(.runtime)|\(.assetIndexId)|\(.assetRoot)|\(.nativesDir)|\(.log4jconf)"' "$SHdir/versions/$inheritance.json")
		  mapfile -t gameArgs < <(jq -r '.gameArgs[]' "$SHdir/versions/$inheritance.json")
		  mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$inheritance.json")
	
	  elif [ "$modloader" == "fabric" ]; then
		  IFS='|' read -r side version inheritance versionType mainClass classpath < \
			  <(jq -r '"\(.side)|\(.name)|\(.inheritsFrom)|\(.versionType)|\(.mainClass)|\(.moddedCp)"' "$SHdir/versions/$jsonInstance.json")
		  mapfile -t moddedGameArgs < <(jq -r '.moddedGameArgs[]' "$SHdir/versions/$jsonInstance.json")
		  mapfile -t moddedJvmArgs < <(jq -r '.moddedJvmArgs[]' "$SHdir/versions/$jsonInstance.json")
	
		  IFS='|' read -r runtime assetIndex assetRoot nativesDir log4jconf < \
			  <(jq -r '"\(.runtime)|\(.assetIndexId)|\(.assetRoot)|\(.nativesDir)|\(.log4jconf)"' "$SHdir/versions/$inheritance.json")
		  mapfile -t gameArgs < <(jq -r '.gameArgs[]' "$SHdir/versions/$inheritance.json")
		  mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$inheritance.json")
	  fi

	  IFS='|' read -r gameDir assetsDir java MinRam MaxRam < \
		  <(jq -r '"\(.gameDir)|\(.assetsDir)|\(.java)|\(.MinRam)|\(.MaxRam)"' "$SHdir/instances/$launchInst.json")
	  mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$SHdir/instances/$launchInst.json")
	  mapfile -t additionalJvmArgs < <(jq -r '.additionalJvmArgs[]' "$SHdir/instances/$launchInst.json")

	  for Fprof in ./SHlauncher/profiles/*.json; do
		  if [ "$(jq -r '.name' "$Fprof")" == "$launchProf" ]; then
			  tuuid=$(jq -r '.tuuid' "$Fprof")
			  log "DEBUG" "launch.sh:launch" "profile's truncated UUID is \"$tuuid\""
		  fi
	  done
  elif [ "$side" = "server" ]; then
      IFS='|' read -r runtime < \
			  <(jq -r '"\(.runtime)"' "$SHdir/versions/$jsonInstance-server.json")
		  gameArgs=() # useless so empty (arg can still be specified with instances)
		  mapfile -t jvmArgs < <(jq -r '.jvmArgs[]' "$SHdir/versions/$jsonInstance-server.json")
  
      IFS='|' read -r gameDir java MinRam MaxRam < \
		    <(jq -r '"\(.gameDir)|\(.java)|\(.MinRam)|\(.MaxRam)"' "$SHdir/instances/$launchInst.json")
	    mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$SHdir/instances/$launchInst.json")
	    mapfile -t additionalJvmArgs < <(jq -r '.additionalJvmArgs[]' "$SHdir/instances/$launchInst.json")
  fi
  
	log "DEBUG" "launch.sh:launch" "resolved side to $side"

	if [ "$java" == "default" ]; then
		java="$SHdir/java/$runtime/bin/java"
	fi # else you don't touch it as it supposed to be a direct path to the java exec

	# building arguments
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
	
	if ! exceptionCatch "launch.sh:launch" "$java" -version &>/dev/null; then
		printf "${YELLOW}The required java version is not installed, please install java $runtime using \"java install $runtime\"${RESET}\n"
		log "ERROR" "launch.sh:launch" "Failed to launch the game, required java version \"$runtime\" is not installed"
		return 1
	fi

	printf "${BLUE_BOLD}Finished building command, launching game...${RESET}\n"
	log "INFO" "launch.sh:launch" "All check completed, launching game!"
	if [ "$side" = "client" ]; then
		if echo "${finalJvmArgs[@]}" | grep -q "$mainClass"; then # check if the JVM args already have a main class (for old minecraft version)
			# if yes, don't specify it
			echo "${java}" "${finalJvmArgs[@]}" "${finalGameArgs[@]}" > .lastLaunchedGame
			"${java}" "${finalJvmArgs[@]}" "${finalGameArgs[@]}"
		else
			echo "${java}" "${finalJvmArgs[@]}" "$mainClass" "${finalGameArgs[@]}" > .lastLaunchedGame
			"${java}" "${finalJvmArgs[@]}" "$mainClass" "${finalGameArgs[@]}" 
		fi
		exitCode=$?
	else
		cd "$gameDir" || return 255 # I hate using cd but here we kinda don't have the choice
		# Minecraft servers uses the working directory to read server.properties. So we need change it

    # checking for eula
    if ! cat "$MCdir/eula.txt" | grep -q "eula=true"; then
      printf "${CYAN}To launch this server, you need to agree to Mojang's EULA (https://aka.ms/MinecraftEULA)${RESET}\n"
      read -rp "Do you agree to the minecraft EULA ? (y/n)>" yn
      if [ "$yn" = "y" ]; then
        echo "To revoke your agreement, set the eula value to false (located in .minecraft/eula.txt)"
        printf "# By changing this setting to true, you are agreeing to Mojang's End User License Agreement (https://aka.ms/MinecraftEULA)\neula=true" > "$MCdir/eula.txt"
      else
        echo "aborting launch"
        return
      fi
    fi
    
    echo "${java}" "${finalJvmArgs[@]}" -jar "$MCdir/versions/$jsonInstance/$jsonInstance-server.jar" "${finalGameArgs[@]}" > .lastLaunchedGame
		"${java}" "${finalJvmArgs[@]}" -jar "$MCdir/versions/$jsonInstance/$jsonInstance-server.jar" "${finalGameArgs[@]}"
		exitCode=$?
	fi

	unset -v modloader

	log "INFO" "launch.sh:launch" "Game returned with exit code $exitCode"
	if [ "$exitCode" -ne 0 ]; then
		echo ""
		printf "${RED_BOLD}The game crashed or did not returned successfully (exit code %s)! Check the crash-report or the log file for more info${RESET}\n" "$exitCode"
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
			for Fprof in "$dir"/.minecraft/SHlauncher/profiles/*.json; do
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
			if ! $customLaunchProf; then launchProf=$(jq -r '.name' "$SHdir/profiles/${Sett[SelectedProfile]}.json" 2>/dev/null \
				|| { log "ERROR" "launch.sh" "Failed to get profile linked to \"${Sett[SelectedProfile]}\""; echo "None"; }); fi # "echo" so, even if the initial command fails, we get something
			
			if ! $customLaunchInst; then launchInst=${Sett[SelectedInstance]}; fi
			if [ "$launchProf" == "None" ] || [ "$launchInst" == "None" ]; then
				printf "${RED_BOLD}The profile or the instance is missing, cannot launch${RESET}\n"
				printf "${RED}Entered profile : %s\n" "$launchProf"
				printf "Entered instance : %s${RESET}\n" "$launchInst"
				log "ERROR" "launch.sh" "Failed to launch the game : some required parameters are missing"
				return 2
			fi
			launch "$launchProf" "$launchInst"
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