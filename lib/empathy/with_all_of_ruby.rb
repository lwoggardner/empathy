require 'eventmachine'
require 'empathy'
require 'empathy/object'

module Empathy
 map_classes(::EventMachine,::Object)
 map_classes(::Object,Empathy::EM)
end
