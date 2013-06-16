module Empathy
  module EM
    # Provides for Empathys (Fibers) what Ruby's ConditionVariable provides for Threads.
    class ConditionVariable

      # Create a new condition variable.
      def initialize
        @waiters = []
      end

      # Using a mutex for condition variables is meant to protect
      # against race conditions when the signal occurs between testing whether
      # a wait is needed and waiting. This situation will never occur with
      # fibers, but the semantic is retained for compatibility with ::ConditionVariable
      # @return [ConditionVariable] self
      def wait(mutex=nil,timeout = nil)

        if timeout.nil? && (mutex.nil? || Numeric === mutex)
          timeout = mutex
          mutex = nil
        end

        # Get the fiber (Empathy::EM::Thread) that called us.
        empathy = Thread.current
        # Add the fiber to the list of waiters.
        @waiters << empathy
        begin
          sleeper = mutex ? mutex : Kernel
          if timeout then sleeper.sleep(timeout) else sleeper.sleep() end
        ensure
          # Remove from list of waiters.
          @waiters.delete(empathy)
        end
        self
      end

      # Like ::ConditionVariable#signal
      # @return [ConditionVariable] self
      def signal
        # If there are no waiters, do nothing.
        return self if @waiters.empty?

        # Find a waiter to wake up.
        waiter = @waiters.shift

        # Resume it on next tick.
        ::EM.next_tick{ waiter.wakeup }
        self
      end

      # Like ::ConditionVariable#broadcast
      # @return [ConditionVariable] self
      def broadcast
        all_waiting = @waiters.dup
        @waiters.clear
        ::EM.next_tick { all_waiting.each { |w| w.wakeup } }
        self
      end

    end
  end
end
