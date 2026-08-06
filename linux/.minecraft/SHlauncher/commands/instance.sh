# shellcheck disable=SC2154
# shellcheck disable=SC2059

function list() {
	if [ "$(ls)" == "" ]; then
		printf "${YELLOW}No Instances were set up (yet!)${RESET}\n"
	else
		for Finst in *.json; do
			IFS='|' read -r name version modloader gameDir java MinRam MaxRam modloaderVersion <<< "$(jq -r '"\(.name)|\(.version)|\(.modloader)|\(.gameDir)|\(.java)|\(.MinRam)|\(.MaxRam)|\(.modloaderVersion)"' "$Finst")"
			mapfile -t additionnalJvmArgs < <(jq -r '.additionnalJvmArgs[]' "$Finst")
			mapfile -t customGameArgs < <(jq -r '.customGameArgs[]' "$Finst")

			printf "${BLUE}%s :${RESET}\n" "$name"
			echo " - Version: $version" 
			echo " - Modloader: $modloader $modloaderVersion"
			echo " - Game directory: $gameDir"
			echo " - Java: $java"
			echo " - Minimal ammount of RAM (-Xms): $MinRam"
			echo " - Maximal ammount of RAM (-Xmx): $MaxRam"
			echo " - Additionnal JVM arguments : " "${additionnalJvmArgs[@]}"
			echo " - Additionnal game arguments : " "${customGameArgs[@]}"
		done
	fi
}

function SetColor() {
	if [ "${Sett[SelectedInstance]}" == "None" ]; then \
		DispInst="${RL_START}${RED}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
	else
		DispInst="${RL_START}${GREEN}${RL_END}${Sett[SelectedInstance]}${RL_START}${RESET}${RL_END}"
	fi
}


function hp() {
	true
}

function create() {
	name=$1
	modloader=$2
	version=$3
	modloaderVersion=$4

	# shellcheck disable=SC2194
	case "" in
		"$name" | "$modloader" | "$version")
		printf "${RED_BOLD}One or more argument were forgotten, this command require at least a name, a modloader (can be vanilla), and a minecraft version${RESET}\n"
		return 1
	esac

	if [[ -f "./$name.json" ]]; then
		printf "${RED_BOLD}The target instance already exist${RESET}\n"
		return 1
	fi

	if [ "$name" == "None" ]; then
		printf "${RED_BOLD}The name of this instance can't be \"None\", please use another name${RESET}\n"
		return 1
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
			if [ "$modloaderVersion" == "" ]; then
				printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
			fi
		;;
		"quilt" | "Quilt")
			modloader="quilt"
			if [ "$modloaderVersion" == "" ]; then
				printf "${RED_BOLD}The modloader version is mandatory for this modloader, please specify a modloader version and retry${RESET}\n"
			fi
		;;
		*)
			printf "${RED_BOLD}Uknown modloader \"%s\", supported modloaders are Vanilla, Forge, NeoForge, Fabric and Quilt${RESET}\n" "$modloader"
			return 1
	esac

	echo "creating instance $name with modloader $modloader and version $version $modloaderVersion"
	if [ "$modloader" == "vanilla" ]; then
		versionProfile="$version"
	else
		versionProfile="$modloader-$fullModLoaderVers"
	fi

	if ${parameter[anotherGameDir]}; then
		# shellcheck disable=SC2154 # il l'est
		gameDir="$MCdir/instances/$name/"
		mkdir -p "$gameDir"
	elif [[ -n "${parameter[anotherGameDir]}" ]]; then
		gameDir="${parameter[anotherGameDir]}"
	else
		# shellcheck disable=SC2154
		gameDir="$MCdir/"
	fi
	
	jq -n \
		--arg name "$name" \
		--arg modloader "$modloader" \
		--arg version "$version" \
		--arg modloaderVersion "$modloaderVersion" \
		--arg gameDir "$gameDir" \
		--arg assetsDir "$MCdir/assets" \
		--arg java "default" \
		--arg MinRam "2G" \
		--arg MaxRam "4G" \
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
			"additionnalJvmArgs": [],
			"customGameArgs": []
		}' \
		> "$name".json
}

function sel() {
	name=$1
	if ! [[ -f "$name.json" ]]; then echo "The selected Instance \"$name\" does not exist"; return 1; fi
	writeSettingsValue SelectedInstance "$name"
	SetColor
}

function delete() {
	name=$1
	if ! [[ -f "$name".json ]]; then echo "The selected Instance \"$name\" does not exist"; return 1; fi
	command -p rm -- "$name.json"
	if [ "${Sett[SelectedInstance]}" == "$name" ]; then
		writeSettingsValue SelectedInstance None
	fi
	SetColor
}

function reset() {
	writeSettingsValue SelectedInstance None
	SetColor
}

function Main() {
	case $1 in
		"create")
			shift 
			create "$@"
		;;
		"remove" | "delete")
			shift
			delete "$@"
		;;
		"list")
			list
		;;
		"reset")
			reset
		;;
		"sel" | "select" | "switch")
			shift
			sel "$@"
		;;
		"")
			printf "${YELLOW}No argument given, assuming \"list\"${RESET}\n"
			list
		;;
		*)
			printf "${RED_BOLD}Uknown argument : %s${RESET}\n" "$1"
	esac
}

mkdir -p "$SHdir/instances"
mkdir -p "$MCdir/instances"
cd "$SHdir/instances" || return 1

parameter[customGameDir]=""
parameter[anotherGameDir]=false

declareArgs customGameDir c value
declareArgs anotherGameDir a flag

if ! globalArgHandler "$@"; then
	return 1
fi

if [[ -n ${parameter[customGameDir]} ]]; then
	parameter[anotherGameDir]=false
fi

# shellcheck disable=SC2154
Main "${instructions[@]}"

unset parameter
declare -gA parameter