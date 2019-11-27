# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

class RemedyGenericDeleteV2
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled


    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    begin
      preinitialize_on_first_load(@input_document, [])
    rescue Exception => error
      @error = error
    end
  end

  # The execute method takes no parameters and should leverage the instance
  # variables setup and validated by the initialize method to generate a result
  # xml string.
  def execute()
    error_handling = @parameters["error_handling"]
    error_message = nil

    # If preinitialize fail then stop execution and rasie or return error
    if (@error.to_s.empty?)
      begin
        # Retrieve a single entry from specified form with given request id
        entry = get_remedy_form(@parameters['form']).find_entries(
          :single,
          :conditions => [%|'1' = "#{@parameters['request_id']}"|],
          :fields => :all
        )

        # Raise error if unable to locate the entry
        if entry.nil?
          error_message = "No matching entry on the #{@parameters['form']} form for the given field 1 [#{@parameters['request_id']}]"
          raise error_message if error_handling == "Raise Error"
        else
          deleteResults = entry.delete!
        end
      rescue Exception => error
        error_message = error.inspect
        raise error if error_handling == "Raise Error"
      end
    else
      error_message = @error
      raise @error if error_handling == "Raise Error"
    end

    # Return the results
    <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(error_message)}</result>
    </results>
    RESULTS
  end

  # This method is an accessor for the @@remedy_forms variable that caches form
  # definitions.  It checks to see if the specified form has been loaded if so
  # it returns it otherwise it needs to load the form and add it to the cache.
  def get_remedy_form(form_name)
	if @@remedy_forms[form_name].nil?
		@@remedy_forms[form_name] = ArsModels::Form.find(form_name, :context => @@remedy_context)
	end
	if @@remedy_forms[form_name].nil?
		raise "Could not find form " + form_name
	end
	@@remedy_forms[form_name]
  end
  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Unless this method has already been called...
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries.
      @@remedy_context = ArsModels::Context.new(
        :server         => get_info_value(input_document, 'server'),
        :username       => get_info_value(input_document, 'username'),
        :password       => get_info_value(input_document, 'password'),
        :port           => get_info_value(input_document, 'port'),
        :prognum        => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )
      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context))
      end
      # Store that we are preinitialized so that this method is not called twice.
      @@preinitialized = true
    end
  end

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desired info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end
