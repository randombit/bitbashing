.. title: Huffman Encoding of Phone Contacts
.. slug: contact_list_sorting
.. date: 2007-03-10

Every mobile phone I've ever used or heard of sorts their contact
lists in alphabetical order based on name.

.. TEASER_END

In 2007, you'd be hard pressed to walk into a mobile store and find
even a single phone that wouldn't let you can tag your contacts with
metadata such as photos to display when that person calls, birthdays
so you can be reminded to call, and the type of relationship you have
with the contact (work, friend, family, etc). But it's impossible to
sort your contacts by these values. You might one day decide to call
all your friends in a particular area invite them to crash an embassy
event with you, but you can't bear to wade through everyone else to
get to them, and instead spend the night at home reading reddit.

I think the most useful of these sortings, though, would be the
call counter. I'm but a sample size of one, but there are essentially
two or three people I might call or SMS at least every other day,
fifteen or so who I might call once a month, and then a bunch of
people I never call. But unfortunately my close friends and associates
do not have alphabetically sequential names. Sorting so the person you
call the most is the top and the person you call the least is at the
bottom will probably make it much faster to call, on average, the
person you want. It's basically a Huffman encoding, except the
optimization is for navigation time instead of bitlength.

The exact syntax for invoking a particular sort would depend
greatly on the phone's interface. On my Nokia, the left/right buttons
don't seem to do anything while you are in the contact list, and could
be used to iterate through the available (and enabled) sortings.

Update: A few weeks after writing this, I found that Norbert Wiener
beat me to this idea by about 40 years. Quoting "The Human Use of
Human Beings: Cybernetics and Society"::

   The number of people with whom I actually wish to talk over the
   telephone is limited, and in a large measure is the same limited group
   day after day and week after week. I use most of the telephone
   equipment available to me to communicate with members of this
   group. Now, as the present technique of switching generally goes, the
   process of reaching one of the people whom we call up four or five
   times a day is in no way different from the process of reaching those
   people with whom we may never have a conversation. From the standpoint
   of balanced service, we are using either too little equipment to
   handle the frequient calls or too much to handle the infrequent
   calls...
