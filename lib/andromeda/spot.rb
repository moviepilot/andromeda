module Andromeda

  # A spot is a reachable destination to which data may be sent for processing.
  # It encapsulates addressing the processing logic of a Plan into a separate,
  # immutable Object that may be passed around freely.
  #
  # It is somewhat similiar/a mixture of notions such as actor address,
  # RPC endpoint, and stack frame in other frameworks
  #
  # You MUST not inherit from this class
  #
  class Spot < Impl::ConnectorBase
    include Impl::To_S

    # @return [Plan] Plan to which this spot will deliver data events
    attr_reader :plan

    # @return [Symbol] Name of spot attribute in plan that corresponds to this spot
    attr_reader :name

    # @return [Plan, nil] Plan of calling spot if any, nil otherwise
    attr_reader :here

    # @return [Symbol, nil] Spot's destination name, or nil for plan.dest, returned by >>
    def dest_name ; @dest end

    # @param [Plan] plan Plan to which this spot will deliver data events
    # @param [Symbol] name Name of spot attribute in plan that corresponds to this spot
    # @param [Plan, nil] here Plan of calling Spot if any, nil otherwise
    # @param [Symbol, nil] dest destination name use to obtain return value for >>
    def initialize(plan, name, here, dest = nil)
      raise ArgumentError, "#{plan} is not a Plan" unless plan.is_a? Plan
      raise ArgumentError, "#{name} is not a Symbol" unless name.is_a? Symbol
      unless plan.meth_spot_name?(name)
        raise ArgumentError, "#{name} is not a known method spot name of #{plan}"
      end
      unless dest.nil? || dest.is_a?(Symbol)
        raise ArgumentError, "#{dest} is neither nil nor a Symbol"
      end
      if !here || here.is_a?(Plan)
        @plan = plan
        @name = name
        @here = here
        @dest = dest
      else
        raise ArgumentError, "#{here} is neither nil nor a Plan"
      end
    end

    def cloneable? ; true end
    def clone_to_copy? ; false end
    def identical_copy ; self end

    # Spots compare attribute-wise and do not accept subclasses
    #
    # @retrun [TrueClass, FalseClass] self == other
    def ==(other)
      return true if self.equal? other
      return false unless other.class.equal? Spot
      name.eq(other.name) && plan.eq(other.plan) && here.eq(other.here) && dest.eq(other.dest)
    end

    def hash ; plan.hash ^ name.hash ^ here.hash ^ dest.hash end

    def to_short_s
      dest_ = dest_name
      dest_ = if dest_ then " dest=:#{dest_name}" else '' end
      here_ = here
      if here_
        then " plan=#{plan} name=:#{name} here=#{here_}#{dest_}"
        else " plan=#{plan} name=:#{name}#{dest_}" end
    end
    alias_method :inspect, :to_s

    # Post data with the associated tags_in to this's spot's plan's method spot with name name
    # and hint that the caller requested the spot activation to be executed on track tack
    #
    # @param [Track] track requested target track
    # @param [Any] data any data event
    # @param [Hash] tags to be passed along
    #
    # @return [self]
    def post_to(track, data, tags_in = {})
      tags_in = (here.tags.identical_copy.update(tags_in) rescue tags_in) if here
      plan.post_data self, track, data, tags_in
      self
    end

    # @return [Spot] a fresh copy of self for which dest_name == spot_name holds
    def via(spot_name)
      raise ArgumentError unless spot_name.nil? || spot_name.is_a?(Symbol)
      Spot.new plan, name, here, spot_name
    end

    # Call the spot method associated with this spot with the provided key and val
    #
    # Precondition is that here == plan, i.e. the caller already executes in the scope
    # of this spot's plan
    #
    # @return [Any] plan.call_local name, key, val
    def call_local(key, val)
      plan.call_local name, key, val
    end

    # @return [self] for compatibility with plan's API
    def entry ; self end

    # @return [Spot] plan.public_spot(dest_name) if that exists, plan.dest otherwise
    def dest
      if dest_name
        then plan.public_spot(dest_name)
        else plan.dest end
    end

    def >>(target)
      return (plan >> target) unless dest_name
      unless plan.attr_spot_name?(dest_name)
        raise ArgumentError, "#{dest_name} is not an attr_spot_name"
      end
      plan.send :"#{dest_name}=", target.entry
      plan.public_spot(dest_name)
    end

    # @return [Spot] this spot or a modified copy of it such that here == new_calling_plan holds
    def intern(new_calling_plan)
      if here.equal? new_calling_plan
        then self
        else Spot.new plan, name, new_calling_plan, dest_name end
    end
  end

end