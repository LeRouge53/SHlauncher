# shellcheck disable=SC2154

function list() {
	if [ "$(ls "$SHdir/instances")" == "" ]; then # give me a better solution..
		printf "${YELLOW}No Instances were set up (yet!)${RESET}\n"
	else
		for Finst in "$SHdir"/instances/*.json; do
			log "DEBUG" "settings.sh:list" "Checking instance \"${Finst}\""
			# jq mess to get every displayed info
			IFS='|' read -r side name version modloader gameDir java MinRam MaxRam modloaderVersion <<< \
				"$(jq -r '"\(.side)|\(.name)|\(.version)|\(.modloader)|\(.gameDir)|\(.java)|\(.MinRam)|\(.MaxRam)|\(.modloaderVersion)"' "$Finst")"
			mapfile -t additionalJvmArgs < <(jq -r '.additionalJvmArgs[]' "$Finst")
			mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$Finst")

			printf "${BLUE}%s :${RESET}\n" "$name"
			echo " - Version (version): $version"
			echo " - Side (side): $side"
			echo " - Modloader (modloader - modloaderVersion): $modloader $modloaderVersion"
			echo " - Game directory (gameDir): $gameDir"
			echo " - Java (java): $java"
			echo " - Minimal amount of RAM (MinRam): $MinRam"
			echo " - Maximal amount of RAM (MaxRam): $MaxRam"
			echo " - Additional JVM arguments (additionalJvmArgs): \"${additionalJvmArgs[*]}\""
			echo " - Additional game arguments (customGameArgs): \"${customGameArgs[*]}\""
		done
	fi
}

function SetColor() {
	# basically the same thing as around the line 20 of core.sh
	if [ "${Sett[SelectedInstance]}" == "None" ]; then \
		DispInst="${RL_START}${RED}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
	else
		DispInst="${RL_START}${GREEN}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
	fi
}

function create() {
	name=$1
	modloader=$2
	version=$3
	modloaderVersion=$4

	case "" in # check if any var is empty
		"$name" | "$modloader" | "$version")
		printf "${RED_BOLD}One or more argument were forgotten, this command require at least a name, a modloader (can be vanilla), and a minecraft version${RESET}\n"
		return 2
	esac

	if [[ -f "$SHdir/instances/$name.json" ]]; then # check if the instance already exist
		printf "${RED_BOLD}The target instance already exist${RESET}\n"
		return 1
	fi

	if [ "$name" == "None" ]; then
		printf "${RED_BOLD}The name of this instance can't be \"None\", please use another name${RESET}\n"
		return 2
	fi

	case $modloader in
		"vanilla" | "Vanilla")
			modloader="vanilla"
		;;
		"forge" | "Forge")
			modloader="forge"
			if [ "$modloaderVersion" == "" ]; then
				printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
			fi
		;;
		"neoforge" | "Neoforge" | "NeoForge" | "neoForge")
			modloader="neoforge"
			if [ "$modloaderVersion" == "" ]; then
				printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
			fi
			if ! [[ "$modloaderVersion" =~ \. ]]; then
				# shellcheck disable=SC2001 # nah
				trunkMcVers=$(echo "$version" | sed 's/^1\.//')
				fullModLoaderVers="${trunkMcVers}.${modloaderVersion}"
			else
				fullModLoaderVers=$modloaderVersion
			fi
		;;
		"fabric" | "Fabric")
			modloader="fabric"
			if [ -z "$modloaderVersion" ]; then
				printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
			fi
			fullModLoaderVers="$version-$modloaderVersion"
		;;
		"quilt" | "Quilt")
			modloader="quilt"
			if [ "$modloaderVersion" == "" ]; then
				printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
			fi
		;;
		*)
			printf "${RED_BOLD}Unknown modloader \"%s\", supported modloaders are Vanilla, Forge, NeoForge, Fabric and Quilt${RESET}\n" "$modloader"
			return 2
	esac

	log "INFO" "instance.sh:create" "Requested creation of instance \"$name\" with modloader \"$modloader\" and version $version $modloaderVersion"
	echo "creating instance $name with modloader $modloader and version $version $modloaderVersion"
	if ! ${parameter[server]}; then
		if [ "$modloader" == "vanilla" ]; then
			versionProfile="$version"
		else
			versionProfile="$modloader-$fullModLoaderVers"
		fi
	else
		if [ "$modloader" == "vanilla" ]; then
			versionProfile="$version"
		else
			versionProfile="$modloader-$fullModLoaderVers"
		fi
	fi
	log "DEBUG" "instance.sh:create" "Resolved versionProfile to \"$versionProfile\""

	if ${parameter[anotherGameDir]}; then
		gameDir="$MCdir/instances/$name/" # creates a directory based on the instance name
		mkdir -p "$gameDir"
	elif [[ -n "${parameter[customGameDir]}" ]]; then
		mkdir -p "${parameter[customGameDir]}"
		gameDir="${parameter[customGameDir]}" # creates a directory based on user input
	else
		gameDir="$MCdir" # if none are specified, just use .minecraft
	fi
	if ${parameter[server]}; then
		printf "# By changing this setting to true, you are agreeing to Mojang's End User License Agreement (https://aka.ms/MinecraftEULA)\neula=false" > "$MCdir/eula.txt"
		if [ "$gameDir" != "$MCdir" ]; then
			if exceptionCatch "instance.sh:create" ln "$MCdir/eula.txt" "$gameDir/eula.txt"; then
				printf "${YELLOW}Failed to create the symlink between the main eula.txt and the secondary in the instance folder${RESET}\n"
				printf "${YELLOW}This may not be an issue (if the directory was not empty before creation). But it can lead to some problems when launching the server${RESET}\n"
			fi
		fi
	fi
	
	if ! ${parameter[server]}; then
		jq -n \
			--arg name "$name" \
			--arg modloader "$modloader" \
			--arg version "$version" \
			--arg modloaderVersion "$modloaderVersion" \
			--arg gameDir "$gameDir" \
			--arg assetsDir "$MCdir/assets" \
			--arg java "default" \
			--arg MinRam "${Sett[DefaultMinimumRam]}" \
			--arg MaxRam "${Sett[DefaultMaximumRam]}" \
			--arg versionProfile "$versionProfile" \
			'{
				"name": $name,
				"modloader": $modloader,
				"version": $version,
				"modloaderVersion": $modloaderVersion,
				"versionProfile": $versionProfile,
				"gameDir": $gameDir,
				"assetsDir": $assetsDir,
				"java": $java,
				"MinRam": $MinRam,
				"MaxRam": $MaxRam,
				"side": "client",
				"additionalJvmArgs": [],
				"customGameArgs": []
			}' \
			> "$SHdir/instances/$name.json"
	else
		jq -n \
			--arg name "$name" \
			--arg modloader "$modloader" \
			--arg version "$version" \
			--arg modloaderVersion "$modloaderVersion" \
			--arg gameDir "$gameDir" \
			--arg java "default" \
			--arg MinRam "${Sett[DefaultMinimumRam]}" \
			--arg MaxRam "${Sett[DefaultMaximumRam]}" \
			--arg versionProfile "$versionProfile" \
			'{
				"name": $name,
				"modloader": $modloader,
				"version": $version,
				"modloaderVersion": $modloaderVersion,
				"versionProfile": $versionProfile,
				"gameDir": $gameDir,
				"java": $java,
				"MinRam": $MinRam,
				"MaxRam": $MaxRam,
				"side": "server",
				"additionalJvmArgs": [],
				"customGameArgs": []
			}' \
			> "$SHdir/instances/$name.json"
	fi
}

function sel() {
	# check if the specified instance name is valid. If yes, write the setting key
	name=$1
	[ -z "$name" ] && name=${parameter[useInstance]}
	if ! [[ -f "$SHdir/instances/$name.json" ]]; then
		printf "${RED_BOLD}The specified instance \"$name\" does not exist${RESET}\n"
		return 2
	fi
	log "INFO" "instance.sh:sel" "New instance is \"$name\""
	writeSettingsValue SelectedInstance "$name"
	SetColor
}

function delete() {
	name=$1
	[ -z "$name" ] && name=${parameter[useInstance]}
	if ! [[ -f "$SHdir/instances/$name".json ]]; then
		printf "${RED_BOLD}The specified Instance \"$name\" does not exist${RESET}\n"
		return 2
	fi
	log "WARN" "instance.sh:delete" "Deleting instance $name"
	command -p rm -- "$SHdir/instances/$name.json"
	if [ "${Sett[SelectedInstance]}" == "$name" ]; then
		writeSettingsValue SelectedInstance None
	fi
	SetColor
}

function reset() {
	log "INFO" "instance.sh:reset" "New instance is \"None\""
	writeSettingsValue SelectedInstance None
	SetColor
}

function helpPage() {
	printf "${CYAN}Usage${RESET} : instance [-cua] <instruction> [<args...>]\n"
	printf "Manages the instances of the launcher\n"
	printf "${CYAN}Argument list${RESET} :\n"
	printf " - create [-ca] <instance name> <modloader name> <vanilla version> [modloader version] : Creates an instance\n"
	printf " - modify <-u> <parameter> <new value> : modifies an instance, uses the selected instance if none are specified\n"
	printf " - remove [-u] OR <instance name> : Deletes an instance\n"
	printf " - list : Lists every created instances alongside their parameter (display name and key). the key is used to modify the value with \"instance modify\"\n"
	printf " - select [-u] OR <instance name> : Select an instance to use\n"
	printf " - reset : Deselect the current instance (switching it to None)\n"
	printf " - help : Prints this help\n"
	printf " - \"-c\" | \"--customGameDir\" : (incompatible with -a) Sets the games directory to the specified one\n"
	printf " - \"-a\" | \"--anotherGameDir\" : (incompatible with -c) Sets the games directory to a generated one\n"
	printf " - \"-u\" | \"--useInstance\" : specifies the instance that will be tampered"
	printf " - \"-S\" | \"--server\" : manage server instead of clients"
}

function modify() {
	local targetInstance=${Sett[SelectedInstance]}
	local setting=$1
	local newValue=$2
	[ "$targetInstance" = "None" ] && targetInstance=${parameter[useInstance]} # if it's empty, it will trow an error later, confusing but it works

	# check if what the user entered is actually valid
	if [ -z "$setting" ]; then
		printf "${RED_BOLD}No key were specified! (use instance help)${RESET}\n"
		log "ERROR" "instance.sh:modify" "Could not modify the specified instance, no key was specified"
		return 2
	elif [ -z "$targetInstance" ]; then
		printf "${RED_BOLD}No instances were specified or selected! (type instance help)${RESET}\n"
		log "ERROR" "instance.sh:modify" "Could not modify the specified instance, no instance was specified or selected"
		return 2
	elif ! [ -f "$SHdir/instances/$targetInstance.json" ]; then
		printf "${RED_BOLD}The specified instance doesn't exist${RESET}\n"
		log "ERROR" "instance.sh:modify" "Could not modify the specified instance, the said instance doesn't exist"
		return 2
	elif [ "$(jq -r ".$setting" "$SHdir/instances/$targetInstance.json")" = "null" ]; then
		printf "${RED_BOLD}The specified key doesn't exist in this instance${RESET}\n"
		log "ERROR" "instance.sh:modify" "Could not modify the specified instance, the key doesn't exist in this instance"
		return 2
	elif [ "$setting" = "versionProfile" ]; then
		printf "${YELLOW_BOLD}The specified key is generated using the modloader, the game version and the modloader version, please avoid tampering it and modify \"version\", \"modloader\" and \"modloaderVersion\" instead${RESET}\n"
		log "ERROR" "instance.sh:modify" "Could not modify the specified instance, bad argument (modify the json yourself if you want to)"
		return 1
	fi

	# if yes, apply the changes
	local tempFile
	tempFile=$(mktemp)
	jq -r ".$setting |= \"$newValue\"" "$SHdir/instances/$targetInstance.json" > "$tempFile"
	mv "$tempFile" "$SHdir/instances/$targetInstance.json"

	# if the key concerns the modloader or any versions, notify the user and apply other changes
	case $setting in
		"modloader" | "version" | "modloaderVersion")
			${Sett[ShowUncheckedVersionWarn]} && { 
				printf "${YELLOW}Please note that SHlauncher does not check if the newly assigned version is installed or if it is even valid. Pay attention${RESET}\n"
				printf "${WHITE_BOLD}This message won't show up again${RESET}\n"
				writeSettingsValue ShowUncheckedVersionWarn false
			}
			local version
			version=$(jq -r '.version' "$SHdir/instances/$targetInstance.json")
			local modloader
			modloader=$(jq -r '.modloader' "$SHdir/instances/$targetInstance.json")
			local modloaderVersion
			modloaderVersion=$(jq -r '.modloaderVersion' "$SHdir/instances/$targetInstance.json")

			case "$modloader" in
				"forge")
					true # forge's unsupported so nop
				;;
				"neoforge")
					# shellcheck disable=SC2001
					fullModLoaderVers="$(echo "$version" | sed 's/^1\.//').${modloaderVersion}"
				;;
				"fabric")
					fullModLoaderVers="$version-$modloaderVersion"
				;;
				"quilt")
					true # same treatment
			esac

			if [ "$modloader" == "vanilla" ]; then
				versionProfile="$version"
			else
				versionProfile="$modloader-$fullModLoaderVers"
			fi

			tempFile=$(mktemp)
			jq -r ".versionProfile |= \"$versionProfile\"" "$SHdir/instances/$targetInstance.json" > "$tempFile"
			mv "$tempFile" "$SHdir/instances/$targetInstance.json"
		;;
		*)
			true
	esac
}
ExitCode=0
function argHandler() {
	case $1 in
		"create")
			shift 
			create "$@"
			ExitCode=$?
		;;
		"remove" | "delete")
			shift
			delete "$@"
			ExitCode=$?
		;;
		"list")
			list
			ExitCode=$?
		;;
		"reset")
			reset
			ExitCode=$?
		;;
		"sel" | "select" | "switch")
			shift
			sel "$@"
			ExitCode=$?
		;;
		"modify")
			shift
			modify "$@"
			ExitCode=$?
		;;
		"help")
			helpPage
		;;
		"")
			printf "${YELLOW}No argument given, assuming \"list\"${RESET}\n"
			list
			ExitCode=$?
		;;
		*)
			printf "${RED_BOLD}Unknown argument : %s${RESET}\n" "$1"
			return 2
	esac
}

mkdir -p "$SHdir/instances"
mkdir -p "$MCdir/instances"

parameter[customGameDir]=""
parameter[anotherGameDir]=false
parameter[useInstance]=""
parameter[server]=false

declareArgs customGameDir c value
declareArgs anotherGameDir a flag
declareArgs useInstance u value
declareArgs server S flag

if ! globalArgHandler "$@"; then
	return $?
fi

if [[ -n ${parameter[customGameDir]} ]]; then
	parameter[anotherGameDir]=false
fi

log "INFO" "settings.sh" "instance.sh called with instructions ${instructions[*]}"

# shellcheck disable=SC2154
argHandler "${instructions[@]}"

unset parameter
declare -gA parameter

return "$ExitCode"