module Empathy
  module EM

    # A Empathy equivalent to ::Queue from thread.rb
    class Queue

      # Creates a new queue
      def initialize
        @mutex = Mutex.new()
        @cv = ConditionVariable.new()
        @q = []
        @waiting = 0
      end

      # @param [Object] obj
      # @return [void]
      def push(obj)
        @q << obj
        @mutex.synchronize { @cv.signal }
      end
      alias :<< :push
      alias :enq :push

      # Retrieves data from the queue.
      # @param [Boolean] non_block
      # @raise FiberError if non_block is true and the queue is empty
      def pop(non_block=false)
        raise FiberError, "queue empty" if non_block && empty?
        if empty?
          @waiting += 1
          @mutex.synchronize { @cv.wait(@mutex) if empty? }
          @waiting -= 1
        end
        # array.pop is like a stack, we're a FIFO
        @q.shift
      end
      alias :shift :pop
      alias :deq :pop

      # @return [Fixnum] the length of the queue
      def length
        @q.length
      end
      alias :size :length

      # @return [true] if the queue is empty
      # @return [false] otherwise
      def empty?
        @q.empty?
      end

      # Removes all objects from the queue
      # @return [void]
      def clear
        @q.clear
      end

      # @return [Fixnum] the number of fibers waiting on the queue
      def num_waiting
        @waiting
      end
    end
  end
end
