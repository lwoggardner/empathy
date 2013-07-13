require 'empathy/version'
require 'thread'
require 'monitor'
require 'fiber'

# This module provides a shim between using standard ruby Threads
# and the thread-like behaviour for Fibers provided by classes in
# the {Empathy::EM} namespace.
#
#     # For the Empathy::EM classes to be available
#     # you must first load EventMachine
#     'require eventmachine'
#
#     'require empathy'
#
#     t = Empathy::Thread.new() do
#         # "t" is a standard ::Thread
#         # ...something...
#     end
#
#     EventMachine.run do
#        t = Empathy::Thread.new() do
#             # "t" is a ::Empathy::EM::Thread
#             # which wraps a ::Fiber
#        end
#     end
#
#     # Outside of event machine
#     t = Empathy::Thread.new() do
#         # "t" is a raw ::Thread
#     end
#
#     #Code using Empathy that may be used in both Fiber or Thread contexts
#     #should take care to rescue Empathy::ThreadError
#
#     def maybe_em_method
#        # ...
#     rescue Empathy::ThreadError
#        # ... will rescue either ::FiberError or ::ThreadError
#     end
#
module Empathy

  @empathised = self
  @empathic_classes = []

  #This is never thrown but can be used to rescue both ThreadError and FiberError
  class ThreadError < StandardError
    RUBY_ThreadError = ::ThreadError
    def self.===(other)
      super || ::FiberError === other || RUBY_ThreadError === other
    end
  end

  @empathic_classes << 'ThreadError'

  # Start EventMachine and run reactor block within a surrounding Empathy::EM::Thread (Fiber).
  # The reactor loop is terminated when the supplied block finishes
  # @return the value of the block
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

  # Create alias constants in each of the supplied modules so that code witin those modules
  # will use modules from the Empathy namespace instaad of the native ruby ones
  #
  # Also monkey patches {Object} to provide EM safe Kernel methods
  # @param [Array<Module>] modules
  # @return [void]
  def self.empathise(*modules)
    modules.each { |m| map_classes(m, self) }
  end

  # @private
  def self.map_classes(into,from)
    # Make Object reactor aware
    require 'empathy/object'
    @empathic_classes.each do |cname|
      case cname
      when Hash
        cname.each { |cn,replace_class| replace_class_constant(into,cn,replace_class) }
      else
        replace_class_constant(into,cname,from.const_get(cname))
      end
    end
    into.instance_variable_set(:@empathised,from)
  end

private
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
public
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
      require 'empathy/em/monitor.rb'
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

  # Create a module under the Empathy namespace that delegates class methods (potentially including #new)
  # to either the top level class, or to its equivalent under the {Empathy::EM} namespace
  # based on being in/out of the reactor
  #
  # Library authors can use this to define an eventmachine aware replacement class for their own purposes
  # @example
  #
  #   class MyBinding
  #     #...code that does not use event machine
  #   end
  #
  #   module Empathy
  #     module EM
  #       class MyBinding
  #         # ... code that uses event machine ...
  #       end
  #     end
  #
  #     create_delegate_module('MyBinding',:new, :my_class_method)
  #   end
  #
  # @visibility public
  # @param [String] cname name of the top level class or module to delegate, there must
  #    also be a class with the same name in the Empathy::EM namespace
  # @param [Array<Sumbol>] methods names of class/module methods to delegate
  def self.create_delegate_module(cname,*methods)
    mod = Module.new
    native_mod = Object.const_get(cname)
    em_mod = Empathy::EM.const_get(cname)
    self.const_set(cname,mod)
    methods.each do |m|
      mod.define_singleton_method(m) do |*args,&block|
        delegate = Empathy.event_machine? ? em_mod : native_mod
        delegate.send(m,*args,&block)
      end
    end
    @empathic_classes << cname unless cname == 'Kernel'
  end

  create_delegate_module('Kernel',:sleep,:at_exit)
  create_delegate_module('Thread',:new, :list, :current, :stop, :pass, :main)
  create_delegate_module('Queue',:new)
  create_delegate_module('ConditionVariable',:new)
  create_delegate_module('Mutex',:new)
  create_delegate_module('Monitor',:new)
end
