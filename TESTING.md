Empathy Testing
===================

Empathy::EM
-----------------
Classes in Empathy::EM module are tested  using the fully empathic method - replacing Ruby's ::Thread constant with one that points to Empathy::EM::Thread etc, and then running against the subset of rubyspec to do with threads. The rubyspecs are not changed at all. Some tests are skipped (see *.mspec)

This also tests Empathy.run and the class replacement approach (including subclassing)

Empathy module - reactor aware
--------------------------------

We just test that the delegation works as expected, with explicit specs run under rspec
