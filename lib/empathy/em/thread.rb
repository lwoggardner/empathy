require "fiber"
require "eventmachine"
require 'empathy/em/mutex'
require 'empathy/em/condition_variable'

module Empathy

  module EM

    def self.empathise(*modules)
      modules.each do |m|
        Empathy::map_classes(m,self,"Thread","Mutex","ConditionVariable","Queue","ThreadError" => FiberError)
      end
    end

    module Kernel
      # Like ::Kernel::sleep. Woken by an ::EM::Timer in +seconds+ if supplied
      def self.sleep(seconds=:__empathy_sleep_forever)

        ::Kernel.raise TypeError, "seconds #{seconds} must be a number" unless seconds == :__empathy_sleep_forever or seconds.is_a? Numeric
        n = Time.now

        em_thread = Thread.current
        timer = ::EM::Timer.new(seconds){ em_thread.__send__(:wake_resume) } unless seconds == :__empathy_sleep_forever
        em_thread.__send__(:yield_sleep,timer)

        (Time.now - n).round()
      end

      def self.at_exit(&block)
        EventMachine.add_shutdown_hook(&block)
      end
    end

    #Acts like a ::Thread using Fibers and EventMachine
    class Thread

      @@em_threads = {}

      # The underlying fiber.
      attr_reader :fiber

      # Like ::Thread::list. Return an array of all EM::Threads that are alive.
      def self.list
        @@em_threads.values.select { |s| s.alive? }
      end

      def self.main
        @@main
      end

      # Like ::Thread::current. Get the currently running EM::Thread, eg to access thread local
      # variables
      def self.current
        @@em_threads[Fiber.current] || ProxyThread.new(Fiber.current)
      end

      # Alias for Fiber::yield
      # Equivalent to a thread being blocked on IO
      #
      # WARNING: Be very careful about using #yield with the other thread like methods
      # Specifically it is important
      # to ensure user calls to #resume don't conflict with the resumes that are setup via
      # EM.timer or EM.next_tick as a result of #::sleep or #::pass
      def self.yield(*args)
        Fiber.yield(*args)
      end


      # Like ::Thread::stop. Sleep forever (until woken)
      def self.stop
        Kernel.sleep()
      end

      # Like ::Thread::pass.
      # The fiber is resumed on the next_tick of EM's event loop
      def self.pass
        em_thread = current
        ::EM.next_tick{ em_thread.__send__(:wake_resume) }
        em_thread.__send__(:yield_sleep)
        nil
      end

      # Like ::Thread.exit
      def self.exit
        current.exit
      end

      def self.kill(thread)
        thread.exit
      end

      def self.new(*args,&block)
        instance = super(*args,&block)
        ::Kernel.raise FiberError, "super not called for subclass of Thread" unless instance.instance_variable_defined?("@fiber")
        instance
      end

      def self.start(*args,&block)
        ::Kernel.raise ArgumentError, "no block" unless block_given?
        c = if self != Thread
              Class.new(self) do
                def initialize(*args,&block)
                  initialize_fiber(*args,&block)
                end
              end
            else
              self
            end 
        c.new(*args,&block)
      end

      # Create and run 
      def initialize(*args,&block)

        ::Kernel.raise FiberError, "no block" unless block_given?
        initialize_fiber(*args,&block)
      end

      # Like ::Thread#join.
      #   s1 = Empathy.new{ Empathy.sleep(1) }
      #   s2 = Empathy.new{ Empathy.sleep(1) }
      #   s1.join
      #   s2.join
      def join(limit = nil)
        @mutex.synchronize { @join_cond.wait(@mutex,limit) } if alive?
        ::Kernel.raise @exception if @exception
        if alive? then nil else self end
      end

      # Like Fiber#resume. Refer to warnings on #::yield
      def resume(*args)
        #TODO  should only allow if @status is :run, which really means
        # blocked by a call to Yield
        fiber.resume(*args)
      end

      # Like ::Thread#alive? or Fiber#alive?
      def alive?
        fiber.alive?
      end

      # Like ::Thread#stop? Always true unless our fiber is the current fiber
      def stop?
        Fiber.current != fiber
      end

      # Like ::Thread#status
      def status
        case @status
        when :run
          #TODO - if not the current fiber
          # we can only be in this state due to a yield on the
          # underlying fiber, which means we are actually in sleep
          # or we're a ProxyThread that is dead and not yet
          # cleaned up
          "run"
        when :sleep
          "sleep"
        when :dead, :killed
          false
        when :exception
          nil
        end
      end

      # Like ::Thread#value.  Implicitly calls #join.
      #   em_thread = Empathy.new{ 1+2 }
      #   em_thread.value # => 3
      def value
        join and @value
      end

      # Like ::Thread#exit. Signals thread to wakeup and die
      def exit
        case @status
        when :sleep
          wake_resume(:exit)
        when :run
          throw :exit
        end
      end

      alias :kill :exit
      alias :terminate :exit

      # Like ::Thread#wakeup Wakes a sleeping Thread
      def wakeup
        ::Kernel.raise FiberError, "dead em_thread" unless status
        wake_resume() 
        self
      end

      # Like ::Thread#raise, raise an exception on a sleeping Thread
      def raise(*args)
        args << RuntimeError if args.empty?
        if fiber == Fiber.current
          ::Kernel.raise(*args)
        elsif status
          wake_resume(:raise,*args)
        else
          #dead em_thread, do nothing
        end
      end

      alias :run :wakeup


      # Access to "fiber local" variables, akin to "thread local" variables.
      #   Empathy.new do
      #     ...
      #     Empathy.current[:connection].send(data)
      #     ...
      #   end
      def [](name)
        ::Kernel.raise TypeError, "name #{name} must convert to_sym" unless name and name.respond_to?(:to_sym)
        @locals[name.to_sym]
      end

      # Access to "fiber local" variables, akin to "thread local" variables.
      #   Empathy.new do
      #     ...
      #     Empathy.current[:connection] = SomeConnectionClass.new(host, port)
      #     ...
      #   end
      def []=(name, value)
        ::Kernel.raise TypeError, "name #{name} must convert to_sym" unless name and name.respond_to?(:to_sym)
        @locals[name.to_sym] = value
      end

      # Like ::Thread#key? Is there a "fiber local" variable defined called +name+
      def key?(name)
        ::Kernel.raise TypeError, "name #{name} must convert to_sym" unless name and name.respond_to?(:to_sym)
        @locals.has_key?(name.to_sym)
      end

      # Like ::Thread#keys The set of "em_thread local" variable keys
      def keys()
        @locals.keys
      end

      def inspect #:nodoc:
        "#<Empathy::EM::Thread:0x%s %s %s" % [object_id, @fiber == Fiber.current ? "run" : "yielded", status || "dead" ]
      end

      # Do something when the fiber completes.
      def ensure_hook(key,&block)
        if block_given? then 
          @ensure_hooks[key] = block
        else
          @ensure_hooks.delete(key)
        end
      end

      protected

      def fiber_body(*args,&block) #:nodoc:
        # Run the em_thread's block and capture the return value.
        @status = :run

        @value, @exception = nil, nil
        catch :exit do
          begin
            @value = block.call(*args)
            @status = :dead
          rescue Exception => e
            @exception = e
            @status = :exception
          ensure
            run_ensure_hooks()
          end
        end
        @status = :dead if @status == :run

        # Resume anyone who called join on us.
        # the synchronize is not really necessary for fibers
        # but does no harm
        @mutex.synchronize { @join_cond.signal() }

        # Delete from the list of running stands.
        @@em_threads.delete(@fiber)

        @value || @exception
      end

      private

      def initialize_fiber(*args,&block)
        ::Kernel.raise FiberError, "already initialized" if @fiber
        # Create our fiber.
        fiber = Fiber.new{ fiber_body(*args,&block) }

        init(fiber)

        # Finally start the em_thread.
        fiber.resume()
      end

      def init(fiber)
        @fiber = fiber
        # Add us to the list of living em_threads.
        @@main ||= self
        @@main = self unless @@main.status

        @@em_threads[@fiber] = self

        # Initialize our "fiber local" storage.
        @locals = {}

        # Record the status
        @status = nil

        # Hooks to run when the em_thread dies (eg by Mutex to release locks)
        @ensure_hooks = {}

        # Condition variable and mutex for joining.
        @mutex =  Mutex.new()
        @join_cond = ConditionVariable.new()
      end

      def yield_sleep(timer=nil)
        @status = :sleep
        event,*args = Fiber.yield
        timer.cancel if timer
        case event
        when :exit
          @status = :killed
          throw :exit
        when :wake
          @status = :run
        when :raise
          ::Kernel.raise(*args)
        end
      end

      def wake_resume(event = :wake,*args)
        fiber.resume(event,*args) if @status == :sleep
        #TODO if fiber is still alive? and status = :run
        # then it has been yielded from non Empathy code. 
        # if it is not alive, and is a proxy em_thread then
        # we can signal the condition variable from here
      end

      def run_ensure_hooks()
        #TODO - better not throw exceptions in an ensure hook
        @ensure_hooks.each { |key,hook| hook.call }
      end
    end

    # This class is used if EM::Thread class methods are called on Fibers that were not created
    # with EM::Thread.new()
    class ProxyThread < Thread

      #TODO start an EM periodic timer to reap dead proxythreads (running ensurehooks)
      #TODO do something sensible for #value, #kill

      def initialize(fiber)
        init(fiber)
      end
    end

  end
end
