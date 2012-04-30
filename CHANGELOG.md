# CHANGELOG

*Note* Not all versions are released gems, many version numbers just exist in the github repository.

## 0.1.2: Architecture Refactoring

* Tested with rbx, mri, and jruby
* Renaming and reorganization of architecture:
Stages are now called plans, chunks data, opts tags and dests spots. Construction of Pools and state management (i.e. copying) of Plans and Tags has been factored into two new abstractions: Guards (state management, track selection), and Tracks (Executors/Thread pools).
* Reorganization of modules (Plan is toplevel + Kit, Sync, Cmd, Atom)
* New code: error.rb, copy_clone.rb, sugar.rb
* Beginning docs: CHANGELOG, ROADMAP
* Cleaned up output in irb considerably
* Wrote helper support for testing: Atom::(Var, Region, FillOnce, Combiner)
* Renamed Command to Cmd and moved into Cmd:: module
* Added guide nick names to Guides.self


## 0.1.1: Architecture Refactoring

* Commands have support for comments
* some work left todo for chunking
* emit is protected now
* exit as default "emitter" for on_enter (allow overloading in subclasses)
* Tested with rubinius
* Set pool from other stage
* Added globally shared single pool
* Andromeda.reload! + maruku installed as fallback for yard by default
* Added FileChunker and FileReader to helpers
* Added signals (keeping track of dests not intended for map/filter by Transf etc)
* Renamed Bases to Stages (was talking about stages all the time anyhow)
* Polished logging/error catching and helpers
* PoolSupport.num_processors caches num_cpus value (dont trust Facter that much to be quick)
* Made >> chaining and added chunk_val for easier mapping
* Added chunk keys for map reduce like handling
* Added GathererBase and a plain Reducer to helpers.rb
* Overhauled Join for concurrent synchronization
* Avoids cloning in single-threaded scenarios for shared state in gatherers
* Modified thread pool creation to happen on init if possible
* Added trace_pool for debugging which pools get used by whom

## 0.1 (Release)

Initial Version