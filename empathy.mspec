# encoding: UTF-8

require 'mspec/runner/formatters'

class MSpecScript
  # An ordered list of the directories containing specs to run
  set :files, ['rubyspec']

  # The default implementation to run the specs.
  set :target, 'ruby'

  irrelevant_class_methods = [
    "Thread.fork","Thread.allocate","Thread.abort_on_exception","Thread.exclusive"
  ]

  irrelevant_instance_methods = [
    "Thread#abort_on_exception"
  ]

  # and some intentionally not compliant
  non_compliant = [
    "running","interrupt Kernel#sleep","thread group","Mutex#lock raises a ThreadError when used recursively",
  ]

  # Exclude IO specs not relevant to IO::Like
  set :excludes, irrelevant_class_methods + irrelevant_instance_methods + non_compliant

  # These are options that are passed to the ruby interpreter running the tests
  #  to test io like "-r io/like" must be passed on the command line to mspec
  set :requires, [
    "-I", File.expand_path("../lib", __FILE__),
    "-I", File.expand_path("../mspec/lib", __FILE__),
  ]
end
