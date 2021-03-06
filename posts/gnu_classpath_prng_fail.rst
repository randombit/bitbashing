.. title: Serious Weakness in GNU Classpath/gcj PRNG; DSA keys are compromised
.. slug: gnu_classpath_prng_analysis
.. date: 2008-12-06
.. tags: crypto

`GNU Classpath <http://www.gnu.org/software/classpath/>`_ is an open source implementation of the Java class
libraries used by `gcj <http://gcc.gnu.org/java/>`_, the
GNU Compiler for Java. One component of the Java library is JCE, the
Java Cryptography Extensions (so called because originally it was not
bundled with the JVM due to United States export restrictions), which
provides the basic crypto features one would expect (ciphers, hashing,
signatures) for Java applications. I found a rather interesting bug
that compromised all RSA and DSA keys used with GNU classpath.

.. TEASER_END

For many RNG purposes, including creating private keys, DSA ``k``
values, and SRP session ids, GNU Classpath uses
`gnu.crypto.security.util.PRNG
<http://cvs.savannah.gnu.org/viewvc/classpath/gnu/java/security/util/PRNG.java?revision=1.1.2.2&root=classpath&view=markup>`_. This
PRNG uses a hash function, which by default is SHA-1 though others can
be used instead. It is initialized with a random seed, and then values
are generated by the recurrence::

   V(0) = H(seed)
   V(i) = H(seed || V(i-1))

The PRNG has an interface allowing the addition of new seed
material at a later time, for instance a GUI application might seed it
with mouse click event information.

Unfortunately there are two problems with how this PRNG is used in
Classpath that in combination cause serious problems. One is a
convention where each object, most of the time, gets its own PRNG. It
seems that it is possible in some but not all cases to override the
PRNG to be used, and there seem to be at least three different
conventions for how to do it in Classpath. A representative example,
from the RSA key pair generator code::

   /** The optional {@link SecureRandom} instance to use. */
     private SecureRandom rnd = null;

     /** Our default source of randomness. */
     private PRNG prng = null;

     [...]

     private void nextRandomBytes(byte[] buffer)
     {
       if (rnd != null)
         rnd.nextBytes(buffer);
       else
         getDefaultPRNG().nextBytes(buffer);
     }

     private PRNG getDefaultPRNG()
     {
       if (prng == null)
         prng = PRNG.getInstance();

       return prng;
     }

This class will use ``nextRandomBytes`` to choose starting
points for the RSA ``p`` and ``q`` values. Note that all
access to the prng itself is private, so an application developer
cannot, for instance, add new seed data to the PRNG.

The other problem is that by default the only seed used in
``gnu.crypto.security.util.PRNG`` is the current timestamp in
milliseconds. This *can* be extended by setting a property
named "gnu.crypto.prng.md.seed", but I could not find out much more
about this because it does not seem to be used by any code at all
within Classpath.

Many cryptographic algorithms require a source of cryptographically
secure random numbers. For instance, DSA requires choosing a new random 160-bit
integer ``k`` for each signature that is generated. If this ``k``
value is ever revealed, the private key is immediately compromised,
since it is equal to (((s*k) - H(m)) * r\ :sup:`-1`) mod q (using the
notation from FIPS 186). Since GNU Classpath (in effect) chooses ``k``
values by simply hashing the current timestamp in milliseconds with
SHA-1, it is quite simple to search for and find ``k``.

Experiments confirmed that the output of
``gnu.crypto.security.util.PRNG``, as it is returned by
``PRNG.getInstance()``, is easily guessable using only the local clock
as the starting point for the search. This usage matches exactly how
this class is used throughout the GNU Classpath source.

There are less than 2\ :sup:`35` millisecond values in a year, which
puts an upper bound on the security of any keys generated by this RNG,
assuming an attacker can guess the year, which seems a reasonably safe
bet. Even a decade contains barely 2\ :sup:`38` milliseconds. These
values are far less than even the toughest export restrictions the
United States ever imposed, which were typically 40 to 56 bits of
security.

Classpath contains a number of other RNGs including
``gnu.crypto.security.util.CSPRNG``, which seems (at least at first
glance) to be somewhat safer. I would recommend adding additional seed
material, which would probably be sufficient, except it seems in many
cases that is not even possible. Unfortunately since g.c.s.u.PRNG's
use is hardcoded in nearly everywhere, it may be difficult for
applications to switch.

Update 2008-12-08: I've confirmed that the private half of a DSA
keypair can be derived from the public key and a single
signature/message pair, simply starting with a guess of the time the
signature was generated. This basically means that every DSA key which
has been used in an application compiled with gcj or using GNU
Classpath/GNU crypto is (or at least can easily be, at any time)
compromised. Based on the CVS history, it appears this flaw was
originally introduced in GNU Crypto about 6 years ago, and was then
imported into Classpath without alteration.

I've entered a `bug report <http://gcc.gnu.org/bugzilla/show_bug.cgi?id=38417>`_ for
Classpath describing the problem, but no response yet. After this is
resolved (hopefully soon), I'll post the private key derivation code
for examination.

An example vulnerable application is
`DSASigGen.java <http://files.randombit.net/rng/DSASigGen.java>`_,
which uses only the normal stock Java/JCE API calls to generate a
random DSA key, sign an empty string (the exact value doesn't matter,
as long as the message is known), and prints the public key and
signature (the private key is printed to stderr by the Java code, just
so I could confirm that the search code was in fact finding the
correct key)::

   (motoko)$ gcj --version
   gcj (Gentoo 4.3.2 p1.2) 4.3.2
   Copyright (C) 2008 Free Software Foundation, Inc.
   This is free software; see the source for copying conditions.  There is NO
   warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

   (motoko)$ gcj --main=DSASigGen DSASigGen.java
   (motoko)$ ./a.out > pubkey_and_sig
   Private key is 286340495355822070335047169143648712734886086939
   (motoko)$ cat pubkey_and_sig
   308201b83082012c ... [(DSA public key truncated for readability / not screwing up formatting)]
   302c02140f22be1f12e4c5950e1a4ff4cb7e269f3cd5b6f60214060ae0e5013a05ee2b1f719b49926b394424bde0
   (motoko)$ g++ -O2 find_dsa_key.cpp -lbotan -o find_dsa_key
   (motoko)$ time ./find_dsa_key < pubkey_and_sig
   Found private key 286340495355822070335047169143648712734886086939

   real    0m0.716s
   user    0m0.634s
   sys     0m0.054s

Update #2: According to Wikipedia, other JVMs including Kaffe and
JikesRVM use GNU Classpath. I have not checked if they are vulnerable
(Kaffe is not building on my machine), but the odds are good.  This
may be a bigger issue than I first thought.

Update #3: I should emphasize that while DSA keys are the easiest
target of this flaw, it is quite likely that all private keys (RSA,
DSA, Diffie-Hellman, etc) generated by Classpath can be easily found,
simply by guessing PRNG seeds and running through the key generation
procedure until a private key corresponding to the known public key is
produced.

Update #4: This issue has been assigned
`CVE-2008-5659 <http://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2008-5659>`_.
