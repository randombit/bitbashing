.. title: Adventures in Signal Handling
.. slug: f_notify
.. date: 2008-03-02
.. tags: security, programming

I was reading the man page for Linux ``fcntl(2)``, because
I've never used it and was curious what exactly it could do. For
a couple of hours this afternoon, I thought I had perhaps found
a security vulnerability in the design, this post is to trace
my logic and describe what I learned.

.. TEASER_END

I noticed this entry among the list of possible commands::

   F_NOTIFY
     (Linux 2.4 onwards) Provide notification when the directory referred
     to by fd or any of the files that it contains is changed. [...]

     Notification occurs via delivery of a signal. The default signal
     is SIGIO, but this can be changed using the F_SETSIG command to
     fcntl().

So of course the first thing I wonder is if these notifications are
passed along with a file descriptor across a call to exec, and if so,
can a process start up a privileged one and then send it an arbitrary
signal?

So I write a program to set up a notification and then pass the
descriptor to a child process::

   #define _GNU_SOURCE
   #include <unistd.h>
   #include <fcntl.h>
   #include <errno.h>
   #include <stdio.h>
   #include <string.h>
   #include <stdlib.h>
   #include <signal.h>

   int main()
      {
      int ret, fd;

      fd = open("/tmp/signal", O_RDONLY);
      if(fd == -1) { perror("open"); return 1; }

      ret = fcntl(fd, F_SETSIG, SIGSEGV);
      if(ret == -1) { perror("fcntl(F_SETSIG)"); return 1; }

      ret = fcntl(fd, F_NOTIFY, DN_CREATE);
      if(ret == -1) { perror("fcntl(F_NOTIFY)"); return 1; }

      execl("target", "target", NULL);

      /* still here -> exec failed */
      perror("exec");

      return 1;
      }

And ``target.c``, which just waits for death::

   #include <signal.h>
   #include <stdio.h>
   #include <unistd.h>

   int main()
      {
      printf("Target started as uid %d euid %d...\n", getuid(), geteuid());
      pause();
      printf("Got a signal\n");
      return 0;
      }

And the first test::

   (motoko ~)$ gcc -Wall -W signal.c -o signal
   (motoko ~)$ gcc -Wall -W target.c -o target
   (motoko ~)$ mkdir /tmp/signal
   (motoko ~)$ ./signal
   Target started as uid 1000 euid 1000...
   [In another terminal: touch /tmp/signal/die]
   Segmentation fault

But on Unix, any process can send a signal to any other process
running as the same user, so this isn't too interesting. But what if
the executed program is setuid? Well::

   (motoko ~)$ sudo chown root.root target
   (motoko ~)$ sudo chmod 4755 target
   (motoko ~$) ./signal
   Target started as uid 1000 euid 0...
   [In another terminal: touch /tmp/signal/die2]
   Segmentation fault

So a process can cause a setuid process to receive a signal! Very
interesting! But, it turns out, not for a process that sets its real
user id using ``setuid(geteuid())``. After compiling a version of
target.c that does this::

   ./signal
   Target started as uid 0 euid 0...

Creating files in /tmp/signal had not effect on this process. Why?
For this I started looking around the Linux kernel sources. A quick
grep showed that the implementation of FD_NOTIFY was in
``fs/fcntl.c`` and ``fs/dnotify.c``. The first contains the
implementation of fcntl, which just does a switch on the fcntl op code
and calls another function. The entire case for ``F_NOTIFY`` is::

   case F_NOTIFY:
         err = fcntl_dirnotify(fd, filp, arg);
         break;

All code handling ``F_NOTIFY`` is in ``dnotify.c``. The
most immediately relevant part is in the implementation of
``__inode_dir_notify``, which is called to actually handle the
delivery. This function walks through the list of processes which
requested notification, and, after signaling them (using
``send_sigio``), removing those which weren't registered with
DN_MULTISHOT (by default, notifications are one shot affairs, much
like Version 7 signal handling).

``send_sigio`` invokes ``send_sigio_to_task``, which
starts out with::

   if (!sigio_perm(p, fown, fown->signum))
          return;

Which is defined as::

   static inline int sigio_perm(struct task_struct *p,
                                struct fown_struct *fown, int sig)
   {
           return (((fown->euid == 0) ||
                    (fown->euid == p->suid) || (fown->euid == p->uid) ||
                    (fown->uid == p->suid) || (fown->uid == p->uid)) &&
                   !security_file_send_sigiotask(p, fown, sig));
   }

Which, in this case, is the process of signal notification to our
privileged target stops. After it set its uid to its effective uid, we
could no longer deliver signals to it (except ones traditionally sent
via the controlling terminal like SIGINT).

In my initial pass I actually missed this check completely, and
followed further down, into ``group_send_sig_info`` in
``kernel/signal.c``, which in turn immediately calls
``check_kill_permission`` in the same file which makes much the
same check.

It turns out this rule is perfectly well documented in the man page
for ``kill(2)``!

   For a process to have permission to send a signal it must either be
   privileged (under Linux: have the CAP_KILL capability), or the real or
   effective user ID of the sending process must equal the real or saved
   set-user-ID of the target process.

An interesting paper on setuid is one from Usenix 2002 by Hao Chen,
David Wagner, and Drew Dean, `Setuid Demystified <http://www.cs.berkeley.edu/~daw/papers/setuid-usenix02.pdf>`_.
