.. title: Fun with assembly
.. slug: x86_asm_hashing
.. date: 2006-08-13
.. tags: programming, crypto

   "If you can explain how you do something, then you're very very bad at it."
     -- John Hopfield

The `Monotone <http://venge.net/monotone>`_ folks have been doing some
profiling and performance work of late. One thing that came out of
that was the finding that Botan's SHA-1 implementation was causing a
bottleneck; because Monotone identifies everything via hashes, there
are times where it needs to hash many (many) megabytes of source data,
and the faster that happens, the better. Since low-level C++ wasn't
cutting it, I felt that it was time to try my hand at x86 assembly
again.

.. TEASER_END

Initially, I simply followed the flow of the existing, and fairly well
optimized, C++ code. Since that code is quite low level, it was fairly
easy to map; many statements in the source corresponded directly to a
single x86 machine instruction. The algorithm fits the machine well -
the 5 chaining variables went into ``%eax``, ``%ebx``, ``%ecx``,
``%edx``, and ``%esi``, leaving ``%edi`` to point to the (expanded)
message and ``%ebp`` as a temporary. This let almost all operations
run out of registers, with the exception of the boolean function in
the third round. The majority function, ``(B & C) | (B & D) | (C &
D)``, can be reduced a bit, down to ``((B & C) | ((B | C) & D))``, but
it still requires two independent variables - you have to have both
``B & C`` and ``((B | C) & D))`` computed before you can OR them
together, and that means two temp variables. I ended up stealing a
(previously used) word out of the expanded message array to hold ``(B
| C)``, which was serviceable if hackish.

The loop to perform the message expansion was partially unrolled (four
times, about as big as could be done and not spill any registers);
this change made for a noticeable (10%) speed increase. The loop that
read in the actual input and byte swapped it was also unrolled; I'm
not certain that this made much of an impact on performance, but it
was easy enough to do, and will perhaps help hide the latency of the
bswap operation (7 cycles on some versions of the Intel P4!)

The code at this stage was not particularly efficient, and I knew it,
but it still managed to run around 20% faster than the code produced
by GCC with full optimizations. Botan's benchmark system came in very
useful here, as it allowed me to directly compare the performance of
the C++ code, the assembly, and of OpenSSL's implementation (all
benchmarks used the hardware time stamp counter and randomly generated
inputs). While my 90 Mib/sec looked great in comparison to the C++, it
didn't fare so well against OpenSSL's assembly, chewing up 130
megabytes every second. And the disparity on a P4-M was even larger.

I was already using the C macro preprocessor for simple looping
constructs and so forth, but to improve readability, and make it
easier to work with the code, I converted everything to macro calls.
This also got rid of the AT&T syntax weirdness of having the output
operand last, which I found troublesome when visually comparing C and
assembly. As a final bonus, it means that, at least in theory, I'll be
able to use the code with Intel assemblers by simply swapping out a
header file of macro definitions. Here's a sample of how it looks, for
the curious::

   ZEROIZE(ESI)

   START_LOOP(.LOAD_INPUT)
      ADD_IMM(ESI, 1)
      ASSIGN(EAX, ARRAY4(EBP, 0))
      ADD_IMM(EBP, 4)
      BSWAP(EAX)
      ASSIGN(ARRAY4_INDIRECT(EDI,ESI,0), EAX)
   LOOP_UNTIL(ESI, IMM(16), .LOAD_INPUT)

This is certainly not the best or most complete assembly macro
language out there, but by adding macros as I needed them, I ended up
with a fairly reasonable system; I eventually used this same set of
macro calls to implement MD4 and MD5. And using the C preprocessor
rather than something specialized, like M4 or a yacc/lex-based
language, made it easy to fit the code into Botan's build environment.

After "rewriting" the code into macros, I went through and reordered
various instructions in an attempt to break dependency chains and hide
latencies as much as possible. In particular, I found that moving
loads well before use (4 or 5 cycles) made a *very* substantial
difference. While I knew that the latency of a L2 cache read could run
into dozens of processor cycles, I had assumed the out of order
execution cores of the Athlon and P4 would handle this detail for
me. But, it seems, hand-tweaking of instruction ordering is still
necessary for the best possible performance. All told, these changes
pushed the speed to just over a 100 megabytes a second.

At this point I felt pretty well stuck; I couldn't figure out how I
could squeeze any more performance out of the code, but OpenSSL was
still running 30% faster than me - obviously the hardware was capable
of more, but how? I had no idea.

So I checked everything into the repository, and sat down to read
for a while.  Specifically, I picked up my copy of the Intel Pentium
4/Pentium M `optimization manual <http://www.intel.com/design/pentium4/manuals/248966.htm>`_, and came up with some neat (if almost
entirely unoriginal) tricks. I'll write about those later on, those
who wish to read ahead can check out ``sha1core.S`` in the latest
version of Botan.
