# shellcheck disable=SC2059
function list() {
    ping() {
        # shellcheck disable=SC2154
        if ! "$dir/.minecraft/SHlauncher/java/$1/bin/java" -version 2>/dev/null; then
            printf "${YELLOW}Java $1 is not installed${RESET}\n"
            return 1
        fi
        "$dir/.minecraft/SHlauncher/java/$1/bin/java" -version
    }
    local allVers=(8 16 17 21 25)
    for version in "${allVers[@]}"; do
        printf "${BLUE_BOLD}Java $version:${RESET}\n"
        ping "$version"
        echo ""
    done 
}

function install() {
    local version=$2
    local versionDir="$dir/.minecraft/SHlauncher/java/$version"
    if ! $ONLINE_MODE; then
        printf "${RED}Can't download, you are in offline mode${RESET}\n"
    fi
    case $version in
        "8" | "16" | "17" | "21" | "25")
            if [[ -d "$versionDir/" ]] && $reinstall; then
                command -p rm -r -- "${version:?}"
            elif [[ -d "$versionDir/" ]]; then
                printf "${YELLOW}This version seem to be already installed, Use \"-r\" to reinstall the target version${RESET}\n"
                return 1
            fi
            if [ "$version" == 16 ]; then
                printf "${YELLOW}Warning, the selected version (16) is only avariable as JDK${RESET}\n"
                image_type="jdk"
            fi
            printf "${BLUE_BOLD}Downloading target java...${RESET}\n"
            url=https://api.adoptium.net/v3/binary/latest/"${version}"/ga/"$(detect_os)"/"$(detect_arch)"/"${image_type}"/hotspot/normal/eclipse
            if ! curl -L --retry 5 --retry-delay 2 -s "$url" -o ./temp_archive.zip; then
                printf "${RED}Failed to download Java, please try to download manually \"$url\" to get a more precise error${RESET}\n"
            fi

            printf "${BLUE_BOLD}Unpacking archive...${RESET}\n"
            mkdir -p "$versionDir"
            tmpfile=$(mktemp)
            unzip -Z1 ./temp_archive.zip > "$tmpfile"
            read -r DirToNuke<"$tmpfile"
            rm "$tmpfile"
            unzip -qod "$versionDir" ./temp_archive.zip
            mv "$versionDir/$DirToNuke"* "$version"
            rmdir "$versionDir/$DirToNuke"

            if "$versionDir/bin/java" -version; then
                printf "${GREEN_BOLD}Installation successful${RESET}\n"
                command -p rm ./temp_archive.zip
            else
                printf "${RED_BOLD}Installation seemed to have failed,${RESET} if you have any issues, retry with \"-r\"\n"
                command -p rm ./temp_archive.zip
                return 1
            fi
        ;;
        *)
            printf "${YELLOW}The only supported Java versions are 8, 16, 17, 21, 25${RESET}\n"
    esac
}

detect_os() {
    case "$OSTYPE" in
        msys*|cygwin*|win32*)  echo "windows" ;;
        darwin*)               echo "osx"     ;;
        linux*)                echo "linux"   ;;
        *)                     echo "unknown" ;;
    esac
}
detect_arch() {
    local arch; arch=$(uname -m)
    case "$arch" in
        i386|i686)   echo "x86"    ;;
        x86_64)      echo "x86_64" ;;
        aarch64)     echo "arm64"  ;;
        *)           echo "$arch"  ;;
    esac
}

function Main() {
    case $1 in
        "install")
            install "$@"
        ;;
        "list")
            list "$@"
        ;;
        "remove")
            case $2 in
                "8" | "16" | "17" | "21" | "25")
                if [ -d "$dir/.minecraft/SHlauncher/java/$2/" ]; then
                    command -p rm -r -- "$dir/.minecraft/SHlauncher/java/$2/"
                else
                    printf "${YELLOW}The selected java version is not installed${RESET}\n"
                fi
                ;;
                "")
                    printf "${RED}Require a java version (8, 16, 17, 21 or 25)${RESET}\n"
                ;;
                *)
                    printf "${RED}Unsupported version, the only supported version are 8, 16, 17, 21 and 25${RESET}\n"
                    return 1
            esac
        ;;
        "-r" | "--reinstall")
            reinstall=true
            shift
            Main "$@"
        ;;
        "-j" | "--jdk")
            image_type="jdk"
            shift
            Main "$@"
        ;;
        "")
            printf "${YELLOW}No argument given, assuming \"list\"${RESET}\n"
            list
        ;;
        *)
            printf "${RED_BOLD}Unregonized option: %s${RESET}\n" "$1"
    esac
}
# shellcheck disable=SC2154
mkdir -p "$dir/.minecraft/SHlauncher/java"
cd "$dir/.minecraft/SHlauncher/java" || cdfail

reinstall=false
image_type="jre"
Main "$@"