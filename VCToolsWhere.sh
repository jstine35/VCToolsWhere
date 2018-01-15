#!/bin/bash
#
# Latest version can probably be found here:
#    https://github.com/jstine35/VCToolsWhere

# TODO: auto-detect host 32 bit systems.
# TODO: make target configurable via CLI.

host=x64
target=x64

CYGPATH_AS_WIN=0
SHOW_HELP=0
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
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

me=$(basename "$0")

# this utility is based on the following comment which I found in a batch file deep in the
# belly of the Visual Studio MSBuild / CLI toolchain:

# @REM The latest/default toolset is read from :
# @REM    * Auxiliary\Build\Microsoft.VCToolsVersion.default.txt
# @REM The latest/default redist directory is read from :
# @REM    * Auxiliary\Build\Microsoft.VCRedistVersion.default.txt

# %ProgramFiles(x86)% from windows environment is not visible to BASH because it
# has invalid characters in its name.  So we must pull it from cmd.exe in a roundabout way.
# Check first if there is a $ProgramFilesx86, just in case future Git for Windows provides
# it with invalid chars stripped in the future.

if [[ -z "$ProgramFilesx86" || ! -e "$programfilesx86" ]]; then
    programfilesx86=$(cmd //C echo "%ProgramFiles(x86)%" 2>/dev/null)
fi

# vswhere.exe comes with Visual Studio Installer as of VS2017 (maybe also 2015).
# it might also be installed to the path.  Favor the one in the path first, since I prefer
# favoring situations where someone provides a vswhere.exe override that points to some specific
# location of their own preference.

vswherepath=$(which vswhere 2>/dev/null)
if [[ -z "$vswherepath" || ! -f "$vswherepath" ]]; then
    vswherepath="$programfilesx86/Microsoft Visual Studio/Installer/vswhere.exe"
fi

#try to fall back on the legacy VS2010->2013 style, which set up an environment variable like so:
if [[ ! -f "$vswherepath" ]]; then
    legacy_tools=${VS100COMNTOOLS}
    legacy_tools=${legacy_tools:-$VS110COMNTOOLS}
    legacy_tools=${legacy_tools:-$VS120COMNTOOLS}
    legacy_tools="$(cygpath "$legacy_tools")../../VC/Bin/amd64"
    
    # sometimes uninstallers leave dirs behind which are empty, so test explicitly for a file
    # we know is in the toolchain: cl.exe
    if [[ -e "$legacy_tools/cl.exe" ]]; then
        if [[ "$CYGPATH_AS_WIN" -eq "1" ]]; then
            echo "$(cygpath -w "$legacy_tools")"
        else
            echo "$legacy_tools"
        fi
        exit 0
    fi
fi

if [[ ! -f "$vswherepath" ]]; then
    2>&1 echo "ERROR: Unable to discover the location of vswhere.exe"
    2>&1 echo ""
    2>&1 echo "This error may mean that you do not have Visual Studio installed, or that your"
    2>&1 echo "installed version is not supported.  You can manually download and install a copy"
    2>&1 echo "of vswhere.exe from either Microsoft/GitHub, or by using Chocolatey package manager:"
    2>&1 echo ""
    2>&1 echo "   $ cinst vswhere"
    2>&1 echo ""
    exit 5
fi

vspath_msw="$("$vswherepath" -property installationPath)"
vspath="$(readlink -f "$(cygpath "$vspath_msw")")"

vstoolsversionfile="$vspath/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt"

if [[ ! -e "$vstoolsversionfile" ]]; then
    2>&1 echo "ERROR: VS Tools Version file was not found."
    2>&1 echo ""
    2>&1 echo "Expected to find: $vstoolsversionfile"
    2>&1 echo "This error may mean that your Visual Studio doesn't have the VC Toolset"
    2>&1 echo "selected for install somehow."
    exit 5
fi

vstoolsver=$(cat "$vstoolsversionfile")
vstoolsbin="$vspath/VC/Tools/MSVC/$vstoolsver/bin/Host$host/$target"

if [[ "$CYGPATH_AS_WIN" -eq "1" ]]; then
    echo "$(cygpath -w "$vstoolsbin")"
else
    echo "$vstoolsbin"
fi

exit 0