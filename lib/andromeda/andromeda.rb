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

      def transplant(new_opts = nil)
        return self if @opts == new_opts
        obj = self.clone
        obj.instance_variable_set '@opts', new_opts
        obj
      end
    end
  end

  class Dest < Internal::Transplanting
    attr_reader :base
    attr_reader :meth

    def initialize(base, meth, init_opts = nil)
      super init_opts
      raise ArgumentError, "'#{meth}' is not a symbol" unless meth.kind_of?(Symbol)
      raise ArgumentError, "'#{base}' is not a base" unless base.kind_of?(Base)
      raise NoMethodError, "'#{base}' does not respond to '#{meth}'" unless base.respond_to?(meth)
      @base  = base
      @meth  = meth
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
      base.transplant(new_opts).process target_pool, new_opts[:scope], self.meth, chunk
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

    attr_reader :trace_enter
    attr_reader :trace_exit

    def initialize(config = {})
      super config[:init_opts]
      @id = Id.gen
      set_from_config init_from_config, config      
      @trace_enter ||= init_trace_hash :enter
      @trace_exit  ||= init_trace_hash :emit
      @pool        ||= init_pool_config
    end 

    def trace=(new_trace)
      raise ArgumentError, "'#{new_trace}' is not a Hash" unless new_trace.kind_of?(Hash)
      @trace = new_trace
    end

    def init_trace_hash(kind) ; {} end
    def init_pool_config ; nil end
    def init_from_config ; [:readers, :writers] end

    def log ; @log = Logger.new(STDERR) unless @log ; @log end
    def mark ; @mark = Id.zero unless @mark ; @mark end

    def on_enter(c)
      emit << c rescue nil
    end   

    # @param [nil, :local, :spawn, :single, :fifo, :default, :global, #process, #process_base] pool_descr 
    #     If nil, uses self.pool as pool_descr and continues. If that is nil, too, defaults to :local.
    #     If #process_base, uses target_pool.process_base(meth) as pool_descr and continues.
    #     If pool_descr is :spawn, uses SpawnPool.default_pool
    #     If pool_descr is :single, uses PoolSupport.new_single_pool
    #     If pool_descr is :fifo, uses PoolSupport.new_fifo_pool
    #     If pool_descr is :global, uses the globally shared PoolSupport.global_pool
    #     If pool_descr is :default uses PoolSupport.new_default_pool
    #     Finally, if #process, runs by calling #process.  If :local, runs in current thread. 
    #     Otherwise, the behaviour is undefined.
    def process(pool_descr, scope, meth, chunk)
      this = self
      run target_pool(pool_descr, meth), scope, meth, chunk  do
        begin
          enter_level = trace_enter[meth]
          exit_level  = trace_exit[meth]
          trace :enter, enter_level, meth, chunk if enter_level
          send meth, chunk
          trace :exit, exit_level, meth, chunk if exit_level
        rescue Exception => e
          handle_exception meth, chunk, e
        ensure
          scope.leave if scope
        end
      end
    end

    def check_mark
      mark = @opts[:mark]
      raise RuntimeError, 'invalid mark' if mark && !mark.zero?
    end

    def intern(dest) ; dest.transplant(opts) end

    def dest(name)
      result = if self.respond_to?(name)
        then intern self.send(name)
        else Dest.new self, "on_#{name}".to_sym, opts  end
      raise ArgumentError, "unknown or invalid dest: '#{name}'" unless result.kind_of?(Dest)
      result
    end

    def trace(kind, level, method, chunk) 
      log_ = log     
      log_.send level, "TRACE #{id.to_s} :#{kind} :#{method} chunk: '#{chunk}'" if log_
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

    def mark_opts
      if @mark && !@mark.zero?
        if @opts[:mark]
          then @opts[:mark] = @opts[:mark].xor(mark)
          else @opts[:mark] = mark end
      end
    end

    def run(pool, scope, meth, chunk, &thunk)
      scope.enter
      begin
        if pool && pool.respond_to?(:process)
          then pool.process(&thunk)
          else thunk.call end
      rescue Exception => e
        handle_exception meth, chunk, e
        scope.leave if scope
      end
      self
    end

    def target_pool(pool_descr, meth)
      pool_descr = pool unless pool_descr
      case pool_descr
          when nil then :local
          when :local then :local
          when :spawn then SpawnPool.default_pool
          when :global then  PoolSupport.global_pool
          when :default then PoolSupport.new_default_pool
          when :single then PoolSupport.new_single_pool
          when :fifo then PoolSupport.new_fifo_pool 
          else 
             if pool_descr.respond_to(:process_base) 
              then pool_descr.process_base(meth) 
              else pool_descr end
      end
    end

    def handle_exception(meth, chunk, e)
      if log
        trace = ''
        e.backtrace.each { |s| trace << "\n    #{s}" }
        log.error "Caught '#{e}' when processing chunk: '#{chunk}' via meth: '#{meth}' with backtrace: '#{trace}'"
      end
    end

    public

    def >>(dest) ; self.emit = dest.entry end

    def drop ; self.emit = nil end

    def entry ; dest(:enter) end
    alias_method :exit, :emit

    def <<(chunk, opts = {}) ; entry.<< chunk, opts end
    def submit(chunk, opts = {}) ; entry.submit chunk, opts end
    def submit_now(chunk, opts = {}) ; entry.submit_now chunk, opts end
    def submit_to(target_pool, chunk, opts = {}) ; entry.submit_to target_pool, chunk, opts end
  end
end

