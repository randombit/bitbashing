.. title: Observation on the SSLv3 MAC function
.. slug: ssl3mac
.. date: 2003-01-11
.. tags: crypto

SSLv3 uses an early form of HMAC for message authentication
functions (we will denote this MAC as SSL3-MAC for brevity). A
critical point of the security of HMAC (and SSL3-MAC) is that the each
of the transformed keys (termed *ikey* and *okey*) is
exactly *B* bytes long, where *B* is the input size of
the hash function (for the MD5 and SHA-1 hash functions, *B* =
64).

.. TEASER_END

SSL3-MAC is different from standard HMAC as follows: instead of
XOR'ing two fixed *B*-byte long strings against the input key
to form *ikey* and *okey*, it appends two different byte
strings, whose length depends on the block size of the hash function,
and the size of the key. In SSLv3, the size of the key is fixed to be
the same as the output size of the hash function.

For MD5, the key is 16 bytes long and the padding strings are 48
bytes long, leading to a total size of *ikey* and *okey*
of 64 bytes (which is equal to *B*). However, for SHA-1, the
padding strings are specified to be only 40 bytes long, meaning the
length of *ikey* and *okey* are both just 60 bytes (with
the 20 byte key), 4 bytes short of *B*.  This is not merely an
error in the specification, since at least one well known and very
widely used implementation of SSLv3 uses exactly this definition for
the authentication code.

It would seem this would, at least potentially, mean that SSL3-MAC
with SHA-1 can be attacked faster than would be expected; in
particular, it may be faster to attack than HMAC with SHA-1, and could
possibly be faster to attack than SSL3-MAC with MD5 as well.

However, there are some factors which mean that an attack is, if
not impossible, at least hard to find. In particular, SHA-1 is a quite
good hash function, and its method of expanding its input words would
make an attack of this sort, based on only the last 4 bytes of the
input block, quite hard to exploit. Also, the HMAC construction, which
SSL3-MAC shares, seems to be able to tolerate this error to at least
some degree. The original HMAC papers claimed that there were
significant security reductions if the padding did not pad to a full
blocksize, but there was relatively little explanation of why.

Lastly, the ascendance of TLS (which uses HMAC, and thus is not
affected by the problem) over SSLv3 means that the issue is rapidly
disappearing in any case.
