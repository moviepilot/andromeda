module Andromeda

  class InfoMsg

    def self.str(msg = '', details = {}, cause_ = nil)
      details[:cause] = cause_ if cause_
      (InfoMsg.new msg, details).to_s
    end

    attr_reader :details
    attr_reader :cause
    attr_reader :msg

    def initialize(msg = '', details = {})
      @msg     = msg
      @details = details
      @cause   = details[:cause]
      details.delete :cause if @cause
    end

    def to_s
      out = msg.dup
      if details && details.length > 0
        if cause
          out << " (cause = #{cause}; details = \{"
        else
          out << ' (details = {'
        end
        details.each_pair { |k,v| out << " #{k}: #{v}" }
        out << ' })'
      else
        out << " (cause = #{cause})" if cause
      end
      out << '.'
      out
    end
  end

	class SendError < RuntimeError ; end
  class ExecError < RuntimeError ; end

end