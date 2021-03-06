# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

# Define the handler class which should:
#  * Be named in the format <GROUP><ITEM><ACTION>HandlerV<VERSION>
#  * Include an initialize method that takes a single String of XML.
#  * Include an execute method that returns XML in the expected format
class BmcItsm7ApprovalApproveV1
  # The initialize method takes a String of XML.  This XML is defined in the
  # process/node.xml file as the taskDefinition/handler element.  This method
  # should setup (usually retrieve from the input xml) any instance variables
  # that will be used by the handler, validate that the variables are valid, and
  # optionally call a preinitialize_on_first_load method (if there are expensive
  # operations that don't need to be executed with each task node instance).
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

	 # Retrieve the list of field values that will be written to the approval record
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
    puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled
  end

  # The execute method takes no parameters and should leverage the instance
  # variables setup and validated by the initialize method to generate a result
  # xml string.
  def execute()

    # Build up impersonated user context...username, password, etc are from info values and user needs to be an Admin.
    impersonateContext = ArsModels::Context.new(
        :server         => get_info_value(@input_document, 'server'),
        :username       => get_info_value(@input_document, 'username'),
        :password       => get_info_value(@input_document, 'password'),
        :port           => get_info_value(@input_document, 'port'),
        :prognum        => get_info_value(@input_document, 'prognum'),
        :authentication => get_info_value(@input_document, 'authentication')
      )
    # Now use the impersonateUser parameter to set the impersonation.
    impersonateContext.ars_context.setImpersonatedUser(@parameters['impersonating'])
    
    
	#update the AP:Detail-Signature record using the @field_values hash that was built up.
    approvalForm = ArsModels::Form.find('AP:Detail-Signature', :context => impersonateContext)
    entry = approvalForm.update_entry!(
	  @parameters['approval_record'],
      :field_values => @field_values,
      :fields       => ['Sig-TermState-Date']
    )
	
    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
	  <result name="Date Approved">#{escape(entry['Sig-TermState-Date'])}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled

    # Return the results String
    return results
  end

   ##############################################################################
  # Kinetic handler utility functions
  ##############################################################################

  # Retrieve the ArsModels::Entry object for the KS_SRV_CustomerSuvey_base
  # record associated to the specified instance id and include the specified
  # fields.
  #
  # Raises an exception if a record associated to the specified instance id does
  # not exist.
  #
  # ==== Parameters
  # * id (String) - The instance Id of the KS_SRV_CustomerSurvey_base record
  #   that should be retrieved.
  # * field_identifiers (Array) - An array of field identifiers, typically field
  #   ids (specified as numbers) or field names (specified as strings), that
  #   should be returned with the requested submission.
  #
  # ==== Returns
  # An ArsModels::Entry record that includes the field values of the located
  # KS_SRV_CustomerSurvey_base record.
  def retrieve_submission(id, field_identifiers=nil)
    entry = @@remedy_forms['AP:Alternate'].find_entries(
      :single, :fields => field_identifiers, :conditions => [%`'Alternate ID' = "#{id}"`]
    )
    raise %|Unable to find the initial request record '#{id}'.| if entry.nil?
    entry
  end
  
 
  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] }
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end