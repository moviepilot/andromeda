# andromeda

Andromeda is a ultra light weight multicore stream processing framework based on a small dataflow DSL

It is currently untested and undocumented.  

Below is an example that writes events to a file and reads them back in, to give an idea of what it does:

    require 'andromeda'
    w = Andromeda::CommandoWriter.new path: '/tmp/some_file'
    w << (Commando.new :test)
    w << (Commando.new :test, weight: 40)    
    w << (Commando.new :test, height: 20)        
    w << :close

    r = Andromeda::CommandParser.new path: '/tmp/some_file'
    # make r process events using a global thread pool of num_cpus threads
    r.pool = :global
    t = Andromeda::Tee.new
    # make r output to t
    r >> t
    # start reading
    r << :start
    # t will log to a Logger.new(STDERR) by default

There is much more, dig the source, luke!


