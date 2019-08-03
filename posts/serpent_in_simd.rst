.. title: Speeding up Serpent: SIMD Edition
.. slug: serpent_in_simd
.. date: 2009-09-09
.. tags: crypto, simd

The `Serpent <http://www.cl.cam.ac.uk/~rja14/serpent.html>`_
block cipher was one of the 5 finalists in the AES competition, and is
widely thought to be the most secure of them due to its conservative
design.  It was also considered the slowest candidate, which is one
major reason it did not win the AES contest. However, it turns out
that on modern machines one can use SIMD operations to implement
Serpent at speeds quite close to AES.

.. TEASER_END

Serpent uses an interesting bitsliced design with eight 4 bit sboxes
which are computed in parallel using boolean operations on
registers. Rather than splitting up the 32 bit words into nibbles and
passing them through table lookups, a special instruction sequence is
used which performs the same operation using only instructions like
AND, OR, XOR, and NOT. Typically these are done using 32 bit register
operations, but it was recently `suggested
<http://groups.google.com/group/crypto-optimization/browse_thread/thread/6bb0e3a7ef1cec99>`_
that SIMD operations such as those available in SSE2 or AltiVec could
be used to encrypt 4 blocks in parallel.

Most cipher modes, such as CBC and OFB, are iterative; after
splitting the plaintext into blocks, the input to the second block
depends on the previously computed ciphertexts. This data dependency
means it is impossible to use a block-parallel implementation in these
modes. However some other modes, including CTR, EAX, and XTS, do not
exhibit this data dependency, and allow for many blocks to be
encrypted in parallel. So being able to compute many encryptions in
parallel is only useful for these modes. Fortunately, CTR, EAX, and
XTS are very useful, unpatented, and (in the case of CTR and XTS)
widely standardized modes.

Recently I implemented Serpent using SSE2 intrinsics in the
`botan <http://botan.randombit.net/>`_ cryptography library.
While not quite as fast as AES, it easily boosts Serpents performance
by a factor of over 2.5 on an Intel Core2 processor.

Up until now, botan has used a rather conventional block cipher
interface where only a single block of data (typically 64 or 128 bits)
would be encrypted at a time; processing multiple blocks required
calling the function multiple times, one for each block. However this
completely hides any parallelism from the block cipher implementation.
So in the upcoming development release (1.9.0), botan offers two new
interfaces for block ciphers::

   void encrypt_n(const byte in[], byte out[], u32bit blocks) const;
   void decrypt_n(const byte in[], byte out[], u32bit blocks) const;

which will process many blocks in a single call. In addition some
mode implementations (at this time, ECB and CTR) will batch their
inputs into larger groups. This will not only allow for parallel
encryption using SIMD techniques, it also improves instruction and
data cache utilization for all ciphers. Right now, the modes will
batch 8 blocks of data together; it is unclear if this is sufficient
for the best performance, but in any case is easy to modify by
changing a macro value in ``build.h``.

On a 2.4 GHz Intel Core2 with GNU C++ 4.3.3, I got these
results:

============  ======  ======  ========
Algorithm     1.8.6   1.9.2   Speedup
============  ======  ======  ========
Serpent/ECB    42.1   113.5   2.7
Serpent/CTR    39.7   100.8   2.5
AES-128/ECB   112.7   134.4   1.2
AES-128/CTR    99.1   114.1   1.15
============  ======  ======  ========

The AES speedups nicely demonstrate that even without any explicit
SIMD operations, the improved cache utilization can make a pretty big
difference.

I also experimented with performing 8 Serpent block operations in
parallel, by interleaving two 4-wide SIMD encryptions. This reduced
the number of key variable loads, as well as offering the processor
much more in the way of independent computations for hot hot
superscalar action. On my Core2, this pushed Serpent's performance
north of 160 MiB/s in CTR mode, which is pretty impressive considering
that is right about the speed of OpenSSL's AES-128 implementation on
the same platform. However this variant seems slower on anything but a
Core2; tests on an Opteron showed it to be somewhat slower than 4-way
SIMD, and it is highly likely that it would also be much slower on
32-bit x86 processors due to excessive register pressure.

AltiVec looks to be an even more promising platform for multiblock
Serpent encryption, as it includes native rotation instructions, which
in SSE2 must be emulated using two shifts and an OR. It is very likely
the Cell processors SIMD units could also implement Serpent in a SIMD
mode. Considering the Cell SPE contains 128 SIMD registers, it might even
be feasible to implement a variant suggested by Wei Dai of encrypting
`128 blocks in parallel <http://groups.google.com/group/crypto-optimization/msg/ed57680512e81ab2>`_
without suffering an excessive number of register spills.

2009-10-20 addendum: On an Intel Atom N270, this SSE2 implementation
of Serpent is over twice as fast as OpenSSL's assembly implementation
of AES-128.
