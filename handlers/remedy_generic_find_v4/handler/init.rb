# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

class RemedyGenericFindV4
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

    # Determine if caching is disabled.
    @disable_caching = get_info_value(@input_document, 'disable_caching') == 'Yes'
    if @disable_caching
      puts("WARNING: Caching disabled.  This may be convenient in development "+
        "environments (where forms are changing), but should not be used in "+
        "production (where it would negatively impact performance).")
    end

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts("Parameters: #{@parameters.inspect}") if @debug_logging_enabled  
  
    
    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    # Here we initialize with an empty forms array because this handler will be
    # used to access a dynamic set of forms depending on the input. 
    begin
        # Obtain a unchangable reference to the configuration (the @@config class 
        # variable could be concurrently changed by other threads -- by defining the 
        # @config instance variable, the execution of this handler is "locked in" to
        # using that config for the entire execution)
        @config = preinitialize_on_first_load(@input_document, [])
    rescue Exception => error
      @error = error
    end
  end
  
  # Returns the request ids (field 1) and instance ids (field 179) for all records 
  # in the specified form that match the provided prameter of query.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    
    error_handling = @parameters["error_handling"]
    error_message = nil
    
    # If preinitialize fail then stop execution and rasie or return error
    if (@error.to_s.empty?) 
    
      begin
        # Retrieve a entries from specified form with given query
        entry = get_remedy_form(@parameters['form']).find_entries(
          :all,
          :conditions => [%|#{@parameters['query']}|],
          :fields => [1,179]
        )
        
        #Begin building XML of fields
        id_list = '<Request_Ids>'
        id_list2 = '<Instance_Ids>'
        count = 0
        
        if !entry.nil?
          # Build up a list of all request ids returned
          entry.each do |entry|
            count = count + 1
            if (entry[1])
              id_list << '<RequestId>'+ entry[1] +'</RequestId>'
            end
            if (entry[179])
              id_list2 << '<InstanceId>'+ entry[179] +'</InstanceId>'
            end
          end
        end
        
        #Complete result XML
        id_list << '</Request_Ids>'
        id_list2 << '</Instance_Ids>'
      rescue Exception => error
        error_message = error.inspect
        raise error if error_handling == "Raise Error"
      end
    
    else
      error_message = @error
      raise @error if error_handling == "Raise Error"
    end

    # Build the results to be returned by this handler
    results = <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="RequestIdList">#{escape(id_list)}</result>
      <result name="InstanceIdList">#{escape(id_list2)}</result>
      <result name="Count">#{escape(count)}</result>
    </results>
    RESULTS
    puts(results) if @debug_logging_enabled  
  
    # Return the results String
    return results
  end

  # This method is an accessor for the @config[:forms] variable that caches 
  # form definitions.  It checks to see if the specified form has been loaded 
  # if so it returns it otherwise it needs to load the form and add it to the 
  # cache.
  def get_remedy_form(form_name)
    if @config[:forms][form_name].nil? || @disable_caching
      @config[:forms][form_name] = ArsModels::Form.find(form_name, :context => @config[:context])
    end
    if @config[:forms][form_name].nil?
      raise "Could not find form " + form_name
    end
    @config[:forms][form_name]
  end
  
  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Build a map of handler properties (these can be used to determine when 
    # there are property changes)
    properties = {
      :server         => get_info_value(input_document, 'server'),
      :username       => get_info_value(input_document, 'username'),
      :password       => get_info_value(input_document, 'password'),
      :port           => get_info_value(input_document, 'port'),
      :prognum        => get_info_value(input_document, 'prognum'),
      :authentication => get_info_value(input_document, 'authentication')
    }

    # If this is the first time the handler has been run, or if the handler 
    # properties are changing
    if !self.class.class_variable_defined?('@@config') || @@config[:properties] != properties
      puts("Info values have changed a new config is being generated.") if @debug_logging_enabled  
      
      remedy_context = ArsModels::Context.new(
        :server         => get_info_value(input_document, 'server'),
        :username       => get_info_value(input_document, 'username'),
        :password       => get_info_value(input_document, 'password'),
        :port           => get_info_value(input_document, 'port'),
        :prognum        => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )

      # Build up a new configuration
      @@config = {
        :properties => properties,
        :context => remedy_context,
        :forms => form_names.inject({}) do |hash, form_name|
          hash.merge!(form_name => ArsModels::Form.find(form_name, :context => remedy_context))
        end
      }
    end
    
    # Return the configuration
    @@config
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