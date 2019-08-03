.. title: How Not To Do BLS Signatures
.. slug: bls_hashing_fail
.. date: 2019-07-24
.. tags: crypto
.. has_math: True

The BLS signature scheme has several interesting properties, namely
that the signatures are very short compared to any other known scheme,
and it affords a simple implementation of threshold signatures and
signature aggregation. For these reasons it has been of some interest
especially in cryptocurrencies which can make good use of these properties.

.. TEASER_END

The BLS scheme relies on an elliptic curve pairing :math:`e`, which is
without getting into implementation details is an operation that works
on three groups conventionally termed :math:`G_1`, :math:`G_2`, and
:math:`G_t`, each of which have some (common) prime order :math:`p`
and generators :math:`g_1, g_2, g_t` (resp). The pairing is a mapping
:math:`e(G_1,G_2) \rightarrow G_t` which has the very useful property
that :math:`\forall x,y \in Z_p : e(x \cdot g_1,y \cdot g_2) =
e(g_1,g_2)^{x \cdot y}`. In all known pairings, :math:`G_1` and
:math:`G_2` are elliptic curve groups (so use multiplicative notation)
and :math:`G_t` is your typical discrete logarithm group modulo a
large prime, and uses exponential notation.

Given a pairing, the BLS signature scheme is very simple. Key
generation consists of just choosing a random element :math:`k \in
Z_p`, and the public key is :math:`g_2^k`. A message is signed by
hashing the message using some function :math:`H(\{0,1\}^\star)
\rightarrow G_1` and then outputting the signature :math:`H(m) \cdot
k`. Given a signature :math:`s` and a public key :math:`g_2^k`, the
verifier checks that :math:`e(s,g_2) = e(H(m),g_2^k)`. [It is possible
to switch the use of :math:`G_1` and :math:`G_2` here, but in practice
one group has smaller elements than the other (conventionally, this is
:math:`G_1`) so it is better to have the public key be an element of
:math:`G_2` to reduce the signature size to the minimum possible
value.]

So, what can go wrong? In fact in contrast to most signature schemes,
BLS is remarkably robust by design. Due to the lack of nonces, there
is no possible issue of nonce bias or reuse, and signature
malleability is not an issue. But there is a subtle flaw, namely in
the definition of :math:`H`. A naive definition of this function would
be to choose some cryptographic hash function :math:`C` (say SHA-512),
then define :math:`H(m) = C(m) \cdot g_1`.

But this :math:`H` causes the scheme to fall to a very simple attack!
Namely, given some public key and a valid message/signature pair, you
can easily compute the valid signature for *any other message*.  We
know that :math:`s = k*C(m)*g_1`, and we additionally know
:math:`C(m)`. So we compute :math:`z = C(m)^{-1} \mod p` and then
:math:`(z \cdot s) \mod p = k \cdot g_1`. Since we can't solve the
discrete logarithm problem in any of the groups, this doesn't allow us
to recover :math:`k`, but it doesn't matter because for any other message
we can compute a valid signature using :math:`k \cdot g_1 \cdot C(m_2)`.
This attack and several variations are described in a nice
`paper by Tibouchi <https://www.normalesup.org/~tibouchi/papers/bnhash-scis.pdf>`_.

Now, who would do such a thing? It turned out that ETH Zurich's "DEDIS Advanced
Crypto Library for Go" implemented BLS signatures in exactly this way!  I
reported this issue to them on Feb 20 and a `fix was proposed a week later
<https://github.com/dedis/kyber/pull/365>`_.

Fixing this implies defining a new :math:`H` which does not lead to trivially
computable relationships between outputs. The simplest and most general method
is to to take advantage of the fact that it is possible to compute the square
root modulo a prime. First hash the message onto :math:`Z_p` to find the
:math:`x` coordinate of the elliptic curve point: :math:`x = C(m) \mod p`. Then
solve for :math:`y` using the Shanks-Tonelli algorithm to compute the square
root modulo :math:`p`: :math:`y = (x^3 + ax + b)^{-2} \mod p`. But this doesn't
always work, because not all values will have a square root. This necessitates a
retry loop, for example by computing :math:`x = C(m \| i) \mod p` and
incrementing :math:`i` until a valid :math:`x`, :math:`y` pair is generated.
Sadly this method introduces a timing channel, since the number of operations depends
on the input: some inputs will find a valid pair after one iteration, some after
two, some after 30 ... For some protocols, like BLS, the message can probably be
safely presumed public, and this doesn't matter. But in other protocols such as
password authentication key exchange, this input dependence can introduce a side
channel and in fact was used to `break WPA3 <https://eprint.iacr.org/2019/383>`_.

Unfortunately there is not (to my knowledge) a known way of hashing to curve
which is both secure against side channels and general, in the sense of being
easily adapted to all commonly used elliptic curves. If you want to hash onto a
BN curve you must use the techniques from `this paper
<https://www.di.ens.fr/~fouque/pub/latincrypt12.pdf>`_, for P-256 you use `SWU
technique <https://datatracker.ietf.org/doc/draft-irtf-cfrg-hash-to-curve/>`_,
for P-384 you use Icart's technique, for x25519 you need `Elligator
<https://elligator.cr.yp.to/>`_ and in general it's kind of a mess. The best
solution in practice is probably to pick a single curve system wide and hope
you never have to change it.
