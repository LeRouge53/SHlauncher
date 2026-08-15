# shellcheck disable=SC2059
# shellcheck disable=SC2154
function list() {
	local allVers=(8 16 17 21 25)
	for version in "${allVers[@]}"; do
		printf "${BLUE_BOLD}Java $version:${RESET}\n"
		if ! "$SHdir/java/$version/bin/java" -version 2>/dev/null; then
			printf "${YELLOW}Java $version is not installed${RESET}\n"
		fi
		echo ""
	done
}

function install() {
	local version=$2
	local versionDir="$SHdir/java/$version"
	if ! $ONLINE_MODE; then
		printf "${RED}Can't download, you are in offline mode${RESET}\n"
		return 1
	fi
	case $version in
		"8" | "16" | "17" | "21" | "25")
			log "INFO" "java.sh:install" "Requested download of $imageType $version"
			if [[ -d "$versionDir/" ]] && ${parameter[reinstall]}; then
				command -p rm -rf -- "${version:?}"
				log "WARN" "java.sh:install" "Deleting java $version for reinstallation"
			elif [[ -d "$versionDir/" ]]; then
				printf "${YELLOW}This version seem to be already installed, Use \"-r\" to reinstall the target version${RESET}\n"
				log "WARN" "java.sh:install" "Failed to install, version already exist"
				return 1
			fi
			if [ "$version" == 16 ]; then
				printf "${YELLOW}Warning, the selected version (16) is only available as JDK${RESET}\n"
				imageType="jdk"
			fi
			printf "${BLUE_BOLD}Downloading target java...${RESET}\n"
			url=https://api.adoptium.net/v3/binary/latest/"${version}"/ga/"$(detect_os)"/"$(detect_arch)"/"${imageType}"/hotspot/normal/eclipse
			if ! exceptionCatch "java.sh:install" curl -LsS --retry 5 --retry-delay 2 "$url" -o ./temp_archive.compressed; then
				printf "${RED}Failed to download Java, an issue occurred when attempting to download. Check the log file for more info${RESET}\n"
				return 1
			fi

			printf "${BLUE_BOLD}Unpacking archive...${RESET}\n"
			mkdir -p "$versionDir"
			if [ "$osName" = "windows" ]; then
				tmpfile=$(mktemp)
            	unzip -Z1 ./temp_archive.compressed > "$tmpfile"
            	read -r DirToNuke<"$tmpfile"
            	rm "$tmpfile"
            	if ! exceptionCatch "java.sh:install" unzip -qod "$versionDir" ./temp_archive.compressed; then
					printf "${RED_BOLD}An error occurred when attempting to unzip the java archive, check the log file for more info${RESET}\n"
					return 1
				fi
            	mv "$versionDir/$DirToNuke"* "$version"
            	command -p rm -rf "${versionDir:?}/$DirToNuke"
			else
				if ! exceptionCatch "java.sh:install" tar xzf ./temp_archive.compressed -C "$version" --strip-components=1; then
					printf "${RED_BOLD}An error occurred when attempting to unzip the java archive, check the log file for more info${RESET}\n"
					return 1
				fi
			fi
			if exceptionCatch "java.sh:install" "$versionDir"/bin/java -version; then
				printf "${GREEN_BOLD}Installation successful${RESET}\n"
				log "INFO" "java.sh:install" "Installation was successful"
				command -p rm ./temp_archive.compressed
			else
				printf "${RED_BOLD}Installation seemed to have failed,${RESET}${RED} if you have any issues, retry with \"-r\"${RESET}\n"
				log "WARN" "java.sh:install" "Install seem to have failed, \"$versionDir/bin/java\" seems not to exist"
				command -p rm ./temp_archive.compressed
				return 1
			fi
		;;
		*)
			printf "${YELLOW}The only supported Java versions are 8, 16, 17, 21, 25${RESET}\n"
	esac
}

function helpPage() {
	printf "${CYAN}Usage${RESET} : java [-j/-r] <instruction> [<version ID>]\n"
	printf "Manages every java installation used\n"
	printf "${CYAN}Argument list${RESET} :\n"
	printf " - install [-j/-r] <version ID> : Installs the specified version\n"
	printf " - remove <version ID> : Deletes the specified version\n"
	printf " - list : Lists every java version installed\n"
	printf " - help : Prints this help\n"
	printf " - \"-r\" | \"--reinstall\" : Allows the reinstallation of a java instance\n"
	printf " - \"-j\" | \"--jdk\" : Manages the java installation as a JDK instead of a JRE\n"
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
		aarch64)     echo "aarch64"  ;;
		*)           echo "$arch"  ;;
	esac
}

function argHandler() {
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
				if [ -d "$SHdir/java/$2/" ]; then
					log "WARN" "java.sh:remove" "Deleting java version $2"
					command -p rm -r -- "$SHdir/java/$2/"
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
		"help")
			helpPage
		;;
		"")
			printf "${YELLOW}No argument given, assuming \"list\"${RESET}\n"
			list
		;;
		*)
			printf "${RED_BOLD}Unrecognized option: %s${RESET}\n" "$1"
	esac
}
# shellcheck disable=SC2154
mkdir -p "$SHdir/java"
cd "$SHdir/java" || cdfail

parameter[reinstall]=false
parameter[jdk]=false

declareArgs reinstall r flag
declareArgs jdk j flag

if ! globalArgHandler "$@"; then
	return 1
fi

if ${parameter[jdk]}; then
	imageType="jdk"
else
	imageType="jre"
fi

# shellcheck disable=SC2154
log "INFO" "java.sh" "java.sh called with instructions ${instructions[*]}"

# shellcheck disable=SC2154
argHandler "${instructions[@]}"

unset parameter
declare -gA parameter