require 'eventmachine'
require 'empathy'
require 'empathy/object'

module Empathy
 map_classes(::EventMachine,::Object,"Thread","Queue","Mutex","ConditionVariable", "ThreadError" )
 map_classes(::Object,Empathy::EM,"Thread","Queue","Mutex","ConditionVariable", "ThreadError" => FiberError)
end
