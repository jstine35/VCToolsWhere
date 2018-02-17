#!/bin/bash
#
# Latest version can probably be found here:
#    https://github.com/jstine35/VCToolsWhere
#

diag_switch=

DIAGNOSTIC=0
CYGPATH_AS_WIN=0
SHOW_HELP=0
CLI_ERROR_ABORT=0

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
    -w|--win|--windows)
    CYGPATH_AS_WIN=1
    shift
    ;;
    -u|--unix)
    CYGPATH_AS_WIN=0
    shift
    ;;
    --host)
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

if [[ "$CLI_ERROR_ABORT" -eq "1" ]]; then
    exit 1
fi

if [[ "$SHOW_HELP" -eq "1" ]]; then
    echo "Returns full path to latest version of msbuild.exe available on the system."
    echo
    echo "  --unix|-u       print result using mingw (unix) style path (/c/default)"
    echo "  --win|-w        print result using windows-style path (C:\\mydir)"
    echo "  --diag          enable verbose diagnostic log output"
    exit 0
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
	msbuild_path=$(readlink -f "$vspath/MSBuild/${vsver}.0/bin")

elif [[ -z "$vspath" || "$vswhich_err" -eq "1" ]]; then
    # vswhich.sh failed due to vswhere.exe not found, or no visual studio products found
    # So let's look for legacy visual studio...
	# sadly, there's no actual way to know where MSBuild is installed on older systems without 
	# doing registry inspection.  But then 99.995% case is that it's installed into:
    #    %PROGRAMFILES(X86)%/MSBuild/xx.x/
    # ... where the xx.x are version numbers.

    [ "$DIAGNOSTIC" -eq "1" ] && diagecho "(diag) vswhere.exe not found! Fall back on legacy MSVC 2010->2015 check!"
	PROGRAMFILESX86=${PROGRAMFILESX86:-$(cmd //C echo "%ProgramFiles(x86)%" 2>/dev/null)}
	searchdir=$PROGRAMFILESX86
	if [[ ! -d "$searchdir" ]]; then
		searchdir="$PROGRAMFILES"
	fi

    # enumerate all the directories in the folder, sort then and then check in descending order
    # for the first one that actually has msbuild.exe...
	searchdir=$(cygpath "$searchdir")
	msbuild_inorder=( $(printf "%s\n" "$searchdir/MSBuild"/??.? | sort -r) )
	
    # sometimes uninstallers leave dirs behind which are empty, so test explicitly for msbuild.exe
	IFS=$'\n'
	for i in ${msbuild_inorder[@]}; do
		msbuild_path="$i/bin/msbuild.exe"
		[ -e "$i" ] && break
	done
	unset IFS

else
    # vswhich.sh failed due to programmer error or invalid cli options or invalid
    # instances of vswhere.exe.  All of these are bad mojo.
    
    >&2 echo "An internal error occurred while running vswhich.sh, result=$?"
    >&2 echo "Specify --diag when running this command for more information."
    exit 2
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