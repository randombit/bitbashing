.. title: Search Based Filesystem
.. slug: search_filesystem
.. date: 2007-10-13
.. tags: programming

I was using a friend's OS X machine briefly, and at one point thought
that how the "Movies" folder worked was it acted as an index into the
actual filesystem, using some search technology or another to find all
of your movies and present them to you. Presenting search results as a
directory of files instead of a list (especially with movies, since
they are normally a single file that are more or less independent of
each other) seemed so obviously user-friendly that I figured that had
to be what Apple would do. (Apparently not: my friend said it's just a
plain old directory with actual files in it). But my misconception
planted the idea that this would be pretty useful!

.. TEASER_END

I wouldn't mind being able to do this::

   $ cd /search/jpg
   $ ls
   [all files matching *.jpg that the current user has read access to in
   all directories]

Just having simple combined extension searches, or a filename-based
regexp, would replace many uses of find or slocate. I think
"(flac|mp3|ogg|m4a)$" would be the first criteria I would want to use,
so I can find all of my music easily no matter what odd corner of my
disk it had ended up in.

Probably this could use slocate or an equivalent as the backend, at
least as the first implementation. I would much rather having it
dynamically update as files are created, renamed, or deleted, with no
need to regenerate a cache. I'm not sure how that could be done
efficiently on Linux without hooking in all of the file syscalls
(which would require using LSM, probably).

Handling filename conflicts would probably be interesting. Maybe
you could prefix as many directories as needed in order to make
duplicates unique? Since if you've walked up to the root and they
are still identical then they have the same path.

Only listing a file once no matter how many hardlinks it has would
seem to require keeping a list of all inodes that you've listed so
far.

`FUSE <http://fuse.sourceforge.net/>`_ seems like it
would be the fastest way to prototype something like this.

