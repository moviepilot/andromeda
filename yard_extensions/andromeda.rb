require 'yard'

class MethSpotHandler < YARD::Handlers::Ruby::AttributeHandler
  handles method_call(:meth_spot)
  namespace_only

  def process
    push_state(:scope => :class) { super }
  end
end

class AttrSpotHandler < YARD::Handlers::Ruby::AttributeHandler
  handles method_call(:attr_spot)
  namespace_only

  def process
    push_state(:scope => :class) { super }
  end
end

class SignalSpotHandler < YARD::Handlers::Ruby::AttributeHandler
  handles method_call(:signal_spot)
  namespace_only

  def process
    push_state(:scope => :class) { super }
  end
end