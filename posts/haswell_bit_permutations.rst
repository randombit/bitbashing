.. title: Bit manipulations using BMI2
.. slug: haswell_bit_permutations
.. date: 2012-06-02
.. tags: programming

Intel's Haswell design (expected in 2013) will include a new
instruction set called BMI2 with various fun bit manipulation
instructions. Particularly of note are the ``pext`` and ``pdep``
instructions which are essentially bit-level gather/scatter
operations. Combining two ``pext`` operations results in the GRP
instruction described in `Efficient Permutation Instructions for Fast
Software Cryptography
<http://palms.ee.princeton.edu/PALMSopen/lee01efficient.pdf>`_, where
the authors show how to implement bit level permutations using a
variety of instructions. Perhaps not coincidentally at least one of
the authors now works at Intel.

.. TEASER_END

Here are the operations written in as C++ templates (Haswell will only
support ``pdep`` and ``pext`` with 32 and 64 bit operands, though). As
might be apparent, they are written for clarity rather than speed:

.. code-block:: c++

  template<typename T>
  T pext(T val, T mask)
     {
     T res = 0;
     size_t off = 0;

     for(size_t bit = 0; bit != sizeof(T)*8; ++bit)
        {
        const bool val_bit = (val >> bit) & 1;
        const bool mask_bit = (mask >> bit) & 1;

        if(mask_bit)
           {
           res |= static_cast<T>(val_bit) << off;
           ++off;
           }
        }

     return res;
     }

  template<typename T>
  T pdep(T val, T mask)
     {
     T res = 0;
     size_t off = 0;

     for(size_t bit = 0; bit != sizeof(T)*8; ++bit)
        {
        const bool val_bit = (val >> off) & 1;
        const bool mask_bit = (mask >> bit) & 1;

        if(mask_bit)
           {
           res |= static_cast<T>(val_bit) << bit;
           ++off;
           }
        }

     return res;
     }

These have been checked fairly heavily (though obviously not
exhaustively), against what is produced by Intel's `emulator`_.

The paper shows that any arbitrary 32-bit permutation can be done
using 10 ``pext``\ s, 5 ors and 5 shifts. For 64-bit permutations,
it's 12, 6, and 6. A big unknown is what kind of latency and
throughput these instructions will have in Haswell, but ``pclmulqdq``,
which seems at least a metaphorically similiar operation, takes 14
cycles with at most two instructions outstanding - assuming those
rates for ``pext``, a 32-bit permutation might take 80 cycles or so.

Here's the DES P permutation:

.. code-block:: c++

  uint32_t des_p(uint32_t val)
     {
     val = (pext(val, 0x07137FE0) << 16) | pext(val, 0xF8EC801F);
     val = (pext(val, 0x75196E8C) << 16) | pext(val, 0x8AE69173);
     val = (pext(val, 0x56A3CCE4) << 16) | pext(val, 0xA95C331B);
     val = (pext(val, 0xAA539AC9) << 16) | pext(val, 0x55AC6536);
     val = (pext(val, 0x96665A69) << 16) | pext(val, 0x6999A596);
     return val;
     }

And here's DES's initial permutation:

.. code-block:: c++

  uint64_t des_ip(uint64_t val)
     {
     val = (pext(val, 0x00FF00FF00FF00FF) << 32) | pext(val, 0xFF00FF00FF00FF00);
     val = (pext(val, 0x00FF00FF00FF00FF) << 32) | pext(val, 0xFF00FF00FF00FF00);
     val = (pext(val, 0x00FF00FF00FF00FF) << 32) | pext(val, 0xFF00FF00FF00FF00);
     val = (pext(val, 0xCCCCCCCCCCCCCCCC) << 32) | pext(val, 0x3333333333333333);
     val = (pext(val, 0xCCCCCCCCCCCCCCCC) << 32) | pext(val, 0x3333333333333333);
     val = (pext(val, 0x5555555555555555) << 32) | pext(val, 0xAAAAAAAAAAAAAAAA);
     return val;
     }

The regularity of the IP operation is pretty obvious, and suggests one
could get by with a much less powerful operation (and indeed Richard
Outerbridge and others have gotten IP down to 30 simple operations)

Finally, `PRESENT`_'s permutation, also a very regular operation:

.. code-block:: c++

  uint64_t present_p(uint64_t val)
     {
     val = (pext(val, 0xF0F0F0F0F0F0F0F0) << 32) | pext(val, 0x0F0F0F0F0F0F0F0F);
     val = (pext(val, 0xF0F0F0F0F0F0F0F0) << 32) | pext(val, 0x0F0F0F0F0F0F0F0F);
     val = (pext(val, 0xF0F0F0F0F0F0F0F0) << 32) | pext(val, 0x0F0F0F0F0F0F0F0F);
     val = (pext(val, 0xF0F0F0F0F0F0F0F0) << 32) | pext(val, 0x0F0F0F0F0F0F0F0F);
     val = (pext(val, 0xAAAAAAAAAAAAAAAA) << 32) | pext(val, 0x5555555555555555);
     val = (pext(val, 0xAAAAAAAAAAAAAAAA) << 32) | pext(val, 0x5555555555555555);
     return val;
     }

Each pair of ``pext``\ s in the above examples is actually a GRP::

  (pext(v, mask) << hamming_weight(mask)) | pext(v, ~mask)

which has the effect of moving all the bits of ``v`` where mask is 1
to the leftmost part of the output, and all the other bits to the
rightmost part.

To generate the sequence of constants, we actually use the same
grouping operation. Your input is an array of words specifying where
each bit should end up. For a 32 bit permutation, each target is 5
bits because it is in the range [0,2\ :sup:`5`), so 160 bits sufficies
to specify the permutation. We convert this to 5 32-bit values, with
the lowest bits of each target index in ``p``\ [0], the 2nd bit of
each target index in ``p``\ [1], and so on. For instance for DES's P,
the values turn out to be::

   p[0] = 0x07137FE0
   p[1] = 0x6BD9232C
   p[2] = 0xDD230F1C
   p[3] = 0x63665639
   p[4] = 0xA5A435AE

Then we can use 15 GRP operations to perform the permutation::

   for i in range(0, 5):
       x = GRP(x, p[i])
       for j in range(i+1, 5):
          p[j] = GRP(p[j], p[i])

However you'll note that almost all of these operations do not depend on
*x*, and we can precompute them::

   for i in range(1, 5):
      for j in range(0, i):
         p[i] = GRP(p[i], p[j])

producing the values hardcoded into the function above.

This approach works for any arbitrary permutation, which is
convenient, but many permutations can be done with fewer operations,
which is pretty relevant since it is rare to need to perform arbitrary
bit permutations compared to performing specific fixed ones.

There are likely many other useful cryptographic applications to the
BMI2 instruction set. Areas that seem particularly ripe for this
include GF\(2^n) mathematics (including GCM's MAC calculation), the
DES round function (likely possible in constant time), perhaps some
LFSRs, and a few of the recent hardware-oriented primitives like
PRESENT, as in hardware a bit permutation is often free. I will also
be interested to see if in a few years, new designs start making use
of cheap bit permutations, key-dependent permutations, or more
elaborate bit operations like bit interleaving of two words, in the
same way that some SHA-3 entries took advantage of the cheap AES round
function AES-NI made available. There is always a tradeoff with this,
though, as running such an algorithm on processors without BMI2 would
mean using a loop such as the ones above, which would be much slower,
and possibly even (as with my templates above) not always running in
constant time, opening up a dangerous side channel.

On some processors and some compilers, if you replace the conditional
in the templates above with::

   res |= (static_cast<T>(val_bit & mask_bit)) << bit;
   off += mask_bit;

it will run in constant time, but you should definitely verify that is
the case by examining the assembly your compiler produces, as a
compiler can sometimes surprise you with its choice of instructions,
including a conditional jump where you do not expect it.

.. _emulator: http://software.intel.com/en-us/articles/intel-software-development-emulator/
.. _PRESENT: http://homes.esat.kuleuven.be/~abogdano/papers/present_ches07.pdf
