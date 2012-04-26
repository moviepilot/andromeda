module Andromeda

  class Dest
    attr_reader :base
    attr_reader :name
    attr_reader :meth
    attr_reader :here # "calling base"

    def initialize(base, name, meth, here)
      raise ArgumentError, "#{base} is not a Stage" unless base.kind_of?(Stage)
      raise ArgumentError, "#{name} is not a symbol" unless name.kind_of?(Symbol)
      raise ArgumentError, "#{meth} is not a symbol" unless meth.kind_of?(Symbol)
      raise NoMethodError, "#{base} does not respond to #{meth}'" unless base.respond_to?(meth)
      raise ArgumentError, "#{here} is neither nil nor is it a Stage" unless !here || here.kind_of?(Stage)
      @base = base
      @meth = meth
      @name = name
      @here = here
    end

    def <<(chunk, opts_in = {}) ; submit chunk, opts_in ; self end

    def submit(chunk, opts_in = {}) ; submit_to nil, chunk, opts_in end
    def submit_now(chunk, opts_in = {}) ; submit_to :local, chunk, opts_in end

    def submit_to(target_pool, chunk, opts_in = {})
       o = here.opts.clone.update(opts_in) rescue opts_in
       base.handle_chunk target_pool, name, meth, chunk, o
    end

    def start ; entry.intern(nil) end

    def entry ; self end
    def exit ; base.exit end

    def intern(new_caller)
      if here == new_caller then self else Dest.new base, name, meth, new_caller end
    end
  end

end