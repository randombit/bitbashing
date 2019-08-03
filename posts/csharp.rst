.. title: Initial Impressions of C#
.. slug: csharp
.. date: 2006-08-03
.. tags: programming

For the last month or so, I've been spending some time on a C#
application to perform vulnerability analysis of PHP and ASP code. The
language was imposed on me by external constraints, but it turns out
to be a very reasonable choice for this sort of problem. I'm not doing
anything particularly groundbreaking or clever, so it ends up that
having really good libraries and a reasonably expressive language is
more useful, in terms of immediate productivity, than having a really
powerful language and half-assed library support (see: Common Lisp).

.. TEASER_END

I'm sure there are people who scoff at properties as being purely
syntactical sugar, but I found judicious use of them can really
improve readability without introducing any new dangers to class
invariance properties. I was recently tried (again) to tackle a design
problem that I've been struggling with in Botan for some time, and
realized that properties would be very useful for me. Unfortunately,
it doesn't seem possible to emulate them in C++ without paying severe
penalties in source code complexity (writing a lot of boilerplate
code, or using macros to generate said boilerplate).

The standard library seems fairly good, but is also deeply limited
in much the same way that the Java class library is. The support for
XML processing, GUI programming, and so forth has all been fairly
pleasant and easy to learn. But at the same time, obviously useful
utilities such as option parsing and filename wildcarding are
nonexistent. You can find several implementations floating around for
both of these, most of which are limited, buggy, or just plain bad -
one would think that would be hint enough that it should be built
in. It's as if nobody at Microsoft ever wrote a nontrivial
command-line application in C#.

And would it kill anyone to include parser and lexer generators in
the toolset? It's rather sad that in many ways the best language
support environment is *still* for C. While searching for one I
could use, I checked the Mono code - and found that it generates the
C# parser with a parser generator from the late 80s written in K&R
C. Go figure. I ended up using `CsLex <http://www.zbrad.net/DotNet/Lex/Lex.htm>`_, which despite not
being updated for over six years turned out to work fairly well.

Nits aside, I'd say I'm overall fairly happy with C# as a
development environment. Without a doubt there are problems for which
it is totally inappropriate, but I can't imagine that I'll ever write
Java again (not that I ever wrote much code in Java, anyway). And
while Mono's current (beta) implementation of Windows.Forms is
horrifically buggy, slow, and visually ugly, the GTK bindings mean
that I'll probably never follow through with my original plan of
learning `GTKmm <http://www.gtkmm.org>`_.
