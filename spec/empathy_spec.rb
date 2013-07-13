require 'spec_helper'

# Test class delegation
class EmTest
  def self.test_class_method(an_arg=:test_class_method,&block)
    return block.call if block_given?
    an_arg
  end

  def whoami
    :test
  end
end

module Empathy
  module EM
    class EmTest
      def self.test_class_method(an_arg=:em_test_class_method,&block)
        return block.call if block_given?
        an_arg
      end

      def whoami
        :em_test
      end
    end
  end

  create_delegate_module('EmTest',:new, :test_class_method)
end

describe Empathy do

  describe "#run" do
    it "raise errors when block raises error" do
      lambda do
        Empathy.run { raise RuntimeError }
      end.should raise_error(RuntimeError)
      EventMachine.reactor_running?.should be_false
    end
  end

  shared_examples_for "empathy_delegation" do
    it "delegates Thread" do
      t =  Empathy::Thread.new() { }
      t.should be_kind_of(thread_class)
      Empathy::Thread.list.should == thread_class.list
      Empathy::Thread.current.should == thread_class.current
      Empathy::Thread.main.should == thread_class.main
      Empathy::Thread.singleton_methods.should include(:stop,:pass)
    end

    it "delegates Queue" do
      q = Empathy::Queue.new()
      q.should be_kind_of(queue_class)
    end

    it "delegates ConditionVariable" do
      q = Empathy::ConditionVariable.new()
      q.should be_kind_of(condition_variable_class)
    end

    it "delegates Mutex" do
      q = Empathy::Mutex.new()
      q.should be_kind_of(mutex_class)
    end

    it "delegates Kernel.sleep" do
      Empathy::Kernel.singleton_methods.should include(:sleep)
    end

    it "delegates Monitor" do
      m = Empathy::Monitor.new()
      m.should be_kind_of(monitor_class)
    end

    it "rescues errors" do
      lambda do
        begin
          raise error_class
        rescue Empathy::ThreadError
          # do nothing
        end
      end.should_not raise_error
    end
  end

  context "in eventmachine" do
    around(:each) do |example|
      Empathy.run { example.run }
    end

    let (:thread_class) { Empathy::EM::Thread }
    let (:queue_class) { Empathy::EM::Queue }
    let (:condition_variable_class) { Empathy::EM::ConditionVariable }
    let (:mutex_class) { Empathy::EM::Mutex }
    let (:error_class) { ::FiberError }
    let (:monitor_class) { Empathy::EM::Monitor }

    it "delegates to Empathy::EM classes" do
        Empathy.event_machine?.should be_true
        t = Empathy::EmTest.new
        t.should be_kind_of(Empathy::EM::EmTest)
        t.whoami.should == :em_test
        Empathy::EmTest.test_class_method.should == :em_test_class_method
        Empathy::EmTest.test_class_method(:em_hello).should == :em_hello
        Empathy::EmTest.test_class_method() { :em_with_block }.should == :em_with_block
    end

    include_examples "empathy_delegation"
  end

  context "outside eventmachine" do
    let (:thread_class) { ::Thread }
    let (:queue_class) { ::Queue }
    let (:condition_variable_class) { ::ConditionVariable }
    let (:mutex_class) { ::Mutex }
    let (:error_class) { ::ThreadError }
    let (:monitor_class) { ::Monitor }

    it "delegate to ruby top level classes" do
      EventMachine.reactor_running?.should be_false
      Empathy.event_machine?.should be_false
      t = Empathy::EmTest.new
      t.should be_kind_of(EmTest)
      t.whoami.should == :test
      Empathy::EmTest.test_class_method.should == :test_class_method
      Empathy::EmTest.test_class_method(:hello).should == :hello
      Empathy::EmTest.test_class_method() { :with_block }.should == :with_block
    end

    include_examples "empathy_delegation"
  end
end
