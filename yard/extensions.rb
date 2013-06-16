class ModuleDelegationHandler< YARD::Handlers::Ruby::Base
  handles method_call(:create_delegate_module)
  namespace_only

  def process
    module_name = statement.parameters.first.jump(:tstring_content,:ident,:symbol).source
    object = YARD::CodeObjects::ModuleObject.new(namespace,module_name)
    register(object)

    object.docstring.replace("Delegates to {Empathy::EM::#{module_name}} when in the EM reactor, otherwise plain old ::#{module_name}")
    object.dynamic = true

    statement.parameters[1..-1].each do |parameter|
      next unless parameter
      method_name = parameter.jump(:symbol_literal).source[1..-1]
      method = YARD::CodeObjects::MethodObject.new(object, method_name, :module)
      register(method)
      method.docstring.replace("Delegates to {Empathy::EM::#{module_name}.#{method_name}} when in the EM reactor, otherwise to plain old ::#{module_name}.#{method_name}")
      method.dynamic=true
      method.visibility=:public
    end
  end

end
