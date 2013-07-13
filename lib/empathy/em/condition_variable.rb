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
        thread = Thread.current
        # Add the fiber to the list of waiters.
        @waiters << thread
        begin
          sleeper = mutex ? mutex : Kernel
          if timeout then sleeper.sleep(timeout) else sleeper.sleep() end
        ensure
          # Remove from list of waiters. Note this doesn't run if the thread is killed
          @waiters.delete(thread)
        end
        self
      end

      # Like ::ConditionVariable#signal
      # @return [ConditionVariable] self
      def signal

        # Find a waiter to wake up
        until @waiters.empty?
           waiter = @waiters.shift
           if waiter.alive?
             ::EM.next_tick{ waiter.wakeup if waiter.alive? }
             break;
           end
        end

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
