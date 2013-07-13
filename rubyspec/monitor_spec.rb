require "monitor"
require File.expand_path('../spec_helper', __FILE__)

describe "Monitor" do
    before(:each) do
        @monitor = Monitor.new
    end

    it "controls entry and exit" do
        ary = []
        queue = Queue.new
        th = Thread.start {
            queue.pop
            @monitor.enter
            for i in 6 .. 10
                ary.push(i)
                Thread.pass
            end
            @monitor.exit
        }
        @monitor.enter
        queue.enq(nil)
        for i in 1 .. 5
            ary.push(i)
            Thread.pass
        end
        @monitor.exit
        th.join
        ary.should == (1..10).to_a
    end

    it "synchronises on itself" do
        ary = []
        queue = Queue.new
        th = Thread.start {
            queue.pop
            @monitor.synchronize do
                for i in 6 .. 10
                    ary.push(i)
                    Thread.pass
                end
            end
        }
        @monitor.synchronize do
            queue.enq(nil)
            for i in 1 .. 5
                ary.push(i)
                Thread.pass
            end
        end
        th.join
        ary.should == (1..10).to_a
    end

    it "recovers from thread killed in synchronize" do
        ary = []
        queue = Queue.new
        t1 = Thread.start {
            queue.pop
            @monitor.synchronize {
                ary << :t1
            }
        }
        t2 = Thread.start {
            queue.pop
            @monitor.synchronize {
                ary << :t2
            }
        }
        @monitor.synchronize do
            queue.enq(nil)
            queue.enq(nil)
            ary.empty?.should be_true
            t1.kill
            t2.kill
            ary << :main
        end
        ary.should == [ :main ]
    end

    it "performs try_enter appropriately" do
        queue1 = Queue.new
        queue2 = Queue.new
        th = Thread.start {
            queue1.deq
            @monitor.enter
            queue2.enq(nil)
            queue1.deq
            @monitor.exit
            queue2.enq(nil)
        }
        @monitor.try_enter.should be_true
        @monitor.exit
        queue1.enq(nil)
        queue2.deq
        @monitor.try_enter.should be_false
        queue1.enq(nil)
        queue2.deq
        @monitor.try_enter.should be_true
    end

    describe "MonitorMixin::ConditionVariable" do
        it "waits and signals" do
            cond = @monitor.new_cond

            a = "foo"
            queue1 = Queue.new
            Thread.start do
                queue1.deq
                @monitor.synchronize do
                    a = "bar"
                    cond.signal
                end
            end
            @monitor.synchronize do
                queue1.enq(nil)
                a.should == "foo"
                result1 = cond.wait
                result1.should == true
                a.should == "bar"
            end
        end

        it "timesout on wait" do
            cond = @monitor.new_cond
            b = "foo"
            queue2 = Queue.new
            Thread.start do
                queue2.deq
                @monitor.synchronize do
                    b = "bar"
                    cond.signal
                end
            end
            @monitor.synchronize do
                queue2.enq(nil)
                b.should == "foo"
                cond.wait(0.1).should == true
                b.should == "bar"
            end

            c = "foo"
            queue3 = Queue.new
            Thread.start do
                queue3.deq
                @monitor.synchronize do
                    c = "bar"
                    cond.signal
                end
            end
            @monitor.synchronize do
                c.should == "foo"
                cond.wait(0.1).should be_true
                c.should == "foo"
                queue3.enq(nil)
                cond.wait.should be_true
                c.should == "bar"
            end

        end
    end
end
