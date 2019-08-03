.. title: Finding Equivalences of Boolean Function
.. slug: booleans
.. date: 2006-08-30
.. tags: programming, algorithms

A fairly common class of functions in crypto are functions mapping
{0,1}\ :sup:`3` onto {0,1}. In particular, these show up a lot in hash
functions derived from MD4, including MD5, SHA-1, RIPEMD, and
SHA-512. These range in complexity from simple three-term expressions
like "(A xor B xor C)" to functions like "((A and B) or (C and (A or
B)))". One interesting and important difference between these two
functions becomes very important when you consider how to implement
these functions on an x86 (or x86-64) processor. The x86 uses
two-operand instructions, and has very few registers, so computing
something like "(A and B) xor (not(A) and C)", which requires two
temporaries (one to hold A and B, the other (not(A) and C)) might
require you to spill values to the stack. Often, that means a major
performance hit. Finding an alternate form for this function that only
requires fewer temporary registers could be a major benefit. Obviously
finding these equivalences could be done by hand, but having a
computer do it seemed both faster and more interesting.

.. TEASER_END

I ended up implementing the equivalence finder in Common Lisp. I
like Lisp, as a language, quite well; unfortunately its qualities as
an overall application platform leave something to be desired. But in
this case that wasn't an issue. After a few false starts, I came up
with a working (if inefficient and ugly) design. Each piece of the the
function was represented by a closure over the expression that it
contains. For example, the function for "and the current expression
with the X variable" is::

   (defun andx (next)
     #'(lambda (x y z) (and x (funcall next x y z))))

And so on for the various other useful expressions. At the bottom
there are some kernels, which do not contain any additional
expressions, but just a single variable reference. For example::

   (defun kernelz (x y z) z)

So ``(xory (andx kernelz))`` is function taking three arguments and
computing (Y xor (X and Z)).

We then perform a depth-first search on all possible expressions until
we find ones that evaluate the same as our target function. Why
depth-first? Mostly because it was simple to program; after we hit a
preset depth, we back out of that path and go upwards. Since an
equivalent to our target with a hundred terms in it wouldn't be
terribly useful (remember, we're looking for ways to optimize code),
dropping out of the search after the expression has reached 5 or 6
terms should be fine.

The first test was ((A and B) or ((not A) and C)), which is a function
used in the SHA-1 hash. This has a known simpler version, discovered
some years ago by Colin Plumb. And it was indeed able to find that (C
xor (A and (B xor C))) is an equivalent. It was also able to find an
equivalent for a related function in SHA-256.

Some useful enhancements will be pruning expressions that are
equivalent, and performing the search breadth-first to ensure we
always find the shortest possible expression. Eventually I'm planning
on using this code for searching for more efficient versions of the
Serpent Sboxes, which are described as 4-bit to 4-bit boolean
functions. In particular, it might be interesting to try and find
versions that are well-suited for implementation on SSE2, IA-64, or
other "exotic" targets (most versions so far have been optimized for
x86 or general RISC targets like PowerPC and SPARC).

