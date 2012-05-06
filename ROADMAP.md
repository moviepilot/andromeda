# Roadmap

This document contains planning steps and ideas for the future of andromeda.

## Short-Term Todo's

* DONE Test with macruby, figure out if rubinius pre-compilation should be added, doesnt work
* DONE Convert old Pool code into Guards
* DONE Convert Kit into Plans
* DONE Convert Command into Plans, moving it into a submodule
* Test scope, tags, threading in IRB
* Subscopes ?

### Write Test-Cases

This needs to be done as soon as the general API has matured enough, i.e.
around when andromeda is re-used by neoscout.

### Write Docs

* Get started on stable calls in the API first
* Complete as time goes by
* Add high-level description to README.md
* Add examples to README.md
* Add link to yardocs to README.md as soon as that makes sense
* Figure out yardoc methods for documenting meth_spot and attr_spot

### Write a better DSL for connecting plans

* connect
* Arrow Calculus via Kit comes to mind
* More operators like '>>': Add multiple via splitter, join results etc.
* This needs more practical experience with the framework first.

### Implement map_reduce.rb

### Implement ActorGuide

### Implement csv.rb

* map statval over everything that looks like a number

## Long-Term Ideas

### Implement more synchronization primitives

* Buffered join

### Implement zmq.rb

### Implement network visualization using GraphViz

* Really should use an abstract graph builder interface

### Implement additional connectors

* TCP
* Syslog
* EventMachine

## Open Issues

### Avoid memory leaks

I'm undecied on this, but spots could be cached instead of being recreated
on intern using the yet to be written Atom::* vars.

## Far, far in the future

Add automatic distribution support.

It should not be that hard.  In the end this is just a mildly interesting graph transformation on the topology, a bit of rewiring, and some support code to run stuff on remote machines.  Ah maybe we just use capistrano for that. Of course, that would be static only. Dynamic job submission is a diffrerent story, as is at-most-once messaging (i.e. transactionality).