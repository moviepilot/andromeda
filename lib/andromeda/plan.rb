
module Andromeda

  class ProtoPlan
    include Impl::To_S
    extend ClassAttr

    def self.spot_names(inherit = true) ; get_attr_set '@spot_names', inherit  end
    def self.name_spot(*names) ; name_attr_set '@spot_names', *names end

    def self.meth_spot(*names)
      name_spot *names
      names.each do |name|
        define_method :"#{name}" do ||
          mk_spot name
        end
      end
    end

    def self.attr_spot(*names)
      name_spot *names
      attr_writer *names
      names.each do |name|
        define_method :"#{name}" do ||
          intern (instance_variable_get("@#{name}"))
        end
      end
    end

    def self.signal_names(inherit = true) ; get_attr_set '@signal_names', inherit end
    def self.signal_spot(*names) ; name_attr_set '@signal_names', *names end

    attr_reader   :id
    attr_reader   :guide

    def initialize(config = {})
      @id      = Id.new
      set_from_config init_from_config, config
      @tags  ||= {}
      @guide ||= init_guide
    end

    def initialize_copy(other)
      @tags    = @tags.identical_copy
      @tags  ||= {}
    end

    def init_guide ; Guides::DefaultGuide.instance end

    def tags ; @tags end
    def to_short_s ; " id=#{id.to_short_s}t" end
    alias_method :inspect, :to_s

    def guide=(new_guide)
      new_guide = new_guide.instance if new_guide.is_ar?(Class) && new_guide.include?(Singleton)
      @guide    = new_guide
    end

    def data_map(name, data) ; data end
    def data_key(name, data) ; name end
    def key_spot(name, key) ; name end
    def key_label(name, key) ; key end
    def data_val(name, data) ; data end
    def data_tag(name, key, val, tags_in) ; { name: name } end
    def selects?(name, key, val, tags_in) ; true end

    def post_data(name, track_in, data, tags_in = {})
      details        = { name: name, data: data, tags_in: tags_in }
      begin
        data   = data_map name, data
        key    = data_key name, data
        name   = key_spot name, key

        spot_  = spot name
        details[:spot] = spot_
        raise ArgumentError, "#{name} could not be resolved to a Spot" unless spot_

        guide_ = guide
        label  = key_label name, key
        details[:label] = label
        track_ = guide_.track spot_, label, track_in
        details[:track] = track_

        value  = data_val name, data
        details[:val] = value
        tags_in.update data_tag name, key, value, tags_in
        tags_in.update guide_.provision track_, label, tags_in

        pack_  = guide_.pack self, track_, track_.equal?(track_in)
        details[:pack] = pack_
        meth   = pack_.method :"on_#{name}"

        if selects? name, key, value, tags_in
          pack_.transport_data name, track_, meth, key, value, tags_in
        end
      rescue Exception => e
        raise SendError, InfoMsg.str('send_data failed', details, e), e.backtrace
      end
    end

    def spot(name)
      raise ArgumentError, "#{name} is not a Symbol" unless name.is_a? Symbol
      raise ArgumentError, "#{name} is not a known spot name" unless spot_name? name

      if respond_to?(name)
        then intern method(name).call()
        else nil
      end
    end

    def call_local(spot_name, k, v)
      spot_ = spot spot_name
      raise ArgumentError, "#{name} could not be resolved to a Spot" unless spot_
      raise ArgumenError, "Cannot call_inline for other Plans" unless spot_.plan == self
      method(:"on_#{spot_name}").call k, v
    end

    def spot_name?(name) ; spot_names.include? name end
    def signal_name?(name) ; signal_names.include? name end

    def spot_names ; self.class.spot_names end
    def signal_names ; self.class.signal_names end

    def current_scope ;  tags[:scope] end
    def current_name ;  tags[:name] end

    def >>(spot)
      if spot.is_a?(Spot)
        self.emit = spot
        return spot.plan
      end
      if spot.is_a?(Plan)
        self.emit = spot.entry
        return spot
      end
      raise ArgumentError, "Argument is neither a Spot nor a Plan"
    end

    # Maybe cache this

    def start ; entry.intern(nil) end
    def entry ; enter end
    def mute ; emit = nil end

    def <<(data, tags_in = {}) ; start.<< data, tags_in end
    def post(data, tags_in = {}) ; start.send data, tags_in end
    def post_to(track, data, tags_in = {}) ; start.send_to track, data, tags_in end

    protected

    attr_spot :emit

    def exit ; emit end

    def init_from_config ; [:readers, :writers] end

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

    def intern(spot)
      return nil unless spot
      raise ArgumentError unless spot.is_a? Spot
      spot.intern(self)
    end

    def signal_error(e) ; raise e end
  end

  class Plan < ProtoPlan

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
      @trace_enter = @trace_enter.identical_copy
      @trace_exit  = @trace_exit.identical_copy
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

    protected

    def init_trace_hash(kind) ; {} end

    def trace_level(h, name) ; if h.is_a?(Symbol) then h else (h[name] rescue nil) end end

    def trace(kind, level, name, details)
      log.send level, InfoMsg.str("TRACE :#{kind} :#{name}", details) if log
    end

    def mk_spot(name) ; Spot.new self, name, self end

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
      log.send error_level,e
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