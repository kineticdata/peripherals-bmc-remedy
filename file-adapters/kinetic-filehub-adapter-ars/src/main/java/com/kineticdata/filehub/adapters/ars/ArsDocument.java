package com.kineticdata.filehub.adapters.ars;

import com.bmc.arsys.api.AttachmentValue;
import com.kineticdata.filehub.adapter.Document;
import java.io.ByteArrayInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.util.Date;
import org.apache.tika.Tika;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ArsDocument implements Document {

    /** Static class logger. */
    private static final Logger LOGGER = LoggerFactory.getLogger(ArsDocument.class);
    
    private static final String UNKNOWN_CONTENT_TYPE = "application/octet-stream";
    
    private final String form;
    private String field;
    private String id;

    private byte[] content;
    private String name;
    private Long size;
    
    /*----------------------------------------------------------------------------------------------
     * CONSTRUCTORS
     *--------------------------------------------------------------------------------------------*/

    /**
     * Represents all submissions for a form.
     * 
     * @param form 
     */
    public ArsDocument(String form) {
        this.form = form;
    }
    
    /**
     * Represents all attachment fields with values for a given entry.
     * 
     * @param form
     * @param id 
     */
    public ArsDocument(String form, String id) {
        this.form = form;
        this.id = id;
    }
    
    /**
     * Represents the attachment field for a given entry.
     * 
     * @param form
     * @param id 
     * @param field 
     */
    public ArsDocument(String form, String id, String field) {
        this.form = form;
        this.id = id;
        this.field = field;
    }
    
    /**
     * Represents a specific attachment field value for a given entry.
     * 
     * @param form
     * @param id
     * @param field
     * @param value 
     */
    public ArsDocument(String form, String id, String field, AttachmentValue value) {
        this.form = form;
        this.id = id;
        this.field = field;
        this.content = value.getContent() == null ? new byte[0] : value.getContent();
        this.name = value.getName();
        this.size = value.getOriginalSize();
    }
    
    
    /*----------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *--------------------------------------------------------------------------------------------*/
    
    @Override
    public Date getCreatedAt() {
        // ARS does not store the timestamps for attachments, return null to indicate unknown
        return null;
    }

    @Override
    public String getContentType() {
        String result;
        try {
            Tika tika = new Tika();
            result = tika.detect(new ByteArrayInputStream(content), getName());
        } catch (IOException e) {
            LOGGER.trace("Unable to determine file content type.", e);
            result = UNKNOWN_CONTENT_TYPE;
        }
        return result;
    }

    @Override
    public String getName() {
        String result;
        if (name != null) {
            result = name;
        } else if (field != null) {
            result = field;
        } else if (id != null) {
            result = id;
        } else if (form != null) {
            result = form;
        } else {
            result = "/";
        }
        return result;
    }

    @Override
    public String getPath() {
        String result;
        if (name != null) {
            result = form+"/"+id+"/"+field+"/"+name;
        } else if (field != null) {
            result = form+"/"+id+"/"+field;
        } else if (id != null) {
            result = form+"/"+id;
        } else if (form != null) {
            result = form;
        } else {
            result = "";
        }
        return result;
    }

    @Override
    public Long getSizeInBytes() {
        return size;
    }

    @Override
    public Date getUpdatedAt() {
        // ARS does not store the timestamps for attachments, return null to indicate unknown
        return null;
    }

    @Override
    public boolean isFile() {
        return name != null;
    }

    @Override
    public InputStream openStream() throws FileNotFoundException {
        return new ByteArrayInputStream(content);
    }
    
}
