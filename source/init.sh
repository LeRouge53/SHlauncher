#!/usr/bin/env bash
set -o pipefail
dir=$(dirname -- "$(readlink "$0")") # POSIX compliant dir discovery

# Check if the script can run in that environment
if echo "$SHELLOPTS" | grep -q posix; then
	# shellcheck source=.minecraft/SHlauncher/crashHandler.sh
	source "$dir/.minecraft/SHlauncher/crashHandler.sh" POSIX
elif [ -n "$ZSH_VERSION" ]; then
	# shellcheck source=.minecraft/SHlauncher/crashHandler.sh
	source "$dir/.minecraft/SHlauncher/crashHandler.sh" ZSH
fi

bashSource="${BASH_SOURCE[0]}"
while [ -h "$bashSource" ]; do
	dirname="$( cd -P "$( dirname "$bashSource" )" >/dev/null 2>&1 && pwd )"
	bashSource="$(readlink "$bashSource")"
	[[ $bashSource != /* ]] && bashSource="$dirname/$bashSource"
done
dir="$( cd -P "$( dirname "$bashSource" )" >/dev/null 2>&1 && pwd )"

export dir
export MCdir="$dir/.minecraft"
export SHdir="$MCdir/SHlauncher"
export SHlogFile="$SHdir/SHlog.log"

function libFail() {
	#shellcheck source=.minecraft/SHlauncher/crashHandler.sh
	source "$SHdir/crashHandler.sh" "LIB_LOAD_FAIL"
}

# shellcheck source=.minecraft/SHlauncher/crashHandler.sh
trap 'echo ""; source "$SHdir/crashHandler.sh" SIGINT' INT # ctrl+c catch

# load libs (kinda useful)
set -e # I don't want anything bad to happen here

#shellcheck source=.minecraft/SHlauncher/libs/logging.sh
source "$SHdir/libs/logging.sh" || libFail 

declare -gA Sett
#shellcheck source=.minecraft/SHlauncher/libs/settingSys.sh
if ! source "$SHdir/libs/settingSys.sh"; then
	log "FATAL" "init.sh" "Failed to load settingSys.sh, crash imminent"
	libFail
fi

#shellcheck source=.minecraft/SHlauncher/libs/mavenParser.sh
if ! source "$SHdir/libs/mavenParser.sh"; then
	log "FATAL" "init.sh" "Failed to load mavenParser.sh, crash imminent"
	libFail
fi

declare -A parameter
declare -A declaredLongParam
declare -A declaredShortParam
#shellcheck source=.minecraft/SHlauncher/libs/argSys.sh
if ! source "$SHdir/libs/argSys.sh"; then
	log "FATAL" "init.sh" "Failed to load argSys.sh, crash imminent"
	libFail
fi

set +e

debug=false # some default values before treating the arguments
verbose=false
trace=false
portable=false
cip=true
onlineMode=true

SHlname="SHlauncherBE"
SHlvers="0.5.0" # edit version here

IFSBak=$' \t\n'

while true; do
	# argHandler
	case $1 in
		"-v" | "--version")
			echo "$SHlname, version $SHlvers" >&2
			exit
		;;
		"-p" | "--portable")
			portable=true # use embedded jq if the user provided the binary
			shift
		;;
		"-V" | "--verbose")
			verbose=true # display logs on the screen
			shift
		;;
		"--debug")
			debug=true # allow debug log lines to be written (does not come with verbose mode)
			shift
		;;
		"--trace")
			trace=true # set -x
			shift
		;;
		"--nocip")
			# shellcheck disable=SC2034
			cip=false # allow to write special characters like " $ ( ) ` "
			shift
		;;
		"--SHlname")
			export SHlname="$2" # custom launcher name, used to display and as JVM arg
			shift 2
		;;
		"--SHlvers")
			export SHlvers="$2" # custom launcher version, also used when launching game
			shift 2
		;;
		"--no-internet")
			onlineMode=false
			log "WARN" "init.sh:argHandler" "Assuming no internet"
			shift
		;;
		"--clear-manifest")
			command -p rm -r "$SHdir/manifests/" 2>/dev/null # removes every manifest
			log "INFO" "init.sh:argHandler" "Manifest cleared with errcode $?"
			shift
		;;
		-*)
			printf "Unknown parameter %s\n" "$1"
			exit 2
		;;
		"")
			break
		;;
		*)
			log "INFO" "init.sh:argHandler" "Found command \"$*\" that will be executed later" # the rest is passed to core.sh
			break
	esac
done

if $trace; then
	printf "As you wish...\n"
	PS4='${BLUE_BOLD}+ [TRACE]${RESET} '
	set -x
fi

command -p rm "$SHlogFile" &>/dev/null
log "DEBUG" "init.sh" "Core directory resolved to $dir"

case "$OSTYPE" in
	msys*|cygwin*|win32*)  osName="windows"; cmdSeparator=';' ;;
	darwin*)               osName="osx"; cmdSeparator=':' ;;
	linux*)                osName="linux"; cmdSeparator=':' ;;
	*)                     osName="unknown"; cmdSeparator=':' ;; # had to put something under cmdSeparator, so it's ":"
esac

# shellcheck disable=SC2015
if $onlineMode; then
	if [ "$osName" = "windows" ]; then
		/c/Windows/System32/ping.exe -n 1 -w 3000 google.com &>/dev/null # msys2 doesn't have ping, so I need to use the windows one
		pingExitCode=$?
	elif [ "$osName" != "unknown" ]; then
		ping -c 1 -W 3 google.com &>/dev/null
		pingExitCode=$?
	else
  		log "WARN" "init.sh" "Unknown operating system, ping feature may not work" # a lot of things may not work
  		ping -c 1 -W 3 google.com &>/dev/null
 		pingExitCode=$?
	fi
else
	log "INFO" "init.sh" "skipping internet check as specified"
	pingExitCode=0
fi

if [ "$pingExitCode" != 0 ] && [ "$pingExitCode"  != 127 ]; then
	log "ERROR" "init.sh" "No internet detected, many features might not work properly"
	printf "[ERROR] This launcher requires an Internet connection for almost everything, an offline mode exist but is very limited.\n"
	printf "[ERROR] Restart or reset the launcher to switch back to Online mode\n"
	onlineMode=false
elif [ "$pingExitCode" = 127 ]; then
	log "WARN" "init.sh" "Can't ping, \"ping\" command not found" # keep online mode anyway
fi

export onlineMode

log "INFO" "init.sh" "Resolved operating system to $osName"

log "INFO" "init.sh" "Starting $SHlname, version $SHlvers, debug mode: $debug, verbose mode: $verbose, cip: $cip, portable mode: $portable"

# starting to check dependencies (jq, unzip and curl)
export MissingDependencies=()

mkdir -p "$SHdir/jq"
if $portable; then
	if exceptionCatch "init.sh" "$SHdir/jq/jq" --version; then
		# shellcheck disable=SC2123
		PATH="$PATH${cmdSeparator}$SHdir/jq" 
		log "INFO" "init.sh" "Engaged portable mode"
	else
		# continues normally if jq is not provided
		printf "${RED_BOLD}No JQ binary detected at %s. Please download the portable version from \"https://jqlang.org/download/\" (or any other sources) and install it there${RESET}\n" "$SHdir/jq"
		log "ERROR" "init.sh" "No JQ binary provided, ignoring portable mode"
	fi
fi
# Checking dependencies
if ! jq --version &>/dev/null; then
	log "FATAL" "init.sh" "JQ was not found in the PATH, crash imminent"
	MissingDependencies+=("jq")
fi
if ! unzip --help &>/dev/null; then
	log "FATAL" "init.sh" "Unzip was not found in the PATH, crash imminent"
	MissingDependencies+=("unzip")
fi
if ! curl --version &>/dev/null; then
	log "FATAL" "init.sh" "curl was not found in the PATH, crash imminent"
	MissingDependencies+=("curl")
fi

# shellcheck source=.minecraft/SHlauncher/dependencyInst.sh
source "$SHdir/dependencyInst.sh"

# shellcheck source=.minecraft/SHlauncher/commands/settings.sh
source "$SHdir/commands/settings.sh" "init" # loads settings, create missing keys, etc...

force_color=false
# check https://no-color.org/ and https://force-color.org/
if [ -n "$FORCE_COLOR" ]; then
	color=true
	force_color=true # force the use of the 24bit color system regardless of settings ; has priority over NO_COLOR
	log INFO "init.sh" "FORCE_COLOR recognized"
elif [ -n "$NO_COLOR" ]; then
	color=false # does not load any colors regardless of settings
	log INFO "init.sh" "NO_COLOR recognized"
else 
	color=true
fi
# shellcheck source=.minecraft/SHlauncher/colorHandler.sh
source "$SHdir/colorHandler.sh" # loads colors

mkdir -p "$SHdir"
# shellcheck source=.minecraft/SHlauncher/crashHandler.sh
cd "$SHdir" || source "$SHdir/crashHandler.sh" "CD_FAIL"

$cip || printf "${RED_BOLD}Command injection protection is disabled, DO NOT execute commands that could lead to arbitrary code execution\n"

printf "${GREEN_BOLD}SHlauncher started${RESET}\n"

log "INFO" "init.sh" "SHlauncher initialization finished, creating directories"

mkdir -p "$MCdir/assets/indexes"
mkdir -p "$MCdir/assets/objects"
mkdir -p "$MCdir/libraries"
mkdir -p "$MCdir/instances"
mkdir -p "$MCdir/versions"

mkdir -p "$SHdir/versions"
mkdir -p "$SHdir/profiles"
mkdir -p "$SHdir/instances"
mkdir -p "$SHdir/manifests/fabric"

echo "Downloading manifests"
log "DEBUG" "init.sh" "Downloading manifests..."
# manifest stuff
if $onlineMode; then
	if curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq '.' > manifests/temp_manifest.json; then
		cat manifests/temp_manifest.json > manifests/vanilla_version_manifest.json
	else
		log "WARN" "init.sh" "Vanilla manifest download failed, invalid JSON file"
		printf "${YELLOW_BOLD}[WARN]${RESET}${YELLOW} The newly downloaded vanilla manifest seem invalid, the old one will be used instead${RESET}\n"
	fi

	if curl -so manifests/temp_manifest.xml https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml; then
		readarray -t NeoVersions < <(grep -oP '(?<=<version>).*?(?=</version>)' manifests/temp_manifest.xml)
		# shellcheck disable=SC2207
		IFS=$'\n' NeoVersions=($( sort <<<"${NeoVersions[*]}")); IFS=$IFSBak # I cried at my computer for 40 minutes trying to understand why my splitting was so weird. All because a temporary variable modification wasn't that temporary (I hate myself)
		printf '%s\n' "${NeoVersions[@]}" | jq -Rs 'split("\n")[:-1]' \
			> manifests/neoforge_version_manifest.json
	else
		log "WARN" "init.sh" "Neoforge manifest download failed, invalid JSON file"
		printf "${YELLOW_BOLD}[WARN]${RESET}${YELLOW} The newly downloaded Neoforge manifest seem invalid, the old one will be used instead${RESET}\n"
		
	fi

	if curl -s "https://meta.fabricmc.net/v2/versions/game" | jq '.' > manifests/temp_manifest.json; then
		cat manifests/temp_manifest.json > manifests/fabric/fabric_game_manifest.json
	else
		log "WARN" "init.sh" "fabric game manifest download failed, invalid JSON file"
		printf "${YELLOW_BOLD}[WARN]${RESET}${YELLOW} The newly downloaded Fabric game manifest seem invalid, the old one will be used instead${RESET}\n"
	fi
else
	printf "${YELLOW_BOLD}[WARN]${YELLOW} Unable to reload some manifest file, old one will be used instead${RESET}\n"
fi
if [ ! -f manifests/vanilla_version_manifest.json ] || [ ! -s manifests/vanilla_version_manifest.json ]; then
	log "ERROR" "init.sh" "Vanilla version manifest is corrupted or empty"
	printf "${RED_BOLD}[ERROR]${RESET}${RED} Invalid version manifest : file is missing or empty. You will not be able to download or repair any Vanilla game instances. Restart the launcher to reload the manifest${RESET}\n"
fi

if [ ! -f manifests/neoforge_version_manifest.json ] || [ ! -s manifests/neoforge_version_manifest.json ]; then
	log "ERROR" "init.sh" "Neoforge version manifest is corrupted or empty"
	printf "${RED_BOLD}[ERROR]${RESET}${RED} Invalid version manifest : file is missing or empty. You will not be able to list any Neoforge versions. Restart the launcher to reload the manifest${RESET}\n"
fi
if [ ! -f manifests/fabric/fabric_game_manifest.json ] || [ ! -s manifests/fabric/fabric_game_manifest.json ]; then
	log "ERROR" "init.sh" "One or multiple fabric manifests are corrupted or empty"
	printf "${RED_BOLD}[ERROR]${RESET}${RED} Invalid version manifest : file is missing or empty. You will not be able to list any Fabric versions. Restart the launcher to reload the manifest${RESET}\n"
fi
$debug || { 
	command -p rm manifests/temp_manifest.json 2>/dev/null
	command -p rm manifests/temp_manifest.xml 2>/dev/null
}

echo "Finished manifest check"
printf "${GREEN_BOLD}Start successful *\\(^o^)/*${RESET}\n"
touch ./.SHLhistory
HISTFILE="$SHdir/.SHLhistory" # setup the history
history -c
history -r
log "INFO" "init.sh" "SHlauncher startup process completed, switching to core.sh"
# shellcheck source=.minecraft/SHlauncher/core.sh
source "$SHdir/core.sh" "$@"