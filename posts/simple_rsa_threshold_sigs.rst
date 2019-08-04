.. title: Simple and hardware friendly RSA threshold signatures
.. slug: simple_rsa_threshold_sigs
.. date: 2019-08-04
.. tags: crypto
.. has_math: True

A :math:`(n,t)` threshold signature schemes allow splitting a key into
:math:`n` pieces, in such a way that at least :math:`t < n`
participants must jointly use their key shards in order to generate a
valid signature.

Many techniques for RSA threshold signatures have been developed. Currently
published techniques require either a trusted dealer, or use of a distributed
key generation algorithm. In addition, the signers must perform a non-standard
RSA signature; that is, signing a message with a private exponent which is not
equal to :math:`e^{-1} \bmod n`. Both requirements prevent using standard hardware
such as HSMs or smartcards to protect the key shards.

I discovered a technique for :math:`n`-of-:math:`n` RSA signatures where both
keys and signatures can be computed using standard cryptographic hardware.

.. TEASER_END

A normal instance of the RSA signature system is created by first fixing a
public exponent :math:`e` then choosing two random primes :math:`p` and
:math:`q` of suitable size such that :math:`p-1` and :math:`q-1` are relatively
prime to :math:`e`. Multiplying :math:`p` and :math:`q` produces the public
modulus :math:`n`, and the private exponent :math:`d` is computed as
:math:`e^{-1} \bmod \phi(n)`. Having established a key, a signature can be
formed by first choosing a suitable hash function :math:`H : \{0,1\}^\star
\rightarrow Z_n` and computing :math:`s` = :math:`H(m)^d \bmod n`. Common
choices for :math:`H` are the PSS and PKCS #1 v1.5 schemes, in combination with
some secure hash function such as SHA-512. The signature can be verified by
computing :math:`H(m)' = s^e \bmod n` and checking that :math:`H(m)'` is a valid
representative for the purported message :math:`m`. Commonly, the Chinese
Remainder Theorem (CRT) is used to compute :math:`s` using two modular
exponentiations, one modulo :math:`q` and another modulo :math:`p`. Since
modular exponentiation algorithms have a runtime that is quadratic based on the
size of the modulus, CRT can offer substantial speedups.

Many threshold signature schemes based on RSA have been proposed, but all rely
on either a trusted dealer or else the use of a distributed key generation
algorithm. A trusted dealer implies a trusted party whose deviation from the
protocol will compromise the security of the system. Distributed key generation
does away with the dealer, but at the cost of complicating key generation, and,
worse, requiring a non-standard key generation mechanism. Thus, it is not
possible to create a threshold RSA key in such a way that the resulting key
shards are stored within a standard PKCS \#11 hardware security module.

But there is a simple approach based on multiprime RSA which neatly avoids these
problems, at the cost of larger public keys, and with the limitation of only
working for :math:`n`-of-:math:`n`. It is probably most suitable for
:math:`2`-of-:math:`2`.

Each of the :math:`n` parties involved in the threshold scheme generate a
public/private RSA keypair. This can be done using standard hardware, and no
interaction between the parties is required during the key generation step. The
only restriction is all keypairs must be generated with the same public exponent
:math:`e`. All parties publish their public key. The combined public key is simply the
common :math:`e` and the product of the public moduli: :math:`(e, n_1 \cdot n_2 \cdot
... \cdot n_n)`

To perform a distributed signature, all parties are given the input message :math:`m`.
They must first jointly agree on the exact value of :math:`H(m)`. For PKCS #1 v1.5
signatures, the padding is deterministic. For randomized schemes such as PSS,
the salt could for instance be chosen by hashing the input message with a shared
secret known to all signers. The encoding of :math:`H(m)` should be sized according
the public modulus rather than that of the individual keys, since verifiers will
judge the correctness of :math:`H(m)` as an encoding for :math:`m` relative to the size of
the public key. This restriction unfortunately inhibits use of hardware which
provides padding as part of the signature operation.  Instead mechanisms for
"raw" RSA such as PKCS #11's ``CKM_RSA_X_509``  must be used.

Each key holder signs :math:`H(m) \bmod n_i` using their private key, and
publishes their signature share :math:`s_i = H(m)^{d_i} \bmod n_i`. All
signature operations can be done in parallel. Given the signature shares
:math:`s_1`, :math:`s_2`, ... :math:`s_n`, the CRT can be used to create a joint
signature :math:`s`. This final recombination step can be done by an untrusted
third party. Deviations from the protocol can be easily detected by verifying
each signature share against the signer's respective public key.

Extending this scheme to :math:`t`-of-:math:`n` can be done by generating :math:`{n \choose t}`
different public keys, and allowing authentication using any of them.

This scheme is at least as secure as breaking the strongest of the :math:`n` sub-keys,
which can easily be seen by observing that any valid signature generated without
the cooperation of one of the key holders, implies either the existence of some
pair :math:`y, s_y` where :math:`s_y = y^{d} \bmod n` which the signer has not issued (and
thus a direct forgery of RSA) or otherwise a signature where some previously
issued (valid) :math:`y, s_y` pair was reused to forge a signature on some other
message. This implies the existence of distinct :math:`m_1, m_2` where :math:`H(m_1) \equiv
H(m_2) \bmod n` where :math:`n` is the signer's public modulus. For PKCS #1 v1.5,
producing such messages requires a collision attack on the hash function,
because the hash of the message is placed into the low bits of :math:`H(m)`. The
situation for PSS here is less clear, and needs further analysis.

Downsides of this scheme are that the resulting (threshold) key is :math:`n` times
larger than the key length of the individual users, increasing both transmission
costs and verification time. While RSA verification is quite fast, likely this
approach is only practical for :math:`n \leq 4`. In addition the larger public key
gives a somewhat false sense of security in terms of safety against NFS attacks;
factoring a 4096 bit RSA key requires :math:`\approx 2^{150}` effort but a pair of
2048 bit keys can be broken with just :math:`\approx 2^{112}` operations.
