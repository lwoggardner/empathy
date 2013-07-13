# See MRI Ruby's MonitorMixin
# This file is derived from MRI Ruby 1.9.3 monitor.rb
#
# Copyright (C) 2001  Shugo Maeda <shugo@ruby-lang.org>
#
# The only changes are constant lookups, it dynamically uses thread constants
# from the included class/extended object
#
# Note this relaces monitor.rb defined by ruby - so even if you don't include empathy
# you may end up using this module.
module MonitorMixin

  # A condition variable associated with a monitor. Do not instantiate directly.
  # @see MonitorMixin#new_cond
  class ConditionVariable
    #
    # Releases the lock held in the associated monitor and waits; reacquires the lock on wakeup.
    # @param [Numeric] timeout maximum time, in seconds, to wait for a signal
    # @return [true]
    def wait(timeout = nil)
      @monitor.__send__(:mon_check_owner)
      count = @monitor.__send__(:mon_exit_for_cond)
      begin
        @cond.wait(@monitor.instance_variable_get("@mon_mutex"), timeout)
        return true
      ensure
        @monitor.__send__(:mon_enter_for_cond, count)
      end
    end

    #
    # Calls wait repeatedly while the given block yields a truthy value.
    #
    # @return [true]
    def wait_while
      while yield
        wait
      end
    end

    #
    # Calls wait repeatedly until the given block yields a truthy value.
    #
    # @return [true]
    def wait_until
      until yield
        wait
      end
    end

    #
    # Wakes up the first thread in line waiting for this lock.
    #
    def signal
      @monitor.__send__(:mon_check_owner)
      @cond.signal
    end

    #
    # Wakes up all threads waiting for this lock.
    #
    def broadcast
      @monitor.__send__(:mon_check_owner)
      @cond.broadcast
    end

    private

    def initialize(monitor)
      @monitor = monitor
      @cond = monitor.__send__(:mon_class_lookup,:ConditionVariable).new
    end
  end

  # @private
  def self.extend_object(obj)
    super(obj)
    obj.__send__(:mon_initialize)
  end

  #
  # Attempts to enter exclusive section.
  #
  # @return [Boolean] whether entry was successful
  def mon_try_enter
    if @mon_owner != mon_class_lookup(:Thread).current
      unless @mon_mutex.try_lock
        return false
      end
      @mon_owner = mon_class_lookup(:Thread).current
    end
    @mon_count += 1
    return true
  end
  # For backward compatibility
  alias try_mon_enter mon_try_enter

  #
  # Enters exclusive section.
  #
  # @return [void]
  def mon_enter
    if @mon_owner != mon_class_lookup(:Thread).current
      @mon_mutex.lock
      @mon_owner = mon_class_lookup(:Thread).current
    end
    @mon_count += 1
  end

  #
  # Leaves exclusive section.
  #
  # @return [void]
  def mon_exit
    mon_check_owner
    @mon_count -=1
    if @mon_count == 0
      @mon_owner = nil
      @mon_mutex.unlock
    end
  end

  #
  # Enters exclusive section and executes the block.  Leaves the exclusive
  # section automatically when the block exits.
  # @return [void]
  def mon_synchronize
    mon_enter
    begin
      yield
    ensure
      mon_exit
    end
  end
  alias synchronize mon_synchronize

  #
  # @return [ConditionVariable]  a new condition variable associated with the receiver.
  #
  def new_cond
    return ConditionVariable.new(self)
  end

  private

  # Use <tt>extend MonitorMixin</tt> or <tt>include MonitorMixin</tt> instead
  # of this constructor.  Have look at the examples above to understand how to
  # use this module.
  def initialize(*args)
    super
    mon_initialize
  end

  # Initializes the MonitorMixin after being included in a class or when an
  # object has been extended with the MonitorMixin
  def mon_initialize
    @mon_owner = nil
    @mon_count = 0

    # Find the appropriate empathised module to use when resolving references to Thread, Mutex etc..
    parts = self.class.name.split("::")[0..-2]
    parents = parts.inject([Object]) { |result,name| result.unshift(result.first.const_get(name,false)) }
    @mon_empathised_module = parents.detect { |p| p.instance_variable_get(:@empathised) } || Object

    @mon_mutex = mon_class_lookup(:Mutex).new
  end

  def mon_check_owner
    if @mon_owner != mon_class_lookup(:Thread).current
      raise mon_class_lookup(:ThreadError), "current thread not owner"
    end
  end

  def mon_enter_for_cond(count)
    @mon_owner = mon_class_lookup(:Thread).current
    @mon_count = count
  end

  def mon_exit_for_cond
    count = @mon_count
    @mon_owner = nil
    @mon_count = 0
    return count
  end

  # looks up namespace hierarchy for an empathised module
  def mon_class_lookup(const)
    @mon_empathised_module.const_get(const,false)
  end
end

# Use the Monitor class when you want to have a lock object for blocks with
# mutual exclusion.
# @example
#   require 'monitor'
#
#   lock = Monitor.new
#   lock.synchronize do
#     # exclusive access
#   end
#
class Monitor
  include MonitorMixin
  alias try_enter try_mon_enter
  alias enter mon_enter
  alias exit mon_exit
end


