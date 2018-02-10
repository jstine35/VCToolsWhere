# VCToolsWhere

Returns the path to the *Microsoft Visual C++ Toolchain* binaries.  Most notably, this includes `cl.exe` and
`ld.exe`.  Primary use case for this tool is to get the path to `cl.exe` so that a build step can use it as a
C/C++ Macro Preprocessor.

## Compatibility
`VCToolsWhere` works for nearly all versions of Visual Studio from MSVC 2008 through MSVC 2017.  When it comes
to VC2017, the tool will return the path to the _primary_ Visual Studio as reported by `VSWhere.exe`.  I haven't
had an interest in adding an option to alter this behavior since 99.975% of functionality of the Visual C++ toolchain
is the same for all variety of Visual Studio distributions -- Community, Pro, Enterprise, betas, what-have-you.

## How to run `.sh` file?
It's a Bash shell script.  Fully-functional **GNU CoreUtils** is available by installing
[Git for Windows](https://gitforwindows.org), which is something almost all Windows developers should have
installed.  See also [my patch installer](https://github.com/jstine35/ShAssocCheck/releases) which fixes a
known issue in Git for Windows `.sh` file association.

### Relationship to VSWhere.exe
This shell command depends on, and is somewhat analogous to, [VSWhere.exe](https://github.com/Microsoft/vswhere).
`VSWhere.exe` normally comes with Visual Studio 2015/2017, and can also be installed via [Chocolatey](https://www.chocolatey.org)

### Why a BASH script?
**Bash** is awesome, as outlined here:

  * GNU CoreUtils are well-documented through the _Posix standard_
  * Scripts written in Bash have a high degree of cross-compatibility across Linux/Mac and Windows
  * GNU CoreUtils on Windows have full support of NTFS long path names (up to 32700 chars)
      * even Powershell is still limited to 260 character paths
