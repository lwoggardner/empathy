require File.expand_path('../spec_helper', __FILE__)
require File.expand_path('../core/thread/fixtures/classes', __FILE__)

extended_on :empathy do
  describe Empathy do

    it "replaces Thread with Empathy::EM::Thread" do
      Thread.should == Empathy::EM::Thread
    end

    it "replaces Queue with Empathy::EM::Queue" do
      Queue.should == Empathy::EM::Queue
    end

    it "is used as a superclass for ThreadSpecs" do
      ThreadSpecs::SubThread.ancestors.should include(Empathy::EM::Thread)
    end

    it "defines constants for EventMachine pointing at Ruby classes" do
      EventMachine::Thread.name.should == "Thread"
      # except for queue... which EventMachine itself defines
      EventMachine::Queue.name.should == "EventMachine::Queue"
    end
  end
end

