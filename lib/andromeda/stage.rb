# TODO
#  - Write tests
#  - Write docs, add yard support for documenting stages, attrs, etc.
#  - Make nice slideshow and become very famous and rich. yay!
module Andromeda

  class ProtoStage    

    extend ClassAttr

    def self.destination_names(inherit = true)
      get_attr_set '@destination_names', inherit 
    end

    def self.name_dest(*names)
      name_attr_set '@destination_names', *names
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

    def self.signal_names(inherit = true)
      get_attr_set '@signal_names', inherit 
    end

    def self.signal_dest(*names)
      name_attr_set '@signal_names', *names
    end

    attr_reader   :id
    attr_accessor :pool

    def initialize(config = {})
      @id     = Id.gen
      set_from_config init_from_config, config
      @pool ||= init_pool_config
      @opts ||= {}
      @pool ||= :local
    end

    def initialize_copy(other)
      @opts = @opts.clone
    end

    def init_from_config ; [:readers, :writers] end
    def init_pool_config ; :local end

    def opts ; @opts end
    def ident ; id.to_s true end

    def pool=(pool_descr)
      @pool = make_pool pool_descr
    end

    def map_chunk(name, chunk) ; chunk end
    def chunk_key(name, chunk) ; name end
    def chunk_val(name, chunk) ; chunk end
    def set_opts!(name, chunk, key, val, opts) ; nil end
    def flt_input(name, chunk, key, val, opts) ; false end

    def handle_chunk(pool_descr, name, meth, chunk, opts_in)
      c = map_chunk name, chunk
      k = chunk_key name, c
      v = chunk_val name, c
      p = target_pool pool_descr, k
      f = should_clone? p, k
      t = if f then clone else self end
      set_opts! name, c, k, v, opts_in
      t.opts.tap do |o|
        o.update opts_in
        o[:scope] ||= Scope.new
        o[:name]    = name
        t.submit_chunk p, meth, f, k, v, o unless flt_input(name, c, k, v, o)
        return o
      end
    end

    def dest(name)
      if self.respond_to?(name)
        result = self.send(name)
        raise ArgumentError, "Invalid dest: '#{name}'" unless result.kind_of?(Dest)
        intern result
      else
        nil
      end
    end

    def call_inline(dest, k, c)
      raise ArgumenError, "Invalid destination" unless dest.kind_of?(Dest)
      raise ArgumenError, "Cannot call_inline for other base" unless dest.base == self
      send_chunk dest.name, dest.meth, k, c    
    end

    def dest_name?(name) ; destination_names.include? name end
    def signal_name?(name) ; signal_names.include? name end

    def destination_names ; self.class.destination_names end    
    def signal_names ; self.class.signal_names end

    def current_scope ;  opts[:scope] end
    def current_name ;  opts[:name] end

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

    def intern(dest) ; if dest then dest.intern(self) else nil end end

    def signal_error(e) ; raise e end

    def make_pool(p) ; PoolSupport.make_pool p end

    def should_clone?(pool, k)
      return true if pool == :local
      return true if (begin pool.respond_to?(:max) && pool.max > 1 rescue false end)
      false
    end

    def target_pool(pool_descr, key)
      p = if pool_descr then pool_descr else pool end
      p = :local unless p
      p = make_pool p
      p = p.key_pool(key) if p.respond_to?(:key_pool)
      p
    end

  end

  class Stage < ProtoStage

    meth_dest :enter
    attr_dest :errors
    attr_dest :emit

    signal_dest :errors

    attr_accessor :log
    attr_accessor :mark
    attr_accessor :nick

    attr_accessor :error_level

    attr_accessor :trace_enter
    attr_accessor :trace_pool
    attr_accessor :trace_opts
    attr_accessor :trace_exit


    def initialize(config = {})
      super config
      @trace_enter ||= init_trace_hash :enter
      @trace_pool  ||= init_trace_hash :pool
      @trace_opts  ||= init_trace_hash :opts
      @trace_exit  ||= init_trace_hash :emit
      @error_level ||= :error
    end

    def initialize_copy(other)
      super other
      @trace_enter = @trace_enter.clone unless @trace_enter.is_a?(Symbol)
      @trace_pool  = @trace_pool.clone unless @trace_pool.is_a?(Symbol)
      @trace_opts  = @trace_opts.clone unless @trace_opts.is_a?(Symbol)
      @trace_exit  = @trace_exit.clone unless @trace_exit.is_a?(Symbol)
    end

    def tap ; yield self end

    def log ; @log = Logger.new(STDERR) unless @log ; @log end
    def mark ; @mark = Id.zero unless @mark ; @mark end

    def on_enter(k, c) ; emit << c rescue nil end

    def ident
      id_str = super
      if nick
        then "#{self.class}(#{id_str}, nick: #{nick})" 
        else "#{self.class}(#{id_str})" end
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
          opts_trace :enter, opts_level, name, meth, k, chunk if opts_level
          pool_trace pool_level, name, meth, k, chunk, p if pool_level
          meth_trace :enter, enter_level, name, meth, k, chunk if enter_level
          send_chunk name, meth, k, chunk
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

    protected

    def init_trace_hash(kind) ; {} end

    def signal_error(e)      
      if (d = errors)
        then d << e
        else super e end
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
      log_.send level, "METH:#{kind} #{ident}.#{name}, method: #{method}, key:, #{k}, chunk: #{chunk}" if log_
    end

    def pool_trace(level, name, method, k, chunk, p)
      log_ = log
      log_.send level, "POOL #{ident}.#{name}, method: #{method}, key: #{k}, chunk: #{chunk}, self_pool: #{self.pool}, pool: #{p}" if log_
    end

    def opts_trace(kind, level, name, method, k, chunk)
      log_ = log
      log_.send level, "OPTS:#{kind} #{ident}.#{name}, method: #{method}, key: #{k}, chunk: #{chunk}, opts: #{opts}" if log_
    end

    def send_chunk(name, meth, k, chunk)
      mark_txn
      self.send meth, k, chunk
    end

    def reset_txn(new_txn) ; opts[:txn] = if new_txn then new_txn else Id.zero end end
    def txn ; opts[:txn] end

    def check_txn
      txn_ = current_txn
      raise RuntimeError, 'Invalid mark' if txn_ && !txn_.zero?
    end

    def mark_txn
      mark_= mark
      if mark_ && !mark_.zero?
        txn_ = txn
        if txn_
          then reset_txn txn_.xor(mark_)
          else reset_txn mark_ end
      end
    end

    def handle_exception(name, meth, k, chunk, e)
      if log
        trace   = ''
        e.backtrace.each { |s| trace << "\n    #{s}" }
        err_str = "#{ident} caught '#{e}' when processing :#{name}, method: #{meth}, key: #{k}, chunk: #{chunk}, backtrace: #{trace}"
        begin          
          log.send error_level, err_str 
        rescue Exception => e2
          log.error("Caught '#{e2}' during logging! Originally #{err_str}") rescue nil
        end
      end
    end

  end

end