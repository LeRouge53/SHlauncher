#shellcheck shell=bash
#shellcheck source=./.minecraft/SHlauncher/dependencyInst.sh
#shellcheck source=./.minecraft/SHlauncher/core.sh
#shellcheck source=./.minecraft/SHlauncher/colorHandler.sh

# Ceci est un script bash porté pour être compatible avec l'émulateur Git-Bash
# demandez pas pourquoi tout les noms de vars sont bizarre

dir=$(dirname -- "$(readlink "$0")") # POSIX compliant dir discovery, remplacé par quelque chose de mieux ensuite

if [ -n "$NO_COLOR" ]; then color=false; else color=true; fi
source "$dir/.minecraft/SHlauncher/colorHandler.sh"
if grep -q posix <<< "$SHELLOPTS"; then
    source "$dir/.minecraft/SHlauncher/crashHandler.sh" POSIX
elif wslinfo --version &>/dev/null; then
    source "$dir/.minecraft/SHlauncher/crashHandler.sh" WSL
fi

source="${BASH_SOURCE[0]}" # le "mieux" en question
while [ -h "$source" ]; do
  dirname="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
  source="$(readlink "$source")"
  [[ $source != /* ]] && source="$dirname/$source"
done
dir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
export dir

trap 'echo ""; source "$dir"/.minecraft/SHlauncher/crashHandler.sh SIGINT' INT

debug=false
portable=false
IFSBak=$' \t\n'
export SHlname="SHlauncherBE"
export SHlvers="0.1.0"
cip=true
# shellcheck disable=SC2329
function trimCr() { 
    printf '%s' "${1%$'\r'}"
}

function argHandler() {
    case $1 in
        "-v" | "--version")
            echo "$SHlname, version $SHlvers"
            exit
        ;;
        "--usePortableMode")
            portable=true
            shift
            argHandler "$@"
        ;;
        "--debug")
            debug=true
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
            echo "Uknown argument : $1"
            exit 1
    esac
}
argHandler "$@"

if $debug; then
    printf "${CYAN}As you wish...${RESET}\n"
    set -x
fi

function cdfail() { #si cd plante, je sais même pas si l'init pouras accéder au crashHandler, donc je met tout dans une fonction
    printf "${RED_BOLD}[FATAL] ${RED}SHlauncher has crashed! :\n"
    printf " The launcher failed to start due to a working directory switch error.\n" 
    printf " - It could be due to issuficient authorisations, the launcher being missinstalled or issues with the disk.${RESET}\n"
    exit 1
}

export DEP_FAILED=false
export JQ_NOT_INSTALLED=false
export CRASH=false

mkdir -p "$dir/.minecraft/SHlauncher"
cd "$dir/.minecraft/SHlauncher" || cdfail
export PROG_DIR=../..
export PREP_CRASH=false

if $portable; then
    printf "${YELLOW_BOLD}[WARN]${YELLOW} You are using SHlauncher in portable mode, which uses a self-stored jq command. \n${YELLOW_BOLD}[WARN]${YELLOW} This is NOT ideal as this version cannot be updated\n"
    printf "${YELLOW_BOLD}[WARN]${YELLOW} Please consider disabling portable mode${RESET}\n"
    PATH="$PATH:$dir/.minecraft/SHlauncher/jq"
fi

if ! $cip; then
    printf "${RED_BOLD}[MAJOR WARNING]${RED} Command injection protection is disabled, DO NOT execute commands that could\n"
    printf "${RED_BOLD}[MAJOR WARNING]${RED} lead to arbitrary code execution${RESET}\n"
fi

ONLINE_MODE=true
printf "${GREEN_BOLD}SHlauncher started${RESET}\n"
echo "Started resolving dependency"

if ! jq --version &>/dev/null; then
    export DEP_FAILED=true
    export JQ_NOT_INSTALLED=true
fi

mkdir -p "$dir/.minecraft/assets/indexes"
mkdir -p "$dir/.minecraft/assets/objects"
mkdir -p "$dir/.minecraft/libraries"
mkdir -p "$dir/.minecraft/instances"
mkdir -p ./versions
mkdir -p ./profiles
mkdir -p ./commands
mkdir -p ./instances

if ! ping -n 1 -w 3000 google.com &>/dev/null; then
    printf "${RED_BOLD}[ERROR]${RED} This launcher requires an Internet connection for almost everything, an offline mode exist but is very limited.\n"
    printf "${RED_BOLD}[ERROR]${RED} Restart or reset the launcher to switch back to Online mode${RESET}\n"
    ONLINE_MODE=false
fi

export ONLINE_MODE

echo "Finished resolving dependencies"
source ./dependencyInst.sh

# shellcheck disable=SC2329
function mavenParser() {
    local is=$1 # is pour "input string"
    if [ "$is" == "" ]; then
    	printf "${YELLOW_BOLD}[BUG] function mavenParser require 1 entry argument, but none were ever passed${RESET}\n"
    	return 1
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
    printf '%s' "${path%$'\r'}"
    return
}


echo "Starting manifest check"
if $ONLINE_MODE; then
    if curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq . > ./temp_manifest.json; then
        cat ./temp_manifest.json > ./vanilla_version_manifest.json
    else
        printf "${RED}[ERROR]${RED} The newly downloaded vanilla manifest seem invalid, the old one will be used instead${RESET}\n"
    fi

    if curl -so ./temp_manifest.xml https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml; then
        readarray -t NeoVersions < <(grep -oP '(?<=<version>).*?(?=</version>)' ./temp_manifest.xml)
        printf '%s\n' "${NeoVersions[@]}" | jq -Rs 'split("\n")[:-1]' \
            > ./neoforge_version_manifest.json
        command -p rm ./temp_manifest.xml
        command -p rm ./temp_manifest.json
    else
        printf "${RED}[ERROR]${RED} The newly downloaded Neoforge manifest seem invalid, the old one will be used instead${RESET}\n"
        command -p rm ./temp_manifest.json 2>/dev/null
    fi
else
    printf "${YELLOW_BOLD}[WARN]${YELLOW} Unable to reload some manifest file, old one will be used instead${RESET}\n"
fi
if [ ! -f ./vanilla_version_manifest.json ] || [ ! -s ./vanilla_version_manifest.json ]; then
    printf "${RED_BOLD}[ERROR]${RED} Invalid version manifest : file is missing or empty. You will not be able to download or repair any Vanilla game instances. Restart the launcher to reload the manifest${RESET}\n"
fi

if [ ! -f ./neoforge_version_manifest.json ] || [ ! -s ./neoforge_version_manifest.json ]; then
    printf "${RED_BOLD}[ERROR]${RED} Invalid version manifest : file is missing or empty. You will not be able to download or repair any Neoforge game instances. Restart the launcher to reload the manifest${RESET}\n"
fi

echo "Finished manifest check"
printf "${GREEN_BOLD}Start successful *\\(^o^)/*${RESET}\n"
touch ./.SHLhistory
HISTFILE="$dir/.minecraft/SHlauncher/.SHLhistory"
history -c
history -r
source ./core.sh
exit