.. title: On Syllable's /dev/random
.. slug: syllable_dev_random
.. date: 2008-12-09
.. tags: crypto

Inspired by the recent `FreeBSDarc4random <http://security.freebsd.org/advisories/FreeBSD-SA-08:11.arc4random.asc>`_
vulnerability, I've been taking a look at the random number generators
used by various libraries and operating systems.

.. TEASER_END

`Syllable <http://web.syllable.org/pages/index.html>`_ is a desktop OS
based on AtheOS that provides what seems like a pretty decent desktop
experience along with POSIX APIs and the GNU toolchain.

Crypto is pretty much entirely a userspace operation - but one area
where system interaction is vital is in the gathering of hard to guess
data used to seed a cryptographically secure PRNG. This is,
unfortunately, difficult to do well in most environments, because of
course direct hardware access is restricted in any modern operating
system, and above the hardware level a computer system is quite
deterministic. On many older systems, the only recourse is to collect
system statistics (for example using Win32's Tooltip API to grab heap
statistics, or running programs like 'netstat' or 'who' on Unix and
capturing the output), and hope there is not a local attacker who is
capturing the same set of statistics and using it to guess the seed
information that was collected.

To help make this process easier and safer for applications, the Linux
kernel introduced ``/dev/random``, which is a PRNG seeded with data
like interrupt timings - data which is accessible to the kernel but
not userspace. This concept of an OS provided RNG was quickly adopted
by most other Unix systems like the BSDs and Solaris.

Botan uses ``/dev/random``, among other sources, to provide seed
information for a PRNG based on the `HMAC-KDF
<http://www.ee.technion.ac.il/~hugo/kdf/>`_ design of Hugo
Krawczyk. Before relying on Syllable's implemementation, I wanted to
check out the code to be sure additional sources were not required
(which, when porting to a completely new OS, typically means writing
new code to access whatever system statistics information the OS might
provide).

I am glad I did so, since it turns out that Syllable's `kernel RNG
<http://syllable.cvs.sourceforge.net/viewvc/syllable/syllable/system/sys/kernel/kernel/random.c>`_
is a MT13397 Mersenne twister.

A Mersenne twister *is* a fine random number generator for general
use, with good statistical properties, but it is not a particularly
good choice for cryptographic applications.

Most troubling is the implementation of ``seed()``, which I have
reproduced here::

   96 /* initializes state[N] with a seed */
   97 void seed(int32 s)
   98 {
   99     int j;
  100     state[0]= s & 0xffffffffUL;
  101     for (j=1; j<N; j++) {
  102         state[j] = (1812433253UL * (state[j-1] ^ (state[j-1] >> 30)) + j);
  103         /* See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier. */
  104         /* In the previous versions, MSBs of the seed affect   */
  105         /* only MSBs of the array state[].                        */
  106         /* 2002/01/09 modified by Makoto Matsumoto             */
  107         state[j] &= 0xffffffffUL;  /* for >32 bit machines */
  108     }
  109     left = 1; initf = 1;
  110 }

The array ``state`` is a 624 word array that contains the internal
state of the twister. However, all of these words are overwritten on
each call to ``seed``, and thus only depends on the single 32-bit word
which was last given as a seed value, plus the number of times the
PRNG has been stepped since it was last seeded.

The `device code
<http://syllable.cvs.sourceforge.net/viewvc/syllable/syllable/system/sys/kernel/drivers/misc/random/random.c>`_
that provides userspace access to the PRNG also does some pretty funky stuff::

   26 static int random_read(void* node, void* cookie, \
                             off_t pos, void* buf, size_t length)
   27 {
   28 	char* buffer = (char*)buf;
   29 	int i, j, k;
   30
   31 	j = k = 0;
   32
   33 	for( i = 0;  i < length;  i++ )
   34 	{
   35 		j = rand();
   36
   37 		if( j != k )
   38 			buffer[i] = j % 256;
   39
   40 		k = j;
   41 	}
   42
   43 	return( length );
   44 }

Here ``rand()`` is a call that produces the next 32 bits of output
from the twister. I'm not sure exactly about the logic on lines 37 and
38, but it appears the idea was to ensure that no two consecutive
bytes have the same value. However this occurring is actually fine,
and in a uniform random distribution of bytes one would expect to see
it about .4% of the time. Instead, when this occurs, no value at all
is written to that index in the output array, leaving it unaltered.

A (citation-less) sentence in the current version of the Wikipedia
article on the Mersenne twister states that "Observing a sufficient
number of iterates (624 in the case of MT19937) allows one to predict
all future iterates". Since only the low 8 bits of each output are
visible outside the kernel, it is not clear to me if this would allow
a practical attack against Syllable's ``/dev/random`` or not.

There seem to be several ways this could be easily improved without
an excessive amount of effort. Instead of wiping out the previous seed
information, new calls to ``seed()`` should supplement the
previously set seeds. Exchanging the twister for a cryptographically
secure PRNG, even a relatively weak one like RC4 (discarding the first
few thousand bytes of output to avoid the known statistical biases),
would also seem to be a compelling win here.
