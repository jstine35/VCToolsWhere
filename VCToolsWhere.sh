#!/bin/bash

host=x64
target=x64

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
vstoolsbin="$vspath/VC/Tools/MSVC/$toolsdir/bin/Host$host/$target"

echo $vstoolsbin
exit 0