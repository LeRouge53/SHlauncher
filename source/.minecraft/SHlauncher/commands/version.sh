# shellcheck disable=SC2154
# shellcheck disable=SC2016
cd "$MCdir" || return 255

function install() {
	side="client"

	function installLib() {
		local inputFile=$1
		local outputDir=$2

		log "INFO" "version.sh:install:installLib" "Started library install job with input file \"$inputFile\" and output directory \"$outputDir\""

		if [[ -z $inputFile ]] || [[ -z $outputDir ]]; then
			printf "${YELLOW_BOLD}[BUG] function installLib require 2 argument, but some are missing! Check the log file for more info\n"
			log "ERROR" "version.sh:install:installLib" "BUG : Some argument are missing. Expected argument: inputFile \"$inputFile\", outputDir \"$outputDir\""
			return 2
		fi

		outputCp=""
		goal=$(jq -r '.libraries | length' "$inputFile")
		log "INFO" "version.sh:install:installLib" "Downloading $goal libraries"
		actual=0
		while IFS='|' read -r type url path sha1 extract; do

			printf "${BLUE_BOLD}Downloading $path...${RESET}\n"
			log "DEBUG" "version.sh:install:installLib" "Started downloading $path"
			sha1="$(trimCr "$sha1")"
			dest="$outputDir/$path"
			mkdir -p "$(dirname "$dest")"

			if [[ -f "$dest" ]]; then
				local_sha1=$(sha1sum "$dest" | cut -d' ' -f1)
				if [ "$local_sha1" = "$sha1" ]; then
					if [[ "$type" == "artifact" ]]; then
						outputCp="${outputCp}${cmdSeparator}${dest}"
					elif [[ "$type" == "native" ]]; then
						if ! unzip -od natives/ "$dest" &>/dev/null; then
							printf "${YELLOW}Unzip of native library $path failed!\n"
							log "ERROR" "version.sh:install:installLib" "Failed to install $path, Unzip failed. Exiting"
							printf "${RED}Error is non-recoverable, exiting${RESET}\n"
							return 1
						fi
					fi
					printf "${GREEN}Skipping $path, already downloaded${RESET}\n"
					log "DEBUG" "version.sh:install:installLib" "$path was already installed and has been skipped"
					actual=$((actual+1))
					printf "${GREEN}Downloaded $actual libraries out of $goal${RESET}\n"
					continue
				else
					printf "${YELLOW}Invalid hash of \"${path}\", redownload required${RESET}\n"
					log "DEBUG" "version.sh:install:installLib" "$path was already installed and has been skipped"
				fi
			fi

			curl --retry 5 --retry-delay 2 -sLo "$dest" "$url" &>/dev/null
			local_sha1=$(sha1sum "$dest" | cut -d' ' -f1)

			if [ "$local_sha1" != "$sha1" ]; then
				printf "${YELLOW}Failed to download $path : mismatched hash\n"
				log "ERROR" "version.sh:install:installLib" "Failed to install $path, download failed. Exiting"
				printf "${RED}Error is non recoverable : please retry${RESET}\n"
				return 1
			fi
			if [ "$type" == "artifact" ]; then
				outputCp="${outputCp}${cmdSeparator}${dest}"
			elif [ "$type" == "native" ]; then
				printf "${BLUE_BOLD}Unzipping natives : $path...${RESET}\n"
				if ! unzip -od natives/ "$dest" &>/dev/null; then
					printf "${YELLOW}Unzip of native library $path failed!\n"
					log "ERROR" "version.sh:install:installLib" "Failed to install $path, Unzip failed. Exiting"
					printf "${RED}Error is non-recoverable, exiting${RESET}\n"
					return 1
				fi
				command -p rm -- "$(trimCr "$dest")"
				IFS=',' read -ra excludes <<< "$extract"
				for exc in "${excludes[@]}"; do
					if [ "$(trimCr "$exc")" == "" ]; then continue; fi
					command -p rm -r -- "natives/$(trimCr "$exc")"
				done
			fi

			actual=$((actual+1))
			printf "${GREEN}Finished downloading \"$path\"\n"
			log "DEBUG" "version.sh:install:installLib" "Finished downloading $path"
			printf "Downloaded $actual libraries out of $goal${RESET}\n"

		done < <(jq -r --arg os "$osName" --arg libRoot "$libRoot" ' 
			.libraries[] | 
			. as $lib | 
			( if $lib.rules == null then 
				true 
			else 
				reduce $lib.rules[] as $rule 
				( false; 
					if $rule.os == null or $rule.os.name == $os then
						$rule.action == "allow" 
					else . 
					end ) 
			end ) 
			as $include | 
			if $include then 
				( if $lib.downloads.artifact != null then
					"artifact|\($lib.downloads.artifact.url)|\($lib.downloads.artifact.path)|\($lib.downloads.artifact.sha1)|" else empty 
				end ),
				( if (($lib.downloads.classifiers // {})["natives-\($os)"]) != null then ( 
						if $lib.extract.exclude != null then
							($lib.extract.exclude | join(",")) 
						else "" 
						end )
				as $extract |
				$lib.downloads.classifiers["natives-\($os)"] as $native |
				"native|\($native.url)|\($native.path)|\($native.sha1)|\($extract)" else empty end ) else empty end
				' "$inputFile")
	}


	function getMainClass() {
		unzip -p "$1" META-INF/MANIFEST.MF 2>/dev/null |
		awk -F': ' '/^Main-Class: / {print $2}' |
		tr -d '\r'
	}

	function detect_os() {
		case "$OSTYPE" in
			msys*|cygwin*|win32*) echo "windows";;
			darwin*) echo "osx";;
			linux*) echo "linux";;
			*) echo "unknown";;
		esac
	}

	function detect_arch() {
		local arch; arch=$(uname -m)
		case "$arch" in
			i386|i686) echo "x86";;
			x86_64) echo "x86_64";;
			aarch64) echo "arm64";;
			*) echo "$arch";;
		esac
	}

	targetVers=$1
	modlVers=$2

	# shellcheck disable=SC2154
	versDir="$MCdir/versions"
	if ! $ONLINE_MODE; then
		printf "${RED}Can't download, you are in offline mode${RESET}\n"
		return 1
	fi

	case $modloader in
		"vanilla")
			echo "Starting download..."
			log "INFO" "version.sh:install" "Requested download of version $targetVers"
			url="$(jq -r '.versions[] | select(.id == "'"$targetVers"'") | .url' "$SHdir/manifests/vanilla_version_manifest.json")"
			mkdir -p "$versDir/$targetVers"
			if [ "$url" == "" ]; then
				printf "${RED}Invalid version, type \"version list\" to list all version available${RESET}\n"
				log "ERROR" "version.sh:install" "Download aborted, invalid version"
				return 2
			fi

			versionJson="$versDir/$targetVers/$targetVers.json"

			curl --retry 5 --retry-delay 2 -s "$url" | jq '.' > "$versionJson"
			curl --retry 5 --retry-delay 2 -o "$versDir/$targetVers/$targetVers.jar" "$(jq -r '.downloads.client.url' "$versionJson")" &>/dev/null

			hash=$(sha1sum "$versDir/$targetVers/$targetVers.jar" | awk '{print $1}')
			if [ "$hash" != "$(jq -r '.downloads.client.sha1' "$versionJson")" ]; then
				printf "${YELLOW}Failed to download the game: mismatched hash\n"
				printf "${RED}Error is non recoverable : please retry${RESET}\n"
				command -p rm -r -- "${versDir:?}/$targetVers"
				return 2
			fi
		;;
		"neoforge")
			function NeoArgSubstitute() {
				local arg
				local fullString
				fullString=$(trimCr "$1")
				if [[ -z $fullString ]]; then
					printf "${YELLOW_BOLD}[BUG]${YELLOW} function NeoArgSubstitute require 1 entry argument, but none were ever passed! Check the log file for more info${RESET}\n" >&2
					log "ERROR" "version.sh:install:NeoArgSubstitute" "BUG : Some argument are missing. Expected argument: fullString \"$fullString\""
					return 2
				fi
				log "INFO" "version.sh:install:NeoArgSubstitute" "Treating fullString \"$fullString\""
				while [[ $fullString =~ \{([^}]*)\} ]]; do
					arg="${BASH_REMATCH[1]}"
					if ! [[ -v installVars[$arg] ]]; then
						printf "${YELLOW_BOLD}[BUG]${YELLOW} Function NeoArgSubstitute encountered an undefined argument when handling %s and cannot continue${RESET}\n" "$arg" >&2
						log "ERROR" "version.sh:install:NeoArgSubstitute" "Encountered an undefined argument when treating $fullString. Cannot continue"
						log "ERROR" "version.sh:install:NeoArgSubstitute" "This usually means the Neoforge version you are trying to download is not compatible with SHlauncher"
						return 2
					fi
					fullString="${fullString//"{$arg}"/${installVars[$arg]}}"
				done
				log "DEBUG" "version.sh:install:NeoArgSubstitute" "Resolved to $fullString"
				if [[ "$fullString" =~ \[ ]] && [[ "$fullString" =~ \] ]]; then
					fullString=$(mavenParser "$fullString")
					log "DEBUG" "version.sh:install:NeoArgSubstitute" "Detected maven coordinates. Downloading \"https://maven.neoforged.net/releases/$fullString\"..."
					curl -sfLo "$MCdir/libraries/$fullString" "https://maven.neoforged.net/releases/$fullString"
				fi

				printf "%s\n" "$fullString"
			}

			echo "Starting download..."
			# shellcheck disable=SC2001
			trunkMcVers=$(echo "$targetVers" | sed 's/^1\.//')
			fullModLoaderVers="${trunkMcVers}.${modlVers}"

			versionJson="$versDir/neoforge-$fullModLoaderVers/neoforge-${fullModLoaderVers}.json"
			installDir="$versDir/neoforge-$fullModLoaderVers/install"
			
			log "INFO" "version.sh:install" "Requested download of version $fullModLoaderVers"
			mkdir -p "$versDir/neoforge-$fullModLoaderVers"
			mkdir -p "$versDir/neoforge-$fullModLoaderVers/install"
			if ! [[ -f "$versDir/neoforge-$fullModLoaderVers/neoforge-${fullModLoaderVers}-installer.jar" ]]; then
				if ! curl -sfLo "$versDir/neoforge-$fullModLoaderVers/neoforge-${fullModLoaderVers}-installer.jar" \
					"https://maven.neoforged.net/releases/net/neoforged/neoforge/$fullModLoaderVers/neoforge-${fullModLoaderVers}-installer.jar"
				then
					printf "${RED}Invalid version, type \"version list -m neoforge\" to list all version available${RESET}\n"
					log "ERROR" "version.sh:install" "Download aborted, invalid version"
					return 2
				fi
			else
				printf "${GREEN}Installer already downloaded, skipping${RESET}\n"
			fi

			if ! unzip -p "$versDir/neoforge-$fullModLoaderVers/neoforge-${fullModLoaderVers}-installer.jar" version.json > "$versionJson"; then
				printf "${RED_BOLD}Unzip of the version.json from the installer failed\n"
				printf "Error is non recoverable. Please retry${RESET}\n"
				log "ERROR" "version.sh:install" "Install aborted, unzip of version.json failed"
				return 1
			fi
			if ! unzip -p "$versDir/neoforge-$fullModLoaderVers/neoforge-${fullModLoaderVers}-installer.jar" install_profile.json > "$installDir/install_profile.json"; then
				printf "${RED_BOLD}Unzip of the install_profile.json from the installer failed\n"
				printf "Error is non recoverable. Please retry${RESET}\n"
				log "ERROR" "version.sh:install" "Install aborted, unzip of install_profile.json failed"
				return 1
			fi

			inheritedVers=$(jq -r '.inheritsFrom' "$versionJson")
			if ! [[ -f "$versDir/$inheritedVers/$inheritedVers.jar" ]]; then
				printf "${RED_BOLD}The requested version inherits part of his content from the vanilla $inheritedVers version, please install it first${RESET}\n"
				log "ERROR" "version.sh:install" "Install aborted, Missing dependency vanilla $inheritedVers"
				return 1
			fi

			local isDone=false
			local allJavaVers=(25 21 17 16 8) # dans l'ordre inverse pour avoir la version la plus récente en 1er
			for version in "${allJavaVers[@]}"; do
				if "$SHdir/java/${version}/bin/java" -version &>/dev/null; then
					localJava="$SHdir/java/$version/bin/java"
					log "INFO" "version.sh:install" "Picked java $version to run the neoforge processors"
					printf "${BLUE}Picking java %s to run the processors${RESET}\n" "${version}"
					isDone=true
					break
				fi
			done
			if ! $isDone; then
				printf "${RED_BOLD}At least one java version is required to run the processors install any and retry${RESET}\n"
				log "ERROR" "version.sh:install" "Install aborted, no java version are installed to run the processors"
				return 1
			fi
			unset -v isDone

			echo "Downloading installation libraries"
			log "INFO" "version.sh:install" "Downloading installation libraries..."
			installLib "$installDir/install_profile.json" "$MCdir/libraries"
			unset -v outputCp

			declare -A installVars
			installVars["ROOT"]="$MCdir" 
			installVars["INSTALLER"]="$versDir/neoforge-$fullModLoaderVers/neoforge-${fullModLoaderVers}-installer.jar"
			installVars["SIDE"]="$side" # client seulement
			installVars["MINECRAFT_JAR"]="$versDir/$inheritedVers/$inheritedVers.jar" # jar vanilla de minecraft
			installVars["MINECRAFT_VERSION"]="$targetVers" # version du jeu 
			installVars["LIBRARY_DIR"]="./libraries/"
			installVars["VERSION_JSON"]="$versDir/$inheritedVers/$inheritedVers.json" # json vanilla du jeu

			while IFS='|' read -r datName datVal; do
				if [[ $datVal == *"["* ]]; then
					datVal=$(mavenParser "$datVal") # asset au format maven
				elif [[ $datVal == *"'"* ]]; then
					datVal="${datVal//"'"/}" # string littéral
				else
					datVal=$(echo "$datVal" | sed 's/^\///')
					command -p install -D /dev/null "./libraries/$datVal"
					unzip -po "$versDir/neoforge-$fullModLoaderVers/neoforge-${fullModLoaderVers}-installer.jar" \
						"$datVal" > "./libraries/$datVal" # fichier littéral
				fi
				datVal=$(trimCr "$datVal")
				installVars["$datName"]="$datVal"
			done < <(jq -r --arg side "$side" ' 
				.data | to_entries[] | 
				"\(.key)|\(.value.[$side])"
			' "$installDir/install_profile.json")

			while IFS= read -r proc; do
				jar=$(mavenParser "$(jq -r .jar <<< "$proc")")
				mapfile -t installCp < <(jq -r '.classpath[]' <<< "$proc")
				for i in "${!installCp[@]}"; do
					installCp[i]=$(trimCr "${installCp[i]}")
				done
				mapfile -t procArgs < <(jq -r '.args[]' <<< "$proc")
				for i in "${!procArgs[@]}"; do
					procArgs[i]=$(trimCr "${procArgs[i]}")
				done
				
				finalInstallCp=""
				for (( i=0; i<${#installCp[@]}; i++ )); do
					installCp[i]="$(mavenParser "${installCp[i]}")"
					finalInstallCp=${finalInstallCp}${cmdSeparator}${installCp[i]}
				done

				for (( i=0; i<${#procArgs[@]}; i++ )); do
					procArgs[i]=$(NeoArgSubstitute "${procArgs[i]}")
					procArgs[i]=$(trimCr "${procArgs[i]}")
				done

				installMainClass=$(getMainClass "$MCdir/libraries/$jar")
				installMainClass=$(trimCr "$installMainClass")
				printf "${BLUE_BOLD}executing processor %s...${RESET}\n" "$jar"

				# shellcheck source=../crashHandler.sh
				cd "./libraries" || source "$SHdir/crashHandler.sh" "CD_FAIL"
				log "INFO" "version.sh:install" "Starting processor \"$jar\""
				if ! "${localJava}" "-Xms64M" "-Xmx2G" "-cp" "${finalInstallCp}" "${installMainClass}" "${procArgs[@]}"; then
					printf "${RED_BOLD}Processor %s failed to execute\n" "$jar"
					log "ERROR" "version.sh:install" "Install aborted, Processor $jar failed to execute"
					printf "Error is non recoverable. please retry${RESET}\n"
					return 1
				fi
				# shellcheck source=../crashHandler.sh
				cd .. || source "$SHdir/crashHandler.sh" "CD_FAIL"
			done < <(jq -c --arg side "$side" '.processors[] | . as $proc | ( if $proc.sides == null or ($side | IN($proc.sides[])) then $proc else empty end )' "$installDir/install_profile.json")
			rm "$versDir/neoforge-$fullModLoaderVers/"*-installer.jar*
			rm -r -- "$installDir"
			log "INFO" "version.sh:install" "Processor execution complete"
			for (( i=0; i<${#procArgs[@]}; i++ )); do
				if [ "${procArgs[i]}" == "--output" ]; then
					newIndex=$((i+1))
				fi
			done
	esac

	mkdir -p "natives/java"
	mkdir -p "natives/jna"
	mkdir -p "natives/lwjgl"
	mkdir -p "natives/netty"

	echo "downloading libraries"

	case $modloader in
		"vanilla")
			log "INFO" "version.sh:install" "Installing game libraries..."
			installLib "$versionJson" "libraries"
			classpath=$outputCp
			client="versions/${targetVers}/${targetVers}.jar"
			classpath="${classpath}${cmdSeparator}${client}"
			log "DEBUG" "version.sh:install" "classpath is \"$classpath\""
			unset -v outputCp
		;;
		"neoforge")
			printf "${BLUE_BOLD}Merging vanilla and modded library list${RESET}\n"
			log "INFO" "version.sh:install" "Merging vanilla (\"$versDir/$inheritedVers/$inheritedVers.json\") and modded (\"$versionJson\") library list..."
			local vanillaLib
			vanillaLib="$versDir/$inheritedVers/$inheritedVers.json"
			local newLib
			newLib="$versDir/neoforge-${fullModLoaderVers}/libraries.json"

			jq -s '
				def libkey:
					(.name | sub("@jar$";"") | split(":")) as $p
					| [$p[0], $p[1], (if ($p|length) > 3 then $p[3] else "" end)] | join(":");

				reduce (.[0].libraries + .[1].libraries)[] as $lib
				(
					{};
					.[$lib|libkey] = $lib
				)
				| {libraries: [.[]]}' \
				"$versionJson" "$vanillaLib" > "$newLib"

			log "INFO" "version.sh:install" "Installing game libraries..."
			installLib "$newLib" "libraries"
			classpath=$outputCp
			command -p rm "$newLib"

			client="libraries/${procArgs[$newIndex]}"

			local tempArgs
			mapfile -t tempArgs < <(jq -r '.arguments.jvm[]' "$versionJson")
			for (( i=0; i<${#tempArgs[@]}; i++ )); do
				tempArgs[i]=$(trimCr "${tempArgs[i]}")
			done
			for (( i=0; i<${#tempArgs[@]}; i++ )); do
				if [ "${tempArgs[i]}" == "-p" ]; then
					newIndex=$((i+1))
					break
				fi
			done
			tempArgs[newIndex]=${tempArgs[newIndex]//'${library_directory}'/"libraries"}
			tempArgs[newIndex]=${tempArgs[newIndex]//'${classpath_separator}'/"${cmdSeparator}"}
			mapfile -td "${cmdSeparator}" CPInAnArray <<< "$classpath"
			mapfile -td "${cmdSeparator}" delete <<< "${tempArgs[$newIndex]}"
			delete+=("versions/$inheritedVers/$inheritedVers.jar")
			for target in "${delete[@]}"; do
				target=$(trimCr "$target")
				for (( i=0; i<${#CPInAnArray[@]}; i++ )); do
					CPInAnArray[i]=$(trimCr "${CPInAnArray[i]}")
					if [ "${CPInAnArray[i]}" == "$target" ]; then
						unset 'CPInAnArray[i]'
					fi
				done
			done
			local new=()
			for e in "${CPInAnArray[@]}"; do
				[[ -n "$e" ]] && new+=("$e")
			done
			IFS="${cmdSeparator}" classpath="${new[*]}"
			classpath=$(trimCr "$classpath")
			unset -v new
			unset -v CPInAnArray
			unset -v tempArgs
			unset -v newIndex
	esac

	if [ "$modloader" == "vanilla" ]; then
		mkdir -p SHlauncher/log4jconf
		read -r url sha1 name < <(jq -r '.logging.client.file | . as $log | "\($log.url) \($log.sha1) \($log.id)"' "$versionJson")
		name=$(trimCr "$name")
		if [ "$name" != "null" ] && [ "$name" != "" ]; then 
			if ! [[ -f "SHlauncher/log4jconf/$name" ]]; then
				echo "Downloading log4j config file..."
				log "INFO" "version.sh:install" "Downloading log4j configuration file at \"$url\""
				curl -so "SHlauncher/log4jconf/$name" "$url" &>/dev/null
				local_sha1=$(sha1sum "SHlauncher/log4jconf/$name" | cut -d' ' -f1)
				if [ "$local_sha1" != "$sha1" ]; then
					printf "${YELLOW}Error: The newly downloaded log4j config file is corrupted\n"
					log "ERROR" "version.sh:install" "Install aborted. The configuration file is invalid (hash check failed)"
					printf "${RED}Error is non recoverable : please retry${RESET}\n"
					return 1
				fi
				echo "Patching log4jconf"
				sed -i 's/<LegacyXMLLayout \/>/<PatternLayout pattern=\"\[%d{HH:mm:ss}\] \[%t\/%level\]: %msg{nolookups}%n\" \/>/g' "./SHlauncher/log4jconf/$name"
			fi
		else
			printf "${GREEN}Log4J configuration file is unrequired for this version${RESET}\n"
		fi
		printf "${GREEN}Finished downloading log4j config file${RESET}\n"

		echo "Downloading assets"
		if ! ${parameter[debugSkipAssets]}; then
			assetDir="$MCdir/assets"
			mkdir -p "$assetDir"
			mkdir -p "$assetDir/objects"
			mkdir -p "$assetDir/indexes"
			read -r id url < <(jq -r '. | "\(.assetIndex.id) \(.assetIndex.url)"' "$versionJson")
			#printf '%q\n' -- note pour plus tard
			curl --fail --retry 5 --retry-delay 2 -s "$(trimCr "$url")"  | jq '.' > "$assetDir/indexes/$id.json"

			function parallelDownload() {
				shopt -s nullglob
				local threadNumber=$1
				local targetFunc=$2
				local file=$3
				local standardErr=$4
				local standardCrash=$5

				local tmpdir
				tmpdir=$(mktemp -d)
				# shellcheck disable=SC1091
				trap 'kill "${pids[@]}";rm -r "$tmpdir";shopt -u nullglob;echo ""; source "$dir"/.minecraft/SHlauncher/crashHandler.sh SIGINT; exit 2' INT

				if [ "$standardErr" == "" ]; then
					standardErr="$tmpdir/err.progress"
				fi
				if [ "$standardCrash" == "" ]; then
					standardCrash="$tmpdir/crash.progress"
				fi
				touch "$standardErr"
				touch "$standardCrash"

				log "INFO" "version.sh:install:parallelDownload" "Starting job with $threadNumber threads"
				printf "${BLUE_BOLD}Starting job with %s threads${RESET}\n" "$threadNumber"

				# shellcheck disable=SC2194
				case "" in
					"$threadNumber" | "$targetFunc" | "$file")
						printf "${YELLOW_BOLD}[BUG] function parallelDownload require 3 entry argument but some are missing! Check the log file for more info\n" >&2
						log "ERROR" "version.sh:install:parallelDownload" "BUG : Some argument are missing. Expected argument: threadNumber \"$threadNumber\", targetFunc \"$targetFunc\", file \"$file\""
						shopt -u nullglob
						return 2
					;;
					*)
						true
				esac

				local goal
				goal=$(wc -l < "$file")
				log "INFO" "version.sh:install:parallelDownload" "goal is $goal"
				split --numeric-suffixes=1 --suffix-length=1 -n l/"$threadNumber" "$file" "$tmpdir/worker_"
				pids=()
				for i in $(seq 1 "$threadNumber"); do
					"${targetFunc}" "$i" "$tmpdir/worker_$i" "$standardErr" "$standardCrash" &
					pids+=($!)
					log "DEBUG" "version.sh:install:parallelDownload" "launched ${targetFunc} successfully"
				done
				log "DEBUG" "version.sh:install:parallelDownload" "list of PIDs : ${pids[*]}"
				local finished=0
				local total=0

				while [ "$finished" -lt "$threadNumber" ]; do
					finished=0
					for f in "$tmpdir"/worker_*.done; do
						[[ -e $f ]] && ((finished++))
					done

					total=0
					for f in "$tmpdir"/progress.*; do
						total=$(( total+"$(wc -l < "$f")" ))
						if [ -s "$standardErr" ]; then
							printf "${YELLOW}%s${RESET}\n" "$( <"$standardErr" )"
							log "WARN" "version.sh:install:parallelDownload" "Error caught from worker (non-fatal): $( <"$standardErr" )"
							echo "" > "$standardErr"
						fi

						if [ -s "$standardCrash" ]; then
							printf "${YELLOW}%s${RESET}\n" "$( <"$standardCrash" )"
							log "ERROR" "version.sh:install:parallelDownload" "Installation aborted, crash caught from worker : $( <"$standardCrash" )"
							printf "${RED}Error is non-recoverable. Please retry${RESET}\n"
							kill "${pids[@]}"
							wait "${pids[@]}" 2>/dev/null
							echo "" > "$standardCrash"
							rm -r "${tmpdir:?}"
							# shellcheck disable=SC1091
							trap 'echo ""; source "$dir"/.minecraft/SHlauncher/crashHandler.sh SIGINT; exit 2' INT
							shopt -u nullglob
							return 1
						fi
					done
					printf "${GREEN}Downloaded %s out of %s${RESET}\n" "$total" "$goal assets"
					sleep 0.2
				done
				printf "${GREEN}Job completed successfully${RESET}\n"
				log "INFO" "version.sh:install:parallelDownload" "Finished job"
				wait "${pids[@]}" 2>/dev/null
				rm -r "${tmpdir}"
				# shellcheck disable=SC1091
				trap 'echo ""; source "$dir"/.minecraft/SHlauncher/crashHandler.sh SIGINT; exit 2' INT
				shopt -u nullglob
			}

			function downloadWorker() {
				local id=$1
				local file=$2
				local standardErr=$3
				local standardCrash=$4

				while read -r sha1; do
					sha1=$(trimCr "$sha1")
					lilsha=${sha1:0:2}
					path="$lilsha/$sha1"
					if [[ -f "$assetDir/objects/$path" ]]; then
						local_sha1=$(sha1sum "$assetDir/objects/$path" | cut -d' ' -f1)
						if [ "$local_sha1" == "$sha1" ]; then
							echo "OK" >> "$tmpdir/progress.$id"
							continue
						else
							echo "Invalid hash of \"${sha1}\", redownload required" > "$standardErr"
						fi
					fi
					mkdir -p "$assetDir/objects/$lilsha"
					curl --fail --retry 5 --retry-delay 2 -so "$assetDir/objects/$path" "https://resources.download.minecraft.net/$lilsha/$sha1"
					local_sha1=$(sha1sum "$assetDir/objects/$path" | cut -d' ' -f1)
					if [ "$local_sha1" != "$sha1" ]; then
						echo "Invalid hash for \"${sha1}\" !" > "$standardCrash"
						return 1
					fi
					echo "OK" >> "$tmpdir/progress.$id"
				done < "$file"
				touch "$tmpdir/worker_$id.done"
			}
			
			jq -r '.objects[].hash' \
				"$assetDir/indexes/$id.json" > assets.todo
			
			log "INFO" "version.sh:install" "Launching asset parallel download"
			if ! parallelDownload "${Sett[ThreadUsedOnAssetDownload]}" downloadWorker ./assets.todo; then
				return "$?"
			fi
			rm ./assets.todo
		else # fin dsa
			printf "${YELLOW}DebugSkipAssets on, asset download skipped${RESET}\n"
			log "WARN" "version.sh:install" "Asset download was skipped due to a debug action, final JSON may be broken"
		fi
	else # c'est la fin du vanilla only
		printf "${GREEN_BOLD}Skipping asset download as it is unrequired for this version${RESET}\n"
		log "INFO" "version.sh:install" "Assets download is unrequired when downloading a modloader"
	fi

	echo "Saving progress"

	# comparaison de version
	version_gte() { printf '%s\n%s\n' "$2" "$1" | sort -V -C; }
	version_lte() { printf '%s\n%s\n' "$1" "$2" | sort -V -C; }

	evaluateArgEntry() {
		local entry="$1"
		local os_name="$2"
		local os_version="$3"
		local arch="$4"

		local type; type=$(echo "$entry" | jq -r 'type')

		log "DEBUG" "version.sh:install:evaluateArgEntry" "Evaluating $entry"

		if [[ "$type" == "string" ]]; then
			# String simple = toujours incluse
			echo "$entry" | jq -r '.'
			return
		fi

		# C'est un objet avec rules et value
		local rules; rules=$(echo "$entry" | jq '.rules // []')
		local rules_count; rules_count=$(echo "$rules" | jq 'length')

		if [[ "$rules_count" -eq 0 ]]; then
			# Objet sans rules = toujours inclus
			echo "$entry" | jq -r '.value | if type == "array" then .[] else . end'
			return
		fi

		# Évaluer les rules
		local state="false"

		while IFS= read -r rule; do
			local action; action=$(echo "$rule" | jq -r '.action')
			local rule_os_name; rule_os_name=$(echo "$rule" | jq -r '.os.name // ""')
			local rule_os_arch; rule_os_arch=$(echo "$rule" | jq -r '.os.arch // ""')
			local range_min; range_min=$(echo "$rule" | jq -r '.os.versionRange.min // ""')
			local range_max; range_max=$(echo "$rule" | jq -r '.os.versionRange.max // ""')

			local match=true

			# Vérif os.name
			if [[ -n "$rule_os_name" && "$rule_os_name" != "$os_name" ]]; then
				match=false
			fi

			# Vérif os.arch
			if [[ -n "$rule_os_arch" && "$rule_os_arch" != "$arch" ]]; then
				match=false
			fi

			# Vérif versionRange (seulement si os_name correspond déjà)
			if [[ "$match" == "true" && -n "$range_min" ]]; then
				if ! version_gte "$os_version" "$range_min"; then match=false; fi
			fi
			if [[ "$match" == "true" && -n "$range_max" ]]; then
				if ! version_lte "$os_version" "$range_max"; then match=false; fi
			fi

			if [[ "$match" == "true" ]]; then
				[[ "$action" == "allow" ]] && state="true" || state="false"
			fi

		done < <(echo "$rules" | jq -c '.[]')

		if [[ "$state" == "true" ]]; then
			echo "$entry" | jq -r '.value | if type == "array" then .[] else . end'
		fi
	}

	# Détection du format
	hasArgs=$(jq 'has("arguments")' "$versionJson")
	if [[ "$hasArgs" == "true" ]]; then
		jsonFormatIsModern=true  # 1.13+
	else
		jsonFormatIsModern=false # avant 1.13 : (minecraftArguments)
	fi

	log "INFO" "version.sh:install" "Saving version..."

	jvmArgs=()
	case $modloader in 
		"vanilla")
			jvmArgs+=("$(jq -r '.logging.client.argument' "$versionJson")")
			while IFS= read -r entry; do
				while IFS= read -r val; do
					jvmArgs+=("$val")
				done < <(evaluateArgEntry "$entry" "$(detect_os)" "" "$(detect_arch)")
			done < <(jq -c '((.arguments["default-user-jvm"] // []) + (.arguments.jvm // []))[]' "$versionJson")
			delete=("-Xms2G" "-Xmx4G")
			for target in "${delete[@]}"; do
				for i in "${!jvmArgs[@]}"; do
					jvmArgs[i]=$(trimCr "${jvmArgs[i]}")
					if [ "${jvmArgs[i]}" == "$target" ]; then
						unset 'jvmArgs[i]'
					fi
				done
			done
			runtime="$(jq -r '.javaVersion.majorVersion // 8' "$versionJson")"
			if $jsonFormatIsModern; then
				gameArgsJson=$(jq '
					.arguments.game
					| map(select(type == "string"))
				' "$versionJson")
			else
				gameArgs=$(jq -r '.minecraftArguments' "$versionJson")
				read -ra gameArgs <<< "$gameArgs"
				gameArgsJson="[]"
				for current in "${gameArgs[@]}"; do
					gameArgsJson=$(echo "$gameArgsJson"| jq --arg current "$current" '. += [$current]') 
				done
				# shellcheck disable=SC2016
				read -ra jvmArgs <<< '-Djava.library.path=${natives_directory} -Dminecraft.launcher.brand=${launcher_name} -Dminecraft.launcher.version=${launcher_version} -Dlog4j.configurationFile=${path} -cp ${classpath} ${mainClass}'
				jvmArgsJson=$(printf '%s\n' "${jvmArgs[@]}" | jq -R . | jq -s .)
			fi
			log "INFO" "version.sh:install" "Ready to save $targetVers.json"
		;;
		"neoforge")
			while IFS= read -r entry; do
				while IFS= read -r val; do
					jvmArgs+=("$val")
				done < <(evaluateArgEntry "$entry" "$(detect_os)" "" "$(detect_arch)")
			done < <(jq -c '.arguments.jvm[]' "$versionJson")

			gameArgsJson=$(jq '.arguments.game' "$versionJson")
			log "INFO" "version.sh:install" "Ready to save $fullModLoaderVers.json"
	esac

	jvmArgsJson=$(printf '%s\n' "${jvmArgs[@]}" | jq -Rs 'split("\n")[:-1]') # jvmArgs pose des \r partout, pas un problème pour le moment

	mainClass="$(jq -r '.mainClass // empty' "$versionJson")"
	versionType=$(jq -r '.type' "$versionJson")

	
	# aled
	case $modloader in
		"vanilla")
			jq -n \
			--arg targetVers "$targetVers" \
			--arg versionType "$versionType" \
			--arg classpath "$classpath" \
			--argjson gameArgs "$gameArgsJson" \
			--argjson jvmArgs "$jvmArgsJson" \
			--arg runtime "$runtime" \
			--arg id "$id" \
			--arg mainClass "$mainClass" \
			--arg log4jName "$name" \
			'{
				"name": $targetVers,
				"modloader": "vanilla",
				"versionType": $versionType,
				"classpath": $classpath,
				"gameArgs": $gameArgs,
				"jvmArgs": $jvmArgs,
				"runtime": $runtime,
				"assetIndexPath": ("./assets/indexes/" + $id + ".json"),
				"assetIndexId": $id,
				"assetRoot": "./assets/",
				"mainClass": $mainClass,
				"nativesDir": ("natives"),
				"log4jconf": ("SHlauncher/log4jconf/" + $log4jName),
			}' > "./SHlauncher/versions/$targetVers.json"
		;;
		"neoforge")
			jq -n \
			--arg name "$fullModLoaderVers" \
			--arg inheritFrom "$inheritedVers" \
			--arg versionType "$versionType" \
			--arg moddedCp "$classpath" \
			--argjson moddedGameArgs "$gameArgsJson" \
			--argjson moddedJvmArgs "$jvmArgsJson" \
			--arg mainClass "$mainClass" \
			'{
				"name": $name,
				"modloader": "neoforge",
				"inheritsFrom": $inheritFrom,
				"versionType": $versionType,
				"moddedCp": $moddedCp,
				"moddedGameArgs": $moddedGameArgs,
				"moddedJvmArgs": $moddedJvmArgs,
				"mainClass": $mainClass
			}' > "./SHlauncher/versions/neoforge-$fullModLoaderVers.json"
	esac
}

list() {
	case $1 in
		"b4" | "b4release")
			if [ "$modloader" != "vanilla" ]; then
				printf "${YELLOW}Using a modded instance for alpha and beta version of the game is unsupported"
				return 2
			fi
			printf -- "|=============================|\n"
			printf "| %-12s | %-12s |\n" "VERSION" "TYPE"
			printf -- "|-----------------------------|\n"
			while read -r id type; do
				id=$(trimCr "$type")
				type=$(trimCr "$type")
				log "DEBUG" "version.sh:list" "Checking version \"$id\""
				if [ "$toGrep" == "" ]; then
					printf "| %-12s | %-12s |\n" "$id" "$type"
				else
					printf "| %-12s | %-12s |\n" "$id" "$type" | grep "$toGrep"
				fi
			done < <(jq -r '.versions[] | select(.type == "old_alpha" or .type == "old_beta") | "\(.id) \(.type)"' "$SHdir/manifest/vanilla_version_manifest.json")
			printf -- "|=============================|\n"
			unset -v toGrep
		;;
		"installed")
			cd "$SHdir/versions" || return 255
			if [ "$(ls)" == "" ]; then printf "${YELLOW}No versions are installed yet${RESET}\n"; fi
			for vers in *.json; do
				log "DEBUG" "version.sh:list" "Checking version \"$vers\""
				read -r name versionType runtime assetIndex currentModloader <<< "$(jq -r '"\(.name) \(.versionType) \(.runtime?) \(.assetIndexId?) \(.modloader)"' "$vers")"
				if [ "$currentModloader" = "null" ]; then currentModloader="vanilla"; fi
				if [ "$currentModloader" = "$modloader" ]; then
					if [ "$modloader" != "vanilla" ]; then
						inheritance=$(jq -r '.inheritsFrom' "$vers")
						runtime=$(jq -r '.runtime' "$inheritance.json")
						assetIndex=$(jq -r '.assetIndexId' "$inheritance.json")
					fi
					printf "${BLUE_BOLD}$name :${RESET}\n"
					echo " - Modloader: $currentModloader"
					echo " - Java runtime: $runtime"
					echo " - Version type: $versionType"
					echo " - Uses assetIndex $assetIndex"
				fi
			done
			cd "$MCdir" || return 255
		;;
		"latest")
			if [ "$modloader" == "vanilla" ]; then
				printf -- "|================================|\n"
				printf "| %-15s | %-12s |\n" "VERSION" "TYPE"
				printf -- "|--------------------------------|\n"
				while IFS= read -r object; do
					IFS='|' read -r type id < <(jq -r '"\(.key)|\(.value)"' <<- EOF
					$object
					EOF
					)
					printf "| %-15s | %-12s |\n" "$id" "$type"
				done < <(jq -c '.latest | to_entries[]' "$SHdir/vanilla_version_manifest.json")
				printf -- "|================================|\n"
			else
				printf "${YELLOW}Viewing the latest modded version per minecraft version is currently unsupported${RESET}\n"
			fi
			unset -v toGrep
		;;
		"snap" | "snapshot")
			printf -- "|=============================|\n"
			printf "| %-12s | %-12s |\n" "VERSION" "TYPE"
			printf -- "|-----------------------------|\n"
			while read -r id type; do
				log "DEBUG" "version.sh:list" "Checking version \"$id\""
				type=$(trimCr "$type")
				if [ "$toGrep" == "" ]; then
					printf "| %-12s | %-12s |\n" "$id" "$type"
				else
					printf "| %-12s | %-12s |\n" "$id" "$type" | grep "$toGrep"
				fi
			done < <(jq -r '.versions[] | select(.type == "snapshot") | "\(.id) \(.type)"' "$SHdir/manifests/vanilla_version_manifest.json")
			printf -- "|=============================|\n"
		;;
		"all")
			if [ "$modloader" == "vanilla" ]; then
				printf -- "|=============================|\n"
				printf "| %-12s | %-12s |\n" "VERSION" "TYPE"
				printf -- "|-----------------------------|\n"
				while read -r id type; do
					log "DEBUG" "version.sh:list" "Checking version \"$id\""
					type=$(trimCr "$type")
					if [ "$toGrep" == "" ]; then
						printf "| %-12s | %-12s |\n" "$id" "$type"
					else
						printf "| %-12s | %-12s |\n" "$id" "$type" | grep "$toGrep"
					fi
				done < <(jq -r '.versions[] | "\(.id)  --  \(.type)"' "$SHdir/manifest/vanilla_version_manifest.json")
				unset -v toGrep
			elif [ "$modloader" == "neoforge" ]; then
				printf -- "|==========================================================|\n"
				printf "| %-12s | %-23s | %-15s |\n" "VERSION" "MODLOADER VERSION" "TYPE"
				printf -- "|----------------------------------------------------------|\n"
				mapfile -t content < <(jq -r '.[]' "$SHdir/manifests/neoforge_version_manifest.json")

				for (( i=0; i<${#content[@]}; i++ )); do
					content[i]=$(trimCr "${content[$i]}")
					IFS='.' read -ra versPart <<< "${content[i]}"
					log "DEBUG" "version.sh:list" "Checking version \"${versPart[*]}\""
					if [[ "${versPart[-1]}" =~ beta ]]; then
						versType="beta"
						#versPart[-1]=${versPart[-1]//'-beta'/}
					elif [[ "${versPart[-1]}" =~ [[:alpha:]] ]]; then
						versPart[-2]="${versPart[-2]}${versPart[-1]}"
						unset "versPart[-1]"
						versType="snapshot_alpha"
					else
						versType="release"
					fi

					if [ "$versType" == "snapshot_alpha" ]; then
						mcVers="${versPart[0]}.${versPart[1]}.${versPart[2]}"
						modlVers="${versPart[3]}"
						log "DEBUG" "version.sh:list" "Resolved version to pattern <0>.<1>.<2> <3>"
					elif [ "${#versPart[@]}" -eq 4 ]; then
						mcVers="${versPart[0]}.${versPart[1]}.${versPart[2]}"
						modlVers=${versPart[3]}
						log "DEBUG" "version.sh:list" "Resolved version to pattern <0>.<1>.<2> <3>"
					elif [ "${#versPart[@]}" -lt 2 ]; then
						printf "${YELLOW_BOLD}[BUG] Invalid version read from neoforge's manifest, skipping %s${RESET}\n" "${versPart[$@]}"
						log "ERROR" "version.sh:list" "Invalid version \"${versPart[*]}\", skipping"
						continue
					else
						mcVers="1.${versPart[0]}.${versPart[1]}"
						modlVers=${versPart[2]}
						log "DEBUG" "version.sh:list" "Resolved version to pattern 1.<0>.<1> <2>"
					fi
					if [ "$toGrep" == "" ]; then
						printf "| %-12s | %-23s | %-15s |\n" "$mcVers" "$modlVers" "$versType"
					else
						printf "| %-12s | %-23s | %-15s |\n" "$mcVers" "$modlVers" "$versType" | grep "$toGrep"
					fi
				done
				printf -- "|==========================================================|\n"
				unset -v toGrep
			fi
		;;
		"")
			if [ "$modloader" == "vanilla" ]; then
				printf -- "|================================|\n"
				printf "| %-12s | %-15s |\n" "VERSION" "TYPE"
				printf -- "|--------------------------------|\n"
				while read -r id type; do
					log "DEBUG" "version.sh:list" "Checking version \"$id\""
					type=$(trimCr "$type")
					if [ "$toGrep" == "" ]; then
						printf "| %-12s | %-15s |\n" "$id" "$type"
					else
						printf "| %-12s | %-15s |\n" "$id" "$type" | grep "$toGrep"
					fi
				done < <(jq -r '.versions[] | select(.type == "release") | "\(.id) \(.type)"' "$SHdir/manifests/vanilla_version_manifest.json")
				printf -- "|================================|\n"
				unset -v toGrep
			elif [ "$modloader" == "neoforge" ]; then
				printf -- "|==========================================================|\n"
				printf "| %-12s | %-23s | %-15s |\n" "VERSION" "MODLOADER VERSION" "TYPE"
				printf -- "|----------------------------------------------------------|\n"
				mapfile -t content < <(jq -r '.[] | select(. | contains("-beta") | not)' "$SHdir/manifests/neoforge_version_manifest.json")

				for (( i=0; i<${#content[@]}; i++ )); do
					content[i]=$(trimCr "${content[$i]}")
					IFS='.' read -ra versPart <<< "${content[i]}"
					if [[ "${versPart[-1]}" =~ [[:alpha:]] ]]; then
						versPart[-2]="${versPart[-2]}${versPart[-1]}"
						unset "versPart[-1]"
						isSnapshotAlpha=true
					else
						isSnapshotAlpha=false
					fi

					if $isSnapshotAlpha; then
						mcVers="${versPart[0]}.${versPart[1]}.${versPart[2]}"
						modlVers=${versPart[3]}
						log "DEBUG" "version.sh:list" "Resolved version to pattern <0>.<1>.<2> <3>"
						versType="snapshot_alpha"
					elif [ "${#versPart[@]}" -eq 4 ]; then
						mcVers="${versPart[0]}.${versPart[1]}.${versPart[2]}"
						modlVers=${versPart[3]}
						log "DEBUG" "version.sh:list" "Resolved version to pattern <0>.<1>.<2> <3>"
						versType="release"
					elif [ "${#versPart[@]}" -lt 2 ]; then
						printf "${YELLOW_BOLD}[BUG] Invalid version read from neoforge's manifest, skipping %s${RESET}\n" "${versPart[$@]}"
						log "ERROR" "version.sh:list" "Invalid version \"${versPart[*]}\", skipping"
						continue
					else
						mcVers="1.${versPart[0]}.${versPart[1]}"
						modlVers=${versPart[2]}
						log "DEBUG" "version.sh:list" "Resolved version to pattern 1.<0>.<1> <2>"
						versType="release"
					fi
					if [ "$toGrep" == "" ]; then
						printf "| %-12s | %-23s | %-15s |\n" "$mcVers" "$modlVers" "$versType"
					else
						printf "| %-12s | %-23s | %-15s |\n" "$mcVers" "$modlVers" "$versType" | grep "$toGrep"
					fi
				done
				printf -- "|==========================================================|\n"
				unset -v toGrep
			fi
		;;
		*)
			echo "Unknown filters or parameters:"
			paramScreenFiller
	esac
}

function remove() {
	targetVers=$1
	modlVers=$2
	if [ "$modloader" = "vanilla" ]; then
		if [[ -d "./versions/$targetVers" ]]; then
			log "INFO" "version.sh:remove" "Deleting version $targetVers"
			printf "${RED}Deleting version %s, you can reinstall it by executing the command \"version install %s\"${RESET}\n" "$targetVers" "$targetVers"
			printf "${RED}Please note that modded versions of the game usually relies on vanilla versions to work properly${RESET}\n" "$targetVers" "$targetVers"
			printf "${YELLOW}Note, the libraries and the assets used by this version are not deleted as they can be used for other versions as well${RESET}\n"
			command -p rm -r -- "./versions/$targetVers"
			command -p rm -- "./SHlauncher/versions/$targetVers.json"
			printf "${BLUE}Don't forget to delete the instances that uses this version${RESET}\n"
		else
			printf "${RED_BOLD}This version doesn't exist or is not installed${RESET}\n"
		fi
	elif [ "$modloader" = "neoforge" ]; then
		# shellcheck disable=SC2001
		trunkMcVers=$(echo "$targetVers" | sed 's/^1\.//')
		fullModLoaderVers="${trunkMcVers}.${modlVers}"
		if [[ -d "./versions/neoforge-$fullModLoaderVers" ]]; then
			log "INFO" "version.sh:remove" "Deleting version $fullModLoaderVers"
			printf "${RED}Deleting version neoforge-%s, you can reinstall it by executing the command \"version install neoforge %s %s\"${RESET}\n" "$fullModLoaderVers" "$targetVers" "$modlVers"
			printf "${YELLOW}Note, the libraries and the assets used by this version are not deleted as they can be used for other versions as well${RESET}\n"
			command -p rm -r -- "./versions/neoforge-$fullModLoaderVers"
			command -p rm -- "./SHlauncher/versions/neoforge-$fullModLoaderVers.json"
			printf "${BLUE}Don't forget to delete the instances that uses this version${RESET}\n"
		else
			printf "${RED_BOLD}This version doesn't exist or is not installed${RESET}\n"
		fi
	fi
}

function helpPage() {
	printf "${CYAN}Usage : ${RESET}version [-m/-v] <instruction> [<args...>]\n"
	printf "Manages the installations of the different minecraft versions\n"
	printf "${CYAN}Argument list${RESET} :\n"
	printf " - list [-m/-v] [<instruction>] : List every version available. Additional instruction may be provided which can be : \n"
	printf "       - (nothing) : Prints every release version\n"
	printf "       - snapshot : Prints every snapshot version\n"
	printf "       - b4release : Prints every alpha and beta version\n"
	printf "       - all : Prints every (snapshot, alpha and beta included) version\n"
	printf "       - installed : Prints every version that are currently installed\n"
	printf " - install [-m] <vanilla version> [<modloader version>] : Install the specified version (some version might not be supported)\n"
	printf " - remove [-m] <vanilla version> [<modloader version>] : Remove the specified version. This instruction is quite inefficient.\n"
	printf " - help : Print this help\n"
	printf "\-m\" | \"--modloader\" : Specifies the concerned modloader. Can be vanilla, Forge, Neoforge, Fabric or Quilt\n"
	printf "\"-v\" | \"--version\" : Select a version \"filter\" (used with the grep command)\n"
}

function Main() {
	case $1 in
		"list")
			shift
			list "$@"
		;;
		"install")
			shift
			install "$@"
		;;
		"remove" | "delete")
			shift
			remove "$@"
		;;
		"help")
			helpPage
		;;
		"")
			printf "${RED_BOLD}Require an argument, type \"version help\"${RESET}\n"
		;;
		*)
			printf "${RED_BOLD}Unknown argument : $1${RESET}\n"
	esac
}

mkdir -p "$MCdir/versions"
mkdir -p "$MCdir/libraries"
mkdir -p "$MCdir/natives"

mkdir -p "$SHdir/versions"
mkdir -p "$SHdir/log4jconf"

parameter[debugSkipAssets]=false
parameter[modloader]=vanilla

declareArgs debugSkipAssets NoShort flag
declareArgs modloader m value
declareArgs version v value

if ! globalArgHandler "$@"; then
	return 1
fi

modloader=${parameter[modloader]}
toGrep=${parameter[version]}

case $modloader in
	"vanilla" | "Vanilla")
		modloader="vanilla"
	;;
	"forge" | "Forge")
		modloader="forge"
	;;
	"neoforge" | "Neoforge" | "NeoForge" | "neoForge")
		modloader="neoforge"
	;;
	"fabric" | "Fabric")
		modloader="fabric"
	;;
	"quilt" | "Quilt")
		modloader="quilt"
	;;
	*)
		printf "${RED}Unknown modloader, the supported modloaders are Vanilla, Forge, Fabric, Neoforge and Quilt${RESET}\n"
		return 1
esac

log "INFO" "version.sh" "version.sh called with instructions ${instructions[*]}"

Main "${instructions[@]}"

unset parameter
declare -gA parameter