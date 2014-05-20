TOOL_SRC                  := $(wildcard tools/*.lua)
HAVE_LUA_JSON             := 
ifeq ($(HAVE_LUA_JSON),yes)
  TOOL_SRC                := $(filter-out tools/json.lua, $(TOOL_SRC))
endif

LMOD_FULL_SETTARG_SUPPORT := $(shell echo "NO"       | tr '[:upper:]' '[:lower:]')
USE_DOT_FILES             := $(shell echo "yes" | tr '[:upper:]' '[:lower:]')
PREPEND_BLOCK     	  := $(shell echo "NORMAL" | tr '[:upper:]' '[:lower:]')
COLORIZE          	  := $(shell echo "YES"      | tr '[:upper:]' '[:lower:]')
CASE_INDEPENDENT_SORTING  := NO
ZSH_SITE_FUNCTIONS_DIR    := 
SPIDER_CACHE_DESCRIPT_FN  := 
ANCIENT           	  := 86400
ALLOW_TCL_MFILES          := yes
MPATH_AVAIL               := no
DUPLICATE_PATHS           := NO
SHORT_TIME        	  := 2
SPIDER_CACHE_DIRS 	  := 
PATH_TO_HASHSUM   	  := /usr/bin/sha1sum
PATH_TO_LUA	  	  := /usr/bin
PATH_TO_PAGER	  	  := /bin/more
PATH_TO_TCLSH             := /usr/bin/tclsh
MODULEPATH_ROOT   	  := /usr/modulefiles
VERSION_SRC	  	  := src/Version.lua
LUA_INCLUDE       	  := /usr/include/lua5.2
UPDATE_SYSTEM_FN  	  := 
GIT_PROG                  := /usr/bin/git
GIT_VERSION               := $(shell if [ -n "$(GIT_PROG)" -a -d .git ]; then lmodV=`git describe --always`; echo "($$lmodV)"; else echo "@git@"; fi)
prefix		  	  := /usr
package		  	  := lmod
version		  	  := $(shell cd ./src; $(PATH_TO_LUA)/lua -e "V=require('Version'); print(V.tag())")
PKGV		  	  := $(prefix)/$(package)/$(version)
PKG		  	  := $(prefix)/$(package)/$(package)
LIBEXEC		  	  := $(prefix)/$(package)/$(version)/libexec
SHELLS                    := $(prefix)/$(package)/$(version)/shells
TOOLS                     := $(prefix)/$(package)/$(version)/tools
SETTARG                   := $(prefix)/$(package)/$(version)/settarg
INIT		  	  := $(prefix)/$(package)/$(version)/init
LMOD_MF 	  	  := $(prefix)/$(package)/$(version)/modulefiles/Core
LMOD_MF_SOURCE            := MF/*.version.lua
SETTARG_SOURCE            := settarg/*.lua  settarg/targ.in

DIRLIST		  	  := $(DESTDIR)$(LIBEXEC) $(DESTDIR)$(TOOLS) $(DESTDIR)$(SETTARG)             \
                             $(DESTDIR)$(SHELLS)                                                      \
                             $(DESTDIR)$(INIT) $(DESTDIR)$(LIB) $(DESTDIR)$(LMOD_MF)


STANDALONE_PRGM   	  := src/lmod.in.lua src/addto.in.lua src/getmt.in.lua src/processMT.in.lua   \
                             src/spider.in.lua src/processModuleUsage.in.lua src/reportUsers.in.lua   \
                             src/clearMT_cmd.in.lua src/ml_cmd.in.lua src/spiderCacheSupport.in.lua   \
                             src/sh_to_modulefile.in.lua
SHELL_INIT	  	  := bash.in csh.in ksh.in tcsh.in zsh.in sh.in perl.in                       \
                             env_modules_python.py.in lmod_bash_completions lmodrc.lua
SHELL_INIT	  	  := $(patsubst %, init/%, $(SHELL_INIT))

ZSH_FUNCS                 := init/zsh/_ml init/zsh/_module

STARTUP		  	  := profile.in cshrc.in
STARTUP		  	  := $(patsubst %, init/%, $(STARTUP))

MAIN_DIR	  	  := Makefile.in INSTALL configure README_lua_modulefiles.txt \
                             README README.old License

CONTRIB_DIRS           	  :=  \
                              bash_patch                        \
                              BuildSystemCacheFile              \
                              converting_shell_to_module_files  \
                              hook                              \
                              parseVersions                     \
	                      settarg                           \
                              SitePackage                       \
                              TACC                              \
                              tricky_modulefiles

CONTRIB                   := $(patsubst %, contrib/%, $(CONTRIB_DIRS))
lua_code	  	  := $(filter-out %.in.lua, $(wildcard src/*.lua))   \
                             $(wildcard src/*.tcl)
VDATE		  	  := $(shell date +'%F %H:%M')

ComputeHashSum    	  := src/computeHashSum.in.lua
spiderCacheSupportCMD     := lua src/spiderCacheSupport.in.lua

HAVE_LUA_TERM             := yes
ifneq ($(HAVE_LUA_TERM),yes)
  PKGS := pkgs
  LIB  := $(prefix)/$(package)/$(version)/lib
endif


.PHONY: test pkgs

all:
	@echo done

pre-install: $(DIRLIST) shell_init startup spiderCacheSupport libexec \
             Inst_Tools Inst_Shells Inst_Settarg Inst_Lmod_MF $(PKGS) other_tools

install: pre-install  zsh_tab_funcs
	$(RM) $(DESTDIR)$(PKG)
	ln -s $(version) $(DESTDIR)$(PKG)

echo:
	@echo Version: $(version)


$(DIRLIST) :
	mkdir -p $@

__installMe:
	-for i in $(FILELIST); do                                     	   \
           bareN=$${i##*/};                                           	   \
           fn=$${bareN%%.in*};                                        	   \
           ext=$${bareN#*.};                                          	   \
	   : echo "DIRLOC/fn: $(DIRLOC)/$$fn";                             \
           sed  -e 's|@PREFIX@|$(prefix)|g'                            	   \
	        -e 's|@path_to_lua@|$(PATH_TO_LUA)|g'                 	   \
	        -e 's|@path_to_hashsum@|$(PATH_TO_HASHSUM)|g'         	   \
	        -e 's|^#!/usr/bin/env tclsh$$|#!$(PATH_TO_TCLSH)|g'    	   \
	        -e 's|@path_to_pager@|$(PATH_TO_PAGER)|g'             	   \
	        -e 's|@case_independent_sorting@|$(CASE_INDEPENDENT_SORTING)|g' \
                -e 's|@lmod_full_settarg_support@|$(LMOD_FULL_SETTARG_SUPPORT)|g' \
                -e 's|@use_dot_files@|$(USE_DOT_FILES)|g'             	   \
                -e 's|@git@|$(GIT_VERSION)|g'                              \
                -e 's|@have_lua_term@|$(HAVE_LUA_TERM)|g'                  \
                -e 's|@have_lua_json@|$(HAVE_LUA_JSON)|g'                  \
	        -e 's|@ancient@|$(ANCIENT)|g'                         	   \
	        -e 's|@prepend_block@|$(PREPEND_BLOCK)|g'             	   \
	        -e 's|@colorize@|$(COLORIZE)|g'                       	   \
	        -e 's|@duplicate_paths@|$(DUPLICATE_PATHS)|g'      	   \
	        -e 's|@allow_tcl_mfiles@|$(ALLOW_TCL_MFILES)|g'      	   \
	        -e 's|@mpath_avail@|$(MPATH_AVAIL)|g'            	   \
	        -e 's|@short_time@|$(SHORT_TIME)|g'                   	   \
	        -e 's|@cacheDirs@|$(SPIDER_CACHE_DIRS)|g'             	   \
	        -e 's|@updateSystemFn@|$(UPDATE_SYSTEM_FN)|g'         	   \
	        -e 's|@modulepath_root@|$(MODULEPATH_ROOT)|g'         	   \
                -e 's|@PKGV@|$(PKGV)|g'                                    \
                -e 's|@PKG@|$(PKG)|g'         < $$i > $(DIRLOC)/$$fn; 	   \
            [ "$$ext" = "in.lua" -o "$$ext" = "tcl" -o "$$ext" = "in" ] && \
               chmod +x $(DIRLOC)/$$fn;                                    \
            if [ "$$ext" = "version.lua" ]; then                           \
               mname=$${bareN%%.*};                                        \
	       : echo "DIRLOC: $(DIRLOC)/$$mname";                         \
	       mkdir -p $(DIRLOC)/$$mname;                                 \
               mv $(DIRLOC)/$$fn $(DIRLOC)/$$mname/$(version).lua;         \
            fi;                                                            \
        done

shell_init: $(SHELL_INIT)
	$(MAKE) FILELIST="$^" DIRLOC=$(DESTDIR)$(INIT)    __installMe

startup: $(STARTUP)
	$(MAKE) FILELIST="$^" DIRLOC=$(DESTDIR)$(INIT)    __installMe

other_tools: $(ComputeHashSum) $(STANDALONE_PRGM)
	$(MAKE) FILELIST="$^" DIRLOC=$(DESTDIR)$(LIBEXEC) __installMe

spiderCacheSupport:
	$(spiderCacheSupportCMD) --cacheDirs "$(SPIDER_CACHE_DIRS)"          \
	                         --updateFn  "$(UPDATE_SYSTEM_FN)"           \
                                 --descriptFn "$(SPIDER_CACHE_DESCRIPT_FN)"  \
                                 >> $(DESTDIR)$(INIT)/lmodrc.lua;

src/computeHashSum: $(ComputeHashSum)
	$(MAKE) FILELIST="$^" DIRLOC="src"                __installMe
	chmod +x $@

pkgs:
	cd pkgs; \
        $(MAKE) LUA_INC=$(LUA_INCLUDE)  LIB=$(DESTDIR)$(LIB) \
                SHARE=$(DESTDIR)$(LIBEXEC) install

zsh_tab_funcs: $(ZSH_FUNCS)
	-if [ -n "$(ZSH_SITE_FUNCTIONS_DIR)" ]; then \
          cp $^ $(DESTDIR)$(ZSH_SITE_FUNCTIONS_DIR);                \
        fi

makefile: Makefile.in config.status
	./config.status $@

config.status:
	./config.status --recheck

dist:
	$(MAKE) DistD=DIST _dist

_dist: _distMkDir _distMainDir _distSrc _distSetup _distSetupZsh \
       _distVersion _distPkgs _distMF    _distContrib _distTar

_distMkDir:
	$(RM) -r $(DistD)
	mkdir $(DistD)


_distContrib:
	mkdir $(DistD)/contrib
	cp -r $(CONTRIB) $(DistD)/contrib

_distSrc:
	mkdir $(DistD)/src $(DistD)/tools $(DistD)/settarg $(DistD)/shells
	cp $(lua_code) $(ComputeHashSum) $(STANDALONE_PRGM) $(DistD)/src
	cp tools/*.lua $(DistD)/tools
	cp $(SETTARG_SOURCE) $(DistD)/settarg
	cp shells/*.lua $(DistD)/shells

_distVersion:
	perl -p -i -e 's/\@git\@/$(GIT_VERSION)/g' $(DistD)/src/Version.lua

_distPkgs:
	mkdir $(DistD)/pkgs
	cp -r pkgs/* $(DistD)/pkgs

_distSetup:
	mkdir $(DistD)/init
	cp $(SHELL_INIT) $(STARTUP) $(DistD)/init

_distSetupZsh:
	mkdir $(DistD)/init/zsh
	cp $(ZSH_FUNCS) $(DistD)/init/zsh



_distMainDir:
	cp $(MAIN_DIR) $(DistD)

_distMF:
	mkdir $(DistD)/MF
	cp -r MF $(DistD)/

_distTar:
	echo "Lmod"-$(version) > .fname;                		   \
	$(RM) -r `cat .fname` `cat .fname`.tar*;         		   \
	mv ${DistD} `cat .fname`;                            		   \
	tar chf `cat .fname`.tar `cat .fname`;           		   \
	bzip2 `cat .fname`.tar;                           		   \
	rm -rf `cat .fname` .fname;


test:
	cd rt; unset TMFuncPATH; tm .

tags:
	find . \( -regex '.*~$$\|.*/\.git\|.*/\.git/' -prune \)  \
               -o -type f > file_list.1
	sed -e 's|.*/.git.*||g'                                  \
            -e 's|.*/rt/.*/t1/.*||g'                             \
            -e 's|./TAGS||g'                                     \
            -e 's|./makefile||g'                                 \
            -e 's|./configure$$||g'                              \
            -e 's|/.DS_Store$$||g'                               \
            -e 's|.*\.tgz$$||g'                                  \
            -e 's|.*\.tar\.gz$$||g'                              \
            -e 's|.*\.tar\.bz2$$||g'                             \
            -e 's|.*\.csv$$||g'                                  \
	    -e 's|.*\.aux$$||g'                                  \
	    -e 's|.*\.fdb_latexmk$$||g'                          \
	    -e 's|.*\.fls$$||g'                                  \
	    -e 's|.*\.nav$$||g'                                  \
	    -e 's|.*\.out$$||g'                                  \
	    -e 's|.*\.pdf$$||g'                                  \
	    -e 's|.*\.snm$$||g'                                  \
	    -e 's|.*\.toc$$||g'                                  \
	    -e 's|.*\.vrb$$||g'                                  \
            -e 's|^#.*||g'                                       \
            -e 's|/#.*||g'                                       \
            -e 's|\.#.*||g'                                      \
            -e 's|.*\.pdf$$||g'                                  \
            -e 's|.*\.used$$||g'                                 \
            -e 's|./.*\.log$$||g'                                \
            -e 's|./testreports/.*||g'                           \
            -e 's|./config\.status$$||g'                         \
            -e 's|.*\~$$||g'                                     \
            -e 's|./file_list\..*||g'                            \
            -e '/^\s*$$/d'                                       \
	       < file_list.1 > file_list.2
	etags  `cat file_list.2`
	$(RM) file_list.*


libexec:  $(lua_code)
	$(MAKE) FILELIST="$^" DIRLOC=$(DESTDIR)$(LIBEXEC) __installMe

Inst_Tools: $(TOOL_SRC)
	$(MAKE) FILELIST="$^" DIRLOC=$(DESTDIR)$(TOOLS) __installMe

Inst_Shells: shells/*.lua
	$(MAKE) FILELIST="$^" DIRLOC=$(DESTDIR)$(SHELLS) __installMe

Inst_Settarg: $(SETTARG_SOURCE)
	$(MAKE) FILELIST="$^" DIRLOC=$(DESTDIR)$(SETTARG) __installMe


Inst_Lmod_MF: $(LMOD_MF_SOURCE)
	$(MAKE) FILELIST="$^" DIRLOC=$(DESTDIR)$(LMOD_MF) __installMe

clean:
	$(RM) config.log
	cd pkgs; $(MAKE) LIB=$(DESTDIR)$(LIB) SHARE=$(DESTDIR)$(LIBEXEC) clean

clobber: clean

distclean: clobber
	$(RM) makefile config.status

world_update:
	@git status -s > /tmp/git_st_$$$$;                                         \
        if [ -s /tmp/git_st_$$$$ ]; then                                           \
            echo "All files not checked in => try again";                          \
        else                                                                       \
            git push github;                                                       \
            git push --tags github;                                                \
            git push sf;                                                           \
            git push --tags sf;                                                    \
        fi;                                                                        \
        rm -f /tmp/git_st_$$$$



gittag:
        ifneq ($(TAG),)
	  @git status -s > /tmp/git_st_$$$$;                                         \
          if [ -s /tmp/git_st_$$$$ ]; then                                           \
	    echo "All files not checked in => try again";                            \
	  else                                                                       \
	    $(RM)                                                    $(VERSION_SRC); \
	    echo "--module('Version')"                            >  $(VERSION_SRC); \
	    echo 'local M={}'                                     >> $(VERSION_SRC); \
	    echo 'function M.tag()  return "$(TAG)"   end'        >> $(VERSION_SRC); \
	    echo 'function M.git()  return "@git@"    end'        >> $(VERSION_SRC); \
	    echo 'function M.date() return "$(VDATE)" end'        >> $(VERSION_SRC); \
	    echo 'function M.name()'                              >> $(VERSION_SRC); \
            echo '  local a = {}'                                 >> $(VERSION_SRC); \
	    echo '  a[#a+1] = M.tag()'                            >> $(VERSION_SRC); \
	    echo '  a[#a+1] = M.git()'                            >> $(VERSION_SRC); \
	    echo '  a[#a+1] = M.date()'                           >> $(VERSION_SRC); \
	    echo '  return table.concat(a," ")'                   >> $(VERSION_SRC); \
	    echo 'end'                                            >> $(VERSION_SRC); \
	    echo 'return M'                                       >> $(VERSION_SRC); \
            git commit -m "moving to TAG_VERSION $(TAG)"             $(VERSION_SRC); \
            git tag -a $(TAG) -m 'Setting TAG_VERSION to $(TAG)'                   ; \
	    git push --tags                                                        ; \
          fi;                                                                        \
          rm -f /tmp/git_st_$$$$
        else
	  @echo "To git tag do: make gittag TAG=?"
        endif
