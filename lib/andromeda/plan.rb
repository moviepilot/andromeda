module Andromeda

  class Plan < Impl::ProtoPlan

    meth_spot :enter
    attr_spot :errors

    signal_spot :errors

    attr_accessor :log
    attr_accessor :marker
    attr_accessor :nick

    attr_accessor :error_level

    attr_accessor :trace_enter
    attr_accessor :trace_exit


    def initialize(config = {})
      super config
      @trace_enter ||= init_trace_hash :enter
      @trace_exit  ||= init_trace_hash :emit
      @error_level ||= :error
    end

    def initialize_copy(other)
      super other
      @trace_enter = other.trace_enter.identical_copy
      @trace_exit  = other.trace_exit.identical_copy
      @error_level = other.error_level.identical_copy
      @nick        = other.nick.identical_copy
    end

    def tap ; yield self end

    def log ; @log = DefaultLogger.instance end
    def mark ; @mark = Id.zero unless @mark ; @mark end

    def on_enter(k, v)
      exit_ = exit
      exit_ << v if exit_
    end

    def to_short_s
      super_ = super()
      nick_  = nick
      if nick_
        then "#{super_} aka: #{Impl::To_S.short_s(nick_)}"
        else super_ end
    end

    protected

    def transport_data name, track, meth, key, val, tags_in
      scope       = tags_in[:scope]
      enter_level = trace_level trace_enter, name
      exit_level  = trace_level trace_exit, name
      details     = { name: name, plan: self, track: track, key: key, val: val }
      track.follow(scope) do
        begin
          trace :enter, enter_level, name, details if enter_level
          deliver_data name, meth, key, val, tags_in
          trace :exit, exit_level, name, details if exit_level
        rescue Exception => e
          uncaught_exception name, key, val, e
        end
      end
    end

    def init_trace_hash(kind) ; {} end

    def trace_level(h, name) ; if h.is_a?(Symbol) then h else (h[name] rescue nil) end end

    def trace(kind, level, name, details)
      log.send level, InfoMsg.str("TRACE :#{kind} :#{name}", details) if log
    end

    def deliver_data(name, meth, k, v, tags_in)
      update_mark
      tags.update tags_in
      meth.call k, v
    end

    def signal_error(e)
      errors_ = errors
      errors_ << e if errors_
    end

    def signal_uncaught(e)
      log.send error_level, e rescue nil
      signal_error e
    end

    def reset_mark(new_mark)
      tags[:mark] = if new_mark then new_mark else Id.zero end
    end

    def mark ; tags[:mark] end

    def check_mark
      mark_ = mark
      raise RuntimeError, 'Invalid mark' if mark_ && !mark_.zero?
    end

    def update_mark
      marker_ = marker
      if marker_ && !marker_.zero?
        mark_ = mark
        if mark_
          then reset_mark mark_.xor(marker_)
          else reset_mark mark_ end
      end
    end

    def uncaught_exception(name, key, value, e)
      begin
        details = { name: name, key: key, val: value, cause: e }
        info    = InfoMsg.str 'Uncaught exception', details
        err     = ExecError.new(info)
        err.set_backtrace e.backtrace
        signal_uncaught e
      rescue Exception => e2
        details[:cause] = e2
        log.error InfoMsg.str('Failure handling uncaught exception', details) rescue nil
      end
    end
  end

end