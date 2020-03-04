.. title: Const-time Modular Inversion Using CRT
.. slug: modular_inversion_using_crt
.. date: 2020-03-04
.. tags: crypto, math
.. has_math: True

Modular inversion is an important component in many cryptographic computations,
notably in number-theoretic public key cryptosystems like RSA and ECDSA.  In
such uses, we must both perform the computation as quickly as possible and also
in const-time, that is without any software-observable side channels which leak
information about the inputs or output. Otherwise it is possible to attack
computations such as RSA key generation or ECDSA signature generation, and
recover the secret key.

This is a bad thing.

.. TEASER_END

There are a few good "general purpose" modular inversion algorithms which work
for any modulus, such as the extended Euclidean algorithm, the binary extended
gcd algorithm, and Montgomery inversion. However these algorithms are relatively
difficult to implement in constant time, and even with only incomplete side
channel countermeasures in place commonly run 2-10 times slower than a naive
implementation. For example Bos reports
(http://www.joppebos.com/files/CTInversion.pdf) a const-time Montgomery
inversion that is about 8 times slower than an unprotected implementation.

There are also inversion algorithms which only work for moduli of a certain
form. The most famous and widely used is to rely on Fermat's little theorem,
which tells us for any prime :math:`p` and any integer :math:`0 < a < p` that
:math:`a^{p-1} \equiv 1 \bmod p`. From this we can easily see that
:math:`a^{p-2} \equiv a^{-1} \bmod p`, so given a (side channel silent) modular
exponentiation algorithm - which we need anyway for a variety of other reasons -
it is possible to compute inversions modulo a prime. This covers almost all
practical cryptographic modular inversions, including computing :math:`k^{-1}
\bmod n` during ECDSA signatures and :math:`q^{-1} \bmod p` during RSA key
generation.

Another series of algorithms works for inversion modulo :math:`p^k` for prime
:math:`p` and any positive integer :math:`k`. A paper by Çetin Koç
(https://eprint.iacr.org/2017/411.pdf) gives an overview of several previously
published algorithms for inversion modulo :math:`2^k` along with a general
algorithm for inversion modulo :math:`p^k`. The special case of Koç's algorithm
for :math:`p = 2` is exceptionally simple, producing one bit of the output with
every loop iteration::

  b = 1
  for i in 0..k
    Xi = b % 2
    b = (b - a*Xi) / 2
  return (Xk,...,X1,X0)

This algorithm is easily implemented in constant-time code.

Finally there are algorithms which compute inversions modulo any *odd*
integer. The two I am aware of are by Bernstein and Yang
(https://gcd.cr.yp.to/safegcd-20190413.pdf) and an algorithm by Möller (Appendix
5 of https://hal.inria.fr/hal-01506572). Both are again quite straightforward
to implement in constant time.

But none of these moduli-specific algorithms can protect a critical inversion
which occurs during RSA key generation: computing :math:`d = e^{-1} \bmod
\phi(n)`, because :math:`\phi(n)` is not only not prime, it is not even odd.
How to fully protect this computation against side channels had bugged me for
some time, but then I hit upon a simple and very useful approach - combine two
of the algorithms!

The trick is to factor :math:`\phi(n)` into :math:`2^{k} \cdot o` for some odd
:math:`o`. This is easily done by counting the low zero bits. Then compute
:math:`e^{-1} \bmod 2^{k}` and :math:`e^{-1} \bmod o` using the two special case
algorithms. Because :math:`2^k` and :math:`o` are relatively prime, the two
results can be combined to compute the inverse modulo :math:`2^k \cdot o =
\phi(n)`.

This does require computing :math:`o^{-1} \bmod 2^{k}`, meaning computing a
single modular inversion requires 3 sub-inversions. However for RSA key
generation, :math:`k` will tend to be small - typically under 8 - and so the two
inversions modulo :math:`2^k` are very fast, since you only ever have to look at
the bottom :math:`k` bits.

Overall the performance is excellent. In fact compared to an *unprotected*
implementation of the binary extended algorithm, the CRT-based algorithm,
using const-time implementations of the modulo-odd and modulo-:math:`2^k`
inversions, was between 1.3 and 2 times faster, depending on operand size.
For moduli where :math:`k` is large and :math:`o` is small, the performance is
less stellar, but such numbers are not common in cryptography, and even then the
performance is at worst half of the (again, completely unprotected against side
channels) binary algorithm.

This approach to modular inversions has been implemented in Botan starting in
version 2.14.0, removing use of a (incompletely protected, yet much slower)
binary extended gcd during RSA key generation.

This CRT based approach seems obvious, but I have not been able to find it
described in any book or journal paper, nor have I seen it used in any other
implementation. If you are aware of a reference, drop me a line.
