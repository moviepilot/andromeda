# andromeda

Andromeda is a light weight framework for complex event processing on multicore architectures. Andromeda users construct networks of plans that are interconnected via endpoint spots, describe how plans are scheduled onto threads, and process data by feeding data events to the resulting structure.

It currently comes without tests but the core architectures is stable (i.e. the concepts have been fleshed out).

## Example

Below is an example that writes events to a file and reads them back such that the JSON gets parsed in parallel, to give an idea of what it does:

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
    s = Sync::Bracket.new
    # Connect the processing steps (Plans)
    s >> r >> p >> t
    # Enfore reader to run on a separate single thread
    r.guide = Guides.single
    # Set multicore processing behaviour to parse Cmd's in parallel
    p.guide = Guides.shared_pool
    # Set logger to execute in sending thread (i.e. Parser)
    t.guide = Guides.local
    # Start reading and wait till processing finishes
    s << :start
    # t will log to a Logger.new(STDERR) by default

There is much more, dig the source, luke!

*Note* All active development happens on the devel branch, cf. boggle/devel, too.

## Installation

    gem install andromeda

## Requirements

Any ruby that has working atomic and threadpool gems should do.

Effectively, that is rubinius, jruby and mri ruby (if the provided threading of mri ruby is enough for your purpose).

## Online Docs

Docs for the latest released gems are to be found in:

http://rubydoc.info/gems/andromeda

## Overview

### Key Concepts: Spots, Plans, Guides, and Tracks

Andromeda works by sending data as events over a network of interconnected event handler endpoints (called spots).  Each spot is implemented in a container object that is called it's plan.  A plan can contain multiple spots, either in the form of event handling method spots (on_name methods of the plan) or as attribute spots that point to spots in other plans. Each plan has a default entry spot, a default exit spot, and an optional spot attribute called errors for signaling exceptions. Plans are connected with each other by assigning spot references to a plan's spot attributes.

Event handling is initiated by sending data to a plan's start spot (a special spot that encapsulates the plan's entry spot). Sendin data to a spot is called method spot activation.

During processing, andromeda distinguised between two kinds of state, plan state and tag state. Plan state is the state of the concret plan instance that contains an event handling method spot prior to its activation. Tag state is state that gets passed along between spots as a side-effect of event handling.

Each plan is associated to a guide. First, guides control if and how plan instances are *copied* (or locked) prior to method spot activation to ensure isolated state access. Secondly, guides assign each method spot activation to a track that describes how and where (on which thread) it actually gets executed.

Out of the box andromeda supports various guides: single thread (per plan or globally shared), thread pool (per plan or globally shared), execution in current thread, and spawning of a new thread per data event.

To sum up, plans are factory objects that describe the instantiation of concrete data processing networks as guided by their associated guide objects and according to the rules of the underlying, executing tracks.

### Quick Usage Example

    class MyPlan < Andromeda::Plan
      spot_attr :a, :b
      spot_meth :alternative

      def data_key(name, data) ; data end

      def on_enter(key, val)
        exit << val
      end

      def on_alternative(key, val)
        return (a << val) if key == :a
        return (b << val) if key == :b
        signal_error ArgumentError.new("Unknown key: #{data}")
      end
    end

    p = MyPlan.new
    p.guide = Andromeda::Guides.shared_pool
    p >> Andromeda::Kit::Tee.new(nick: :red)
    p.a = Andromeda::Kit::Tee.new(nick: :green)
    p.b = Andromeda::Kit::Tee.new(nick: :blue)

    p << :a # logs to :red
    p << :b # logs to :red
    p.alternative << :a # logs to :green
    p.alternative << :b # logs to :blue
    p << :c # logs error


### Event handling details

Data processing starts when a data object is submitted to a spot. Processing
happens mainly in two steps, preprocessing in the sending thread, and actual
execution (processing) on the target track.

#### Preprocessing

During preprocessing, the data object may be mapped, split into a key for routing and an actual data value, it may be used to modify the set of associated tags, and finally get filtered out before sending.  Furthermore, the key may be used to switch the target spot name and track label.  All of these steps are optional and aim to push preprocessing fucntionality to the sending thread to avoid unneccesary thread context switches.

Please consult the documentation of class Plan to discover the preprocessing methods that are available for overloading in subclasses.

#### Execution/Processing

Prior to execution, the plan's guide selects a track for spot activation, packs the plan (i.e. copies/freezes/locks it's plan state as necessary), and optionally modifies the associated incoming tags.  Finally, the method spot gets activated by calling the spot's method on the packed plan inside the chosen track with the accumulated tags (plan tags and incoming tags).

#### Tags

Each method activation is associated with a set of tags (a hash) that contains optional parameters.  The tags may be modified by the spot method
and are passed on whenever a spot method activates another.

Andromeda provides a small set of reserved default tags that should not be overwritten:

* `tags[:name]` final target spot name
* `tags[:scope]` an Atom::Region instance that is used to wait for completion of processing (cf. below)
* `tags[:label]` the label passed on to the guide to select the track for execution (usually identical to name)
* `tags[:mark]` used for xor-mark based tracking of event flow

#### Wating for event handling completion

Waiting for event handling completion may be achieved by utilizing a special wrapper plan (cf. Sync::Bracket). This is implemented using an atomic counter (cf. Atom::Region).

#### Performance

Andromeda's event handling mechanism is powerful but associated with some performance overhead due to the associated state management. It was written for using it with larger events (i.e. array slices) that user plans iterate over and is not intended for the processing of massively many small events. YMMV.

#### Correctness

Andromeda provides guides to ensure that state is only accessed by a single thread or that it's state is locked apropriately otherwise.  However this only works if you assign correct guides to your plans. Please read and understand the documentation of the various available guides to make sure that no unintended concurrent access of plans takes place.

Alternatively, look at the provided plan implementations for example code.

## Remarks

### Inspiration

Andromeda takes inspiration from several existing approaches / techniques in the area of concurrent programming.

* actor model: state encapsulation
* event processing: preprocessing in sender thread, large events
* libdispatch: abstracting over used queues / thread pool
* join calculus: Sync::Sync

### Status

Alpha at best.
