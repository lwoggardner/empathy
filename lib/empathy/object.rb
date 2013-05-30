
warn "empathy/object: Monkey patching Object#sleep and Object@at_exit for EM::reactor awareness"

# Monkey patch object to make EM safe
class Object

  # use EM safe sleep if we are in the reactor
  def sleep(*args)
    kernel = Empathy.event_machine? ? Empathy::EM::Kernel : Kernel
    kernel.sleep(*args)
  end

  # run exit blocks created in the reactor as reactor shutdown hooks
  def at_exit(&block)
    kernel = Empathy.event_machine? ? Empathy::EM::Kernel : Kernel
    kernel.at_exit(&block)
  end
end

