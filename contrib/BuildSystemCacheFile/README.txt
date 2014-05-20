The script in this directory shows one way to build the system cache
file. Obviously, you will need to taylor this to your site.

One new subtlety is how to deal with different types of machines
sharing a common file system.  Suppose you have different modules
installed on different types of machines.  Say your login nodes have
a certain set of software installed and your vis nodes or your compute
nodes have a different set of software installed.  You will need
separate spider cache files for each host type.

The choices I see are:

1) have the spider cache be local on each compute.
2) have one machine in each host type produce the cache file for that
   host type.

If you use method 2, you will need some way for a host to know which
spider cache to read.  So if you have a system file that marks the
last update to the system, Lmod will try to read the first line of
this file to find where the cache file directory is located.

So if you configure Lmod to look for the cache file directory,
then the rules are:

  1) if the file is empty then use the directory specified
  2) Otherwise read the first line in the file to be the hostType
     and combine $CACHEDIR and hostType to be the cache directory.


So if

   CACHEDIR="/opt/moduleData/cacheDir"
   UpdateFN="/tmp/systemUpdate/update"

and the contents of /tmp/systemUpdate/update are:
   compute

Then the cache directory will be:

  /opt/moduleData/cacheDir/compute






