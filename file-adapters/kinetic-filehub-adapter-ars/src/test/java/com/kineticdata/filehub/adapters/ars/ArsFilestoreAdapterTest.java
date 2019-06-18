package com.kineticdata.filehub.adapters.ars;

import com.bmc.arsys.api.ARException;
import com.bmc.arsys.api.AttachmentValue;
import com.bmc.arsys.api.Entry;
import com.bmc.arsys.api.EntryListInfo;
import com.bmc.arsys.api.QualifierInfo;
import com.bmc.arsys.api.Value;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.TreeSet;
import org.apache.tika.io.IOUtils;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import org.junit.Before;
import org.junit.Test;
import testing.kineticdata.filehub.adapters.ars.ArsTestBase;

public class ArsFilestoreAdapterTest extends ArsTestBase {
    
    ArsFilestoreAdapter adapter;
    String entryId;
    
    @Before
    public void beforeEach() throws Exception {
        // Prepare the Adapter
        adapter = new ArsFilestoreAdapter();
        adapter.initialize(new HashMap(properties));
        // Clear the form
        deleteAll("KTEST_FilehubArsAdapter_AttachmentForm");
        // Create a record
        entryId = createAttachmentFormEntry(
            new File("src/test/resources/test-files/content.txt"),
            new File("src/test/resources/test-files/image.png"));
    }
    
    /*----------------------------------------------------------------------------------------------
     * TESTS
     *--------------------------------------------------------------------------------------------*/
    
    @Test
    public void test_deleteDocument() throws Exception {
        String path = "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1";
        adapter.deleteDocument(path);
        Entry entry = retrieveAttachmentFormEntry(entryId);
        assertEquals(null, entry.get(700000001).getValue());
    }
    
    @Test
    public void test_deleteDocument_WithFilename_Matching() throws Exception {
        String path = "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1/content.txt";
        adapter.deleteDocument(path);
        Entry entry = retrieveAttachmentFormEntry(entryId);
        assertEquals(null, entry.get(700000001).getValue());
    }
    
    @Test
    public void test_deleteDocument_WithFilename_NotMatching() throws Exception {
        String path = "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1/wrong.filename";
        Exception exception = null;
        try {
            adapter.deleteDocument(path);
        } catch (Exception e) { exception = e; }
        assertNotNull(exception);
    }
    
    @Test
    public void test_getDocument() throws Exception {
        ArsDocument document = adapter.getDocument(
            "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1");
        assertEquals("text/plain", document.getContentType());
        assertEquals("content.txt", document.getName());
        assertEquals((Long)22L, document.getSizeInBytes());
        assertEquals("This file has content.", IOUtils.toString(document.openStream()));
    }
    
    @Test
    public void test_getDocument_WithFilename_Matching() throws Exception {
        ArsDocument document = adapter.getDocument(
            "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1/content.txt");
        assertEquals("text/plain", document.getContentType());
        assertEquals("content.txt", document.getName());
        assertEquals((Long)22L, document.getSizeInBytes());
        assertEquals("This file has content.", IOUtils.toString(document.openStream()));
    }
    
    @Test
    public void test_getDocument_WithFilename_NotMatching() throws Exception {
        Exception exception = null;
        try {
            adapter.getDocument(
            "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1/wrong.filename");
        } catch (Exception e) { exception = e; }
        assertNotNull(exception);
    }
    
    @Test
    public void test_getDocuments() throws Exception {
        List<ArsDocument> documents = adapter.getDocuments("");
        assertEquals(Arrays.asList("FORM_NAME"), getNames(documents));
    }
    
    @Test
    public void test_getDocuments_ByForm() throws Exception {
        List<ArsDocument> documents = adapter.getDocuments(
            "KTEST_FilehubArsAdapter_AttachmentForm");
        assertEquals(Arrays.asList("ENTRY_ID"), getNames(documents));
    }
    
    @Test
    public void test_getDocuments_ByFormEntry() throws Exception {
        List<ArsDocument> documents = adapter.getDocuments(
            "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId);
        assertEquals(2, documents.size());
        TreeSet<String> expectedDocumentNames = new TreeSet<String>() {{
            add("Attachment 1");
            add("Attachment 2");
        }};
        TreeSet<String> actualDocumentNames = new TreeSet<>();
        for (ArsDocument document : documents) {
            actualDocumentNames.add(document.getName());
        }
        assertEquals(expectedDocumentNames, actualDocumentNames);
    }
    
    @Test
    public void test_getDocuments_ByFormEntryField() throws Exception {
        List<ArsDocument> documents = adapter.getDocuments(
            "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1");
        assertEquals(1, documents.size());
        TreeSet<String> expectedDocumentNames = new TreeSet<String>() {{
            add("content.txt");
        }};
        TreeSet<String> actualDocumentNames = new TreeSet<>();
        for (ArsDocument document : documents) {
            actualDocumentNames.add(document.getName());
        }
        assertEquals(expectedDocumentNames, actualDocumentNames);
    }
    
    @Test
    public void test_getDocuments_ByFormEntryFieldFile() throws Exception {
        List<ArsDocument> documents = adapter.getDocuments(
            "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1/content.txt");
        assertEquals(1, documents.size());
        TreeSet<String> expectedDocumentNames = new TreeSet<String>() {{
            add("content.txt");
        }};
        TreeSet<String> actualDocumentNames = new TreeSet<>();
        for (ArsDocument document : documents) {
            actualDocumentNames.add(document.getName());
        }
        assertEquals(expectedDocumentNames, actualDocumentNames);
    }
    
    @Test
    public void test_putDocument() throws Exception {
        String path = "KTEST_FilehubArsAdapter_AttachmentForm/"+entryId+"/Attachment 1/newfile";
        adapter.putDocument(
            path, new FileInputStream("src/test/resources/test-files/content"), "text/plain");
        
        ArsDocument document = adapter.getDocument(path);
        assertEquals("text/plain", document.getContentType());
        assertEquals("newfile", document.getName());
        assertEquals((Long)22L, document.getSizeInBytes());
        assertEquals("This file has content.", IOUtils.toString(document.openStream()));
    }
    
    /*----------------------------------------------------------------------------------------------
     * HELPER METHODS
     *--------------------------------------------------------------------------------------------*/
    
    private String createAttachmentFormEntry(File attachment1, File attachment2) 
    throws ARException, IOException {
        Entry entry = new Entry();
        entry.put(2, new Value(ArsFilestoreAdapterTest.class.getSimpleName()));
        if (attachment1 != null) {
            entry.put(700000001, new Value(new AttachmentValue(attachment1.getName(), attachment1.getPath())));
        }
        if (attachment2 != null) {
            entry.put(700000002, new Value(new AttachmentValue(attachment2.getName(), attachment2.getPath())));
        }
        String id = user.createEntry("KTEST_FilehubArsAdapter_AttachmentForm", entry);
        return id;
    }

    private void deleteAll(String form) throws Exception {
        QualifierInfo qualification = user.parseQualification(form, "'1'>0");
        
        List<EntryListInfo> entries = user.getListEntry(
            form, 
            qualification,
            0, // Offset
            0, // Limit
            null, // Sort order
            Collections.EMPTY_LIST, // Fields
            false, // Use Locale
            null // OutputInteger
        );
        
        for (EntryListInfo entry : entries) {
            user.deleteEntry(form, entry.getEntryID(), 0);
        }
    }
    
    private List<String> getNames(List<ArsDocument> documents) {
        List<String> results = new ArrayList<>();
        for (ArsDocument document : documents) {
            results.add(document.getName());
        }
        return results;
    }

    private Entry retrieveAttachmentFormEntry(String entryId) throws ARException {
        return user.getEntry(
            "KTEST_FilehubArsAdapter_AttachmentForm", entryId, new int[] {700000001, 700000002});
    }
    
}
