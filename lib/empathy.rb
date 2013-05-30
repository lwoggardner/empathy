require 'empathy/version'
require 'thread'
require 'fiber'

# This module provides a shim between using standard ruby Threads
# and the thread-like behaviour for Fibers provided by classes in
# the Empathy::EM module
#
#   # For the Empathy::EM classes to be available
#   # you must first load EventMachine
#   'require eventmachine'
#
#   'require empathy'
#
#   t = Empathy::Thread.new() do
#       begin
#       # "t" is a standard ::Thread
#       ...something...
#   end
#
#   EventMachine.run do
#      t = Empathy::Thread.new() do
#           # "t" is a ::Empathy::EM::Thread
#           # which wraps a ::Fiber
#      end
#   end
#
#   # Outside of event machine
#   t = Empathy::Thread.new() do
#       # "t" is a raw ::Thread
#   end
#
# Code using Empathy that may be used in both Fiber or Thread contexts
# should take care to rescue *Empathy::Errors which is shorthand for
# *[FiberError,ThreadError]
#
#   def maybe_em_method
#      # some code
#   rescue *Empathy::Errors
#
#   end
#
# {::Thread} methods not implemented by Empathy
#   * #exclusive - not implemented
#   * #critical - not implemented
#   * #set_trace_func - not implemented
#   * #safe_level - not implemented
#   * #priority - not implemented
module Empathy

  class ThreadError < StandardError
    def self.===(other)
      super || ::FiberError === other || ::ThreadError === other
    end
  end

  # Start EventMachine and run reactor block within a surrounding Empathy::EM::Thread (Fiber).
  # The reactor loop is terminated when the supplied block finishes
  def self.run
    reload()
    exception = nil
    value = nil
    EventMachine.run do
      EM::Thread.new do
        begin
          value = yield
        rescue Exception => ex
          exception = ex
        ensure
          EventMachine.stop
        end
      end
    end
    raise exception if exception
    value
  end

  def self.empathise(*modules)
    modules.each do |m|
      map_classes(m, self, "Thread","Queue","Mutex","ConditionVariable", "ThreadError")
    end
  end

  #@api private
  def self.map_classes(into,from,*class_names)
    # Make Object reactor aware
    require 'empathy/object'
    class_names.each do |cname|
      case cname
      when Hash
        cname.each { |cn,replace_class| replace_class_constant(into,cn,replace_class) }
      else
        replace_class_constant(into,cname,from.const_get(cname))
      end
    end
  end

  def self.replace_class_constant(into,cname,replace_class)
    if into != Object && into.const_defined?(cname,false)
       existing_const = into.const_get(cname)
       if !existing_const.is_a?(Module) || existing_const.name.start_with?(into.name)
         warn "mmpathy: Skipping replacement of #{into.name}::#{cname}"
         return nil
       end
    end

    warn "empathy: Defined fake class constant #{into}::#{cname} => #{replace_class.name}"
    into.const_set(cname,replace_class)
  end

  # Test whether we have real fibers or a thread based fiber implmentation
  t = Thread.current
  ft = nil
  Fiber.new { ft = Thread.current }.resume

  ROOT_FIBER = Fiber.current
  REAL_FIBERS = ( t == ft )

  # Specifically try to enable use of Eventmachine if it is now available
  def self.reload()
    @loaded ||= false
    if !@loaded && defined?(EventMachine)
      require 'empathy/em/thread.rb'
      require 'empathy/em/queue.rb'
      @loaded = true
    end
    return @loaded
  end

  # If EM already required then enable it, otherwise defer until first use
  reload()

  # Are we running in the EventMachine reactor thread
  #
  # For JRuby or other interpreters where fibers are implemented with threads
  # this will return true if the reactor is running and the code is called from
  # *any* fiber other than the root fiber
  def self.event_machine?
    @loaded ||= false
    @loaded && EventMachine.reactor_running? &&
      ( EventMachine.reactor_thread? || (!REAL_FIBERS && ROOT_FIBER != Fiber.current))
  end

  private
  def self.create_delegate_module(cname,*methods)
    mod = Module.new
    self.const_set(cname,mod)
    methods.each do |m|
      mod.define_singleton_method(m) do |*args,&block|
        parent = Empathy.event_machine? ? Empathy::EM : Object
        delegate = parent.const_get(cname)
        delegate.send(m,*args,&block)
      end
    end
  end

  create_delegate_module('Kernel',:sleep,:at_exit)
  create_delegate_module('Thread',:new, :list, :current, :stop, :pass, :main)
  create_delegate_module('Queue',:new)
  create_delegate_module('ConditionVariable',:new)
  create_delegate_module('Mutex',:new)
end
