extgrep for Ruby
================
extgrep is a command-line tool, designed to help you restore your data from an ext3-filesystem.
It simply searches over all blocks (can take a while) and outputs all blocks containing your
specified `search_string`

Requirements
------------
Please note, that extgrep **only works with ruby1.9** and it is in a really early stage.
It helped me to recover 99% of my lost data. It is designed as a **last resort**. Because
crawling all blocks can take a while (and i now compiled programs would be much faster) you
may try out the following two programs first:

  - [http://www.xs4all.nl/~carlo17/howto/undelete_ext3.html ext3grep by Carlo Wood]
  - [http://extundelete.sourceforge.net/ extundelete]
  
Only if those two programs won't work for you - for example because there are no inodes
left to search for - extgrep

Installation
------------
Checkout extgrep, allow execution and create a symbolic link.

    git clone git://github.com/b-studios/extgrep.git
    chmod u+x extgrep.rb
    sudo ln -s /YOUR_PATH/extgrep.rb /usr/bin/extgrep
    

Usage
-----
extgrep has to work on an image of a filesystem. You may copy your **unmounted** filesystem with the following command:

    dd bs=4M if=/dev/sda1 of=data.img

If you want to find out all blocks which contain, let's say, "foobar" simply type:

    ~% extgrep data.img "foobar"    
    searching for foobar
    Block 916: matched
    Block 1267: matched
    Block 1549: matched
    Block 9558: matched
    Block 9731: matched
    Block 12972: matched
    Block 13960: matched
    Block 13967: matched
    Block 19683: matched
    ----------------------------- FOUND -------------------------------------
    916 1267 1549 9558 9731 12972 13960 13967 19683

To find out about all of the features just type:

   ~% extgrep help

