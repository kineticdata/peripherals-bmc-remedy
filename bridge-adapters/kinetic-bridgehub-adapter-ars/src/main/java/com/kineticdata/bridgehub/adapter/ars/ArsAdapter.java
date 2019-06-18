package com.kineticdata.bridgehub.adapter.ars;

import com.bmc.arsys.api.ARException;
import com.bmc.arsys.api.CharacterFieldLimit;
import com.bmc.arsys.api.Constants;
import com.bmc.arsys.api.DataType;
import com.bmc.arsys.api.Field;
import com.bmc.arsys.api.FieldCriteria;
import com.bmc.arsys.api.Form;
import com.bmc.arsys.api.FormCriteria;
import com.bmc.arsys.api.StatusInfo;
import com.kd.arsHelpers.ArsHelper;
import com.kd.arsHelpers.ArsPrecisionHelper;
import com.kd.arsHelpers.HelperContext;
import com.kd.arsHelpers.RecordCount;
import com.kd.arsHelpers.SimpleEntry;
import com.kd.arsHelpers.caching.FormCache;
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
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TimeZone;
import org.slf4j.LoggerFactory;

/**
 *
 */
public class ArsAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/
    
    /** Defines the adapter display name. */
    public static final String NAME = "Ars Bridge";
    
    /** Defines the logger */
    private static final org.slf4j.Logger logger = LoggerFactory.getLogger(ArsAdapter.class);
    
    /** Adapter version constant. */
    public static String VERSION;
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(ArsAdapter.class.getResourceAsStream("/"+ArsAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+ArsAdapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }
    
    // Define the date formats
    public static final String ARS_DATE_FORMAT = "MM/dd/yyyy HH:mm:ss";
    public static final String DATE_FORMAT = "yyyy-MM-dd'T'HH:mm:ssZ";
    
    // Declare the instance variables
    private ArsPrecisionHelper helper;
    private HelperContext helperContext;
    /**
     * Map of form names to fieldMaps.  This is used to avoid querying for the
     * form field definitions every time a bridge request is made.
     */
    private Map<String,FieldMap> fieldMaps = new LinkedHashMap<String,FieldMap>();
    
    /** Defines the collection of property names for the adapter. */
    public static class Properties {
        // Specify the property name constants
        public static final String USERNAME = "Username";
        public static final String PASSWORD = "Password";
        public static final String SERVER = "Server";
        public static final String PORT = "Port";
        public static final String PROGNUM = "Prognum";
    }
    
    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
            new ConfigurableProperty(Properties.USERNAME).setValue("Demo").setIsRequired(true),
            new ConfigurableProperty(Properties.PASSWORD).setIsSensitive(true),
            new ConfigurableProperty(Properties.SERVER).setValue("127.0.0.1").setIsRequired(true),
            new ConfigurableProperty(Properties.PORT).setValue("0"),
            new ConfigurableProperty(Properties.PROGNUM).setValue("0")
    );
    
    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/
    @Override
    public String getName() {
        return NAME;
    }
    
    @Override
    public String getVersion() {
       return  VERSION;
    }
    
    @Override
    public ConfigurablePropertyMap getProperties() {
        return properties;
    }
    
    @Override
    public void setProperties(Map<String,String> parameters) {
        properties.setValues(parameters);
    }
     
    @Override
    public void initialize() throws BridgeError {
        // Retrieve the necessary configuration values
        String username = properties.getValue(Properties.USERNAME);
        String password = properties.getValue(Properties.PASSWORD);
        String server = properties.getValue(Properties.SERVER);
        String portString = properties.getValue(Properties.PORT);
        String prognumString = properties.getValue(Properties.PROGNUM);

        // Default the configuration values
        int port = 0;
        int prognum = 0;

        // Validate the configuration
        if (portString != null) {
            try {
                port = Integer.parseInt(portString);
            } catch (NumberFormatException e) {
                throw new BridgeError("The 'port' configuration parameter is not a valid integer: \""+portString+"\".", e);
            }
        }
        if (prognumString != null) {
            try {
                prognum = Integer.parseInt(prognumString);
            } catch (NumberFormatException e) {
                throw new BridgeError("The 'prognum' configuration parameter is not a valid integer: \""+prognumString+"\".", e);
            }
        }

        // Initialize the helper
        try {
            this.helperContext = new HelperContext(username, password, server, port, prognum);
            this.helperContext.setTimezoneOffset(0);

            // Initialize a global form cache
            FormCache globalCache = new FormCache(helperContext);
            // Set the global cache
            ArsHelper.setGlobalFormCache(globalCache);
            ArsPrecisionHelper.setGlobalFormCache(globalCache);

            // Initialize a new helper
            this.helper = new ArsPrecisionHelper(this.helperContext);
        } catch (Exception e) {
            throw new BridgeError("Unable to initialize the bridge, "+
                "there was a problem instantiating the ARS context.", e);
        }
        
        // Verify the configuration
        try {
            this.helperContext.getContext().login();
        } catch (Exception e) {
            throw new BridgeError("Invalid bridge configuration.", e);
        }
    }
    
    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/
    
    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        // Build the qualification
        String qualification = buildQualification(request.getQuery(), request.getParameters());
        
        logger.trace("  Query with parameter values: " + qualification);

        // Try to retrieve the count
        Integer count;
        try {
            // Retrieve the count
            count = helper.getEntryCount(request.getStructure(), qualification);
        } catch (ARException e) {
            throw buildArBridgeException(e);
        } catch (Exception e) {
            throw new BridgeError(e.getMessage(), e);
        }
        
        return new Count(count);
    }
    
    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        // Build the qualification
        String qualification = buildQualification(request.getQuery(), request.getParameters());
        
        logger.trace("  Query with parameter values: "+ qualification);
        
        // Build the included field ids
        String[] includedFieldIds = buildFieldIdArray(request.getStructure(), request.getFields());

        // Try to retrieve the entries
        SimpleEntry entry;
        try {
            // Retrieve the Simple Entries
            entry = helper.getSingleSimpleEntry(request.getStructure(), qualification, includedFieldIds);
        } catch (ARException e) {
            throw buildArBridgeException(e);
        } catch (Exception e) {
            throw new BridgeError(e.getMessage(), e);
        }
        
        // buildAttributesMap returns as a Map<String,String>, but we cast it to a Map<String,Object>
        // so that we can use it in the constructor for Record();
        Map<String,Object> record = (Map)buildAttributesMap(request.getStructure(), entry);
        return new Record(record);
    }
    
    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        Map<String,String> metadata = BridgeUtils.normalizePaginationMetadata(request.getMetadata());

        // Build the qualification
        String qualification = buildQualification(request.getQuery(), request.getParameters());
        
        logger.trace("  Query with parameter values: "+ qualification);
        logger.trace("  Searching for "+metadata.get("pageSize")+" records starting at "+metadata.get("offset")+".");
        
        // Build the included field ids
        String[] includedFieldIds = buildFieldIdArray(request.getStructure(), request.getFields());

        // Retrieve the field map
        FieldMap fieldMap = getFieldMap(request.getStructure());
        // Build the sort fields
        LinkedHashMap<String,String> sortFields = new LinkedHashMap<String,String>();
        if (request.getMetadata("order") == null) {
            if (includedFieldIds != null) {
                for (String fieldName : request.getFields()) {
                    Field field = fieldMap.getField(fieldName);
                    // Limit sorting to just on Integer, Real, Char, Decimal, and Enum fields
                    //   - If the field type is a Decimal, Enum, Integer, or Real just add as a sortField.
                    //   - If the field type is a Char, make sure it isn't a 0 length field before adding
                    //     it to the sortFields map
                    int type = field.getDataType();
                    if (type == DataType.DECIMAL.toInt() || type == DataType.ENUM.toInt() 
                            || type == DataType.INTEGER.toInt() || type == DataType.REAL.toInt()) {
                        sortFields.put(fieldMap.getFieldId(fieldName), "ASC");
                    } else if (type == DataType.CHAR.toInt()) {
                        CharacterFieldLimit cFieldLimit = (CharacterFieldLimit)field.getFieldLimit();
                        if (cFieldLimit.getMaxLength() > 0) {
                            sortFields.put(fieldMap.getFieldId(fieldName), "ASC");
                        }
                    }
                }
            }
        } else {
            // For each of the order items
            for (Map.Entry<String,String> entry : BridgeUtils.parseOrder(request.getMetadata("order")).entrySet()) {
                String fieldId = fieldMap.getFieldId(entry.getKey());
                if (fieldId == null) {
                    throw new BridgeError("The specified sort field does not exist on the '"+
                        request.getStructure()+"' form: "+entry.getKey());
                } else {
                    sortFields.put(fieldId, entry.getValue());
                }
            }
        }

        // Try to retrieve the entries
        RecordCount count = new RecordCount();
        SimpleEntry[] entries;
        try {
            // Retrieve the Simple Entries
            long start = System.currentTimeMillis();
            logger.debug("Starting search: "+qualification);
            entries = helper.getSimpleEntryList(request.getStructure(), qualification, includedFieldIds, sortFields, Integer.valueOf(metadata.get("pageSize")), 
                    Integer.valueOf(metadata.get("offset")), count);
            logger.debug("Complete search: "+(System.currentTimeMillis()-start));
        } catch (ARException e) {
            throw buildArBridgeException(e);
        } catch (Exception e) {
            throw new BridgeError(e.getMessage(), e);
        }
        //
        List<String> fields = request.getFields();
        if (fields == null) {
            fields = fieldMap.getFieldNames();
        }

        // Build the records objects
        List<Record> records = new ArrayList<Record>();
        for(SimpleEntry entry : entries) {
            // buildAttributesMap returns as a Map<String,String>, but we cast it to a Map<String,Object>
            // so that we can use it in the constructor for Record();
            Map<String,Object> record = (Map)buildAttributesMap(request.getStructure(), entry);
            records.add(new Record(record));
        }
        
        return new RecordList(fields, records);
    }
    
    
    /*---------------------------------------------------------------------------------------------
     * HELPER METHODS
     *-------------------------------------------------------------------------------------------*/
    
    private BridgeError buildArBridgeException(ARException e) {
        StringBuilder message = new StringBuilder();
        List<StatusInfo> infos = e.getLastStatus();
        for(StatusInfo info : infos) {
            message.append("MessageNum: ").append(info.getMessageNum()).append(", ");
            message.append("MessageText: ").append(info.getMessageText()).append(", ");
            message.append("AppendedText: ").append(info.getAppendedText());
        }
        return new BridgeError(message.toString(), e);
    }

    private Map<String,String> buildAttributesMap(String formName, SimpleEntry entry) throws BridgeError {
        Map<String,String> attributeMap = null;
        if (entry != null) {
            attributeMap = new LinkedHashMap<String,String>();
            FieldMap fieldMap = getFieldMap(formName);
            for (String fieldId : (Set<String>)entry.getEntryItems().keySet()) {
                String value = entry.getEntryFieldValue(fieldId);
                String type = entry.getEntryFieldType(fieldId);
                if ("TIME".equals(type)) {
                    if (value != null && !"".equals(value)) {
                        Calendar calendar = new GregorianCalendar(TimeZone.getTimeZone("GMT"));
                        SimpleDateFormat arsFormat = new SimpleDateFormat(ARS_DATE_FORMAT);
                        arsFormat.setCalendar(calendar);
                        SimpleDateFormat iso8601Format = new SimpleDateFormat(DATE_FORMAT);
                        iso8601Format.setCalendar(calendar);

                        try {
                            Date date = arsFormat.parse(value);
                            value = iso8601Format.format(date);
                        } catch (java.text.ParseException e) {
                            throw new BridgeError("Unable to parse date value: "+value, e);
                        }
                    }
                } else {
                    value = entry.getEntryFieldValue(fieldId);
                }

                attributeMap.put(fieldMap.getFieldName(fieldId), value);
            }
        }
        return attributeMap;
    }

    private String[] buildFieldIdArray(String formName, List<String> fieldNames) throws BridgeError {
        FieldMap fieldMap = getFieldMap(formName);
        String[] results = null;
        if(fieldNames != null && !fieldNames.isEmpty()) {
            results = new String[fieldNames.size()];
            for(int i=0;i<results.length;i++) {
                String fieldId = fieldMap.getFieldId(fieldNames.get(i));
                if (fieldId == null) {
                    throw new BridgeError("Unable to retrieve the '"+
                        fieldNames.get(i)+"' field from the '"+formName+"' form.");
                } else {
                    results[i] = fieldId;
                }
            }
        }
        return results;
    }

    private String buildQualification(String query, Map<String,String> parameters) throws BridgeError {
        ArsQualificationParser parser = new ArsQualificationParser();
        String qualification = parser.parse(query, parameters);
        return qualification;
    }


    private FieldMap getFieldMap(String formName) {
        FieldMap fieldMap = fieldMaps.get(formName);
        if (fieldMap == null) {
            try {
                logger.debug("Retrieving field information for: "+formName);
                // Initialize the map
                fieldMap = new FieldMap();
                // Validate the form exists
                FormCriteria formCriteria = new FormCriteria();
                formCriteria.setRetrieveAll(false);
                formCriteria.setPropertiesToRetrieve(FormCriteria.NAME);
                Form form = helperContext.getContext().getForm(formName, formCriteria);
                if (form == null) {
                    throw new RuntimeException("The specified ARS form does not exist: "+formName);
                }

                // Initialize a FieldCriteria object to return only the field id and field name properties
                FieldCriteria fieldCriteria = new FieldCriteria();
                fieldCriteria.setPropertiesToRetrieve(FieldCriteria.FIELD_MAP | FieldCriteria.FIELD_NAME | FieldCriteria.LIMIT);
                // Retrieve the field id and field names all of the fields on the specified form
                List<Field> fields = helperContext.getContext().getListFieldObjects(formName, Constants.AR_FIELD_TYPE_ALL, 0, fieldCriteria);
                // For each of the fields
                for (Field field : fields) {
                    logger.trace("  "+field.getFieldID()+": "+field.getName());
                    fieldMap.addField(field);
                }
                // Store the field map in the cached field maps
                fieldMaps.put(formName, fieldMap);
            } catch (Exception e) {
                throw new RuntimeException("There was a problem retrieving the field definition from Ars.", e);
            }
        }
        return fieldMap;
    }

    private static class FieldMap {
        private Map<String,String> idToNameMap = new LinkedHashMap<String,String>();
        private Map<String,String> nameToIdMap = new LinkedHashMap<String,String>();
        private Map<String,Field> nameToFieldMap = new LinkedHashMap<String,Field>();

        public void addField(Field field) {
            String fieldId = String.valueOf(field.getFieldID());
            String fieldName = String.valueOf(field.getName());
            
            idToNameMap.put(fieldId, fieldName);
            nameToIdMap.put(fieldName, fieldId);
            nameToFieldMap.put(fieldName, field);
        }

        public String getFieldId(String fieldName) {
            return nameToIdMap.get(fieldName);
        }

        public String getFieldName(String fieldId) {
            return idToNameMap.get(fieldId);
        }
        
        public Field getField(String fieldName) {
            return nameToFieldMap.get(fieldName);
        }

        public List<String> getFieldNames() {
            return new ArrayList<String>(nameToIdMap.keySet());
        }
    }
}
