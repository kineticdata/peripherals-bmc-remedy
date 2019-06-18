package com.kineticdata.filehub.adapters.ars;

import com.bmc.arsys.api.ARException;
import com.bmc.arsys.api.ARServerUser;
import com.bmc.arsys.api.AttachmentValue;
import com.bmc.arsys.api.Constants;
import com.bmc.arsys.api.Entry;
import com.bmc.arsys.api.Field;
import com.bmc.arsys.api.LoggingInfo;
import com.bmc.arsys.api.StatusInfo;
import com.bmc.arsys.api.Timestamp;
import com.bmc.arsys.api.Value;
import static com.google.common.base.Preconditions.checkArgument;
import com.google.common.base.Strings;
import com.google.common.cache.CacheBuilder;
import com.google.common.cache.CacheLoader;
import com.google.common.cache.LoadingCache;
import com.google.common.io.ByteStreams;
import com.google.common.primitives.Ints;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import com.kineticdata.filehub.adapter.FilestoreAdapter;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.TreeMap;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 *
 */
public class ArsFilestoreAdapter implements FilestoreAdapter {

    /** Static class logger. */
    private static final Logger LOGGER = LoggerFactory.getLogger(ArsFilestoreAdapter.class);
    
    /** Defines the adapter display name. */
    public static final String NAME = "ARS";
    
    /** Defines the collection of property names for the adapter. */
    public static class Properties {
        public static final String SERVER = "Server";
        public static final String PORT = "Port";
        public static final String USERNAME = "Username";
        public static final String PASSWORD = "Password";
    }
    
    /** Adapter version constant. */
    public static String VERSION;
    /** Load the properties version from the version.properties file. */
    static {
        try (
            InputStream inputStream = ArsFilestoreAdapter.class.getResourceAsStream(
                "/"+ArsFilestoreAdapter.class.getName()+".version")
        ) {
            java.util.Properties properties = new java.util.Properties();
            properties.load(inputStream);
            VERSION = properties.getProperty("version")+"-"+properties.getProperty("build");
        } catch (IOException e) {
            LOGGER.warn("Unable to load "+ArsFilestoreAdapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }
    
    /** 
     * Specifies the configurable properties for the adapter.  These are populated as part of object
     * construction so that the collection of properties (default values, menu options, etc) are 
     * available before the adapter is configured.  These initial properties can be used to 
     * dynamically generate the list of configurable properties, such as when the Kinetic Filehub
     * application prepares the new Filestore display.
     */
    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.SERVER)
            .setIsRequired(true),
        new ConfigurableProperty(Properties.PORT)
            .setIsRequired(true),
        new ConfigurableProperty(Properties.USERNAME)
            .setIsRequired(true),
        new ConfigurableProperty(Properties.PASSWORD)
            .setIsRequired(false)
            .setIsSensitive(true)
    );
    
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/
    
    private ARServerUser user;
    
    private final LoadingCache<String,AttachmentFieldMap> cache = CacheBuilder.newBuilder()
        .build(new CacheLoader<String,AttachmentFieldMap>() {
            @Override
            public AttachmentFieldMap load(String formName) throws Exception {
                updateLoggingConfig();
                List<Field> fields = user.getListFieldObjects(formName);
                logLastMessages();
                return new AttachmentFieldMap(formName, fields);
            }
        });

    
    /*----------------------------------------------------------------------------------------------
     * CONFIGURATION
     *--------------------------------------------------------------------------------------------*/
    
    /**
     * Initializes the filestore adapter.  This method will be called when the properties are first
     * specified, and when the properties are updated.
     * 
     * @param propertyValues 
     */
    @Override
    public void initialize(Map<String, String> propertyValues) {
        // Set the configurable properties
        properties.setValues(propertyValues);
        user = new ARServerUser();
        user.setServer(propertyValues.get(Properties.SERVER));
        user.setPort(Integer.valueOf(propertyValues.get(Properties.PORT)));
        user.setUser(propertyValues.get(Properties.USERNAME));
        user.setPassword(propertyValues.get(Properties.PASSWORD));
        // Try to configure logging
        LoggingInfo loggingInfo = new LoggingInfo();
        loggingInfo.setType(Constants.AR_DEBUG_SERVER_API | Constants.AR_DEBUG_SERVER_SQL);
        loggingInfo.setWriteToFileOrStatus(Constants.AR_WRITE_TO_STATUS_LIST);
        loggingInfo.enable(false);
        try {
            user.setLogging(loggingInfo);
        }
        catch (ARException e) {
            LOGGER.warn("Failed to enable ARServerUser logging", e);
        }
    }

    /**
     * Returns the display name for the adapter.
     * 
     * @return 
     */
    @Override
    public String getName() {
        return NAME;
    }

    /**
     * Returns the collection of configurable properties for the adapter.
     * 
     * @return 
     */
    @Override
    public ConfigurablePropertyMap getProperties() {
        return properties;
    }
    
    
    /*----------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *--------------------------------------------------------------------------------------------*/

    @Override
    public void deleteDocument(String path) {
        long start = System.currentTimeMillis();
        try {
            // Parse the path
            Route route = new Route(path);
            // Retrieve the field information
            Field field = cache.get(route.getForm()).getField(route.getFieldReference());
            if (field == null) {
                throw new RuntimeException("Unable to retrieve the \""+route.getFieldReference()+"\" "+
                    "field from the \""+route.getForm()+"\" form.");
            }
            // Update the logging to enable/disable the arapi/arsql logging as necessary
            updateLoggingConfig();
            // Retrieve the entry
            Entry entry = user.getEntry(
                route.getForm(), route.getEntryId(), new int[] {field.getFieldID()});
            // Log arapi/arsql log messages if applicable
            logLastMessages();
            // Obtain a reference to the value
            AttachmentValue value = (AttachmentValue)entry.get(field.getFieldID()).getValue();
            // If the field value was found
            if (value != null) {
                // If the filename was specified and does notmatch
                if (route.getFileName() != null && !Objects.equals(route.getFileName(), value.getName())) {
                    LOGGER.debug("The specified filename does not match the current field value."+
                        "\n    Specified: {}\n    Current: {}", route.getFileName(), value.getName());
                    throw new RuntimeException("The specified filename does not match the current "+
                        "field value.");
                }
                // Remove field "1" as it can't be updated; this avoids an ARS WARNING (52) message
                entry.setEntryId(null);
                entry.put(1, null);
                // Clear the value
                entry.put(field.getFieldID(), new Value((AttachmentValue)null));
                // Update the record
                user.setEntry(route.getForm(), route.getEntryId(), entry, new Timestamp(0), 0);
                // Log arapi/arsql log messages if applicable
                logLastMessages();
            }
        } catch (Exception e) {
            throw new RuntimeException("Unable to retrieve document.", e);
        }
        LOGGER.debug("Deleted \"{}\" ({}ms)", path, System.currentTimeMillis()-start);
    }

    @Override
    public ArsDocument getDocument(String path) {
        long start = System.currentTimeMillis();
        ArsDocument result = null;
        try {
            // Parse the path
            Route route = new Route(path);
            // Retrieve the field information
            Field field = cache.get(route.getForm()).getField(route.getFieldReference());
            if (field == null) {
                throw new RuntimeException("Unable to retrieve the \""+route.getFieldReference()+"\" "+
                    "field from the \""+route.getForm()+"\" form.");
            }
            // Update the logging to enable/disable the arapi/arsql logging as necessary
            updateLoggingConfig();
            // Retrieve the entry
            Entry entry = user.getEntry(
                route.getForm(), route.getEntryId(), new int[] {field.getFieldID()});
            // Log arapi/arsql log messages if applicable
            logLastMessages();
            // Obtain a reference to the value
            AttachmentValue value = (AttachmentValue)entry.get(field.getFieldID()).getValue();
            // If the field value was found
            if (value != null) {
                // If the filename was specified and does notmatch
                if (route.getFileName() != null && !Objects.equals(route.getFileName(), value.getName())) {
                    LOGGER.debug("The specified filename does not match the current field value."+
                        "\n    Specified: {}\n    Current: {}", route.getFileName(), value.getName());
                    throw new RuntimeException("The specified filename does not match the current "+
                        "field value.");
                }
                // Set the blob content
                value.setValue(user.getEntryBlob(route.getForm(), route.getEntryId(), field.getFieldID()));
                // Log arapi/arsql log messages if applicable
                logLastMessages();
            }
            // Prepare the result
            result = new ArsDocument(
                route.getForm(), route.getEntryId(), route.getFieldReference(), value);
        } catch (Exception e) {
            throw new RuntimeException("Unable to retrieve document.", e);
        }
        LOGGER.debug("Retrieved \"{}\" ({}ms)", path, System.currentTimeMillis()-start);
        return result;
    }

    @Override
    public List<ArsDocument> getDocuments(String path) throws IOException {
        long start = System.currentTimeMillis();
        List<ArsDocument> results = new ArrayList<>();
        try {
            // Parse the path
            Route route = new Route(path);
            // If the request is for the "root" path
            if (route.getForm() == null) {
                // Add a "DUMMY" document
                results.add(new ArsDocument("FORM_NAME"));
            }
            // If the request is for a "form" path
            else if (route.getEntryId() == null) {
                // Add a "DUMMY" document
                results.add(new ArsDocument(route.getForm(), "ENTRY_ID"));
            }
            // If the request is for a "entry" path
            else if (route.getFieldReference() == null) {
                // Retrieve the field information
                AttachmentFieldMap fieldMap = cache.get(route.getForm());
                // For each of the attachment fields
                for (Field field : fieldMap.getFields()) {
                    // Add a "DUMMY" document
                    results.add(new ArsDocument(route.getForm(), route.getEntryId(), field.getName()));
                }
            }
            // If the request is for a "field" path
            else if (route.getFieldReference() == null) {
                // Retrieve the field information
                Field field = cache.get(route.getForm()).getField(route.getFieldReference());
                if (field == null) {
                    throw new RuntimeException("Unable to retrieve the \""+
                        route.getFieldReference()+"\" field from the \""+route.getForm()+"\" form.");
                }
                // Update the logging to enable/disable the arapi/arsql logging as necessary
                updateLoggingConfig();
                // Retrieve the entry
                Entry entry = user.getEntry(
                    route.getForm(), route.getEntryId(), new int[] {field.getFieldID()});
                // Log arapi/arsql log messages if applicable
                logLastMessages();
                // Obtain a reference to the value
                AttachmentValue value = (AttachmentValue)entry.get(field.getFieldID()).getValue();
                // If the field value was found
                if (value != null) {
                    // Set the blob content
                    value.setValue(user.getEntryBlob(route.getForm(), route.getEntryId(), field.getFieldID()));
                    // Log arapi/arsql log messages if applicable
                    logLastMessages();
                    // Prepare the result
                    results.add(new ArsDocument(
                        route.getForm(), route.getEntryId(), route.getFieldReference(), value));
                }
            }
            // If the request is for a "file" path
            else {
                results.add(getDocument(path));
            }
        } catch (Exception e) {
            throw new RuntimeException("Unable to retrieve document.", e);
        }
        LOGGER.debug("Retrieved \"{}\" ({}ms)", path, System.currentTimeMillis()-start);
        return results;
    }
    
    @Override
    public String getRedirectDelegationUrl(String path, String friendlyFilename) {
        throw new RuntimeException("Redirect delegation is not supported.");
    }

    @Override
    public String getVersion() {
        return VERSION;
    }

    @Override
    public void putDocument(String path, InputStream inputStream, String contentType) {
        long start = System.currentTimeMillis();
        try {
            // Parse the path
            Route route = new Route(path);
            checkArgument(route.getFileName() != null, "Expected document path to be in the "+
                "format of FORM_NAME/ENTRY_ID/ATTACHMENT_FIELD_NAME/FILE_NAME");
            // Retrieve the field information
            Field field = cache.get(route.getForm()).getField(route.getFieldReference());
            if (field == null) {
                throw new RuntimeException("Unable to retrieve the \""+route.getFieldReference()+
                    "\" field from the \""+route.getForm()+"\" form.");
            }
            // Create an entry container with the desired value
            Entry entry = new Entry();
            AttachmentValue value = new AttachmentValue(
                route.getFileName(), ByteStreams.toByteArray(inputStream));
            entry.put(field.getFieldID(), new Value(value));
            // Update the record
            user.setEntry(route.getForm(), route.getEntryId(), entry, new Timestamp(0), 0);
            // Log arapi/arsql log messages if applicable
            logLastMessages();
        } catch (Exception e) {
            throw new RuntimeException("Unable to retrieve document.", e);
        }
        LOGGER.debug("Updated \"{}\" ({}ms)", path, System.currentTimeMillis()-start);
    }

    @Override
    public boolean supportsRedirectDelegation() {
        return false;
    }
    
    /*----------------------------------------------------------------------------------------------
     * HELPER METHODS
     *--------------------------------------------------------------------------------------------*/
    
    public void logLastMessages() {
        List<StatusInfo> messages = user.getLastStatus();
        if (messages != null) {
            for (StatusInfo info : messages) {
                // If the message is server logging turned on for the API
                if (info.getMessageNum() == 8914L) {
                    LOGGER.trace("ARS SERVER LOG (8914):\n    "+
                        info.getMessageText().trim().replaceAll("\\n", "\n    "));
                }
                // If the log is a WARNING message
                else if (Constants.AR_RETURN_WARNING == info.getMessageType()) {
                    StringBuilder builder = new StringBuilder();
                    builder.append("ARS WARNING (").append(info.getMessageNum()).append("): ");
                    builder.append(info.getMessageText());
                    if (!Strings.isNullOrEmpty(info.getAppendedText())) {
                        builder.append(" --- ").append(info.getAppendedText());
                    }
                    // If the info message is for ARS WARNING (66):
                    //   The query matched more than the maximum number of entries specified for retrieval
                    // which is an expected message when doing things like limit=10.  Note that this
                    // is different than ARS WARNING (72):
                    //   The query matched more than the maximum number of entries specified by the server
                    // which will still be logged as a warning message.
                    if (info.getMessageNum() == 66L) {
                        LOGGER.trace(builder.toString());
                    } else {
                        LOGGER.warn(builder.toString());
                    }
                }
                // If the log is a NOTE message
                else if (Constants.AR_RETURN_OK == info.getMessageType()) {
                    StringBuilder builder = new StringBuilder();
                    builder.append("ARS NOTE (").append(+info.getMessageNum()).append("): ");
                    builder.append(info.getMessageText());
                    if (!Strings.isNullOrEmpty(info.getAppendedText())) {
                        builder.append(" --- ").append(info.getAppendedText());
                    }
                    LOGGER.info(builder.toString());
                }
                // If the message type is not an expected value
                else {
                    LOGGER.warn("ARS UNKNOWN TYPE ("+info.getMessageNum()+"): "+info.getMessageText());
                }
            }
        }
    }
    
    public void updateLoggingConfig() throws ARException {
        user.getLogging().enable(LOGGER.isTraceEnabled());
    }
    
    /*----------------------------------------------------------------------------------------------
     * HELPER CLASSES
     *--------------------------------------------------------------------------------------------*/
    
    private static class AttachmentFieldMap {
        private final String form;
        private final Map<String,Field> fieldsById = new TreeMap<>();
        private final Map<String,Field> fieldsByName = new TreeMap<>();
        private final int[] fieldIds;
        public AttachmentFieldMap(String form, List<Field> fields) {
            this.form = form;
            List<Integer> fieldIdsList = new ArrayList<>();
            for (Field field : fields) {
                if (field.getFieldType() == Constants.AR_FIELD_TYPE_ATTACH) {
                    fieldsById.put(String.valueOf(field.getFieldID()), field);
                    fieldsByName.put(field.getName(), field);
                    fieldIdsList.add(field.getFieldID());
                }
            }
            this.fieldIds = Ints.toArray(fieldIdsList);
        }
        public Field getField(String fieldReference) {
            return fieldsById.containsKey(fieldReference) 
                ? fieldsById.get(fieldReference)
                : fieldsByName.get(fieldReference);
        }
        public int[] getFieldIds() {
            return fieldIds;
        }
        public Collection<Field> getFields() {
            return fieldsByName.values();
        }
        public String getForm() {
            return form;
        }
    }
    
    private static class Route {
        private String entryId;
        private String form;
        private String fieldReference;
        private String fileName;
        public Route(String path) {
            String[] parts = Strings.isNullOrEmpty(path) ? new String[0] : path.split("/");
            if (parts.length == 1) {
                form = parts[0];
            } else if (parts.length == 2) {
                form = parts[0];
                entryId = parts[1];
            } else if (parts.length == 3) {
                form = parts[0];
                entryId = parts[1];
                fieldReference = parts[2];
            } else if (parts.length == 4) {
                form = parts[0];
                entryId = parts[1];
                fieldReference = parts[2];
                fileName = parts[3];
            } else if (parts.length > 4) {
                throw new IllegalArgumentException();
            }
        }
        public String getEntryId() {
            return entryId;
        }
        public String getForm() {
            return form;
        }
        public String getFieldReference() {
            return fieldReference;
        }
        public String getFileName() {
            return fileName;
        }
    }
    
}
