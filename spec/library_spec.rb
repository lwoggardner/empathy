require 'spec_helper'

module EmpathyEMLibrary

  module SubModule
    def self.thread_class
      Thread
    end
  end
  class TestClass
    include MonitorMixin

    def self.thread_class
      Thread
    end

    def thread_class
      Thread
    end

  end
end

Empathy::EM.empathise(EmpathyEMLibrary)

module EmpathyLibrary
  module SubModule
    def self.thread_class
      Thread
    end
  end
  class TestClass
    include MonitorMixin

    def self.thread_class
      Thread
    end

    def thread_class
      Thread
    end

  end

end

Empathy.empathise(EmpathyLibrary)

module NonEmpathisedLibrary
  module SubModule
    def self.thread_class
      Thread
    end
  end
  class TestClass
    include MonitorMixin

    def self.thread_class
      Thread
    end

    def thread_class
      Thread
    end

  end
end

shared_examples_for "an empathised library" do

  it "has constant references in its namespace pointing to modules in empathy namespace" do
    library_module.const_get('Thread',false).should == empathy_module.const_get('Thread',false)
    library_module.const_get('Queue',false).should == empathy_module.const_get('Queue',false)
    library_module.const_get('Mutex',false).should == empathy_module.const_get('Mutex',false)
    library_module.const_get('ConditionVariable',false).should == empathy_module.const_get('ConditionVariable',false)
    library_module.const_get('Monitor',false).should == empathy_module.const_get('Monitor',false)
    library_module.const_get('ThreadError',false).should == empathy_module.const_get('ThreadError',false)
  end
end

shared_examples_for "a possibly empathised library" do

  it "resolves constant references from submodules in its namepsace to modules in empathy namepsace" do
    submodule = library_module.const_get('SubModule',false)
    submodule.thread_class.should == empathy_module.const_get('Thread',false)
  end

  it "resolves constant references from classes within its namespace to modules in empathy namespace" do
    library_class = library_module.const_get('TestClass',false)
    library_class.thread_class.should == empathy_module.const_get('Thread',false)
    obj = library_module.const_get('TestClass',false).new()
    obj.thread_class.should == empathy_module.const_get('Thread',false)
  end

  context "MonitorMixin" do
    it "uses empathised classes" do
      monitor = library_module.const_get("TestClass",false).new
      monitor.__send__(:mon_class_lookup,'Thread').should == empathy_module.const_get('Thread',false)
    end
  end
end

describe Empathy do

  let(:empathy_module) { described_class }
  let(:library_module) { EmpathyLibrary }

  include_examples "an empathised library"
  include_examples "a possibly empathised library"
end

describe Empathy::EM do

  let(:empathy_module) { described_class }
  let(:library_module) { EmpathyEMLibrary }

  include_examples "an empathised library"
  include_examples "a possibly empathised library"
end

describe Object do
  let(:empathy_module) { described_class }
  let(:library_module) { NonEmpathisedLibrary }

  include_examples "a possibly empathised library"
end
