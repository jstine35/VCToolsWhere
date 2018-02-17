#!/bin/bash
#
# Latest version can probably be found here:
#    https://github.com/jstine35/VCToolsWhere
#

diag_switch=

DIAGNOSTIC=0
SHOW_TOOLS_VERSION_ONLY=0
CYGPATH_AS_WIN=0
SHOW_HELP=0
CLI_ERROR_ABORT=0
dir_host=

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --diagnostic|--diag)
    DIAGNOSTIC=1
    diag_switch=--diag
    shift
    ;;
    --toolsver)
    SHOW_TOOLS_VERSION_ONLY=1
    shift
    ;;
    --host=*)
	param=${key#=}
	dir_host=$param
	if [[ "$param" == "x86" ]]; then dir_host=amd64; fi
	if [[ "$param" == "x64" ]]; then dir_host=.;     fi
    shift
    ;;
    -w|--win|--windows)
    CYGPATH_AS_WIN=1
    shift
    ;;
    -u|--unix)
    CYGPATH_AS_WIN=0
    shift
    ;;
    --target|--host)
    >&2 echo "Switch $key requires a parameter assignment."
    >&2 echo "Example: $key=x64"
    CLI_ERROR_ABORT=1
    ;;
    --help)
    SHOW_HELP=1
    shift
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

if [[ -z "$dir_host" ]]; then
	if   [[ "$HOSTTYPE" -eq "x86_64" ]]; then dir_host=amd64
	elif [[ "$HOSTTYPE" -eq "x86_32" ]]; then dir_host=.
	else
		>&2 echo "Unknown host system/OS type '$HOSTTYPE"
		>&2 echo "Expected either 'x86_64' or 'x86_32'"
		exit 1
	fi
fi


if [[ "$CLI_ERROR_ABORT" -eq "1" ]]; then
    exit 1
fi

set -- "${POSITIONAL[@]}" # restore positional parameters

me=$(basename "${BASH_SOURCE[0]}")
mydir=$(dirname $(readlink -f ${BASH_SOURCE[0]}))


# route diagnostic into stderr so that the stdout result is still valid/parsable by script.
diagecho() { >&2 echo $@; }

vspath="$("$mydir/vswhich.sh" $diag_switch --install-path)"
vswhich_err="$?"

if [[ -n "$vspath" && "$vswhich_err" -eq "0" ]]; then
	vsver=$("$mydir/vswhich.sh" --install-version | cut -d'.' -f1)
	msbuild_path="$vspath/MSBuild/${vsver}.0/bin/$dir_host/msbuild.exe"

elif [[ -z "$vspath" || "$vswhich_err" -eq "1" ]]; then
    # vswhich.sh failed due to vswhere.exe not found, or no visual studio products found
    # So let's look for legacy visual studio...
	# sadly, there's no actual way to know where MSBuild is installed on older systems without 
	# doing registry inspection.  Let's just check the common spots and then give up.

	PROGRAMFILESX86=${PROGRAMFILESX86:-$(cmd //C echo "%ProgramFiles(x86)%" 2>/dev/null)}
	searchdir=$PROGRAMFILESX86
	if [[ ! -d "$searchdir" ]]; then
		searchdir="$PROGRAMFILES"
	fi

	searchdir=$(cygpath "$searchdir")
	msbuild_inorder=( $(printf "%s\n" "$searchdir/MSBuild"/??.? | sort -r) )
	
    # sometimes uninstallers leave dirs behind which are empty, so test explicitly for msbuild.exe
	IFS=$'\n'
	for i in ${msbuild_inorder[@]}; do
		msbuild_path="$i/bin/$dir_host/msbuild.exe"
		[ -e "$i" ] && break
	done
	unset IFS

else
    # vswhich.sh failed due to programmer error or invalid cli options or invalid
    # instances of vswhere.exe.  All of these are bad mojo.
    
    >&2 echo "An internal error occurred while running vswhich.sh, result=$?"
    >&2 echo "Specify --diag when running this command for more information."
    exit 1
fi

if [[ ! -e "$msbuild_path" ]]; then
	>&2 echo "ERROR: Unable to discover the location of msbuild.exe"
	
	if [[ "$DIAGNOSTIC" -eq "1" ]]; then
		>&2 echo "This error may mean that you do not have Visual Studio installed, or that your"
		>&2 echo "installed version is not supported.  You can manually download and install a copy"
		>&2 echo "of vswhere.exe from either Microsoft/GitHub, or by using Chocolatey package manager:"
		>&2 echo ""
		>&2 echo "   $ cinst vswhere"
		>&2 echo ""
	else
		>&2 echo "Run this command with the --diagnostic switch to enable detailed reporting."
	fi
	exit 1
fi

if [[ "$CYGPATH_AS_WIN" -eq "1" ]]; then
    echo "$(cygpath -w "$msbuild_path")"
else
	echo "$msbuild_path"
fi


exit 0