#------------------------------------------------------------------------
# tea-cxx.m4 --
#
#	C++ support for TEA.
#
#	TEA's tcl.m4 sets up a C compiler and nothing else. An extension
#	written in C++ therefore has to arrange three things by hand: find a
#	C++ compiler, compile .cpp files, and get the C++ runtime linked in.
#
#	The macros below do all three. Include this file from aclocal.m4 next
#	to tcl.m4, call TEA_SETUP_CXX after TEA_SETUP_COMPILER, and add the
#	.cpp rule from the Makefile.in fragment.
#
#	Copyright (c) 2026 Gregor Ebbing
#
#	Distributed under the same terms as tclconfig -- see the file
#	license.terms in this directory.
#------------------------------------------------------------------------

#------------------------------------------------------------------------
# TEA_SETUP_CXX --
#
#	Find a C++ compiler and make TEA link with it.
#
#	Must be called AFTER TEA_CONFIG_CFLAGS, because it rewrites the
#	SHLIB_LD that macro computed.
#
# Arguments:
#	none
#
# Results:
#	Substitutes CXX, CXXFLAGS, CXXCPP.
#	Rewrites SHLIB_LD to use the C++ driver.
#	Defines the CXXFLAGS_DEFAULT/CXXFLAGS_OPTIMIZE/CXXFLAGS_DEBUG trio,
#	mirroring what TEA_CONFIG_CFLAGS does for C.
#------------------------------------------------------------------------

AC_DEFUN([TEA_SETUP_CXX], [
    #--------------------------------------------------------------------
    # Keep AC_PROG_CXX from injecting its own "-g -O2".
    #
    # TEA does the same for CFLAGS: it builds the flag string itself, out of
    # CFLAGS_DEFAULT, CFLAGS_WARNING and SHLIB_CFLAGS, and would rather not have
    # autoconf's guesses mixed in. A user-supplied CXXFLAGS on the configure
    # line survives -- the assignment only fires when the variable is unset.
    #--------------------------------------------------------------------

    : ${CXXFLAGS=""}

    AC_PROG_CXX
    AC_PROG_CXXCPP

    #--------------------------------------------------------------------
    # Link with the C++ driver, not the C one.
    #
    # tclConfig.sh reports TCL_SHLIB_LD as '${CC} -shared' (or similar),
    # and TEA_CONFIG_CFLAGS carries that into SHLIB_LD. Linking C++ objects
    # with the C driver leaves the C++ runtime symbols undefined -- the
    # extension builds and then fails to load, which is the worst kind of
    # failure.
    #
    # Adding -lstdc++ would also work, but it hardcodes a GNU library name.
    # Swapping the driver is portable: g++, clang++ and cl all know what
    # runtime their own objects need.
    #
    # On MSVC, SHLIB_LD is link.exe and carries no ${CC}; the substitution
    # then does nothing, which is correct -- cl embeds the runtime directive
    # in the object file, and link.exe honours it.
    #--------------------------------------------------------------------

    case "${SHLIB_LD}" in
	*'${CC}'*)
	    SHLIB_LD=`echo "${SHLIB_LD}" | sed -e 's|${CC}|${CXX}|' \
					      -e 's|${CFLAGS}|${CXXFLAGS}|'`
	    AC_MSG_NOTICE([linking with the C++ driver: ${SHLIB_LD}])
	    ;;
	*)
	    AC_MSG_NOTICE([SHLIB_LD carries no C driver, left unchanged])
	    ;;
    esac

    #--------------------------------------------------------------------
    # The CXXFLAGS trio, mirroring TEA_CONFIG_CFLAGS.
    #
    # TEA computes CFLAGS_DEFAULT from CFLAGS_OPTIMIZE or CFLAGS_DEBUG,
    # depending on --enable-symbols. C++ needs the same, plus a standard
    # level -- without -std= the compiler picks its own default, and that
    # changes between compiler versions.
    #--------------------------------------------------------------------

    AC_ARG_WITH([cxx-standard],
	AS_HELP_STRING([--with-cxx-standard=VER],
		       [C++ standard: 11, 14, 17, 20 (default: 17)]),
	[tea_cxx_std=$withval], [tea_cxx_std=17])

    AS_CASE([$tea_cxx_std],
	[11|14|17|20|23], [],
	[AC_MSG_ERROR([unknown C++ standard: $tea_cxx_std])])

    CXXFLAGS_STD="-std=c++${tea_cxx_std}"
    if test "$GXX" != "yes" -a "$CXX" = "cl"; then
	CXXFLAGS_STD="-std:c++${tea_cxx_std}"
    fi

    #--------------------------------------------------------------------
    # Build CXXFLAGS the way TEA_CONFIG_CFLAGS builds CFLAGS: append make
    # variables, let make expand them.
    #
    # CFLAGS_DEFAULT, CFLAGS_WARNING and SHLIB_CFLAGS are reused as they are.
    # They hold -O2, -Wall and -fPIC -- flags that mean the same to the C++
    # compiler, so a parallel set would be duplication, and duplication drifts.
    #
    # SHLIB_CFLAGS is the one that must not be forgotten. Without -fPIC the
    # compile succeeds and the *link* fails, with a message about relocations
    # that says nothing about the missing flag:
    #
    #   relocation R_X86_64_PC32 against symbol `_ZN7Greeter6DeleteEPv'
    #   can not be used when making a shared object
    #
    # Simple C++ files can get away without it; a class with out-of-line member
    # functions cannot. So the fault appears only once the extension grows.
    #--------------------------------------------------------------------

    CXXFLAGS="${CXXFLAGS} \${CXXFLAGS_STD} \${CFLAGS_DEFAULT} \${CFLAGS_WARNING} \${SHLIB_CFLAGS}"

    AC_SUBST(CXX)
    AC_SUBST(CXXCPP)
    AC_SUBST(CXXFLAGS)
    AC_SUBST(CXXFLAGS_STD)
    AC_SUBST(SHLIB_LD)
])

#------------------------------------------------------------------------
# TEA_CXX_RUNTIME --
#
#	Decide whether the C++ runtime is linked statically.
#
#	This matters more than it looks. A C++ extension linked against a
#	shared libstdc++ needs that library present on the target machine, in
#	a compatible version. On Windows it means shipping libstdc++-6.dll and
#	libgcc_s_seh-1.dll beside the extension -- and a starpack then is not
#	one file any more.
#
#	Linking the runtime statically costs a few tens of kilobytes and
#	removes the dependency entirely. For a Tcl extension -- a leaf in the
#	dependency graph, loaded into a foreign process -- that is nearly
#	always the better trade.
#
#	Note this is about the *C++* runtime, not libc. libc stays shared.
#
# Arguments:
#	none -- reads --enable-static-cxx (default: yes)
#
# Results:
#	Appends -static-libstdc++ -static-libgcc to SHLIB_LD where the
#	compiler understands them.
#------------------------------------------------------------------------

AC_DEFUN([TEA_CXX_RUNTIME], [
    AC_REQUIRE([TEA_SETUP_CXX])

    AC_MSG_CHECKING([how to link the C++ runtime])

    AC_ARG_ENABLE([static-cxx],
	AS_HELP_STRING([--disable-static-cxx],
		       [link the C++ runtime dynamically (default: static)]),
	[tea_static_cxx=$enableval], [tea_static_cxx=yes])

    if test "$tea_static_cxx" = "yes" ; then
	if test "$GXX" = "yes" ; then
	    SHLIB_LD="${SHLIB_LD} -static-libstdc++ -static-libgcc"
	    AC_MSG_RESULT([static])
	else
	    AC_MSG_RESULT([dynamic (compiler has no -static-libstdc++)])
	fi
    else
	AC_MSG_RESULT([dynamic (requested)])
    fi

    AC_SUBST(SHLIB_LD)
])

#------------------------------------------------------------------------
# TEA_ADD_CXXFLAGS --
#
#	The C++ counterpart of TEA_ADD_CFLAGS.
#------------------------------------------------------------------------

AC_DEFUN([TEA_ADD_CXXFLAGS], [
    CXXFLAGS="$CXXFLAGS $@"
    AC_SUBST(CXXFLAGS)
])
