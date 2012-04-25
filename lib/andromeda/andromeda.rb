# TODO
#  - Turn into separate gem
#  - Write Tests
#  - Write fusor for synchronization (extra class that blocks until ready to submit)
#  - Write docs, add yard support for documenting bases, attrs, etc.
#  - Make nice slideshow and become very famous and rich. yay!
module Andromeda

  module Internal
    class Transplanting
      attr_reader :orig

      def initialize(init_opts = nil)
        @opts = init_opts
        @orig = self
      end

      protected

      def transplant(should_clone, new_opts = nil)
        if should_clone.nil?
          should_clone = @opts == new_opts
        end
        obj = if should_clone then self.clone else self end
        obj.instance_variable_set '@opts', new_opts
        obj
      end
    end
  end

  class Dest < Internal::Transplanting
    attr_reader :base
    attr_reader :meth
    attr_reader :name

    def initialize(base, name, meth, init_opts = nil)
      super init_opts
      raise ArgumentError, "#{name} is not a symbol" unless name.kind_of?(Symbol)
      raise ArgumentError, "#{meth} is not a symbol" unless meth.kind_of?(Symbol)
      raise ArgumentError, "#{base} is not a base" unless base.kind_of?(Base)
      raise NoMethodError, "#{base} does not respond to #{meth}'" unless base.respond_to?(meth)
      @base  = base
      @meth  = meth
      @name  = name
    end

    def <<(chunk, opts = {}) ; submit chunk, opts ; self end
    def submit(chunk, opts = {}) ; submit_to nil, chunk, opts end
    def submit_now(chunk, opts = {}) ; submit_to :local, chunk, opts end

    def submit_to(target_pool, chunk, opts = {})
      if @opts
        new_opts = @opts.clone
        opts.each { |k, v| new_opts[k] = v }
      else
        new_opts = opts
      end
      new_opts[:scope] ||= Scope.new
      new_opts[:mark]  ||= Id.zero
      base.handle_chunk target_pool, new_opts[:scope], name, meth, chunk, new_opts
      new_opts
    end

    def entry ; self end
  end

  class Base < Internal::Transplanting
    attr_reader :id
    attr_reader :opts

    attr_accessor :log
    attr_accessor :mark
    attr_accessor :emit
    attr_accessor :pool

    attr_accessor :trace_enter
    attr_accessor :trace_pool
    attr_accessor :trace_exit

    def initialize(config = {})
      super config[:init_opts]
      @id = Id.gen
      set_from_config init_from_config, config      
      @trace_enter ||= init_trace_hash :enter
      @trace_pool  ||= init_trace_hash :pool
      @trace_exit  ||= init_trace_hash :emit
      @pool        ||= init_pool_config
      @pool          = make_pool @pool
    end 

    def init_trace_hash(kind) ; {} end
    def init_pool_config ; :local end
    def init_from_config ; [:readers, :writers] end

    def log ; @log = Logger.new(STDERR) unless @log ; @log end
    def mark ; @mark = Id.zero unless @mark ; @mark end

    def chunk_key(name, chunk) ; name end
    def on_enter(k, c) ; emit << c rescue nil end   

    def handle_chunk(pool_descr, scope, name, meth, chunk, new_opts = nil)
      k = chunk_key name, chunk
      p = target_pool pool_descr, k      
      t = transplant(should_clone?(p, k), new_opts) if new_opts
      t.submit_chunk p, scope, name, meth, k, chunk
      t
    end

    def intern(dest) ; dest.transplant(nil, opts) end

    def dest(name)
      result = if self.respond_to?(name)
        then intern self.send(name)
        else Dest.new self, name, "on_#{name}".to_sym, opts  end
      raise ArgumentError, "unknown or invalid dest: '#{name}'" unless result.kind_of?(Dest)
      result
    end

    protected

    def set_from_config(what, config = {})
      init_readers = what.include? :readers
      init_writers = what.include? :writers
      config.each_pair do |k, v|
        k = k.to_sym rescue nil
        if init_writers
          writer = "#{k}=".to_sym rescue nil
          if writer &&  self.respond_to?(writer)
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

    def make_pool(p) ; PoolSupport.make_pool p  end

    def should_clone?(pool, k) 
      if pool.respond_to?(:max) 
        then pool.max > 1 
        else true end
    end

    def submit_chunk(p, scope, name, meth, k, chunk)
      mark_opts
      run_chunk p, scope, name, meth, k, chunk do
        begin
          enter_level = trace_level(trace_enter, name)
          pool_level  = trace_level(trace_pool, name)
          exit_level  = trace_level(trace_exit, name)
          meth_trace :enter, enter_level, name, meth, k, chunk if enter_level
          pool_trace pool_level, name, meth, k, p if pool_level
          send meth, k, chunk
          meth_trace :exit, exit_level, name, meth, k, chunk if exit_level
        rescue Exception => e
          handle_exception name, meth, k, chunk, e
        ensure
          scope.leave if scope
        end
      end
    end

    def trace_level(h, name)
      if h.kind_of?(Hash)
        then h[name] rescue nil
        else h end
    end

    def meth_trace(kind, level, name, method, k, chunk) 
      log_ = log     
      log_.send level, "METH #{id.to_s}, :#{kind}, :#{name}, method: #{method}, key:, #{k}, chunk: #{chunk}" if log_
    end

    def pool_trace(level, name, method, k, p)
      log_ = log     
      log_.send level, "POOL #{id.to_s}, :#{name}, method: #{method}, key: #{k}, self_pool: #{self.pool}, pool: #{p}" if log_
    end

    def check_mark
      mark = @opts[:mark]
      raise RuntimeError, 'invalid mark' if mark && !mark.zero?
    end

    def mark_opts
      if @mark && !@mark.zero?
        if @opts[:mark]
          then @opts[:mark] = @opts[:mark].xor(mark)
          else @opts[:mark] = mark end
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

    def handle_exception(name, meth, k, chunk, e)
      if log
        trace = ''
        e.backtrace.each { |s| trace << "\n    #{s}" }
        log.error "Caught '#{e}' when processing key: #{k}, chunk: #{chunk} as dest: #{name} using meth: #{meth} with backtrace: #{trace}"
      end
    end

    public

    def >>(dest) ; self.emit = if dest.kind_of?(Dest) then dest else dest.entry end end

    def drop ; self.emit = nil end

    def entry ; dest(:enter) end
    alias_method :exit, :emit

    def <<(chunk, opts = {}) ; entry.<< chunk, opts end
    def submit(chunk, opts = {}) ; entry.submit chunk, opts end
    def submit_now(chunk, opts = {}) ; entry.submit_now chunk, opts end
    def submit_to(target_pool, chunk, opts = {}) ; entry.submit_to target_pool, chunk, opts end
  end
end