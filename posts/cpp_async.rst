.. title: Using std::async for easy parallel computations
.. slug: cpp_async
.. date: 2009-11-24
.. tags: programming

C++0x, the next major revision of C++, includes a number of new
language and library facilities that I am greatly looking forward to,
including a standard thread interface. Initially the agenda for C++0x
had included facilities built on threads, such as a thread pool, but as
part of the so-called 'Kona compromise' (named after the location of
the committee meeting where the compromise was made) all but the most
basic facilities were deferred for a later revision.

.. TEASER_END

However there were many requests for a simple facility for creating
an asynchronous function call, and a function for this, named
``std::async``, was voted in at the last meeting.
``std::async`` is a rather blunt tool; it spawns a new thread
(though wording is included which would allow an implementation to
spawn threads in a fixed-size thread pool to eliminate thread creation
overhead and reduce hardware oversubscription) and returns a "future"
representing the return value of the function. A future is a
placeholder for a value which can be passed around the program, and if
and when the value is actually needed, it can be retrieved from the
future; the ``get`` operation may block if the value has not yet
been computed. In C++0x the future/promise system is primarily
intended for use with threads, but there doesn't seem to be any reason
a system for distributed RPC (ala `E's <http://www.erights.org/elang/>`_ Pluribus protocol) could not
provide an interface using the same classes.

An operation which felt like easy low-hanging fruit for parallel
invocation is RSA's decrypt/sign operation. Mathematically, when one
signs a message using RSA, the message representation (usually a hash
function output plus some specialized padding) is converted to an
integer, and then raised to the power of ``d``, the RSA private
key, modulo another number. Both of these numbers are relatively
large, typically 300 to 600 digits long. A well known trick, which
takes advantage of the underlying structure of the numbers, allows one
to instead compute two modular exponentiations, both using numbers
about half the size of ``d``, and combine them using the Chinese
Remainder Theorem (thus this optimization is often called
RSA-CRT). The two computations are both still quite intensive, and
since they are independent it seemed reasonable to try computing them
in parallel.  Running one of the two exponentiations in a different
thread showed an immediate doubling in speed for RSA signing on a
multicore! Other mathematically intensive algorithms that offer some
amount of parallel computation, including DSA and ElGamal, also showed
nice improvements.

As ``std::async`` is not included in GCC 4.5, I wrote a simple
clone of it. This version does not offer thread pooling or the option
of telling the runtime to run the function on the same thread; it is
mostly a 'proof of concept' version I'm using until GCC includes the
real deal in libstdc++. Here is the code::

   #include <future>
   #include <thread>

   template<typename F>
   auto std_async(F f) -> std::unique_future<decltype(f())>
      {
      typedef decltype(f()) result_type;
      std::packaged_task<result_type ()> task(std::move(f));
      std::unique_future<result_type> future = task.get_future();
      std::thread thread(std::move(task));
      thread.detach();
      return future;
      }

The highly curious ``auto`` return type of ``std_async``
uses C++0x's new function declaration syntax; ordinarily there is
no reason to use it but here we want to specify that the function
returns a ``unique_future`` paramaterized by whatever it is
that ``f`` returns. Since ``f`` can't be referred to until
it has been mentioned as the name of an argument, the return value
has to come after the parameter list.

Unlike the version of ``std::async`` that was finally voted
in, ``std_async`` assumes its argument takes no arguments (one of
the original proposals for ``std::async`` used a similar
interface). This would be highly inconvenient except for the
assistance of C++0x's lambdas, which allow us to pack everything
together. For instance here is the code for RSA signing, which
packages up one half of the computation in a 0-ary lambda
function::

   auto future_j1 = std_async([&]() { return powermod_d1_p(i); });
      BigInt j2 = powermod_d2_q(i);
      BigInt j1 = future_j1.get();
      // Now combine j1 and j2 using CRT

Using C++0x's ``std::bind`` instead of a lambda here should
work as well, but I ran into problem with that in the 4.5 snapshot I'm
using; the current implementation follows the TR1 style of requiring
``result_type`` typedefs which will not be necessary in C++0x
thanks to ``decltype``. Since the actual ``std::async`` can
take an arbitrary number of arguments, the declaration of
``future_j1`` will eventually change to simply::

   auto future_j1 = std::async(powermod_d1_p, i);

The implementation of ``std_async`` may strike you as
excessively C++0x-ish, for instance by using ``decltype`` instead
of TR1's ``result_of`` metaprogramming function. Part of this is
due to current limitations of GCC and/or libstdc++; the version of
``result_of`` in 4.5's libstdc++ does not understand lambda
functions (C++0x's ``result_of`` is guaranteed to get this right,
because it itself uses ``decltype``, but apparently libstdc++
hasn't changed to use this yet).

Overall I'm pretty happy with C++0x as an evolution of C++98 for
systems programming tasks. Though I am certainly interested to see how
Thompson and Pike's `Go <http://golang.org>`_ works out; now that
`BitC <http://bitc-lang.org>`_ is more or less dead after the
departure of its designers to Microsoft, Go seems to be the only game
in town in terms of new systems programming languages that might
provide a compelling alternative to C++.
