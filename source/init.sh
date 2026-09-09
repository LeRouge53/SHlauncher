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

function log() {
	local level=$1
	local source=$2
	shift 2
	local msg="$*"
	case "" in # check if any arguments is empty, throws an error if yes
		"$level" | "$source")
			printf "${YELLOW_BOLD}[BUG]${YELLOW} Function log require 2 arguments but some are missing! Check the log file for more info${RESET}\n"
			log "ERROR" "init.sh:log" "BUG : Some argument are missing. Expected argument: level \"$level\", source \"$source\""
			return 2
		;;
		*)
			true
	esac

	touch "$SHlogFile"
	# write DEBUG lines only if debug mode is enabled
	if [ "$level" != "DEBUG" ]; then
		printf '[%(%F %T)T] [%s/%s] %s\n' -1 "$level" "$source" "$msg" >> "$SHlogFile"
	elif $debug; then
		printf '[%(%F %T)T] [%s/%s] %s\n' -1 "$level" "$source" "$msg" >> "$SHlogFile"
	fi

	if $verbose || $trace; then
		case $level in
		"INFO")
			printf "${GREEN_BOLD}[%s/%s]"$'\033[0m'"${GREEN} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"WARN")
			printf "${YELLOW_BOLD}[%s/%s]${RESET}${YELLOW} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"ERROR")
			printf "${RED_BOLD}[%s/%s]${RESET}${RED} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"FATAL")
			printf "${RED_BOLD}[%s/%s] %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"DEBUG")
			$debug && printf "${CYAN_BOLD}[%s/%s]${RESET}${CYAN} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		*)
			printf "${WHITE_BOLD}[%s/%s]${RESET}${WHITE} %s\n${RESET}" "$level" "$source" "$msg" >&2
		esac
	fi
}
exec 3>&1 # create file descriptor 3 (used to capture stderr only in exceptionCatch)
function exceptionCatch(){
	local source=$1 # source script (used for logging). Other arguments are the content the command to execute
	shift
	if [[ -z $source || $# -eq 0 ]]; then
		printf '%b\n' "${YELLOW_BOLD}[BUG]${RESET}${YELLOW} Function exceptionCatch requires 2 arguments, but some are missing! Check the log file for more info\n" >&2
		log "ERROR" "init.sh:exceptionCatch" "BUG : Some argument are missing. Expected argument: source \"$source\", "'$*'" \"$*\""
		return 2
	fi
	local output
	output=$("$@" 2>&1 >&3 3>&-) # using file descriptor 3 to get stderr only
	local exitCode=$?
	if (( exitCode != 0 )); then
		log "ERROR" "init.sh:exceptionCatch" "Command \"$*\" requested by $source failed to execute!"
		[[ -n $output ]] && log "ERROR" "init.sh:exceptionCatch" "$output" # if there is an output, print it
	fi
	return "$exitCode" # return the command's exit code so the function can be used in if statements
}

bashSource="${BASH_SOURCE[0]}"
while [ -h "$bashSource" ]; do
	dirname="$( cd -P "$( dirname "$bashSource" )" >/dev/null 2>&1 && pwd )"
	bashSource="$(readlink "$bashSource")"
	[[ $bashSource != /* ]] && bashSource="$dirname/$bashSource"
done
dir="$( cd -P "$( dirname "$bashSource" )" >/dev/null 2>&1 && pwd )"

MCdir="$dir/.minecraft"
SHdir="$MCdir/SHlauncher"
SHlogFile="$SHdir/SHlog.log"
# shellcheck source=.minecraft/SHlauncher/crashHandler.sh
trap 'echo ""; source "$SHdir/crashHandler.sh" SIGINT' INT # ctrl+c catch

debug=false # some default values before treating the arguments
verbose=false
trace=false
portable=false
cip=true
onlineMode=true

SHlname="SHlauncherBE"
SHlvers="0.5.0-pre1" # edit version here

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
		--* | -*)
			printf "Unknown parameter %s\n" "$1"
			exit 2
		;;
		"")
			break
		;;
		*)
			log "INFO" "init.sh:argHandler" "Found command $* that will be executed later" # the rest is passed to core.sh
			break
	esac
done


command -p rm "$SHlogFile" &>/dev/null
log "DEBUG" "init.sh" "Core directory resolved to $dir"

case "$OSTYPE" in
	msys*|cygwin*|win32*)  osName="windows"; cmdSeparator=';' ;;
	darwin*)               osName="osx"; cmdSeparator=':' ;;
	linux*)                osName="linux"; cmdSeparator=':' ;;
	*)                     osName="unknown"; cmdSeparator=':' ;;
esac

# shellcheck disable=SC2015
"$onlineMode" && {
	if [ "$osName" = "windows" ]; then
		/c/Windows/System32/ping.exe -n 1 -w 3000 google.com &>/dev/null # idk why msys2 doesn't have ping, so I need to use the windows one
		pingExitCode=$?
	elif [ "$osName" != "unknown" ]; then
		ping -c 1 -W 3 google.com &>/dev/null
		pingExitCode=$?
	else
  		log "WARN" "init.sh" "Unknown operating system, ping feature may not work" # a lot of things may not work
  		ping -c 1 -W 3 google.com &>/dev/null
 		pingExitCode=$?
	fi
} || {
	log "INFO" "init.sh" "skipping internet check as specified"
	pingExitCode=0
}

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

if $trace; then
	printf "As you wish...\n"
	set -x
fi
# starting to check dependencies (jq and unzip)
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
# shellcheck source=.minecraft/SHlauncher/dependencyInst.sh
source "$SHdir/dependencyInst.sh"

declare -A parameter
declare -A declaredLongParam
declare -A declaredShortParam
function declareArgs() {
	local long="$1" # foo (long parameter name)
	local short="$2" # f (short parameter name linked to the long one). Is optional
	local type="$3" # "value" or "flag" ; value : the user needs to enter a value with the parameter. flag : if the parameter is specified, switch the value to true 
	case "" in
		"$long" | "$short" | "$type")
			printf "${YELLOW_BOLD}[BUG]${YELLOW} Function declareArgs requires 3 arguments but some are missing! Check the log file for more info\n" >&2
			log "ERROR" "init.sh:declareArgs" "BUG : Some argument are missing. Expected argument: long \"$long\", short \"$short\" (optional), type \"$type\""
			return 2
		;;
		*)
			true
	esac

	declaredLongParam["$long"]="$type"

	if [ "$short" != "NoShort" ] || [ -z "$short" ]; then
		declaredShortParam["$short"]="$long"
	fi
	log "DEBUG" "init.sh:declareArgs" "Declared parameter \"$long\" with short \"$short\" and type \"$type\""
}
function globalArgHandler() {
	local -a args=("$@")
	local translatedParam
	local argName
	instructions=()

	for ((i=0;i<"${#args[@]}";i++)); do
		case ${args[i]} in
			--*)
				# if the arg is long
				argName=${args[i]#--}
				log "DEBUG" "init.sh:globalArgHandler" "Found parameter $argName"
				if [ "${declaredLongParam["$argName"]}" == "" ]; then continue; fi # if it's undefined, skip
				if [ "${declaredLongParam["$argName"]}" = "value" ]; then # if it's defined as a value, take the following arg
					if (( i + 1 >= ${#args[@]} )); then
						printf "${RED_BOLD}%s require a value${RESET}\n" "$argName"
						return 2
					fi
					parameter["$argName"]=${args[(( i + 1 ))]}
					((i++)) # skip the value as an argument (as it's already been treated)
				else
					parameter["$argName"]=true # if it's not defined as a value, then it's a flag
				fi
				log "DEBUG" "init.sh:globalArgHandler" "resolved $argName to ${parameter["$argName"]}"
			;;
			-*)
				# if the arg is short, just translate it to the long arg and treat it the exact same way
				translatedParam=${declaredShortParam["${args[i]#-}"]}
				log "DEBUG" "init.sh:globalArgHandler" "Found parameter $translatedParam"
				if [ "$translatedParam" == "" ]; then continue; fi
				if [ "${declaredLongParam["$translatedParam"]}" = "value" ]; then
					if (( i + 1 >= ${#args[@]} )); then
						printf "${RED_BOLD}%s require a value${RESET}\n" "$translatedParam"
						return 2
					fi
					parameter["$translatedParam"]=${args[(( i + 1 ))]}
					((i++))
				else
					parameter["$translatedParam"]=true
				fi
				log "DEBUG" "init.sh:globalArgHandler" "resolved $translatedParam to ${parameter["$translatedParam"]}"
			;;
			*)
				instructions+=("${args[$i]}")
		esac
	done
}

declare -A Sett
function writeSettingsValue() {
	local settingId=$1 # ID of the setting to write
	local value=$2 # value (can be empty)
  if [[ -z "$settingId" ]]; then
    log "ERROR" "init.sh:writeSettingsValue" "BUG : Some argument are missing, expected argument settingId : \"$settingId\", value (optional): \"$value\""
    printf "${YELLOW_BOLD}[BUG]${RESET}${YELLOW} Function writeSettingsValue requires 2 arguments but some are missing! Check the log file for more info\n" >&2
    return 2
  fi
	tmp=$(mktemp)
	Sett["$settingId"]=$value
	jq ".settings.$settingId = \"$value\"" "$SHdir/settings/data/user.json" > "$tmp" && mv "$tmp" "$SHdir/settings/data/user.json"
	log "DEBUG" "init.sh:writeSettingsValue" "wrote setting value \"$settingId\" with \"$value\""
}
# shellcheck source=.minecraft/SHlauncher/commands/settings.sh
source "$SHdir/commands/settings.sh" init # loads settings, create missing keys, etc...

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


function mavenParser() {
	local is=$1 # is for "input string"
	log "DEBUG" "init.sh:mavenParser" "mavenParser called with $is"
	if [ "$is" == "" ]; then
		printf "${YELLOW_BOLD}[BUG] function mavenParser require 1 entry argument but none were ever passed! Check the log file for more info${RESET}\n"
		log "ERROR" "init.sh:mavenParser" "BUG : Some argument are missing. Expected argument: is \"$is\""
		return 2
	fi

	is="${is//'['/}" # remove the squares brackets
	is="${is//']'/}"

	local ext="${is##*@}"
	if [[ "$is" == "$ext" ]]; then
		ext="jar" # if the extension is unspecified, then it's a jar file
	else
		is="${is%@*}" # else it's whatever the extension is
	fi

	IFS=':' read -ra parts <<< "$is"
	local group="${parts[0]}"
	local artifact="${parts[1]}"
	local version="${parts[2]}"

	if [ "${#parts[@]}" -ge 4 ]; then
		local classifier="${parts[3]}"
	else
		local classifier=""
	fi

	local groupPath="${group//./\/}" # replace dots with forward slashes 
	local filename="${artifact}-${version}" # build the filename
	if [[ -n "$classifier" ]]; then
		filename+="-$classifier"
	fi
	filename+=".$ext"

	local path="$groupPath/$artifact/$version/$filename" # build the final path
	log "DEBUG" "init.sh:mavenParser" "resolved $is to $path"
	printf '%s' "${path%$'\r'}"
}

echo "Downloading manifests"
log "DEBUG" "init.sh" "Downloading manifests..."
# manifest stuff
if $onlineMode; then
	if curl -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | jq '.' > manifests/temp_manifest.json; then
		cat manifests/temp_manifest.json > manifests/vanilla_version_manifest.json
	else
		log "WARN" "init.sh" "Vanilla manifest download failed, invalid JSON file"
		printf "${YELLOW}The newly downloaded vanilla manifest seem invalid, the old one will be used instead${RESET}\n"
	fi

	if curl -so manifests/temp_manifest.xml https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml; then
		readarray -t NeoVersions < <(grep -oP '(?<=<version>).*?(?=</version>)' manifests/temp_manifest.xml)
		# shellcheck disable=SC2207
		IFS=$'\n' NeoVersions=($( sort <<<"${NeoVersions[*]}")); IFS=$IFSBak # I cried at my computer for 40 minutes trying to understand why my splitting was so weird. All because a temporary variable modification wasn't that temporary (I hate myself)
		printf '%s\n' "${NeoVersions[@]}" | jq -Rs 'split("\n")[:-1]' \
			> manifests/neoforge_version_manifest.json
	else
		log "WARN" "init.sh" "Neoforge manifest download failed, invalid JSON file"
		printf "${YELLOW}The newly downloaded Neoforge manifest seem invalid, the old one will be used instead${RESET}\n"
		
	fi

	if curl -s "https://meta.fabricmc.net/v2/versions/game" | jq '.' > manifests/temp_manifest.json; then
		cat manifests/temp_manifest.json > manifests/fabric/fabric_game_manifest.json
	else
		log "WARN" "init.sh" "fabric game manifest download failed, invalid JSON file"
		printf "${YELLOW}The newly downloaded Fabric game manifest seem invalid, the old one will be used instead${RESET}\n"
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
exit