# VCToolsWhere

Returns the path to the *Microsoft Visual C++ Toolchain* binaries.  Most notably, this includes `cl.exe` and
`ld.exe`.  Primary use case for this tool is to get the path to `cl.exe` so that a build step can use it as a
C/C++ Macro Preprocessor.

## Compatibility

`VCToolsWhere` works for nearly all versions of Visual Studio from MSVC 2008 through MSVC 2017.  When it comes
to VC2017, the tool will return the path to the _primary_ Visual Studio as reported by `VSWhere.exe`.  I haven't
had an interest in adding an option to alter this behavior since 99.975% of functionality of the Visual C++ toolchain
is the same for all variety of Visual Studio distributions -- Community, Pro, Enterprise, betas, what-have-you.

### Relationship to VSWhere.exe
This shell command depends on, and is somewhat analogous to, [VSWhere.exe](https://github.com/Microsoft/vswhere).
`VSWhere.exe` normally comes with Visual Studio 2015/2017, and can also be installed via [Chocolatey](https://www.chocolatey.org)

### Why a BASH script?
`BASH` is awesome.  It comes with Git for Windows and, if you're a developer, you almost certainly have that installed.
