local mroot  = os.getenv("MODULEPATH_ROOT")
local shared = pathJoin(mroot,"Shared")
prepend_path("MODULEPATH", shared)
load('c')
load('d')
add_property("state","obsolete")
