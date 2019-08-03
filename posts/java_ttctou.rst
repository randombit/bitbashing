.. title: Racing in Java
.. slug: java_ttctou
.. date: 2008-05-14
.. tags: security

Reading the documentation for Java's `File <http://java.sun.com/j2se/1.4.2/docs/api/java/io/File.html>`_
object, I was astounded to find that the Java designers managed to
replicate one of the best known file system `race conditions <http://www.dwheeler.com/secure-programs/Secure-Programs-HOWTO/avoid-race.html>`_
for no good reason: the functions ``canRead`` and ``canWrite`` are
essentially the Java equivalents of the ``access`` function, which is
so well known to be a security hole that the Linux man page actually
warns that:

   Using access() to check if a user is authorized to e.g. open a file
   before actually doing so using open(2) creates a security hole,
   because the user might exploit the short time interval between
   checking and opening the file to manipulate it.

While OpenBSD provides the less ambiguous caveat that:

   access() is a potential security hole and should never be used.

.. TEASER_END

This comes up in several contexts, including when trying to allocate a
temporary file. A classic (flawed) pattern for this task is to
generate a random filename (usually situated in a shared directory
like ``/tmp``), call ``access`` to see if the file exists, and if not,
open up that filename and use the returned file object as a
scratchpad. The problem is if someone else is racing you: in between
the time ``access`` returns and the file is opened, an attacker can
create that file and "capture" your open call. One common (if not
particularly inventive) attack is to create the file as a symbolic
link to a file owned by the victim. The victim's process will (on
ACL-based systems like Windows, MacOS X, or Unix) have full access
rights to all of their files, so it will happily stomp on something
important without ever realizing it. This is a great example of the
confused deputy problem a non-malicious program is tricked by a third
party into using its authority in unintended ways.

I don't believe there is any situation where an application can use
these functions safely. At best, they can provide "early failure" to
additional user friendliness, in the same way that doing input
validation of a web form in JavaScript can. But in both cases, in the
end you can't trust the results.

An additional comment: these functions will throw a
``SecurityException`` if the security manager forbids read or write
access to the files. But this is in direct violation of the semantics
of the functions: if attempts to actually read or write the file will
be forbidden by the security manager, then a function that "Tests
whether the application can read[/write] the file denoted by this
abstract pathname." should simply return false (because the
application cannot read/write that file), not fail with an
exception. Bizarre!
