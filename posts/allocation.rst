.. title: Algorithmic Complexity Attacks on Allocators
.. slug: allocation
.. date: 2006-11-01
.. tags: security, algorithms

A few years back some researchers presented the concept of performing
denial of service through `algorithmic complexity attacks
<http://www.cs.rice.edu/~scrosby/hash/>`_, which essentially cause
pathological behavior in data structures like hash tables through
carefully chosen inputs.

.. TEASER_END

Of course the general concept was well known; *Introduction to
Algorithms*, more or less the standard algorithms textbook, begins the
section on universal hashing with *"If a malicious adversary chooses
the keys to be hashed, then he can choose n keys that all hash to the
same slot, yielding an average retrieval time of O(n)"*. In the case
of data structures, the typical response is randomization, which is
simple enough in the case of hash tables. Universal hashing is the
theoretically clean way, but even something very crude, like
initializing a CRC feedback register with a randomly chosen value,
will often be more than sufficient.

There have been a small number of papers over the years which present
memory allocation in game-theoretic terms - one side being an
application, the other being the allocator. Each "turn" of the game
involves the application making an allocation or deallocation request,
and the allocator must respond in an online fashion (that is, it can't
batch together requests and reply all at once - it's only context for
requests are those which have already completed, and has no knowledge
of future requests). This form of analysis doesn't seem particularly
useful in the common case; applications tend to have very regular
patterns of dynamic memory use, and an allocator which had no
pathological cases might well perform much worse on average, compared
to a general purpose allocator with some obscure pathological case
that never came up in common workloads. However, it does seem very
valuable from the perspective of analyzing complexity attacks.

Can these attacks be carried out against memory allocators in
practice? How strongly can an attacker affect the memory allocation
patterns of an application (especially fat targets like servers and OS
kernels?). What pathological cases exist within common memory
allocator implementations, and how serious are they?

Are there any known designs for randomized memory allocators? I
have done a literature search and haven't been able to find anything
along these lines.
