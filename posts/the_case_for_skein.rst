.. title: The Case For Skein
.. slug: the_case_for_skein
.. date: 2009-10-09
.. tags: crypto

After the initial set of attacks on MD5 and SHA-1, NIST organized a
series of conferences on hash function design. I was lucky enough to
be able to attend the first one, and had a great time. This was the
place where the suggestion of a competition in the style of the AES
process to replace SHA-1 and SHA-2 was first proposed (to wide
approval). This has resulted in over 60 submissions to the `SHA-3 <http://ehash.iaik.tugraz.at/wiki/The_SHA-3_Zoo>`_ contest, of
which 14 have been brought into the second round.

Of the second round contenders, I think Skein is the best choice
for becoming SHA-3, and want to explain why I think so.

.. TEASER_END

First, some backstory which explains a bit about my philosophy of
security, which will help explain my reasoning behind supporting Skein
versus the other candidates.

In the AES contest, there were 15 submissions with the
second round candidates being Rijndael, Twofish, Serpent MARS, and
RC6. Of these, I was strongly rooting for Serpent and against
Twofish. MARS and RC6 both seemed unlikely to win due to the use of
multiplications, which greatly complicate hardware implementations,
and in the case of RC6, data-dependent rotations, which caused
horrible performance on non-x86 processors, so it seemed clear to me
at the time the winner would be one of Rijndael, Serpent, or Twofish -
and in fact, RC6 and MARS did come in the bottom of the poll held at
the second AES conference.

My concern with Twofish was that the design, which incorporates a
couple of kitchen sinks worth of design ideas including PHTs, MDS
codes, and key-generated sboxes made it too difficult to analyze
properly. This is not to say that Twofish is insecure; to my knowledge
no serious attacks on it has been found, and I certainly do not claim
to have one. My concern (then and now) is that Twofish is too
complicated for me to feel it is reasonable to have any confidence
that the lack of attacks is due to the strength of the algorithm,
rather than simply there are too many interacting pieces for anyone to
wrap their head around it sufficiently to find the attacks that are
possible.

In contrast, Serpent has a SP-network structure that iterates a
simple round function 32 times. This is both very conservative (32
rounds is twice the number needed to prevent the best known attacks)
and very simple (thus making it easy to analyze and
implement). Serpent's key schedule is also the simplest of all the AES
candidates, except for perhaps RC6's, and largely reuses components of
the cipher. Its treatment of keys of different length is uniform,
unlike Rijndael or Twofish - and in fact, it turns out that Rijndael's
different key schedules have
`completely different security properties <http://eprint.iacr.org/2009/374>`_,
so that AES with a 256 bit key is actually *weaker* than AES with a
128 bit key against certain attacks, even though AES-256 actually uses
4 more rounds than AES-128.

And with DJB's finding that table lookups with key or data
dependent values are vulnerable to
`timing attacks <http://cr.yp.to/antiforgery/cachetiming-20050414.pdf>`_,
it seems that of the finalists, Serpent is the only round-2 AES
candidate that is actually safe to use in many realistic threat
environments.

So what does any of this have to do with Skein?

There are a number of ways of turning a block cipher into a
cryptographic hash function. The most widely used is probably
Davies-Meyer. Another is Matyas-Meyer-Oseas. The key difference
between the two is that in Davies-Meyer, the input (the data being
hashed) is used as the block cipher key, whereas in MMO mode, the
input is used as the plaintext to the block cipher, with the previous
hash value being used as the key. Block ciphers are mostly designed to
encrypt and decrypt text (even text that can be chosen or otherwise
influenced by an attacker) under the control of random keys, rather
than keys controlled by the attacker, so MMO mode places less 'strain'
on the cipher design.

Skein in fact uses MMO mode, with a new block cipher named
Threefish. Threefish has an incredibly simple round function, called
MIX::

   def mix(a, b, r):
     a = a + b
     b = rotate_left<r>(b ^ a)

which is iterated 72 times along with a simple word permutation; the
permutation repeats every 4 rounds, and the rotation constants repeat
after 8 rounds.

Using only add, XOR and fixed rotations for operations means timing
attacks, as possible against AES, cannot be conducted against
Threefish, because all of these operations take constant time on all
known processors. And the simplicity of the round function makes it
very easy to understand; so far the best known attack against
Threefish can distinguish it from a random permutation after 35 rounds
using 2\ :sup:`478` operations, which puts 72 rounds at just about a
safety factor of 2. As the Skein paper points out

   For comparison, at a similar stage in the standardization process,
   the AES encryption algorithm had an attack on 6 of 10 rounds, for a
   safety factor of only 1.7.

Skein is built on top of MMO mode and Threefish using provable
reductions - basically, if one assumes the existence of an attack on
Skein, such as being able to find a collision in the hash, then this
can be used to create an attack on Threefish and/or MMO mode
themselves.

Skein is also fast - as fast or faster than MD5 and SHA-1 on many
common 64 bit processors like the Core2 or PPC970. It is not
*the* fastest of the second round contestants; that title seems
to go to either Blue Midnight Wish or CubeHash, depending on
parameters, but it certainly falls into 'fast enough', and
specifically is much faster than SHA-2.

Another major reason to like Skein compared to most of the other
submissions is Skein's support for personalization and keying.
Personalization is the concept of producing many distinct hash
functions from a single design. This is important, because some
systems are vulnerable to having a hash generated in one context being
replaced with a hash generated and intended for a different
context. Of course not all system designs using a hash function are
vulnerable to this, but that is the rub - if you use the same hash
function everywhere, then one must be very careful when designing or
changing the system that a vulnerability is not introduced. In
contrast, by pervasively tagging hash functions with the intended
context, one can be assured that such attack can never be
possible. One system that does this is
`Tahoe-LAFS <http://allmydata.org/trac/tahoe/wiki>`_; quoting from the
Tahoe paper presented at ACM Storage Security and Survivability '08
Workshop:

   In addition, each time we use a secure hash function for a particular
   purpose (for example hashing a block of data to form a small identifier
   for that block, or hashing a master key to form a sub-key), we prepend
   to the input a tag specific to that purpose. This ensures that two
   uses of a secure hash function for different purposes cannot result in
   the same value.

It would be nice to have a SHA-3 that made this easy for developers to
do; as far as I know Skein is the only contestant which supports
it. It also supports other contextual inputs, like including the
associated public key when generating input for a signing algorithm,
extensions which obviously reflect the Skein authors' experience in
designing and breaking protocols.

My particular concerns with the other finalists include: I feel
designs that use AES components, like SHAvite, Groestl, and ECHO, are
non-starters. They will be fast on processors, like the forthcoming
Sandy Bridge that include AES instructions, but will remain slow and
vulnerable to timing attacks everywhere else. This does not seem an
acceptable trade off to me for an algorithm which is going to be used
everywhere.

CubeHash, Luffa, and Keccak all seem promising, but I don't believe
there is sufficient time in the next year or so for sufficient
confidence to be developed in their overall styles; CubeHash being a
somewhat custom, Salsa20-like function, and Luffa and Keccak using the
sponge construction first used, I believe, in PANAMA, and which has
seen a number of designs since, but nothing that has been widely
adopted; and PANAMA itself turned out to be trivially breakable. This
is not to suggest that either Luffa or Keccak has any weakness - it
just means that I don't believe the cryptographic community has
developed the necessary tools to be able to confidently state whether
they do or not - maybe they are strong, or maybe they are trivially
breakable but in a way that we do not currently know because sponge
functions have not been a very major topic of research. In contrast,
hash functions based on iterative modes of block ciphers have been how
hash functions have been built in the open community going back to MD4
and MDC-2, which means we at least have a chance of understanding how
to build and analyze one.
