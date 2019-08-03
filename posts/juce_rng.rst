.. title: The More Things Change...
.. slug: juce_rng_fail
.. date: 2008-12-05
.. tags: crypto

   "Anyone who considers arithmetic methods of producing random digits
   is, of course, in a state of sin." - John von Neumann, 1951

On an Ubuntu forum I caught a reference to a C++ library called `JUCE
<http://www.rawmaterialsoftware.com/juce/>`_, which is one of those
all-inclusive C++ libraries along the lines of `POCO
<http://pocoproject.org>`_ or `GNU Common C++
<http://www.gnu.org/software/commoncpp/>`_. One thing I noticed was
that it includes a few cryptographic operations, including RSA key
generation, so I decided to take a peek at the latest release as of
this writing, 1.46.

.. TEASER_END

Tracing through the code, we find the primes for the RSA keys are
created by calling ``Primes::createProbablePrime``, which generates a
random starting point and then uses a sieve to find the nearest prime
number. The random starting point is chosen on line 131 of
``juce_Primes.cpp``, using ``BitArray::fillBitsRandomly``. This
function in turn calls ``Random::getSystemRandom()`` to actually get
random data. So far so good.

From the name "getSystemRandom", I assumed this would in turn use an
OS specific RNG like ``/dev/random`` on Linux/OS X or CryptGenRandom
on Windows. So you can imagine my horror to find that JUCE's 'system
RNG' is a linear congruential generator, seeded with the constant
value 1::

   static Random sysRand (1);

   Random& Random::getSystemRandom() throw()
   {
       return sysRand;
   }

OK, where to start.

First off, of course seeding with a constant value is just terrible,
about the worst case one could imagine, cryptographically
speaking. For any given bit length, JUCE will always generate the same
RSA key, every time, on *every machine everywhere*. The only possible
differentiator is how many times the RNG is stepped prior to the RSA
key is created. To confirm this I wrote a program that generates 10
256-bit RSA keys::

   #include <juce_amalgamated.h>
   #include <iostream>

   using namespace juce;

   int main()
      {
      for(int i = 0; i != 10; ++i)
         {
         RSAKey public_key;
         RSAKey private_key;
         RSAKey::createKeyPair(public_key, private_key, 256);

         const char* s = private_key.toString();

         std::cout << s << "\n";
         }
      }

And this program will always generate the exact same set of RSA
keys, namely::

   a209135d3ee17dcfd94c82d6f091deb5ad6d6f544bb2ec150b65b9bead0b07c9,d3e47bc8b4b0b8372fda34f1b0bec0c803b5ea206a39967727816dfd101d271b
   c0564aaed7b7d5762ced59cf0d95c0a4da43d6d5bed0f87406760d781efd8ac9,e98d5aafbcccf0eaed695ac4907efc37cda86726feb9b4b793d0056e5efc6af9
   79fa7870b31feda3606c1e0922560f26f33be3764be89d9425acfc0034a0492b,b6f7b4a90cafe47510a22d0db38116bc22e804cc672758984846edf7c2db2501
   48343ab33dbaf483bdf514b7769312cd39a150e76e2991be690b194195498cd3,6c4e580cdc986ec59cef9f1331dc9c3524a64161ba3678276ce1c4528b95acbd
   1efc8ae862fa270e7258649ac718968e4e043c857a6e40644d3bfe11ec3c83cd,9aeeb689eee2c3483bb9f705e37af0c914648e0b46a5c29245dbb5ae014343bb
   81829de5126bd77cb3f4f76c9a34e48f04247a4bf7a9b96365639144a78e5131,899ac7c3639294f47f3446e363d832d97cc0f7cd6b19d03ac08e27b05a48a601
   450983766dc84447df4578a1f7aa549326002aa25eb4ec75ffe20f6c92d36ecb,678e4531a4ac666bcee834f2f37f7ede076d4eaed561e605a4f981765d49ae6b
   50ae0de272b7a3bc1cd91b57dc67d90a01e1777e4b1c739724bfe83f0dcc2e53,790514d3ac13759a2b45a903ca9bc59063e5e91a1462451bdc42dca9e5c5800d
   1a141eb26d11fbd59c108d3fa968cacc95bf443dac00e44dc20bbb6a888a9831,93c7589dbf65e8651f0875be1551d288df1051e0a7a2bc65058d39c7b056fce7
   5c50e0cf26fde11cf21a4789ea92012542f965856c6f63dc34fbb7d2a2916a0d,e6ca3205e17ab2c85d41b2d8ca6d02df0dd6441f603fbdc963839196b83bd0ff

While repeatability is often a desirable behavior in programs, it is
less so when you're trying to generate a secret key.

Fortunately you can reseed the JUCE RNG, so as a stopgap for JUCE
applications, they can gather a random seed themselves and reset the
internal state. The JUCE documentation for Random recommends using the
time in milliseconds, which, while somewhat better than a constant, is
not exactly secure. This is something we've known for well over a
decade, at least since 1995 when Ian Goldberg and David Wagner
broke `Netscape's SSL implementation <http://prng.net/about/netscapessl>`_,
when it tried the exact same thing. Instead let's use /dev/random,
which is usually secure enough, though later analysis has found some
weaknesses in the

`Linux <http://www.pinkas.net/PAPERS/gpr06.pdf>`_ and
`FreeBSD <http://security.freebsd.org/advisories/FreeBSD-SA-08:11.arc4random.asc>`_
implementations, and it is quite likely that other flaws still remain
undiscovered. Still, for most applications and most developers, it is
much better to trust /dev/random (and then keep up to date with
patches) than it is to roll ones own RNG::

   void seed_juce_rng()
      {
      int dev_random = open("/dev/random", O_RDONLY);
      if(dev_random == -1)
         {
         fprintf(stderr, "Could not open /dev/random, die!\n");
         exit(1);
         }

      int64 seed = 0;
      if(read(dev_random, &seed, sizeof(seed)) != sizeof(seed))
         {
         close(dev_random);
         fprintf(stderr, "Read of /dev/random failed, die!\n");
         exit(1);
         }

      close(dev_random);

      Random::getSystemRandom() = Random(seed);
      }

So, with 64 bits of fresh randomness from the system RNG, we're all
set, right? Well, not really. This does at least cause JUCE to
generate different keys between runs of the programs, and among
different machines. But an attacker can still simply search the 64-bit
seed space. Performing a full search of a 64-bit keyspace is still
outside the range of everyone but major corporations and national
governments, but the barrier to entry for performing such a search
will only grow smaller with time. And it means that even if you
generate a 256 bit Blowfish key, or a 2048 bit RSA key, all an
attacker needs to do is guess the original 64-bit starting seed that
was chosen and work forward from there.

In fact you don't even get 64 bits of security out of juce::Random,
even when providing a 64-bit random seed, because the algorithm
truncates intermediate values to 48 bits (juce::Random seems to be
using the lrand48 LCRNG parameters)::

   seed = (seed * literal64bit (0x5deece66d) + 11) & literal64bit (0xffffffffffff);
   return (int) (seed >> 16);

which moves the keysearch from being feasible by the NSA to be
feasible by anyone with a few hundred dollars worth of general purpose
CPUs to spare. Outstanding.

Another problem with only being able to use a 64-bit seed becomes
obvious when we remember the `birthday paradox <http://www.efgh.com/math/birthday.htm>`_.
Statistically speaking, even if /dev/random is perfect in every way,
then if you take 2\ :sup:`32` 64-bit samples, you will have about a
50% chance of getting a repeated seed (which, due to the previously
described issues, means you will get repeated key values). And since
internally this value is truncated to 48 bits, the birthday paradox
should imply an internal seed collision after only about
2\ :sup:`24` samples. Not good.

One could always assume that it is unlikely that JUCE (and,
indirectly, all applications using JUCE) will ever generate more than
2\ :sup:`24` keys. But it seems a bit foolish to base the security
of a system on the grounds that only a few people will ever use
it.

JUCE may well be a fine library for general application
programming. Clearly the author has put a lot of work into it. But
that said, given the above, I don't think it would be a good idea to
use JUCE for any sort of cryptographic operations, even with an
explicit reseeding step, at least until the flaws can be resolved
in a future release.

Update: I contacted the author of JUCE, Julian Storer, with my
findings. He pointed out a fact that I had missed, that the JUCE
initialization function will reset the PRNG with the time in
milliseconds (great...), and asserted this document is "heavy on the
FUD". Feel free to draw your own conclusions on that one. Recall that
there are less than 2\ :sup:`35` milliseconds in a year. So, assuming
an attacker can guess what *year* a particular key was generated, it
is quite simple for her to generate all possible keys and test them,
probably with less than a day of CPU time on a modern processor.

Additionally, because the LCRNG will leak large amounts of the state
with each output, if any of the RNG output becomes visible to an
attacker, it immediately becomes much easier for her to guess the
entire state. This is relevant to applications which need to generate
both random values which are made public (such as nonces,
initialization vectors, or session identifiers) and others which are
secret (such as keys).

