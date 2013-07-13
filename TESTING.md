Empathy Testing
===================

Empathy::EM
-----------------
Classes in Empathy::EM module are tested  using the fully empathic method - replacing Ruby's ::Thread constant with one that points to Empathy::EM::Thread etc, and then running against the subset of rubyspec to do with threads. The rubyspecs are not changed at all but some tests are skipped (see empathy.mspec)

This also tests Empathy.run and the class replacement approach (including subclassing)

Empathy module - reactor aware
--------------------------------

We just test that the delegation works as expected, with explicit specs run under rspec - see spec/empathy_spec.rb


Empathising libaries
-------------------------------

We prove that code can reference various classes as normal, and have them actually use the ones injected by {Empathy.empathise} or {Empathy::EM.empathise}. Aside from some magic for the MonitorMixin this is really just standard ruby behaviour.

MonitorMixin
-------------------------------

There are no rubyspecs for this module, so I have converted ruby 1.9's unit tests into a simple rubyspec - see rubyspec/monitor_spec.rb



