#!/bin/bash
#
# Main purpose of this script is to encapsulate evaluation of %ProgramFiles(x86)% from an msys environment.
#
# Latest version can probably be found here:
#    https://github.com/jstine35/VCToolsWhere
#

CYGPATH_AS_WIN=0
RUN_CUSTOM_SWITCH_MODE=0
vswhere_property="installationPath"
skip_cygpath=0

DIAGNOSTIC=0
SHOW_HELP=0
CLI_ERROR_ABORT=0
POSITIONAL=()

while [[ $# -gt 0 ]]; do
key="$1"
case $key in
    --diagnostic|--diag)
    DIAGNOSTIC=1
    shift
    ;;
    --install-path)
    vswhere_property="installationPath"
    shift
    ;;
    --install-version)
    vswhere_property="installationVersion"
	skip_cygpath=1
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
    --)
    RUN_CUSTOM_SWITCH_MODE=1
    shift
    POSITIONAL+=("$@") # save it in an array for later
    shift $#
    ;;
    *)    # unknown option
    >&2 echo "Unknown option '$key'"
    >&2 echo "Use -- to pass options into vswhere.exe, ex:"
    >&2 echo "  $ vswhere.sh -- -property installationPath"
    #POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

if [[ "$CLI_ERROR_ABORT" -eq "1" ]]; then
    exit 5
fi

set -- "${POSITIONAL[@]}" # restore positional parameters
me=$(basename "$0")

# route diagnostic into stderr so that the stdout result is still valid/parsable by script.
diagecho() { >&2 echo "$@"; }

# vswhere.exe comes with Visual Studio Installer as of VS2017 v15.2 or later.  Note that it comes
# with the installer and not any specific Visual Studio product, so updating the installer is enough
# to acquire it.  Favor that one first, fall back on PATH if it can't be found.
# Check both PROGRAMFILES and PROGRAMFILES(X86) in case we're actually running on a 32-bit host.

# %ProgramFiles(x86)% from windows environment is not visible to BASH because it
# has invalid characters in its name.  So we must pull it from cmd.exe in a roundabout way.
# Check first if there is a $PROGRAMFILESX86, just in case future Git for Windows provides
# it with invalid chars stripped in the future.

PROGRAMFILESX86=${PROGRAMFILESX86:-$(cmd //C echo "%ProgramFiles(x86)%" 2>/dev/null)}

[ "$DIAGNOSTIC" -eq "1" ] && diagecho "(diag) PROGRAMFILES    = $PROGRAMFILES"
[ "$DIAGNOSTIC" -eq "1" ] && diagecho "(diag) PROGRAMFILESX86 = $PROGRAMFILESX86"
vswherepath="$PROGRAMFILESX86/Microsoft Visual Studio/Installer/vswhere.exe"
if [[ ! -f "$vswherepath" ]]; then
    [ "$DIAGNOSTIC" -eq "1" ] && diagecho "(diag) vswhere.exe not found in PROGRAMFILESX86, trying PROGRAMFILES"
    vswherepath="$PROGRAMFILES/Microsoft Visual Studio/Installer/vswhere.exe"
fi

if [[ ! -f "$vswherepath" ]]; then
    [ "$DIAGNOSTIC" -eq "1" ] && diagecho "(diag) vswhere.exe not found in PROGRAMFILES. Looking in PATH..."
    vswherepath=$(which vswhere) || exit 1
fi

if [[ "$RUN_CUSTOM_SWITCH_MODE" -eq "1" ]]; then
    [ "$DIAGNOSTIC" -eq "1" ] && diagecho "(diag) Custom args: $@"
    "$vswherepath" "$@" || exit 2
    exit 0
fi

vspath_msw="$("$vswherepath" -latest -property $vswhere_property)" || exit 2

if [[ "$CYGPATH_AS_WIN" -eq "1" ]]; then
    echo $vspath_msw
    exit 0
fi

[[ "$DIAGNOSTIC"   -eq "1" ]] && diagecho "(diag) vswhere.exe returned: $vspath_msw"
[[ "$skip_cygpath" -eq "0" ]] && cygpath "$vspath_msw" || echo "$vspath_msw"
