.. title: A Failure Case in a Linux Random Number Generator
.. slug: linux_random32_fail
.. date: 2008-07-01
.. tags: programming

The Linux kernel implements a random number generator called a
Tausworthe generator, in the file ``lib/kernel32.c``. The kernel uses
this generator for a variety of non-cryptographic purposes, such as
calculating network delays and random ports numbers, choosing a random
element to drop from full caches, and many other places where a
randomized algorithm is useful. While looking through this source, I
found some cases where it could fail quite dramatically.

.. TEASER_END

The state of the generator consists of three 32-bit integers,
providing 96 bits of state::

   struct rnd_state {
           u32 s1, s2, s3;
   };

These three values must be initialized in a particular way to ensure
the generator works correctly. A quote from the original paper
describing the generator [#Tausworthe]_ is included in the source to
document these conditions:

   ... the k_j most significant bits of z_j must be non-zero, for each
   j. (Note: this restriction also applies to the computer code given in
   [4], but was mistakenly not mentioned in that paper.)

With an additional note that "This affects the seeding procedure by
imposing the requirement s1 > 1, s2 > 7, s3 > 15." (In the source, s1,
s2, s3 of ``rnd_state`` correspond to z_1, z_2, z_3 in the paper).

To generate output, the following transformation is used (the code
used in the kernel uses decimal values for the constants, which hides
the underlying binary structure)::

   s1 = ((s1 & 0xFFFFFFFE) << 12) ^ (((s1 << 13) ^ s1) >> 19);
   s2 = ((s2 & 0xFFFFFFF8) <<  4) ^ (((s2 <<  2) ^ s2) >> 25);
   s3 = ((s3 & 0xFFFFFFF0) << 17) ^ (((s3 <<  3) ^ s3) >> 11);
   return (s1 ^ s2 ^ s3);

Particularly notable here is that, if all of ``s1``,
``s2``, and ``s3`` are zero, then the generator will output
nothing but zero values forever.

To set up the initial state, the kernel first grabs an ``unsigned
long``'s worth of randomness from the kernel entropy pool using
``get_random_bytes`` (this is the same high-entropy RNG used to feed
``/dev/random``), which it calls ``s``. The code first checks to make
sure ``s`` is not zero, and if so, sets it to 1.  Then, it derives
``s1``, ``s2``, and ``s3`` from ``s`` using this procedure::

   #define LCG(n) (69069 * n)
   state->s1 = LCG(s);
   state->s2 = LCG(state->s1);
   state->s3 = LCG(state->s2);

Recall that ``s`` is an ``unsigned long``, so on 64-bit systems, the
product assigned to ``s1`` will also be 64 bits, but truncated down to
a 32-bit value. Herein lies the bug: if the low 32 bits of ``s`` are
zero, but at least one high bit is set, then the comparison to zero
will not be true, but the resulting product will have 32 low order
bits. After being truncated, ``s1`` will be zero, which will then also
cause ``s2`` and ``s3`` to be zero. As mentioned, this will cause the
RNG to output nothing but zero values forever. To a first
approximation, ``get_random_bytes`` will return a uniform random
value, so the odds of this happening are roughly 1/2\ :sup:`32`, or
about 1 in 4 billion. The RNG is seeded at boot time, with one RNG
state per CPU (presumably this is to remove locking
contention). Taking a pair of WAGs that there are 20 million CPUs
running Linux, and that the average uptime of a Linux machine is 10
days, that suggests an all zero RNG output will occur on at least one
CPU about every 6 years.

Additionally, the invariant mentioned in the source, that s1 >
1, s2 > 7, s3 > 15, are not actually met with the current
code. For instance on 32-bit systems (with ``sizeof(long)`` = 4),
a seed of 0x4BC54E0A will generate the state s1 = 0x4BC54E0A, s2 = (s1
* 69069) % 2\ :sup:`32` = 2, s3 = 2*69069 = 138138. In a random
sampling, I found there were large numbers of these bad seeds for both
32-bit and 64-bit systems. The paper that describes the RNG does not
actually specify how badly violating this condition breaks the
generator, though, so it's unclear how serious this actually is.

I submitted a patch to fix these bugs to `LKML <http://www.ussg.iu.edu/hypermail/linux/kernel/0806.2/1419.html>`_ on June 19. While I got no replies, today it was included as
part of Andrew Morton's -mm branch, so this bug should be fixed in
upcoming kernels.

.. [#Tausworthe]
  P. L'Ecuyer,
  `Maximally Equidistributed Combined Tausworthe Generators <http://www.iro.umontreal.ca/~lecuyer/myftp/papers/tausme.ps>`_,
  Mathematics of Computation, 65, 213 (1996), 203--213
