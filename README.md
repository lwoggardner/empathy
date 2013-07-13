Empathy
=======================

http://rubygems.org/gems/empathy

Make EventMachine behave like standard Ruby

Empathic Threads
------------------------

{Empathy::EM} uses Fibers to provide Thread, Queue, Mutex, ConditionVariable and MonitorMixin classes that behave like the native ruby ones.

    require 'eventmachine'
    require 'empathy'

    # start eventmachine and a main EM::Thread
    Empathy.run do
      thread = Empathy::EM::Thread.new do
        my_thread = Empathy::EM::Thread.current

        #local storage
        Empathy::EM::Thread.current[:my_key] = "some value"

        #pass control elsewhere
        Empathy::EM::Thread.pass

        Empathy::EM::Kernel.sleep(1)

        1 + 2
      end

      thread.join
      thread.value # => 3
    end

Almost all Thread behaviour is provided except that one thread will never see another as "running". Where ruby's thread API raises ThreadError, Empathy::EM will raise FiberError (which is also available as {Empathy::EM::ThreadError})

Empathic code outside of the EventMachine reactor
--------------------------------------------------

If your code may run inside or outside the reactor the {Empathy} module itself provides a set of submodules that delegate to either the native ruby class when called outside of the reactor, or to the {Empathy::EM} class when called inside the reactor.

    require 'eventmachine'
    require 'empathy'
    Empathy::Thread.current.inspect # => "Thread<...>"

    Empathy::Kernel.sleep(1)

    Empathy.event_machine? # => false

    Empathy.run do

      Empathy.event_machine? # => true

      Empathy::Thread.new do

        Empathy::Thread.current.inspect #=> "Empathy::EM::Thread<...>"

        Empathy::Kernel.sleep(1)

        begin
             #...do something with threads...
        rescue Empathy::ThreadError
             # ...
        end
      end
    end

Note that since Empathy::Thread and friends are modules, you cannot subclass them

Empathise with all ruby code
-------------------------------

Seamlessly Replace Ruby's native classes with the Empathy:EM ones (redefines top level constants), plus monkey patching of
{Object#sleep} and {Object#at_exit}

    require 'empathy/with_all_of_ruby'
    # do not run any code that uses threads outside of the reactor after the above require

    Empathy.run do
      t = Thread.new { 1 + 2 }

      t.inspect # => "Empathy::EM::Thread<.....>"

      # this will be a Fiber+EM sleep, not Kernel.sleep
      sleep(4)

      t.join
    end

 Caveat: Take care with code that subclasses Thread. This can work as long as the classes are defined after
 'empathy/thread' is required.

 Q: But doesn't eventmachine need to use normal threads?

 A: Indeed, 'empathy/thread' also defines constants in the EventMachine namespace that refer to the original Ruby classes

Empathise a library module
----------------------------------

    module MyLibary
       def create_thread
          Thread.new { Thread.current.inspect }
       end
    end

    # If library will only be used inside the reactor
    Empathy::EM.empathise(MyLibrary)

    # If library is used both inside and outside the reactor
    Empathy.empathise(MyLibrary)

 See {Empathy::EM.empathise} and {Empathy.empathise}.

 In both cases constants are defined in the MyLibrary namespace so that Thread, Queue etc, refer to either Empathy modules
 or Empathy:EM classes. Note that any call to empathise will have the side-effect of monkey patching Object to provide EM
 safe #sleep and #at_exit.

 Caveat: MyLibrary must not subclass Thread etc...

Empathy::EM::IO - Implement Ruby's Socket API over EventMachine
---------------------------------------------------------------

Work in progress - see experimental socket-io branch

Contributing to empathy
---------------------------

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add specs, preferably based on ruby-spec

Copyright
-----------------

Copyright (c) 2011 Christopher J. Bottaro. (Original fiber+EM concept in "strand" library)

Copyright (c) 2012,2013 Grant Gardner.

See {file:LICENSE.txt} for further details.

