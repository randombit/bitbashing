.. title: Optimizing Forward Error Correction Coding Using SIMD Instructions
.. slug: forward_error_correction_using_simd
.. date: 2009-01-19
.. tags: programming, simd

Forward error correction (FEC) is a technique for handling lossy
storage devices or transmission channels. A FEC code takes *k* blocks
of data and produces an additional *m* blocks of encoding information,
such that any set of *k* of the blocks (out of the *k+m* total) is
sufficient to recover the original data. One can think of RAID5 as a
FEC with arbitrary *k* and *m* fixed at 1; most FEC algorithms allow
wide latitude for the values that can be sent, allowing the code to be
adjusted for the reliability expectations and needs of the particular
channel and application. For instance, the `Tahoe
<http://allmydata.org/trac/tahoe>`_ distributed filesystem splits
stored files using *k* of 3 and *m* of 7, so as long as at least 30%
of the devices storing the file survive, the original file can be
recoved.

.. TEASER_END

One of the best known open source FEC implementations is Luigi Rizzo's
`fec <http://www.iet.unipi.it/~luigi/fec.html>`_ library, which was
later adapted into projects including `zfec
<http://allmydata.org/trac/zfec>`_ (the FEC library used in Tahoe) and
Onion Network's `Java FEC lib <http://onionnetworks.com/developers/>`_.
Rizzo's fec implements a Reed-Solomon code using Vandermonde matrices,
which works by multiplying the input data against a specially
constructed matrix in GF(2\ :sup:`n`). The first *k* rows of this
matrix are *I*, the identity matrix, which when multiplied against the
vector containing the input data, produces exactly the input
data. Codes with this property, that the first blocks of encoded data
contain an exact bitwise copy of the input, are referred to as
systematic codes. The final *m* rows are constructed in such a way
that a matrix formed by choosing any arbitrary *k* rows of the
encoding matrix is invertible (this is equivalent to saying that each
row of the matrix is linearly independent from the others)

The reason for wanting to be able to invert the matrix becomes clear once we
consider how to decode some set of *k* shares into the original input
data. This set of shares is exactly the data that would have been produced had
the original data been multiplied by a *k* * *k* matrix containing
only the rows corresponding to the surviving shares - thus, multiplying the
vector by the inverse of this matrix always results in the original input
vector.

It would be possible to implement this algorithm using infinite
precision integers, but for efficiency (using only fixed size
elements), the matrix elements are taken from a finite field, which
normally is chosen to be a power of 2 that matches a CPU wordsize,
typically 2\ :sup:`8` or 2\ :sup:`16`, though `Paul Crowley and
Sebastian Egner <http://www.lshift.net/blog/2006/11/29/gf232-5>`_ have
shown how to efficiently implement finite field arithmetic in GF(2\
:sup:`32`-5). Rizzo's fec supports a range of field sizes, but others,
including zfec, restrict it to 2\ :sup:`8` since that tends to be the
most efficient field to operate in on most computers.

Computing the matrix multiplication requires a series of row-level
multiply-add operations. Profiling (using `valgrind
<http://valgrind.org>`_ and `kcachegrind
<http://kcachegrind.sourceforge.net>`_) indicated this operation takes
up over 90% of the runtime for both encoding and decoding
operations. In a finite field of characteristic two, addition and
subtraction are both implemented easily as XOR, but multiplication and
division are significantly more complex; multiplying two field
elements in GF(2\ :sup:`8`) looks like this::

   byte gf_mul(byte a, byte b)
      {
      byte product = 0;

      for(size_t counter = 0; counter < 8; ++counter)
         {
         if((b & 1) == 1)
            product ^= a;
         bool hi_bit_set = (a & 0x80);
         a <<= 1;
         if(hi_bit_set)
            a ^= 0x1D; /* x^8 + x^4 + x^3 + x^2 + 1 */
         b >>= 1;
         }

      return product;
      }

Normally, instead the multiplication operation is performed using a
precomputed table of exponentials and logarithms, which reduces the problem to a
set of table lookups and an addition::

   byte gf_mul(byte a, byte b)
      {
      return GF_EXP[(GF_LOG[a] + GF_LOG[b]) % 255];
      }

which is much faster than the loop-based algorithm given above. The reduction
modulo 255 is not strictly necessary - since each element of GF_LOG is at most
255, instead you can double out GF_EXP to 510 elements, with the last half of
the array simply replicating the first half.

Rizzo's fec includes an optimization to use a larger 64 kilobyte table which
precomputes all byte-by-byte multiplications.

This month I've been doing some work with updating Rizzo's fec with
relatively convenient C++ API, as well as optimizing some of the
internals. During that process, I realized it is possible to implement
GF(2\ :sup:`8`) multiplications in parallel using SSE2 or other SIMD
instruction sets.

The trick is to go back to the slower loop based operation. Here was
my initial prototype of the addmul inner loop which I used to test the
concept::

   void addmul(byte z[], const byte x[], byte y, size_t size)
      {
      if(y == 0)
         return;

      const size_t blocks_16 = size - (size % 16);

      const byte polynomial[16] = {
         0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D,
         0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D, 0x1D };

      for(size_t i = 0; i != blocks_16; i += 16)
         {
         byte products[16] = { 0 };

         byte x_is[16];
         memcpy(x_is, x + i, 16);

         for(size_t j = 0; j != 8; ++j)
            {
            if((y >> j) & 1)
               for(size_t k = 0; k != 16; ++k) // pxor
                  products[k] ^= x_is[k];

            byte mask[16] = { 0 };
            for(size_t k = 0; k != 16; ++k) // maskmovdqu
               if(x_is[k] & 0x80)
                  mask[k] = polynomial[k];

            for(size_t k = 0; k != 16; ++k) // paddb
               x_is[k] = x_is[k] + x_is[k];

            for(size_t k = 0; k != 16; ++k) // pxor
               x_is[k] ^= mask[k];

            }

         for(size_t k = 0; k != 16; ++k) // pxor
            z[i+k] ^= products[k];
         }

      for(size_t i = blocks_16; i != size; ++i)
         {
         byte product = 0;
         byte x_i = x[i];

         for(size_t j = 0; j != 8; ++j)
            {
            if((y >> j) & 1)
               product ^= x_i;
            bool high_set = (x_i & 0x80);
            x_i <<= 1;
            if(high_set)
               x_i ^= 0x1D;
            }

         z[i] ^= product;
         }

Comparing the two loops, the equivalence is pretty straightforward.
The only confusing parts are the replacement of the right shift by 1
with an addition; SSE2 contains bitshift instructions for operating on
64, 32, and 16 bit elements in a SSE register, but not on
bytes. However a right shift by 1 is equivalent to a multiplication by
2, which is the same as adding the same value twice, so the byte-wise
addition instruction ``paddb`` works nicely.

The other difficult part is that the XOR of the bitwise representation of the
polynomial should only occur if the right shift overflowed. Reading through
Intel's processor `manuals <http://www.intel.com/products/processor/manuals/>`_, I found
MASKMOVDQU, which seemed, at first, to be exactly what I wanted:

   Stores selected bytes from the source operand (first operand) into
   a 128-bit memory location. The mask operand (second operand)
   selects which bytes from the source operand are written to
   memory. The source and mask operands are SSE registers. The most
   significant bit in each byte of the mask operand determines whether
   the corresponding byte in the source operand is written to the
   corresponding byte location in memory: 0 indicates no write and 1
   indicates write.

However tests showed my implementation using Intel intrinsics was
about 10 times slower than using a simple 64 kilobyte lookup
table. This turned out to be mostly due to my choice of MASKMOVDQU for
creating the mask. First, MASKMOVDQU can only write to memory, so I
had to create a buffer on the stack, have MASKMOVDQU write to it, and
then immediately read it back into a SSE register. Worse, the
instruction assumes this memory address is not properly aligned -
meaning it is much slower than is necessary, since there is no problem
aligning the buffer using GCC's __attribute__((aligned)) syntax. And
third, it writes only to a fixed location in memory, specified by the
EDI register. This causes trouble in particular because I wanted to
unroll the loop 4 times to process 64 bytes (a L1 cache line's worth
of data) at a time, but the pipeline was probably stalling constantly
due to conflicting reads and writes in this memory location.

So, how to generate the mask? What we specifically want here is a SSE
register whose bytes are 0 or 0x1D (the primitive polynomial),
depending on if the high bits of the bytes in another SSE register are
set. The SSE compare instructions seemed promising for this: if the
comparison is true for a subword, the instruction will fill the
corresponding word in the result with all 1 bits, or otherwise all 0
bits. So combining the result of the right SSE comparison operation
with a vector containing 16 0x1D bytes using a bit-wise AND would
generate our desired mask.

For various reasons (mostly because I was hacking on it at 2 in the
morning and didn't read Intel's documentation correctly) I initially
believed that I could not use PCMPGTB, the byte-wise greater than
comparison operation. So the solution I came up with to generate the
mask without using this instruction was to add 0x7F to each byte using
saturating arithmetic - if the high bit is set, this will clamp the
result to 0xFF, leaving ones that did not have the high bit set with
some value between 0x7F and 0xFE. Then by comparing each byte for
equality with 0xFF, we generate the mask containing bytes of either
all 0 or all
1. Using Intel intrinsics, this looks like::

   const __m128i polynomial = _mm_set1_epi8(0x1D);
   const __m128i high_bit_set_if_gt = _mm_set1_epi8(0x7F);
   const __m128i all_ones = _mm_set1_epi8(0xFF);

   [...]

   __m128i mask = _mm_adds_epu8(x, high_bit_set_if_gt);
   mask = _mm_cmpeq_epi8(mask, all_ones);
   mask = _mm_and_si128(mask, polynomial);

This version was much faster than using MASKMOVDQU, but still slower
than a table lookup on the x86 processors I have. As this instruction
sequence executes 7 times for every 16 bytes of data, I really wanted
to shorten this up, and searched through the instruction references
for all the x86 SIMD instruction sets in vain; the Wikipedia
description of the SSSE3 instruction PSIGNB, that it will "Negate the
elements of a register of bytes, words or dwords if the sign of the
corresponding elements of another register is negative." gave me some
hope, but it turns out to have some funky semantics which I think
prevent it from being useful for this application.

After puzzling over this for a while, I finally realized that the
comparison operation actually would work for my purposes, and I
changed the mask generation to::

   const __m128i polynomial = _mm_set1_epi8(0x1D);
   const __m128i all_zeros = _mm_setzero_si128();

   [...]

   __m128i mask = _mm_cmpgt_epi8(all_zeros, x);
   mask = _mm_and_si128(mask, polynomial);

SSE2 only contains signed comparison operators (this is part of what
confused me in the first place), so when we check that 0 is greater
than x, the result will only be true iff the sign bit (the MSB) of
each byte in x is set, which is exactly what we are going for.

Using this sequence to generate the mask, the SSE2 code is
significantly faster than using a byte at a time lookup into a 64
kilobyte table of precomputed results on both an Opteron and a Core2
(twice as fast, for large blocks), though it is actually a bit slower
on my Pentium4-M laptop. This is a bit disappointing but not hugely
surprising - the SSE2 version is doing a great deal more computational
work than the lookup table version, so it will only be faster when the
ratio of SIMD instructions per clock to memory access latency (in CPU
clocks) is sufficiently high. So I suspect SIMD GF(2\ :sup:`8`)
multiplications will be a win on processors like the Intel Core2 and
i7, the STI Cell, or the PowerPC 970, all of which have incredibly
amounts of SIMD horsepower but relatively poor memory latency (in
terms of CPU clock cycles), while less SIMD-focused processors (or
those with very low memory latencies) will continue to get superior
performance using lookup tables. However from my understanding of the
current and likely near-future state of processors, the former are
going to become much more common than the latter.

I have also experimented with various loop optimizations, such as loop
tiling, which is often used to optimize large matrix multiplications,
but with no measurable speedups on any platform. I am hoping to
revisit this issue later in terms of multithreaded operation, since
cache effects may become more important with multiple threads
competing for a limited amount of L2 cache.

The full source code of my BSD-licensed implementation is available on
`Github <https://github.com/randombit/fecpp>`_. There is not much
documentation but the readme contains an overview and there are a few
example programs, including a zfec-compatible encoder.

