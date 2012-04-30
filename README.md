# andromeda

Andromeda is a ultra light weight framework for complex event processing on multicore architectures. Andromeda is noteworthty in that it borrows ideas from dataflow based stream processing of events, the actor model, join calculus, and staging architectures.

It currently comes without tests but the core architectures is stable (i.e. the concepts have been fleshed out).

## Example

Below is an example that writes events to a file and reads them back in, to give an idea of what it does:

    require 'andromeda'

    # Enter scope 'Andromeda' in irb
    cb Andromeda

    # Write Cmd instances to a log file, nothing fancy here
    w = Cmd::Writer.new path: '/tmp/some_file'
    w << :open
    w << (Cmd::Cmd.new_input :test)
    w << (Cmd::Cmd.new_input :test, weight: 40)
    w << (Cmd::Cmd.new_input :test, height: 20)
    w << :close

    r = Cmd::Reader.new path: '/tmp/some_file'
    p = Cmd::Parser.new
    t = Kit::Tee.new
    s = Sync::ScopeWaiter.new
    # Connect the processing steps (Plans)
    s >> r >> p >> t
    # Enfore reader to run on a separate single thread
    r.guide = Guides.single
    # Set multicore processing behaviour to parse Cmd's in parallel
    p.guide = Guides.shared_pool
    # Start reading and wait till processing finishes
    s << :start
    # t will log to a Logger.new(STDERR) by default

There is much more, dig the source, luke!

*Note* All active development happens on the devel branch, cf. boggle/devel, too.

## Online Docs

Docs for the latest released gems are to be found in:

http://rubydoc.info/gems/andromeda

## Key Concepts

### Overview

Andromeda works by sending data as events over a network of interconnected event handler endpoints (called spots).  Each spot is implemented in a container object that is called it's plan.  A plan can contain multiple spots, either in the form of event handling method spots (on_name methods of the plan) or as attribute spots that point to spots in other plans. Each plan has a default entry spot, a default exit spot, and an optional spot attribute called errors for signaling exceptions. Plans are connected with each other by assigning spot references to a plan's spot attributes.

Event handling is initiated by sending data to a plan's start spot (a special spot that encapsulates the plan's entry spot). This is called method spot activation.

During processing, andromeda distinguised between two kinds of state, plan state and tag state. Plan state is the state of the concret plan instance that contains an event handling method spot prior to its activation. Tag state is state that gets passed along between spots as a side-effect of event handling.

Each plan is associated to a guide. First, guides control if and how plan instances are *copied* (or locked) prior to method spot activation to ensure isolated state access. Secondly, guides assign each method spot activation to a track that describes how it actually gets executed.

Out of the box andromeda supports various guides: single thread (per plan or globally shared), thread pool (per plan or globally shared), execution in current thread, and spawning of a new thread per event.

To sum up, plans are factory objects that describe the instantiation of concrete data processing networks as guided by their associated guide objects and according to the rules of the underlying, executing tracks.

### Event handling details

Data processing starts when a data object is submitted to a spot. Processing
happens mainly in two steps, preprocessing in the sending thread, and actual
processing on the executing track.

#### Preprocessing

During preprocessing, the data object may be mapped, split into a key for routing and an actual data value, used to modify the set of assoicated tags, and finally get filtered out before sending.  Furthermore, the key may
be used to switch the target spot name and track label.  All of these steps are optional and aim to push lightweight preprocessing to the sending thread with the purpose of avoiding unneccesary context switches.

Please consult the documentation of Plan to discover the preprocessing methods that are available for overloading in subclasses.

#### Execution

Prior to execution, the plan's guide selects a track for spot activation, packs the plan (i.e. copies/freezes/locks it's state as necessary), and optionally modifies the associated tags.  Finally, the method spot gets activated by called the spot's method on the packed plan inside the chosen track with the accumulated tags.

### Wating for event handling completion

Waiting for event handling completion may be achieved by utilizing a special wrapper plan (cf. Sync::ScopeWaiter). This is implemented using an atomic counter (cf. Atom::Region).


