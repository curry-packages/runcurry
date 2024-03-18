runcurry: a command to run a Curry program without invoking the REPL
====================================================================

The `runcurry` command has three modes of operation:

* Shell command: execute the `main` operation of a Curry program
  whose **file name** is provided as an argument, e.g.,

    > runcurry [Curry system options] <Curry program name> <run-time arguments>

* Interactive mode: execute the `main` operation of a Curry program
  whose program text comes from the standard input, e.g.,

    > runcurry
    ...type your Curry program until end-of-file...

* Shell script: execute the `main` operation of a Curry program
  whose program text is in a script file starting with

    #!/usr/bin/env runcurry

  If the name of the script file has a suffix, it must be different
  from `.curry` and `.lcurry`.
  
  If the script file contains the line `#jit`, it is compiled
  and saved as an executable so that it is faster executed
  when called the next time.

The directory `examples` contains various examples of using `runcurry`.

