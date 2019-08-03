.. title: Inverting Mersenne Twister's final transform
.. slug: inverting_mt19937_tempering
.. date: 2009-07-21
.. tags: programming

The Mersenne twister RNG 'tempers' its output using an invertible
transformation::

   unsigned int temper(unsigned int x)
      {
      x ^= (x >> 11);
      x ^= (x << 7) & 0x9D2C5680;
      x ^= (x << 15) & 0xEFC60000;
      x ^= (x >> 18);
      return x;
      }

The inversion function is::

   unsigned int detemper(unsigned int x)
      {
      x ^= (x >> 18);
      x ^= (x << 15) & 0xEFC60000;
      x ^= (x << 7) & 0x1680;
      x ^= (x << 7) & 0xC4000;
      x ^= (x << 7) & 0xD200000;
      x ^= (x << 7) & 0x90000000;
      x ^= (x >> 11) & 0xFFC00000;
      x ^= (x >> 11) & 0x3FF800;
      x ^= (x >> 11) & 0x7FF;

      return x;
      }

This inversion has been confirmed correct with exhaustive search.
