# the rest

function detectArch() {
	case "$(uname -m)" in
		i386|i686)   echo "x86"     ;;
		x86_64)      echo "x86_64"  ;;
		aarch64)     echo "aarch64" ;;
		*)           "$(uname -m)"  ;;
	esac
}