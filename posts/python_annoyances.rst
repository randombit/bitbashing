.. title: Python Format String Annoyance
.. slug: python_format_strings
.. date: 2007-04-09
.. tags: programming

Python's format string operator is useful, but if you wish to provide
arguments to it you must do so all at once. This makes some situations
harder to deal with, including this one wherein I am annoyed at being
unable to compact some Python code manipulating a MySQL database.

.. TEASER_END

The code I was looking at was generated a large number of SQL
statements, mostly very much like each other, roughly like::

   cmds += "insert into %s values("%s", "%s")" % ("table1", "v1", "v2")
      cmds += "insert into %s values("%s", "%s")" % ("table1", "v3", "v4")
      # a few hundred more lines like that with various different tables
      query_object.execute(cmds)

The first thing that sucked was simply you couldn't immediately
tell that these were all the same insertion statement with different
values, so I changed it to::

   insert_statement = ""insert into %s values("%s", "%s")"
      cmds += insert_statement % ("table1", "v1", "v2")
      cmds += insert_statement % ("table1", "v3", "v4")

For some of the tables there was 20 or 30 inserts, and I wanted to
merge those together. I really dislike seeing the same thing repeated
more than once or twice in code, even in something very non-core such
as this (this script is just occasionally run by hand, it will
probably be run in production once every few months, so I probably
spent too much time worrying about this, but it was bothering me).

Unfortunately, for Python format strings, when you apply the %
operator, you have to provide all of the values on the spot::

   >>> "%s %s" % ('a', 'b')
   'a b'
   >>> "%s %s" % ('a')
   Traceback (most recent call last).
     File "<stdin>", line 1, in ?
   TypeError: not enough arguments for format string
   >>> "%s %s" % ('a') % ('b')
   Traceback (most recent call last).
     File "<stdin>", line 1, in ?
   TypeError: not enough arguments for format string

My intuition was that this would work, with successive applications
of the % operator filling in further elemements from left to right. It
does work with

   >>> "%s %%s" % ('a') % ('b')
   'a b'

But unfortunately.

   >>> "%s %%s" % ('a', 'b')
   Traceback (most recent call last).
     File "<stdin>", line 1, in ?
   TypeError: not all arguments converted during string formatting

So you have to know how many times you'll want to call the %
operator at the time when you construct the format string. (Not to
mention that ending up with %%%%%s is pretty unattractive).
