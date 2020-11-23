package com.kineticdata.bridgehub.adapter.ars.rest;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.bridgehub.adapter.ars.rest.ArsRestAdapter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.Test;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

public class ArsRestV1Test extends BridgeAdapterTestBase{
        
    @Override
    public Class getAdapterClass() {
        return ArsRestAdapter.class;
    }
    
    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-v1-config.yml";
    }
    
    @Test
    public void test_count() throws Exception{
        BridgeError error = null;
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("id");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Entry");
        request.setFields(fields);
        request.setQuery("entry/CTM:People?q='Remedy Login ID'=\"<%=parameter[\"Id\"]%>\"");
        
        Map parameters = new HashMap();
        parameters.put("Id", "kinetic_integration_user");
        request.setParameters(parameters);
        
        Count count = null;
        try {
            count = getAdapter().count(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(count.getValue() > 0);
    }
    
    @Test
    public void test_invalid_field() throws Exception{
        BridgeError error = null;

        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("id");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Entry");
        request.setFields(fields);
        request.setQuery("entry/CTM:People?q='Remedy Login sID'=\"<%=parameter[\"Id\"]%>\"");
        
        Map parameters = new HashMap();
        parameters.put("Id", "_tiggebz");
        request.setParameters(parameters);
        
        error = null;
        try {
            getAdapter().count(request);
        } catch (BridgeError e) {
            error = e;
        }
        assertNotNull(error);
        
         error = null;
        try {
            getAdapter().retrieve(request);
        } catch (BridgeError e) {
            error = e;
        }
        assertNotNull(error);

        error = null;
        try {
            getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }
        assertNotNull(error);
    }
    
    @Test
    public void test_retrieve() throws Exception{
        BridgeError error = null;
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Entry");
        request.setFields(fields);
        request.setQuery("entry/CST:CHSAttributes/000000000003430/attach/Schematic");
        
        Record record = null;
        try {
            record =  getAdapter().retrieve(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_retrieve_single() throws Exception{
        BridgeError error = null;
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("Hourly Rate");
        fields.add("Last Modified Date");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Entry");
        request.setFields(fields);
        request.setQuery("entry/CTM:People?q='Remedy Login ID'=\"<%=parameter[\"Login ID\"]%>\"");
        
        Map parameters = new HashMap();
        parameters.put("Login ID", "marcin.zarycki@kineticdata.com");
        request.setParameters(parameters);
        
        Record record = null;
        try {
            record =  getAdapter().retrieve(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(record.getRecord().size() > 0);
    }
    
    @Test
    public void test_search() throws Exception{
        BridgeError error = null;
        
        assertNull(error);
        
        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("First Name");
        fields.add("Last Name");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Entry");
        request.setFields(fields);
        request.setQuery("entry/CTM:People");
        
        RecordList records = null;
        try {
            records = getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_sort() throws Exception{
        BridgeError error = null;

        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("First Name");
        fields.add("Last Name");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Entry");
        request.setFields(fields);
        request.setQuery("entry/CTM:People?sort=Last+Name.desc,First+Name.desc");
        
        RecordList records = null;
        try {
            records = getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(records.getRecords().size() > 0);
    }
   
    @Test
    public void test_search_sort_metadata() throws Exception{
        BridgeError error = null;

        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("First Name");
        fields.add("Last Name");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Entry");
        request.setFields(fields);
        request.setQuery("entry/CTM:People");
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"Last Name\"]%>:DESC");       
        request.setMetadata(metadata);
        
        RecordList records = null;
        try {
            records = getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_search_sort_metadata_2() throws Exception{
        BridgeError error = null;

        // Create the Bridge Request
        List<String> fields = new ArrayList<String>();
        fields.add("First Name");
        fields.add("Last Name");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Entry");
        request.setFields(fields);
        request.setQuery("entry/CTM:People");
        
        Map <String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"Last Name\"]%>:DESC"
            + ",<%=field[\"First Name\"]%>:DESC");       
        request.setMetadata(metadata);
        
        RecordList records = null;
        try {
            records = getAdapter().search(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertTrue(records.getRecords().size() > 0);
    }
    
    @Test
    public void test_setOffset() {
        ArsRestAdapter adapter = new ArsRestAdapter();
        
        Map<String, String> metadata = new HashMap<>();
        Map<String, String> parameters = new HashMap<>();
        
        // It is expected that limit is already set.
        parameters.put("limit", "1000");
        
        // Test that metadata and parameters don't have offset.
        adapter.setOffset(metadata, parameters);
        assertTrue(Integer.parseInt(metadata.get("offset")) == 1001);
        
        // Test that offset in metadata adjust results by limit (1000).
        metadata.put("offset", "1001");
        adapter.setOffset(metadata, parameters);
        assertTrue(Integer.parseInt(metadata.get("offset")) == 2002);
        
        // Test that parameters have precedence over metadata and that offset
        // adjust results by limit (1000)
        parameters.put("offset", "1001");
        adapter.setOffset(metadata, parameters);
        assertTrue(Integer.parseInt(metadata.get("offset")) == 2002);        
    }
    
    @Test
    public void test_sortOrder() throws BridgeError{
        ArsRestAdapter adapter = new ArsRestAdapter();
        
        String order = "<%=field[\"Last Name\"]%>:DESC,"
            + "<%=field[\"First Name\"]%>:DESC";
        Map<String, String> parameters = new HashMap<>();
        
        String control = "Last+Name.desc,First+Name.desc";
        adapter.addSort(order, parameters);      
        assertTrue(control.equals(parameters.get("sort"))); 
        
        // Test that field names are encoded.
        control = "Last Name.desc,First Name.desc";
        assertFalse(control.equals(parameters.get("sort")));
        
        // Test that sort order is respected.
        control = "First+Name.desc,Last+Name.desc";
        assertFalse(control.equals(parameters.get("sort")));
    }
}