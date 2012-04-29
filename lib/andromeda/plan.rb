module Andromeda

  module Proto

    class Plan

      extend ClassAttr

      def self.spot_names(inherit = true) ; get_attr_set '@spot_names', inherit  end
      def self.name_spot(*names) ; name_attr_set '@spot_names', *names end

      def self.meth_spot(*names)
        name_spot *names
        names.each do |name|
          define_method :"#{name}" do ||
            intern (Spot.new self, :"#{name}", :"#{name}", self)
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
      attr_accessor :guide

      def initialize(config = {})
        @id      = Id.new
        set_from_config init_from_config, config
        @tags  ||= {}
        @guide ||= Guides::LocalGuide.instance
      end

      def initialize_copy(other)
        @tags    = @tags.copy
        @tags  ||= {}
      end

      def tags ; @tags end
      def ident ; id.to_s true end

      def map_data(name, data) ; data end
      def data_key(name, data) ; name end
      def data_val(name, data) ; data end
      def keylabel(name, key) ; key end
      def data_tag(name, key, val, tags_in) ; { name: name } end
      def selects?(name, key, val, tags_in) ; true end

      def send_data(name, track_in, data, tags_in = {})
        begin
          spot   = spot name
          raise ArgumentError, "#{name} could not be resolved to a Spot" unless spot

          data   = map_data name, data
          key    = data_key name, data

          guide_ = guide
          label  = keylabel name, key
          track_ = guide_.track spot, label, track_in

          value  = data_val name, data
          tags_in.update data_tag name, key, value, tags_in
          tags_in.update guide_.provision track_, tags_in

          pack_  = guide_.pack _track, track_.equal?(track_in)
          meth   = pack_.method name

          if selects? name, track_, key, value,
            pack_.transport_data track_, meth, key, value, tags_in
          end
        rescue Exception => e
          details = { spot: spot, track: track, data: data, tags_in: tags_in, cause: e }
          raise SendError, InfoMsg.str('send_data failed', details), e
        end
      end

      def spot(name)
        raise ArgumentError, "#{name} is not a Symbol" unless name.is_a? Symbol
        raise ArgumentError, "#{name} is not a known spot name" unless spot_name? name

        if self.respond_to?(name)
          then intern self.send(name)
          else nil
        end
      end

      def call_inline(spot, k, v)
        spot = intern spot
        raise ArgumentError, "#{name} could not be resolved to a Spot" unless spot
        raise ArgumenError, "Cannot call_inline for other Plans" unless spot.plan == self
        # TODO
      end

      def spot_name?(name) ; spot_names.include? name end
      def signal_name?(name) ; signal_names.include? name end

      def spot_names ; self.class.spot_names end
      def signal_names ; self.class.signal_names end

      def current_scope ;  tags[:scope] end
      def current_name ;  tags[:name] end

      def >>(spot)
        if spot.is_a?(spot)
          self.emit = spot
          spot.plan
        else
          self.emit = spot.entry
          spot
        end
      end

      def start ; entry.intern(nil) end
      def entry ; enter end
      def mute ; emit = nil end

      def <<(data, tags_in = {}) ; start.<< data, tags_in end
      def send(data, tags_in = {}) ; start.send data, tags_in end
      def send_to(track, data, tags_in = {}) ; start.send_to track, data, tags_in end

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

  end

  class Plan < Proto::Plan

    meth_spot :enter
    attr_spot :errors

    signal_spot :errors

    attr_accessor :log
    attr_accessor :mark
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

    def enter(k, v) ; exit << v end

    def ident
      id_str = super
      nick_  = nick
      if nick_
        then "#{self.class}(#{id_str}, nick: #{nick_})"
        else "#{self.class}(#{id_str})" end
    end

    def transport_data track, meth, key, value, tags_in
      scope       = tags_in[:scope]
      name        = tags_in[:name]
      enter_level = trace_level trace_enter, name
      exit_level  = trace_level trace_exit, name
      details     = { plan: self, track: track, key: key, val: value, tags: tags_in }
      track.follow do
        begin
          scope.enter
          trace :enter, enter_level, name, details if enter_level
          send_chunk name, meth, k, chunk
          trace :exit, exit_level, name, details if exit_level
        rescue Exception => e

        ensure
          # TODO cleanup tags ?
          tags_trace :exit, tags_level, name, meth, k, chunk if tags_level
          scope.leave if scope
        end
      end
    end

    protected

    def init_trace_hash(kind) ; {} end

    def signal_error(e) ; if (d = errors) then d << e else super e end end

    def trace_level(h, name)
      if h.kind_of?(Symbol) then h else (h[name] rescue nil) end
    end

    def trace(kind, level, name, details)
      log.send level, InfoMsg.str("TRACE :#{kind} :#{name}", details)
    end

    # TODO Marking

    # def reset_txn(new_txn) ; tags[:txn] = if new_txn then new_txn else Id.zero end end
    # def txn ; tags[:txn] end

    # def check_txn
    #   txn_ = current_txn
    #   raise RuntimeError, 'Invalid mark' if txn_ && !txn_.zero?
    # end

    # def mark_txn
    #   mark_= mark
    #   if mark_ && !mark_.zero?
    #     txn_ = txn
    #     if txn_
    #       then reset_txn txn_.xor(mark_)
    #       else reset_txn mark_ end
    #   end
    # end

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