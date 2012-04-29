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
  class Spot

    # @return [Plan] Plan on which this spot has been placed
    attr_reader :plan

    # @return [Symbol] Name of spot on plan
    attr_reader :name

    # @return [Plan, nil] Plan of calling Spot if any, nil otherwise
    attr_reader :here

    # @param [Plan] plan Plan on which this spot has been placed
    # @param [Symbol] name Name of spot on plan
    # @param [Plan, nil] here Plan of calling Spot if any, nil otherwise
    def initialize(plan, name, here)
      raise ArgumentError, "#{plan} is not a Plan" unless plan.is_a? Plan
      raise ArgumentError, "#{name} is not a Symbol" unless name.is_a? Symbol
      if !here || here.is_a?(Plan)
        @plan = plan
        @name = name
        @here = here
      else
        raise ArgumentError, "#{here} is neither nil nor a Plan"
      end
    end

    def cloneable? ; true end
    def clone_to_copy? ; false end
    def identical_copy ; self end

    def ==(other)
      return true if self.equal? other
      return false unless other.class.equal? Spot
      return name.eq(other.name) && plan.eq(other.plan) && here.eq(other.here)
    end

    def hash ; plan.hash ^ name.hash ^ here.hash end

    alias_method :<<, :send

    def send(data, tags_in = {}) ; send_to nil, data, tags_in end
    def send_local(data, tags_in = {}) ; send_to LocalTrack.instance, data, tags_in end

    def send_to(track, data, tags_in = {})
      tags_in = (here.tags.identical_copy.update(tags_in) rescue tags_in) if here
      plan.send_data name, track, data, tags_in
      self
    end


    def start ; entry.intern(nil) end
    def entry ; self end
    def exit ; plan.exit end

    def intern(new_calling_plan)
      if here.equal? new_calling_plan
        then self
        else Spot.new plan, name, new_calling_plan end
    end
  end

end