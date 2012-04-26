# TODO
#  - Write tests
#  - Write docs, add yard support for documenting bases, attrs, etc.
#  - Make nice slideshow and become very famous and rich. yay!
module Andromeda

  class Dest
    attr_reader :base
    attr_reader :name
    attr_reader :meth
    attr_reader :here # "calling base"

    def initialize(base, name, meth, here)
      raise ArgumentError, "#{base} is not a Base" unless base.kind_of?(Base)
      raise ArgumentError, "#{name} is not a symbol" unless name.kind_of?(Symbol)
      raise ArgumentError, "#{meth} is not a symbol" unless meth.kind_of?(Symbol)
      raise NoMethodError, "#{base} does not respond to #{meth}'" unless base.respond_to?(meth)
      raise ArgumentError, "#{here} is neither nil nor a Base" unless !here || here.kind_of?(Base)
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

  class Base

    def self.destinations(inherit = true)
      s = if instance_variable_defined?('@destinations')
            then instance_variable_get('@destinations')
            else Set.new end
      if inherit
        c = self
        while (c = c.superclass)
          s = s.union c.destinations(false) rescue s
        end
      end
      s
    end

    def self.name_dest(*names)
      name_set = names.to_set
      dest_set = destinations false
      instance_variable_set '@destinations', dest_set.union(name_set)
    end

    def self.meth_dest(*names)
      name_dest *names
      names.each do |name|
        define_method :"#{name}" do ||
          intern (Dest.new self, :"#{name}", :"on_#{name}", self)
        end
      end
    end

    def self.attr_dest(*names)
      name_dest *names
      attr_writer *names
      names.each do |name|
        define_method :"#{name}" do ||
          intern (instance_variable_get("@#{name}"))
        end
      end
    end

    attr_reader :id

    meth_dest :enter
    attr_dest :emit

    attr_accessor :log
    attr_accessor :mark
    attr_accessor :nick
    attr_accessor :pool

    attr_accessor :trace_enter
    attr_accessor :trace_pool
    attr_accessor :trace_opts
    attr_accessor :trace_exit

    def initialize(config = {})
      @id            = Id.gen
      set_from_config init_from_config, config
      @trace_enter ||= init_trace_hash :enter
      @trace_pool  ||= init_trace_hash :pool
      @trace_opts  ||= init_trace_hash :opts
      @trace_exit  ||= init_trace_hash :emit
      @pool        ||= init_pool_config
      @opts        ||= {}
      @pool        ||= :local
    end

    def initialize_copy(other)
      super other
      @trace_enter = @trace_enter.clone
      @trace_pools = @trace_pool.clone
      @trace_opts  = @trace_opts.clone
      @trace_exit  = @trace_exit.clone
      @opts        = @opts.clone
    end

    def pool=(pool_descr)
      @pool = make_pool pool_descr
    end

    def init_trace_hash(kind) ; {} end
    def init_pool_config ; :local end
    def init_from_config ; [:readers, :writers] end

    def opts ; @opts end
    def log ; @log = Logger.new(STDERR) unless @log ; @log end
    def mark ; @mark = Id.zero unless @mark ; @mark end

    def chunk_key(name, chunk) ; name end
    def chunk_val(name, chunk) ; chunk end
    def chunk_flt(name, key, val, opts) ; false end

    def on_enter(k, c) ; emit << c rescue nil end

    def handle_chunk(pool_descr, name, meth, chunk, opts_in)
      k = chunk_key name, chunk
      v = chunk_val name, chunk
      p = target_pool pool_descr, k
      f = should_clone? p, k
      t = if f then clone else self end
      t.opts.tap do |o|
        o.update opts_in
        o[:scope] ||= Scope.new
        o[:mark]  ||= Id.zero
        o[:name]    = name
        t.submit_chunk p, meth, f, k, v, o unless chunk_flt(name, k, v, o)
        return o
      end
    end

    def intern(dest) ; if dest then dest.intern(self) else nil end end

    def dest(name)
      if self.respond_to?(name)
        result = self.send(name)
        raise ArgumentError, "Invalid dest: '#{name}'" unless result.kind_of?(Dest)
        intern result
      else
        nil
      end
    end

    def destinations ; self.class.destinations end

    def ident ; if nick then "#{id} (aka #{nick})" else "#{id}" end end

    protected

    def set_from_config(what, config = {})
      init_readers = what.include? :readers
      init_writers = what.include? :writers
      config.each_pair do |k, v|
        k = k.to_sym rescue nil
        if init_writers
          writer = :"#{k}=" rescue nil
          if writer && self.respond_to?(writer)
            then self.send writer, v
            else instance_variable_set "@#{k}", v if init_readers && self.respond_to?(k) end
        else
          instance_variable_set "@#{k}", v if init_readers && self.respond_to?(k)
        end
      end
    end

    def target_pool(pool_descr, key)
      p = if pool_descr then pool_descr else pool end
      p = :local unless p
      p = make_pool p
      p = p.key_pool(key) if p.respond_to?(:key_pool)
      p
    end

    def make_pool(p) ; PoolSupport.make_pool p end

    def should_clone?(pool, k)
      return true if pool == :local
      return true if (begin pool.respond_to?(:max) && pool.max > 1 rescue false end)
      false
    end

    def submit_chunk(p, meth, was_cloned, k, chunk, o)
      scope = o[:scope]
      name  = o[:name]
      run_chunk p, scope, name, meth, k, chunk do
        begin
          enter_level = trace_level(trace_enter, name)
          opts_level  = trace_level(trace_opts, name)
          pool_level  = trace_level(trace_pool, name)
          exit_level  = trace_level(trace_exit, name)
          meth_trace :enter, enter_level, name, meth, k, chunk if enter_level
          pool_trace pool_level, name, meth, k, chunk, p if pool_level
          opts_trace :enter, opts_level, name, meth, k, chunk if opts_level
          send_chunk meth, k, chunk
          meth_trace :exit, exit_level, name, meth, k, chunk if exit_level
        rescue Exception => e
          handle_exception name, meth, k, chunk, e
        ensure
          if o && !was_cloned
            o.delete :scope
            o.delete :mark
            o.delete :name
          end
          opts_trace :exit, opts_level, name, meth, k, chunk if opts_level
          scope.leave if scope
        end
      end
    end

    def run_chunk(pool, scope, name, meth, k, chunk, &thunk)
      scope.enter
      begin
        if pool && pool.respond_to?(:process)
          then pool.process(&thunk)
          else thunk.call end
      rescue Exception => e
        handle_exception name, meth, k, chunk, e
        scope.leave if scope
      end
      self
    end

    def trace_level(h, name)
      if h.kind_of?(Symbol) then h else (h[name] rescue nil) end
    end

    def meth_trace(kind, level, name, method, k, chunk)
      log_ = log
      log_.send level, "METH #{ident}, :#{kind}, :#{name}, method: #{method}, key:, #{k}, chunk: #{chunk}" if log_
    end

    def pool_trace(level, name, method, k, chunk, p)
      log_ = log
      log_.send level, "POOL #{ident}, :#{name}, method: #{method}, key: #{k}, chunk: #{chunk}, self_pool: #{self.pool}, pool: #{p}" if log_
    end

    def opts_trace(kind, level, name, method, k, chunk)
      log_ = log
      log_.send level, "OPTS #{ident}, :#{kind}, :#{name}, method: #{method}, key: #{k}, chunk: #{chunk}, opts: #{opts}" if log_
    end

    def send_chunk(meth, k, chunk)
      mark_opts
      self.send meth, k, chunk
    end

    def check_mark
      m = @opts[:mark]
      raise RuntimeError, 'Invalid mark' if m && !m.zero?
    end

    def mark_opts
      mark_ = mark
      if mark_ && !mark_.zero?
        if @opts[:mark]
          then @opts[:mark] = @opts[:mark].xor(mark_)
          else @opts[:mark] = mark_ end
      end
    end

    def handle_exception(name, meth, k, chunk, e)
      if log
        trace = ''
        e.backtrace.each { |s| trace << "\n    #{s}" }
        log.error "Caught '#{e}' when processing key: #{k}, chunk: #{chunk} as dest: #{name} using meth: #{meth} with backtrace: #{trace}"
      end
    end

    public

    def >>(dest)
      if dest.kind_of?(Dest)
        self.emit = dest
        dest.base
      else
        self.emit = dest.entry
        dest
      end
    end

    def start ; entry.intern(nil) end
    def entry ; enter end
    def exit ; emit end
    def drop ; emit = nil end

    def <<(chunk, opts = {}) ; start.<< chunk, opts end
    def submit(chunk, opts = {}) ; start.submit chunk, opts end
    def submit_now(chunk, opts = {}) ; start.submit_now chunk, opts end
    def submit_to(target_pool, chunk, opts = {}) ; start.submit_to target_pool, chunk, opts end
  end

end