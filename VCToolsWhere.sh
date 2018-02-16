#!/bin/bash
#
# Latest version can probably be found here:
#    https://github.com/jstine35/VCToolsWhere
#
# this utility is based on the following comment which I found in a batch file deep in the
# belly of the Visual Studio MSBuild / CLI toolchain:
#
# @REM The latest/default toolset is read from :
# @REM    * Auxiliary\Build\Microsoft.VCToolsVersion.default.txt
# @REM The latest/default redist directory is read from :
# @REM    * Auxiliary\Build\Microsoft.VCRedistVersion.default.txt


dir_host=
dir_target=
diag_switch=

DIAGNOSTIC=0
SHOW_TOOLS_VERSION_ONLY=0
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
    --toolsver)
    SHOW_TOOLS_VERSION_ONLY=1
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
    --target=*)
    dir_target="${key#*=}"
    shift
    ;;
    --host=*)
    dir_host="${key#*=}"
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

if [[ "$CLI_ERROR_ABORT" -eq "1" ]]; then
    exit 1
fi

set -- "${POSITIONAL[@]}" # restore positional parameters

me=$(basename "${BASH_SOURCE[0]}")
mydir=$(dirname $(readlink -f ${BASH_SOURCE[0]}))


# route diagnostic into stderr so that the stdout result is still valid/parsable by script.
diagecho() { >&2 echo $@; }

if [[ "$HOSTTYPE" == "x86_64" ]]; then
    dir_host=${dir_host:-x64}
    dir_target=${dir_target:-x64}
else
    dir_host=${dir_host:-x32}
    dir_target=${dir_target:-x32}
fi

result_msw="$("$mydir/vswhich.sh" $diag_switch -- -latest -property installationPath)"

if [[ "$?" -gt "1" ]]; then
    # vswhich.sh failed due to programmer error or invalid cli options or invalid
    # instances of vswhere.exe.  All of these are bad mojo.
    
    >&2 echo "An internal error occurred while running vswhich.sh, result=$?"
    >&2 echo "Specify --diag when running this command for more information."
    exit 1
fi

if [[ "$?" -eq "1" ]]; then
    # vswhich.sh failed due to vswhere.exe not found.
    # So let's look for legacy visual studio...
    
    [ "$DIAGNOSTIC" -eq "1" ] && diagecho "(diag) vswhere.exe not found! Fall back on legacy MSVC 2010->2013 check!"
    host=$(   [ "$dir_host"   == "x64" ] && echo ""      || echo "x86" )
    target=$( [ "$dir_target" == "x64" ] && echo "amd64" || echo "x86" )
    legacy_tools=${VS100COMNTOOLS}
    legacy_tools=${legacy_tools:-$VS110COMNTOOLS}
    legacy_tools=${legacy_tools:-$VS120COMNTOOLS}
    legacy_tools="$(cygpath "$legacy_tools")../../VC/Bin/$host$target"
    
    # sometimes uninstallers leave dirs behind which are empty, so test explicitly for a file
    # we know is in the toolchain: cl.exe
    if [[ -e "$legacy_tools/cl.exe" ]]; then
        if [[ "$SHOW_TOOLS_VERSION_ONLY" -eq "1" ]]; then
            >&2 echo "Tools version cannot be determined for legacy Visual Studio installs."
            >&2 echo "Run this command with the --diagnostic switch to enable detailed reporting."
            exit 1
        fi
        
        if [[ "$CYGPATH_AS_WIN" -eq "1" ]]; then
            echo "$(cygpath -w "$legacy_tools")"
        else
            echo "$legacy_tools"
        fi
        exit 0
    else
        >&2 echo "ERROR: Unable to discover the location of vswhere.exe"
        
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
        exit 5
    fi
fi

vspath="$(readlink -f "$result_msw")"

[ "$DIAGNOSTIC" -eq "1" ] && diagecho "vswhere.exe returned: $vspath_msw"
[ "$DIAGNOSTIC" -eq "1" ] && diagecho "readlink'd as       : $vspath"

vstoolsversionfile="$vspath/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt"

if [[ ! -e "$vstoolsversionfile" ]]; then
    >&2 echo "ERROR: VS Tools Version file was not found."
    >&2 echo ""
    >&2 echo "Expected to find: $vstoolsversionfile"
    >&2 echo "This error may mean that your Visual Studio doesn't have the VC Toolset"
    >&2 echo "selected for install."
    exit 5
fi

vstoolsver=$(cat "$vstoolsversionfile")
vstoolsbin="$vspath/VC/Tools/MSVC/$vstoolsver/bin/Host$dir_host/$dir_target"

if [[ "$SHOW_TOOLS_VERSION_ONLY" -eq "1" ]]; then
    echo $vstoolsver
    exit 0
fi

if [[ "$CYGPATH_AS_WIN" -eq "1" ]]; then
    echo "$(cygpath -w "$vstoolsbin")"
else
    echo "$vstoolsbin"
fi

exit 0