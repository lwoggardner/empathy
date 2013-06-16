
warn "empathy/object: Monkey patching Object#sleep and Object#at_exit for EventMachine reactor awareness"

# Monkey patch object to make EM safe
class Object

  # use {Empathy::EM::Kernel.sleep} if we are in the reactor, Kernel.sleep otherwise
  def sleep(*args)
    kernel = Empathy.event_machine? ? Empathy::EM::Kernel : Kernel
    kernel.sleep(*args)
  end

  # use {Empathy::EM::Kernel.at_exit} if we are in the reactor, Kernel.sleep otherwise
  def at_exit(&block)
    kernel = Empathy.event_machine? ? Empathy::EM::Kernel : Kernel
    kernel.at_exit(&block)
  end
end

