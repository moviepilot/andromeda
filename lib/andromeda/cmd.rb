module Andromeda

  module Cmd

    class Cmd
      attr_reader :cmd
      attr_reader :data
      attr_reader :time

      def initialize(cmd, data = {}, cmd_time = nil)
        raise ArgumentError unless cmd.kind_of?(Symbol)
        @cmd     = cmd
        @data    = data
        @time    = if cmd_time then cmd_time else Time.now.to_i end
        @comment = nil
      end

      def comment ; @comment || ''  end
      def comment=(str = nil) ; @comment = str end

      def if_cmd(sym) ; if sym == cmd then yield data else seld end end

      def as_json
        h = { cmd: cmd, data: (data.as_json rescue data), time: time }
        c = @comment
        h[:comment] = c if c
        h
      end

      def to_s ; as_json.to_json end

      def with_comment(str = nil)
        @comment = str
        self
      end

      def self.new_input(cmd, data = {}, cmd_time = nil)
        inner = Cmd.new cmd, data, cmd_time
        Cmd.new :input, inner, cmd_time
      end

      def self.from_json(json)
        Cmd.new json['cmd'].to_sym, json['data'], (json['time'] rescue nil)
      end
    end

    class FileCmdPlan < Kit::InlineKeyRouter
      attr_reader :path
      attr_reader :mode
      attr_reader :file

      spot_meth :open
      spot_meth :sync
      spot_meth :close
      spot_meth :input

      signal_spot :open
      signal_spot :close
      signal_spot :sync

      def data_map(name, data)
        if data.is_a?(Cmd) then data else Cmd.new(data) end
      end

      def data_key(name, data) ; data.cmd  end
      def data_val(name, data) ; data.data end

      def data_tag(name, key, val, tags_in)
        tags_out = super
        if name == :input
          tags_out[:time]    = val.time
          tags_out[:comment] = val.comment
        end
        tags_out
      end

      def on_open(key, val)
        if @file
          signal_error ArgumentError.new("associated file already open")
        else
          @path   = val[:path] if val[:path]
          @mode   = val[:mode] if val[:mode]
          @mode ||= init_mode
          @file = File.open @path, @mode
        end
      end

      def on_input(key, val)
        exit << val if exit
      end

      def on_sync(key, val)
        f = @file ; sync_file f if f
      end

      def on_close(key, val)
        if @file
          begin
            close_file(@file)
          ensure
            @file = nil
          end
        else
          signal_error ArgumentError.new("associated file not open")
        end
      end

      protected

      def close_file(f)
        begin
          sync_file f
        ensure
          f.close
        end
      end

      def sync_file(f) ; end
    end

    class Writer < FileCmdPlan

      def init_mode ; 'w' end

      def on_input(key, val)
        signal_error ArgumentError.new("associated filed not open") unless file
        cmd  = val.cmd
        raise ArgumentError, "invalid cmd" unless cmd.kind_of?(Symbol)
        data = val.data
        str  = if data then data.to_json else '' end
        len  = str.length + 1
        tim  = val.time if val.time
        tim  = Time.now unless tim
        tim  = tim.to_i unless tim.kind_of?(Fixnum)
        new_str = ''
        str.each_line { |line| new_str << "... #{line}\n" }
        str  = nil
        len  = new_str.length
        val  = tags[:comment]
        val.each_line { |line| file.write "\# #{line}\n" } if val
        file.write "<<< ANDROMEDA START :#{cmd} TIME #{tim} LEN #{len} >>>\n"
        file.write new_str
        file.write "<<< ANDROMEDA END :#{cmd} >>>\n"
        super key, val
      end

      protected

      def sync_file(f)
        f.sync
        f.fsync rescue nil
      end
    end

    class Reader < Kit::FileReader
      attr_reader :start_matcher, :end_matcher, :comment_matcher, :line_matcher

      def initialize(config = {})
        super config
        @start_matcher   = /<<< ANDROMEDA START :(\w+) TIME (\d+) LEN (\d+) >>>/
        @end_matcher     = /<<< ANDROMEDA END :(\w+) >>>/
        @comment_matcher = /#(.*)/
        # remember to change the offset for :line, too whenever you change this
        @line_matcher    = /... (.*)/
      end

      def match_line(state, line)
        m = @start_matcher.match line
        return yield :start, state, ({ cmd: m[1].to_sym, tim: m[2].to_i, len: m[3].to_i }) if m
        m = @end_matcher.match line
        return yield :end, state, m[1].to_sym if m
        m = @comment_matcher.match line
        return yield :comment, state, m[1] if m
        m = @line_matcher.match line
        return yield :line, state, m[1] if m
        yield :garbage, state, line
      end

      def on_enter(key, val)
        super key, val do |file|
          fst = tags[:first]
          lst = tags[:last]

          state = { :comment => true, :start => true, :cont => true }
          while (line = file.gets) && state[:cont]
            line = line.chomp
            match_line(state, line) do |token, state, parts|
              signal_error ArgumentError.new("Skipping unexpected token #{token} in line '#{line}' (state: #{state})") unless state[token]
              case token
              when :comment
                if state[:comment_str]
                  then state[:comment_str] << parts
                  else state[:comment_str]  = parts end
              when :start
                state.delete :comment
                state.delete :start
                state[:line]    = true
                state[:end]     = true
                parts[:data]    = ''
                state[:len]     = 0
                state[:cur]     = parts
                parts[:comment] = state[:comment_str]
                state.delete :comment_str
              when :line
                state[:len] += parts.length + 5
                state[:cur][:data] << "#{parts}\n"
              when :end
                state.delete :line
                state.delete :end
                state[:start]   = true
                state[:comment] = true
                cur             = state[:cur]
                data            = cur[:data]
                signal_error ArgumentError.new("Start (#{cur[:cmd]}) and end (#{parts})cmd mismatch") unless cur[:cmd] == parts
                signal_error ArgumentError.new("Length mismatch (expected: #{cur[:len]}, found: #{state[:len]})") unless cur[:len] == state[:len]
                exit << cur if exit
                state[:cont] = false unless file.pos <= lst
              else
                signal_error ArgumentError.new("Garbage encountered (line: '#{line}')")
                return
              end
            end
          end
        end
      end

    end

    class Parser < Plan

      def on_enter(key, val)
        data = val[:data].chomp
        data = JSON::parse(data)
        cmd  = Cmd.new val[:cmd], data, val[:time]
        rem  = val[:comment] rescue nil
        cmd.with_comment rem if rem
        exit << cmd if cmd
      end
    end

  end
end