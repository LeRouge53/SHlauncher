#!/bin/bash
#shellcheck source=./.minecraft/SHlauncher/dependencyInst.sh
#shellcheck source=./.minecraft/SHlauncher/core.sh
#shellcheck source=./.minecraft/SHlauncher/colorHandler.sh

# demandez pas pourquoi tout les noms de vars sont bizarre

dir=$(dirname -- "$(readlink "$0")") # POSIX compliant dir discovery, remplacé par quelque chose de mieux ensuite

if grep -q posix <<< "$SHELLOPTS"; then
	source "$dir/.minecraft/SHlauncher/crashHandler.sh" POSIX
elif wslinfo --version &>/dev/null; then
	source "$dir/.minecraft/SHlauncher/crashHandler.sh" WSL
fi

function log() {
	local level=$1
	local source=$2
	shift 2
	local msg="$*"
	case "" in
		"$level" | "$source")
			printf "${YELLOW_BOLD}[BUG]${YELLOW} Function log require 2 arguments but some are missing! Check the log file for more info \n"
			log "ERROR" "init.sh:log" "BUG : Some argument are missing. Expected argument: level \"$level\", source \"$source\""
			return 2
		;;
		*)
			true
	esac

	touch "$SHlogFile"
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
			printf "${RED_BOLD}[%s/%s]${RESET}${RED_BOLD} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		"DEBUG")
			printf "${CYAN_BOLD}[%s/%s]${RESET}${CYAN} %s\n${RESET}" "$level" "$source" "$msg" >&2
		;;
		*)
			printf "${WHITE_BOLD}[%s/%s]${RESET}${WHITE} %s\n${RESET}" "$level" "$source" "$msg" >&2
		esac
	fi
}
exec 3>&1
function exceptionCatch(){
	local source=$1
	shift
	if [[ -z $source || $# -eq 0 ]]; then
		printf '%b\n' "${YELLOW_BOLD}[BUG]${RESET}${YELLOW} Function exceptionCatch requires 2 arguments, but some are missing! Check the log file for more info\n" >&2
		log "ERROR" "init.sh:exceptionCatch" "BUG : Some argument are missing. Expected argument: source \"$source\", "'$*'" \"$*\""
		return 2
	fi
	local output
	output=$("$@" 2>&1 >&3 3>&-)
	local exitCode=$?
	if (( exitCode != 0 )); then
		log "ERROR" "init.sh:exceptionCatch" \
			"Command \"$*\" requested by $source failed to execute!"
		[[ -n $output ]] && log "ERROR" "init.sh:exceptionCatch" "$output"
	fi
	return "$exitCode"
}

source="${BASH_SOURCE[0]}" # le "mieux" en question
while [ -h "$source" ]; do
	dirname="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
	source="$(readlink "$source")"
	[[ $source != /* ]] && source="$dirname/$source"
done
dir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
MCdir="$dir/.minecraft"
SHdir="$MCdir/SHlauncher"
SHlogFile="$SHdir/SHlog.log"
export dir

trap 'echo ""; source "$SHdir/crashHandler.sh" SIGINT' INT

debug=false
verbose=false
trace=false
portable=false
IFSBak=$' \t\n'
cip=true
export SHlname="SHlauncherBE"
export SHlvers="0.2.0"
# shellcheck disable=SC2329
function trimCr() { 
	printf '%s' "${1%$'\r'}"
}

function cdfail() { #si cd plante, je sais même pas si l'init pouras accéder au crashHandler, donc je met tout dans une fonction
	printf "${RED_BOLD}[FATAL] ${RED}SHlauncher has crashed! :\n"
	printf " The launcher failed to start due to a working directory switch error.\n" 
	printf " - It could be due to insufficient authorizations, the launcher being missinstalled or issues with the disk.${RESET}\n"
	exit 1
}

function argHandler() {
	case $1 in
		"-v" | "--version")
			echo "$SHlname, version $SHlvers"
			exit 0
		;;
		"-p" | "--portable")
			portable=true
			shift
			argHandler "$@"
		;;
		"-V" | "--verbose")
			verbose=true
			shift
			argHandler "$@"
		;;
		"--debug")
			debug=true
			shift
			argHandler "$@"
		;;
		"--trace")
			trace=true
			shift
			argHandler "$@"
		;;
		"--nocip")
			# shellcheck disable=SC2034
			cip=false
			shift
			argHandler "$@"
		;;
		"--SHlname")
			export SHlname="$2"
			shift 2
			argHandler "$@"
		;;
		"--SHlvers")
			export SHlvers="$2"
			shift 2
			argHandler "$@"
		;;
		"")
			true
		;;
		*)
			echo "Unknown argument : $1"
			exit 1
	esac
}
argHandler "$@"

command -p rm "$SHlogFile"
log "DEBUG" "init.sh" "Core directory resolved to $dir"
log "INFO" "init.sh" "Starting $SHlname, version $SHlvers, debug mode: $debug, verbose mode: $verbose, cip: $cip, portable mode: $portable"

if $trace; then
	printf "As you wish...\n"
	set -x
fi

export depFailed=false
export jqNotInstalled=false

mkdir -p "$SHdir/jq"
if $portable; then
	printf "${YELLOW_BOLD}[WARN]${YELLOW} You are using SHlauncher in portable mode, which uses a self-stored jq command. \n${YELLOW_BOLD}[WARN]${YELLOW} This is NOT ideal as this version cannot be updated\n"
	printf "${YELLOW_BOLD}[WARN]${YELLOW} Please consider disabling portable mode${RESET}\n"
	if exceptionCatch "init.sh" "$SHdir/jq" --version; then
		PATH="$PATH:$SHdir/jq"
	else
		printf "${RED_BOLD}No JQ binary detected at %s. Please download the portable version of JQ and put it there${RESET}\n" "$SHdir/jq/jq"
	fi
fi

if ! jq --version &>/dev/null; then
	log "FATAL" "init.sh" "JQ was not found in the PATH, crash imminent"
	export depFailed=true
	export jqNotInstalled=true
fi ; source "$SHdir/dependencyInst.sh"

declare -A parameter
declare -A declaredLongParam
declare -A declaredShortParam
function declareArgs() {
	local long="$1"
	local short="$2"
	local type="$3"
	case "" in
		"$long" | "$short" | "$type")
			printf "${YELLOW_BOLD}[BUG]${YELLOW} Function declareArgs requires 3 arguments but some are missing! Check the log file for more info\n" >&2
			log "ERROR" "init.sh:declareArgs" "BUG : Some argument are missing. Expected argument: long \"$long\", short \"$short\", type \"$type\""
			return 2
		;;
		*)
			true
	esac

	declaredLongParam["$long"]="$type"

	if [ "$short" != "NoShort" ]; then
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
				argName=${args[i]#--}
				log "DEBUG" "init.sh:globalArgHandler" "Found parameter $argName"
				if [ "${declaredLongParam["$argName"]}" == "" ]; then continue; fi
				if [ "${declaredLongParam["$argName"]}" = "value" ]; then
					if (( i + 1 >= ${#args[@]} )); then
						printf "${RED_BOLD}%s require a value${RESET}\n" "$argName"
						return 2
					fi
					parameter["$argName"]=${args[(( i + 1 ))]}
					((i++))
				else
					parameter["$argName"]=true
				fi
				log "DEBUG" "init.sh:globalArgHandler" "resolved $argName to ${parameter["$argName"]}"
			;;
			-*)
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
	local settingId=$1
	local value=$2
	tmp=$(mktemp)
	Sett["$settingId"]=$value
	jq ".settings.$settingId = \"$value\"" "$SHdir/settings/data/user.json" > "$tmp" && mv "$tmp" "$SHdir/settings/data/user.json"
	log "DEBUG" "init.sh:writeSettingsValue" "wrote setting value \"$settingId\" with \"$value\""
}

source "$SHdir/commands/settings.sh" init

force_color=false
if [ -n "$FORCE_COLOR" ]; then
	color=true
	force_color=true
	log INFO "init.sh" "FORCE_COLOR recognized"
elif [ -n "$NO_COLOR" ]; then
	color=false
	log INFO "init.sh" "NO_COLOR recognized"
else 
	color=true
fi

source "$SHdir/colorHandler.sh"

case "$OSTYPE" in
	msys*|cygwin*|win32*)  osName="windows"; cmdSeparator=';' ;;
	darwin*)               osName="osx"; cmdSeparator=':' ;;
	linux*)                osName="linux"; cmdSeparator=':' ;;
	*)                     osName="unknown"; cmdSeparator=':' ;;
esac

log "INFO" "init.sh" "Resolved operating system to $osName"

mkdir -p "$SHdir"
cd "$SHdir" || cdfail

if ! $cip; then
	printf "${RED_BOLD}[MAJOR WARNING]${RED} Command injection protection is disabled, DO NOT execute commands that could\n"
	printf "${RED_BOLD}[MAJOR WARNING]${RED} lead to arbitrary code execution${RESET}\n"
fi

ONLINE_MODE=true
printf "${GREEN_BOLD}SHlauncher started${RESET}\n"
echo "Started resolving dependency"

log "INFO" "init.sh" "SHlauncher initialization finished, checking internet and creating directories"

mkdir -p "$MCdir/assets/indexes"
mkdir -p "$MCdir/assets/objects"
mkdir -p "$MCdir/libraries"
mkdir -p "$MCdir/instances"
mkdir -p ./versions
mkdir -p ./profiles
mkdir -p ./commands
mkdir -p ./instances
mkdir -p ./manifests

if [ $osName = "windows" ]; then
	/c/Windows/System32/ping.exe -n 1 -w 3000 google.com &>/dev/null
	pingExitCode=$?
else
	ping -c 1 -W 3 google.com &>/dev/null
	pingExitCode=$?
fi

if [ "$pingExitCode" != 0 ]; then
	log "ERROR" "init.sh" "No internet detected, many features might not work properly"
	printf "${RED_BOLD}[ERROR]${RED} This launcher requires an Internet connection for almost everything, an offline mode exist but is very limited.\n"
	printf "${RED_BOLD}[ERROR]${RED} Restart or reset the launcher to switch back to Online mode${RESET}\n"
	ONLINE_MODE=false
fi

export ONLINE_MODE

echo "Finished resolving dependencies"

# shellcheck disable=SC2329
function mavenParser() {
	local is=$1 # is pour "input string"
	log "DEBUG" "init.sh:mavenParser" "mavenParser called with $is"
	if [ "$is" == "" ]; then
		printf "${YELLOW_BOLD}[BUG] function mavenParser require 1 entry argument but none were ever passed! Check the log file for more info${RESET}\n"
		log "ERROR" "init.sh:mavenParser" "BUG : Some argument are missing. Expected argument: is \"$is\""
		return 2
	fi
	is=$(trimCr "$is")
	is="${is//'['/}"
	is="${is//']'/}"

	local ext="${is##*@}"
	if [[ "$is" == "$ext" ]]; then
		ext="jar"
	else
		is="${is%@*}"
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

	local groupPath="${group//./\/}"
	local filename="${artifact}-${version}"
	if [[ -n "$classifier" ]]; then
		filename+="-$classifier"
	fi
	filename+=".$ext"

	local path="$groupPath/$artifact/$version/$filename"
	log "DEBUG" "init.sh:mavenParser" "resolved $is to $path"
	printf '%s' "${path%$'\r'}"
}

echo "Starting manifest check"
log "DEBUG" "init.sh" "Downloading manifests..."
if $ONLINE_MODE; then
	if curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq '.' > manifests/temp_manifest.json; then
		cat manifests/temp_manifest.json > manifests/vanilla_version_manifest.json
	else
		log "WARN" "init.sh" "Vanilla manifest download failed, invalid JSON file"
		printf "${RED}[ERROR]${RED} The newly downloaded vanilla manifest seem invalid, the old one will be used instead${RESET}\n"
	fi

	if curl -so manifests/temp_manifest.xml https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml; then
		readarray -t NeoVersions < <(grep -oP '(?<=<version>).*?(?=</version>)' manifests/temp_manifest.xml)
		# shellcheck disable=SC2207
		IFS=$'\n' NeoVersions=($(sort <<<"${NeoVersions[*]}"))
		printf '%s\n' "${NeoVersions[@]}" | jq -Rs 'split("\n")[:-1]' \
			> manifests/neoforge_version_manifest.json
		command -p rm manifests/temp_manifest.xml
		command -p rm manifests/temp_manifest.json
	else
		log "WARN" "init.sh" "Neoforge manifest download failed, invalid JSON file"
		printf "${RED}[ERROR]${RED} The newly downloaded Neoforge manifest seem invalid, the old one will be used instead${RESET}\n"
		command -p rm manifests/temp_manifest.json 2>/dev/null
	fi
else
	printf "${YELLOW_BOLD}[WARN]${YELLOW} Unable to reload some manifest file, old one will be used instead${RESET}\n"
fi
if [ ! -f manifests/vanilla_version_manifest.json ] || [ ! -s manifests/vanilla_version_manifest.json ]; then
	log "ERROR" "init.sh" "Vanilla version manifest is corrupted or empty"
	printf "${RED_BOLD}[ERROR]${RED} Invalid version manifest : file is missing or empty. You will not be able to download or repair any Vanilla game instances. Restart the launcher to reload the manifest${RESET}\n"
fi

if [ ! -f manifests/neoforge_version_manifest.json ] || [ ! -s manifests/neoforge_version_manifest.json ]; then
	log "ERROR" "init.sh" "Neoforge version manifest is corrupted or empty"
	printf "${RED_BOLD}[ERROR]${RED} Invalid version manifest : file is missing or empty. You will not be able to list any Neoforge versions. Restart the launcher to reload the manifest${RESET}\n"
fi
echo "Finished manifest check"
printf "${GREEN_BOLD}Start successful *\\(^o^)/*${RESET}\n"
touch ./.SHLhistory
HISTFILE="$SHdir/.SHLhistory"
history -c
history -r
log "INFO" "init.sh" "SHlauncher startup process completed, switching to core.sh"
source ./core.sh
exit