.. title: Converting Line Endings in InnoSetup
.. slug: convert_line_endings_in_innosetup
.. date: 2009-11-23
.. tags: programming

I recently packaged `botan <https://botan.randombit.net>`_ using
`InnoSetup <http://www.jrsoftware.org/isinfo.php>`_, an open source
installation creator. Overall I was pretty pleased with it - it seems
to do everything I need it to do without much of a hassle, and I'll
probably use it in the future if I need to package other programs or
tools for Windows.

.. TEASER_END

After I got the basic package working, a nit I wanted to deal with
was converting the line endings of all the header files and plain-text
documentation (readme, license file, etc) to use Windows line
endings. While many Windows programs, including Wordpad and Visual
Studio, can deal with files with Unix line endings, not all do, and it
seemed like it would be a nice touch if the files were not completely
unreadable if opened in Notepad.

There is no built in support for this, but InnoSetup includes a
scripting facility (using Pascal!), including hooks that can be called
at various points in the installation process, including immediately
after a file is installed, which handles this sort of problem
perfectly. So all that was required was to learn enough Pascal to
write the function. I've included it below to help anyone who might be
searching for a similar facility, since my own searches looking
for an example of doing this were fruitless::

   [Code]
   const
      LF = #10;
      CR = #13;
      CRLF = CR + LF;

   procedure ConvertLineEndings();
     var
        FilePath : String;
        FileContents : String;
   begin
      FilePath := ExpandConstant(CurrentFileName)
      LoadStringFromFile(FilePath, FileContents);
      StringChangeEx(FileContents, LF, CRLF, False);
      SaveStringToFile(FilePath, FileContents, False);
   end;

Adding the hook with ``AfterInstall: ConvertLineEndings``
caused this function to run on each of my text and include files.
