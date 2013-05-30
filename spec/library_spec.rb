require 'spec_helper'

module TestReactorLibrary
  def self.test_thread_error
    raise ::FiberError, "oops"
  rescue ThreadError
    :rescued
  end
end

Empathy::EM.empathise(TestReactorLibrary)

module TestLibrary
  def self.test_thread_error
    begin
      raise ::FiberError, "fiber error"
    rescue ThreadError
    end

    begin
      raise ::ThreadError, "thread error"
    rescue ThreadError
    end
    :ok
  end
end

Empathy.empathise(TestLibrary)

shared_examples_for "Empathy.empathise" do
  it "rescues thread and fiber exceptions" do
    TestLibrary.test_thread_error.should == :ok
  end
end

describe "Empathy.empathise" do

  it "defines constants in Library namespace" do
    TestLibrary::Thread.should == Empathy::Thread
    TestLibrary::Queue.should == Empathy::Queue
    TestLibrary::ConditionVariable.should == Empathy::ConditionVariable
    TestLibrary::Mutex.should == Empathy::Mutex
    TestLibrary::ThreadError.should == Empathy::ThreadError
  end

  context "in reactor" do
    around :each do |example|
      Empathy.run { example.run }
    end

    include_examples "Empathy.empathise"
  end

  context "outside reactor" do
    include_examples "Empathy.empathise"
  end

end

describe "Empathy::EM.empathise" do

  it "defines constants in Library namespace" do
    TestReactorLibrary::Thread.should == Empathy::EM::Thread
    TestReactorLibrary::Queue.should == Empathy::EM::Queue
    TestReactorLibrary::ConditionVariable.should == Empathy::EM::ConditionVariable
    TestReactorLibrary::Mutex.should == Empathy::EM::Mutex
    TestReactorLibrary::ThreadError.should == FiberError
  end

  context "in reactor" do
    around :each do |example|
      Empathy.run { example.run }
    end

    it "rescues fiber errors" do
      TestReactorLibrary.test_thread_error.should == :rescued
    end
  end
end
