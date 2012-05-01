module Andromeda

  module Impl

    module To_S

      def to_s(short = false)
        if short
          to_short_s
        else
          super_str  = super()
          class_name = self.class.name.split('::')[-1]
          obj_id     = object_id.to_s(16)
          "\#<#{class_name}:0x#{obj_id}#{to_s(true)}>"
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

    # Shared base class of Spot and Impl::PrePlan
    class ConnectorBase
      # @return [Spot] entry.intern nil
      def start ; entry.intern(nil) end

      # post_to nil, data, tags_in
      #
      # @return [self]
      def post(data, tags_in = {}) ; post_to nil, data, tags_in end

      alias_method :<<, :post

      # post_to LocalTrack.instance, data, tags_in
      #
      # @return [self]
      def post_local(data, tags_in = {}) ; post_to Guides::LocalTrack.instance, data, tags_in end
    end

  end
end
