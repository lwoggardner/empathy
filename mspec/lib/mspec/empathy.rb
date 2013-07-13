require 'empathy/with_all_of_ruby'
require 'mspec'
require 'mspec/guards/empathy'
module MSpec

    class << self
        alias :process_orig :process

        def process
            # start the EventMachine, and run reactor code within a Fiber,
            # when the main fiber finishes, stop the event machine
            Empathy.run do
               process_orig
            end
        end
    end

end

