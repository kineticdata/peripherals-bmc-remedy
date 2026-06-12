package com.kineticdata.bridgehub.adapter.ars.rest;

import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;
import com.jayway.jsonpath.JsonPathException;
import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.BridgeUtils;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ArsRestV2Adapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * CONSTRUCTOR
     *--------------------------------------------------------------------------------------------*/
    public ArsRestV2Adapter () {
        // Parse the query and exchange out any parameters with their parameter 
        // values. ie. change the query username=<%=parameter["Username"]%> to
        // username=test.user where parameter["Username"]=test.user
        this.parser = new ArsRestV2QualificationParser();
    }
    
    /*----------------------------------------------------------------------------------------------
     * STRUCTURES
     *      AdapterMapping( Structure Name, Path Function)
     *--------------------------------------------------------------------------------------------*/
    public static Map<String,AdapterMapping> MAPPINGS 
        = new HashMap<String,AdapterMapping>() {{
        put("Entry", new AdapterMapping("Entry",
            ArsRestV2Adapter::pathEntry));
        put("Adhoc", new AdapterMapping("Adhoc",
            ArsRestV2Adapter::pathAdhoc));
    }};
    
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name */
    public static final String NAME = "Ars Rest Bridge";

    /** Defines the logger */
    protected static final Logger LOGGER = LoggerFactory.getLogger(ArsRestV2Adapter.class);
    
    /** Adapter version constant. */
    public static String VERSION = "";
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(ArsRestV2Adapter.class.getResourceAsStream("/"+ArsRestV2Adapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            LOGGER.warn("Unable to load "+ArsRestV2Adapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }

    /** Defines the collection of property names for the adapter */
    public static class Properties {
        public static final String PROPERTY_USERNAME = "Username";
        public static final String PROPERTY_PASSWORD = "Password";
        public static final String PROPERTY_ORIGIN = "URL Origin";
        public static final String PROPERTY_MAX_RECORDS = "Max Records";

    }

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.PROPERTY_USERNAME).setIsRequired(true),
        new ConfigurableProperty(Properties.PROPERTY_PASSWORD).setIsSensitive(true),
        new ConfigurableProperty(Properties.PROPERTY_ORIGIN).setIsRequired(true)
            .setDescription("The scheme://hostname:port of the Ars Server"),
        new ConfigurableProperty(Properties.PROPERTY_MAX_RECORDS).setIsRequired(false)
            .setDescription("Hard ceiling on total records returned per request "
                + "when the limit parameter exceeds 1000 (default 10000)")
            .setValue(Integer.toString(DEFAULT_MAX_RECORDS))
    );

    // Local variables to store the property values in
    private String username;
    private String password;
    private String origin;
    private ArsRestV2QualificationParser parser;
    ArsRestV2ApiHelper apiHelper; // package-private for unit testing
    int maxRecords = DEFAULT_MAX_RECORDS; // package-private for unit testing

    // constant variables
    private final String API_PATH = "/api/arsys/v1";
    /** Maximum records the ARS REST api will return from a single request. */
    private static final int PAGE_SIZE = 1000;
    /** Default value for the Max Records configurable property. */
    private static final int DEFAULT_MAX_RECORDS = 10000;
    
    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public void initialize() throws BridgeError {
        // Initializing the variables with the property values that were passed
        // when creating the bridge so that they are easier to use
        username = properties.getValue(Properties.PROPERTY_USERNAME);
        password = properties.getValue(Properties.PROPERTY_PASSWORD);
        origin = properties.getValue(Properties.PROPERTY_ORIGIN);

        // Parse the optional Max Records property.  Fail on bridge save when
        // the property is not a positive number.
        String maxRecordsValue = properties.getValue(Properties.PROPERTY_MAX_RECORDS);
        if (maxRecordsValue != null && !maxRecordsValue.trim().isEmpty()) {
            try {
                maxRecords = Integer.parseInt(maxRecordsValue.trim());
            } catch (NumberFormatException e) {
                throw new BridgeError("The Max Records property must be a number.", e);
            }
            if (maxRecords < 1) {
                throw new BridgeError("The Max Records property must be greater than 0.");
            }
        } else {
            maxRecords = DEFAULT_MAX_RECORDS;
        }

        apiHelper = new ArsRestV2ApiHelper(origin, username, password);

        apiHelper.getToken();
    }

    @Override
    public String getName() {
        return NAME;
    }

    @Override
    public String getVersion() {
       return VERSION;
    }

    @Override
    public void setProperties(Map<String,String> parameters) {
        // This should always be the same unless there are special circumstances
        // for changing it
        properties.setValues(parameters);
    }

    @Override
    public ConfigurablePropertyMap getProperties() {
        // This should always be the same unless there are special circumstances
        // for changing it
        return properties;
    }

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        // Log the access
        LOGGER.trace("Counting records");
        LOGGER.trace("  Structure: " + request.getStructure());
        LOGGER.trace("  Query: " + request.getQuery());

        // parse Structure
        List<String> structureList = Arrays.asList(request.getStructure().trim()
            .split("\\s*>\\s*"));
        // get Structure model
        AdapterMapping mapping = getMapping(structureList.get(0));
        
        Map<String, String> parameters = getParameters(
            parser.parse(request.getQuery(),request.getParameters()), mapping);

        // A limit in the qualification caps the count; otherwise count all
        // matching records up to the Max Records ceiling.
        int requestedLimit = parameters.containsKey("limit")
            ? getRequestedLimit(parameters) : maxRecords;

        Map<String, String> metadata = new HashMap<>();

        // Path builder functions may mutate the parameters Map;
        String path = mapping.getPathbuilder().apply(structureList, parameters);

        // Retrieve the objects based on the structure from the source
        JSONArray entries = aggregateEntries(apiHelper, path, parameters,
            requestedLimit, metadata);

        // Create and return a count object that contains the count
        return new Count(entries.size(), metadata);
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        // Log the access
        LOGGER.trace("Retrieving Kinetic Request CE Record");
        LOGGER.trace("  Structure: " + request.getStructure());
        LOGGER.trace("  Query: " + request.getQuery());
        LOGGER.trace("  Fields: " + request.getFieldString());

        // parse Structure
        List<String> structureList = Arrays.asList(request.getStructure().trim()
            .split("\\s*>\\s*"));
        // get Structure model
        AdapterMapping mapping = getMapping(structureList.get(0));
        
        Map<String, String> parameters = getParameters(
            parser.parse(request.getQuery(),request.getParameters()), mapping);
        
        // Path builder functions may mutate the parameters Map;
        String path = mapping.getPathbuilder().apply(structureList, parameters);
        
        // Retrieve the objects based on the structure from the source
        JSONObject object = apiHelper.executeRequest(getUrl(path, parameters));

        // Get domain specific data.
        // TODO: consider using mapper for single/multiple similar to kinetic
        // core
        JSONObject obj = (JSONObject)(object).get("values");
        JSONArray entries = (JSONArray)object.get("entries");
        
        // If "multiple" were requested than obj will be null and entries will 
        // get populated.
        Record record = new Record();
        if (entries != null) {
            // Throw error if multiple results found.
            if (entries.size() > 1) {
                throw new BridgeError ("Retrieve must return a single result."
                    + " Multiple results found.");
            } else if (entries.size() == 0) {
                // empty retrieve condition
                return new Record();
            } else if (entries.size() == 1){
                obj = (JSONObject)((JSONObject)entries.get(0)).get("values");
            }
        }
        if (obj != null) {
            List<String> fields = getFields(request.getFields() == null ? 
                new ArrayList() : request.getFields(), obj);
            record = buildRecord(fields, obj);
        } else {
            throw new BridgeError ("An unexpected error has occured.");
        }

        // Return the created Record object
        return record;
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        // Log the access
        LOGGER.trace("Searching Records");
        LOGGER.trace("  Structure: " + request.getStructure());
        LOGGER.trace("  Query: " + request.getQuery());
        LOGGER.trace("  Fields: " + request.getFieldString());
        
        // parse Structure
        List<String> structureList = Arrays.asList(request.getStructure().trim()
            .split("\\s*>\\s*"));
        // get Structure model
        AdapterMapping mapping = getMapping(structureList.get(0));

        Map<String, String> parameters = getParameters(
            parser.parse(request.getQuery(),request.getParameters()), mapping);

        int requestedLimit = getRequestedLimit(parameters);

        Map<String, String> metadata = request.getMetadata() != null ?
                request.getMetadata() : new HashMap<>();

        // Capture order prior to clearing metadata for reuse in response.
        String order = metadata.get("order");

        // If offest exists in metadata add it to the parameters for use with
        // reqeust.
        if (metadata.get("offset") != null) {
            // Offset in parameters takes precedence.
            parameters.putIfAbsent("offset", metadata.get("offset"));
        }
        // clear metadata object to be repopulated for response.
        metadata.clear();

        // Add a sorting order to be used with the request if order was defined,
        // but sort was not included in the qualification mapping.
        if (order != null && !parameters.containsKey("sort")) {
            addSort(order, parameters);
        }

        // Paging without an explicit sort relies on the ARS server's default
        // ordering.  A sort field is not injected because field names vary by
        // form.
        if (requestedLimit > PAGE_SIZE && !parameters.containsKey("sort")) {
            LOGGER.warn("Aggregating paged requests without an explicit sort. "
                + "Paging relies on the ARS server's default ordering; records "
                + "may be skipped or duplicated if that ordering is not stable.");
        }

        // Path builder functions may mutate the parameters Map;
        String path = mapping.getPathbuilder().apply(structureList, parameters);

        // Retrieve the objects based on the structure from the source
        JSONArray entries = aggregateEntries(apiHelper, path, parameters,
            requestedLimit, metadata);

        // Create a List of records that will be used to make a RecordList object
        List<Record> recordList = new ArrayList<Record>();
        List<String> fields = request.getFields() == null ? new ArrayList() :
            request.getFields();
        if(entries.isEmpty() != true){
            fields = getFields(fields,
                (JSONObject)((JSONObject)entries.get(0)).get("values"));
            // Iterate through the response objects and make a new Record for each.
            for (Object o : entries) {
                JSONObject obj = (JSONObject)((JSONObject)o).get("values");

                Record record;
                if (obj != null) {
                    record = buildRecord(fields, obj);
                } else {
                    record = new Record();
                }
                // Add the created record to the list of records
                recordList.add(record);
            }
        }

        // Return the RecordList object
        return new RecordList(fields, recordList, metadata);
    }

    /*----------------------------------------------------------------------------------------------
     * HELPER METHODS
     *--------------------------------------------------------------------------------------------*/
    protected List<String> getFields(List<String> fields, JSONObject jsonobj) {
        // if no fields were provided then all fields will be returned. 
        if(fields.isEmpty()){
            fields.addAll(jsonobj.keySet());
        }
        
        return fields;
    }
    
    /**
     * Build a Record.  If no fields are provided all fields will be returned.
     * 
     * @param fields
     * @param jsonobj
     * @return Record
     */
    protected Record buildRecord (List<String> fields, JSONObject jsonobj) {
        JSONObject obj = new JSONObject();
        DocumentContext jsonContext = JsonPath.parse(jsonobj); 
        
        fields.stream().forEach(field -> {
            // either use JsonPath or just add the field value.  We're assuming
            // all JsonPath usages will begin with $[ or $.. 
            if (field.startsWith("$.") || field.startsWith("$[")) {
                try {
                    obj.put(field, jsonContext.read(field));
                } catch (JsonPathException e) {
                    throw new JsonPathException(String.format("There was an issue"
                        + " reading %s", field), e);
                }
            } else {
                obj.put(field, jsonobj.get(field));
            }
        });
        
        Record record = new Record(obj, fields);
        return record;
    }

    /**
     * Set the offset that will be used in subsequent requests for pagination.
     * The next offset advances by the number of records actually returned.
     *
     * @param metadata
     * @param offset
     * @param returnedCount
     */
    protected void setOffset(Map<String, String> metadata, int offset,
        int returnedCount) {

        metadata.put("offset", Integer.toString(offset + returnedCount));
    }

    /**
     * Get the total number of records requested.  A limit greater than 1000
     * signals that the adapter should aggregate paged requests.  Defaults to
     * 1000 when limit is absent, negative, or not a number.  This method does
     * not mutate the parameters Map; the per request limit is set by
     * aggregateEntries.
     *
     * @param parameters
     * @return int
     */
    // TODO: consider if limit is on metadata.
    protected int getRequestedLimit(Map<String, String> parameters) {
        int limit = PAGE_SIZE;
        try {
            if (parameters.containsKey("limit")) {
                limit = Integer.parseInt(parameters.get("limit").trim());
                if (limit < 0) {
                    limit = PAGE_SIZE;
                    LOGGER.debug("limit was outside standard values. Limit set "
                        + "to 1000 default.");
                }
            }
        } catch (NumberFormatException e) {
            limit = PAGE_SIZE;
            LOGGER.error("limit parmaeter must be a number.  limit set to 1000 "
                + "default. ", e);
        }
        return limit;
    }

    /**
     * Fetch entries from the ARS server.  When the requested limit exceeds the
     * single request maximum of 1000 the adapter loops requests in chunks,
     * advancing offset by the number of entries actually returned, and
     * concatenates the results.  Total results are capped by the Max Records
     * property.  This method mutates the limit and offset keys of the
     * parameters Map.  On completion the metadata Map is populated with the
     * next offset and, when the Max Records ceiling cut results short, a
     * truncated indicator.
     *
     * @param apiHelper
     * @param path
     * @param parameters
     * @param requestedLimit
     * @param metadata
     * @return JSONArray
     * @throws BridgeError
     */
    protected JSONArray aggregateEntries(ArsRestV2ApiHelper apiHelper,
        String path, Map<String, String> parameters, int requestedLimit,
        Map<String, String> metadata) throws BridgeError {

        int totalLimit = Math.min(requestedLimit, maxRecords);
        if (requestedLimit > maxRecords) {
            LOGGER.warn("The requested limit of " + requestedLimit + " exceeds "
                + "the Max Records property.  Results will be capped at "
                + maxRecords + ".");
        }
        boolean aggregating = requestedLimit > PAGE_SIZE;

        // Parse the initial offset if one was provided with the request.
        int initialOffset = 0;
        if (parameters.containsKey("offset")) {
            try {
                initialOffset = Integer.parseInt(parameters.get("offset").trim());
            } catch (NumberFormatException e) {
                LOGGER.error("Error parsing int: ", e);
            }
        }
        int offset = initialOffset;

        JSONArray allEntries = new JSONArray();
        boolean exhausted = false;
        boolean firstPage = true;

        do {
            int chunk = Math.min(PAGE_SIZE, totalLimit - allEntries.size());
            parameters.put("limit", Integer.toString(chunk));
            // Leave offset untouched on the first request so single page
            // request urls are unchanged from prior adapter versions.
            if (!firstPage) {
                parameters.put("offset", Integer.toString(offset));
            }
            firstPage = false;

            // Retrieve the objects based on the structure from the source
            JSONObject object = apiHelper.executeRequest(getUrl(path, parameters));

            // Get domain specific data.
            JSONArray entries = (JSONArray)object.get("entries");

            if (entries == null) {
                // Single entry responses (entry_id requests) return a values
                // object instead of an entries array.
                // TODO: consider using mapper for single/multiple similar to
                // kinetic core
                if (object.get("values") != null) {
                    allEntries.add(object);
                }
                exhausted = true;
                break;
            }

            allEntries.addAll(entries);
            offset += entries.size();

            if (entries.size() == 0) {
                // No more results on the server.
                exhausted = true;
            } else if (entries.size() < chunk && !aggregating) {
                // Single request mode never issues a follow up request.  While
                // aggregating a partial page is NOT treated as exhausted
                // because the ARS server may be configured to return fewer
                // records than requested.
                exhausted = true;
            }
        } while (!exhausted && allEntries.size() < totalLimit);

        if (!allEntries.isEmpty()) {
            setOffset(metadata, initialOffset, allEntries.size());
        }
        if (!exhausted && allEntries.size() >= maxRecords) {
            metadata.put("truncated", "true");
            LOGGER.warn("Results were truncated at the Max Records ceiling of "
                + maxRecords + ". Additional matching records may exist on the "
                + "server.");
        }

        return allEntries;
    }
    
    private LinkedHashMap<String, String> 
        getSortOrderItems (Map<String, String> uncastSortOrderItems)
        throws IllegalArgumentException{
        
        /* results of parseOrder does not allow for a structure that 
         * guarantees order.  Casting is required to preserver order.
         */
        if (!(uncastSortOrderItems instanceof LinkedHashMap)) {
            throw new IllegalArgumentException("MESSAGE");
        }
        
        return (LinkedHashMap)uncastSortOrderItems;
    }
        
    /**
     *
     * @param responseData
     * @return
     */
    protected JSONArray getResponseData(Object responseData) {
        JSONArray responseArray = new JSONArray();
        
        if (responseData instanceof JSONArray) {
            responseArray = (JSONArray)responseData;
        }
        else if (responseData instanceof JSONObject) {
            // It's an object
            responseArray.add((JSONObject)responseData);
        }
        
        return responseArray;
    }
    
    /**
     * This helper is intended to abstract the parser get parameters from the core
     * methods.
     * 
     * @param request
     * @param mapping
     * @return
     * @throws BridgeError 
     */
    protected Map<String, String> getParameters(String query,  
        AdapterMapping mapping) throws BridgeError {
        
        Map<String, String> parameters = new HashMap<>();
        if (mapping.getStructure() == "Adhoc") {
            // Adhoc qualifications are two segments. ie path?queryParameters
            String [] segments = query.split("[?]",2);

            // getParameters only needs the queryParameters segment
            if (segments.length > 1) {
                parameters = parser.getParameters(segments[1]);
            }
            // Pass the path along to the functional operator
            parameters.put("adapterPath", segments[0]);
        } else {
            parameters = parser.getParameters(query);
        }
        
        return parameters;
    }
        
    /**
     * This method checks that the structure on the request matches on in the 
     * Mapping internal class.  Mappings map directly to the adapters supported 
     * Structures.  
     * 
     * @param structure
     * @return Mapping
     * @throws BridgeError 
     */
    protected AdapterMapping getMapping (String structure) throws BridgeError{
        AdapterMapping mapping = MAPPINGS.get(structure);
        if (mapping == null) {
            throw new BridgeError("Invalid Structure: '" 
                + structure + "' is not a valid structure.");
        }
        return mapping;
    }
    
    /**
     * Build url for request.  Encode all parameters except the sort parameter.
     * The encoding for sort is done in the addSort method.  Read comment for 
     * explanation.
     * 
     * @param path
     * @param parameters
     * @return String
     */
    protected String getUrl (String path, Map<String, String> parameters) {
                
        String str = parameters.entrySet().stream().map(entry -> {
            if (!entry.getKey().equals("sort")) {
                try {
                    return entry.getKey() + "=" 
                        + URLEncoder.encode(entry.getValue(), "UTF-8");
                } catch (UnsupportedEncodingException e) {
                    LOGGER.error("Error encoding query parameter: " + e);
                }
                return entry.getKey() + "=" + entry.getValue();
            }
            return entry.getKey() + "=" + entry.getValue();
        }).collect(Collectors.joining("&"));
        
        return String.format("%s%s?%s", API_PATH, path, str);
    }
 
    /**
     * Take the sort order from metadata and add it to parameters for use with
     * request.  Encoding field names and joining fields with comma is required
     * due to ARS 9 api behavior.  Encoded commas between field names breaks api 
     * requests. 
     * 
     * @param order
     * @param parameters
     * @return
     * @throws BridgeError 
     */
    protected void addSort(String order, 
        Map<String, String> parameters) throws BridgeError {
        
        LinkedHashMap<String,String> sortOrderItems = getSortOrderItems(
            BridgeUtils.parseOrder(order));
        String str = sortOrderItems.entrySet().stream().map(entry -> {
            String key = "";
            try {
                key = URLEncoder.encode(entry.getKey().trim(), "UTF-8");
            }   catch (UnsupportedEncodingException e) {
                LOGGER.error("Error encoding sort order for field: " 
                    + entry.getKey() + " ", e);
                return "";
            }
            return key + "." + entry.getValue().toLowerCase();

        }).collect(Collectors.joining(","));
        
        parameters.put("sort", str);
    }
    
    /**************************** Path Definitions ****************************/
    /**
     * Build the path for the Deals structure.
     * 
     * @param structureList
     * @param parameters
     * @return 
     * @throws com.kineticdata.bridgehub.adapter.BridgeError 
     */
    protected static String pathEntry(List<String> structureList,
        Map<String, String> parameters) throws BridgeError {

        if (!(structureList.size() > 1)) {
            throw new BridgeError("The Entry structure requires a Form Name.");
        }
        
        String path = String.format("%s/%s","/entry", structureList.get(1));
        if (parameters.containsKey("entry_id")) {
            path = String.format("%s/%s", path, parameters.get("entry_id"));
            parameters.remove("entry_id");
        }

        return path;
    }
    
    /**
     * Build path for Adhoc structure.
     * 
     * @param structureList
     * @param parameters
     * @return
     * @throws BridgeError 
     */
    protected static String pathAdhoc(List<String> structureList,
        Map<String, String> parameters) throws BridgeError {

        // Remove adapterPath so it is not serialized as a query parameter.
        return parameters.remove("adapterPath");
    }

    /**
     * Checks if a parameter exists in the parameters Map.
     * 
     * @param param
     * @param parameters
     * @param structureList
     * @throws BridgeError 
     */
    protected static void checkRequiredParamForStruct(String param,
        Map<String, String> parameters, List<String> structureList)
        throws BridgeError{
        
        if (!parameters.containsKey(param)) {
            String structure = String.join(" > ", structureList);
            throw new BridgeError(String.format("The %s structure requires %s"
                + "parameter.", structure, param));
        }
    }
}
