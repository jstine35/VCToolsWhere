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

# As of VS 2019 msbuild reports itself as v16 but is installed into the 'MSBuild/Current' directory,
# with the v16 directory non-existent.
#
# Sigh. Reminds me of the VS2003 days, when msbuild had no version-controlled directory. History repeats.
# Here's what you're supposed to do: install it side-by-side with itself in two locations (since windows
# sucks at symlinks), one location at "default" and one at "16.0".  Now we can use it as the default and also
# explicitly when needed, without complicating the build system. Yes it uses some MBs of disk space. No, no
# one effing cares anymore about 100MB of disk space. We all have 4 versions of MSVC and a half dozen Windows 10
# SDKs installed as it is, and those are all much larger.
#
# But instead microsoft will keep switching between a generic install location and a strongly versioned one
# because in their infinitely narrow lack-of-wisdom they don't want to "waste" a couple megs of disk space.

if [[ -n "$vspath" && "$vswhich_err" -eq "0" ]]; then
    # Step 1. assume "MSBuild/Current" is the best choice
    # Step 2. fall back on explicit version location provided by vswhere.exe, which actually will clearly
    #         change every visual studio because microsoft is less capable of intelligent design than 
    #         a nakedd RNA chain bombarded by direct sun radiation trying to form its own life (a consequence
	#         of their level of succsess making it unnecessary to be competitively intelligent).
    #    (in 200 million years micorsoft might finally stop repeating the same dumb mistakes over and over.)

    msbuild_path=$(readlink -f "$vspath/MSBuild/Current/bin")
    if [[ ! -e "$msbuild_path/msbuild.exe" ]]; then
        vsver=$("$mydir/vswhich.sh" --install-version | cut -d'.' -f1)
        msbuild_path=$(readlink -f "$vspath/MSBuild/${vsver}.0/bin")
    fi
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
