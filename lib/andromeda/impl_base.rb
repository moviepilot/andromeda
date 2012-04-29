module Andromeda

  module Impl

    module To_S

      def to_s(short = false)
        if short
          to_short_s
        else
          super_str  = super()
          short_name = self.class.name.split('::')[-1]
          obj_id     = object_id.to_s(16)
          "\#<#{short_name}:0x#{obj_id}#{to_s(true)}>"
        end
      end

      def to_short_s ; '' end

      def self.short_s(v = value)
        return ":#{v}" if v.is_a?(Symbol)
        return "'#{v}'" if v.is_a?(String)
        return 'nil' unless v
        "#{v}"
      end

    end
  end
end
