module Empathy
  module EM
    class Mutex

      def initialize()
        @waiters = []
      end

      def lock()
        em_thread = Thread.current
        @waiters << em_thread
        #The lock allows reentry but requires matching unlocks
        em_thread.send(:yield_sleep) unless @waiters.first == em_thread
        # Now em_thread has the lock, make sure it is released if the em_thread thread dies
        em_thread.ensure_hook(self) { release() unless waiters.empty? || waiters.first != em_thread }
        self
      end

      def unlock()
        em_thread = Thread.current
        raise FiberError, "not owner" unless @waiters.first == em_thread
        release()
      end

      def locked?
        !@waiters.empty? && @waiters.first.alive?
      end

      def try_lock
        if locked?
          false
        else
          lock
          true
        end
      end

      def synchronize(&block)
        lock
        yield
      ensure
        unlock
      end

      def sleep(timeout=nil)
        unlock
        begin
          if timeout then Kernel.sleep(timeout) else Kernel.sleep() end
        ensure
          lock
        end
      end

      private
      def waiters
        @waiters
      end

      def release()
        # release the current lock holder, and clear the em_thread death hook
        waiters.shift.ensure_hook(self)

        ::EM.next_tick do
          waiters.shift until waiters.empty? || waiters.first.alive?
          waiters.first.send(:wake_resume) unless waiters.empty?
        end
      end
    end
  end
end
