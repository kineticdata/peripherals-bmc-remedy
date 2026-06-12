package com.kineticdata.bridgehub.adapter.ars.rest;

import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.RecordList;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import org.junit.Test;

/**
 * Unit tests for the request aggregation behavior added in v2.1.0.  These
 * tests stub the api helper so no live ARS server is required.
 */
public class ArsRestV2AggregationTest {

    /**
     * Stub helper that records request urls and replays queued responses.
     */
    private static class StubApiHelper extends ArsRestV2ApiHelper {
        final List<String> urls = new ArrayList<>();
        final Deque<JSONObject> responses = new ArrayDeque<>();

        StubApiHelper() {
            super("http://stub", "user", "pass");
        }

        @Override
        public JSONObject executeRequest(String path) {
            urls.add(path);
            return responses.removeFirst();
        }
    }

    // Build a response page containing n entries.
    private static JSONObject buildPage(int n) {
        JSONArray entries = new JSONArray();
        for (int i = 0; i < n; i++) {
            JSONObject values = new JSONObject();
            values.put("First Name", "Foo" + i);
            JSONObject entry = new JSONObject();
            entry.put("values", values);
            entries.add(entry);
        }
        JSONObject page = new JSONObject();
        page.put("entries", entries);
        return page;
    }

    private static ArsRestV2Adapter buildAdapter(StubApiHelper stub) {
        ArsRestV2Adapter adapter = new ArsRestV2Adapter();
        adapter.apiHelper = stub;
        return adapter;
    }

    private static BridgeRequest buildRequest(String structure, String query) {
        BridgeRequest request = new BridgeRequest();
        request.setStructure(structure);
        request.setFields(new ArrayList<String>());
        request.setQuery(query);
        return request;
    }

    @Test
    public void test_search_single_page_default_limit() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(3));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        RecordList records = adapter.search(buildRequest("Entry > Foo", ""));

        assertEquals(1, stub.urls.size());
        assertTrue(stub.urls.get(0).contains("limit=1000"));
        assertFalse(stub.urls.get(0).contains("offset="));
        assertEquals(3, records.getRecords().size());
        assertEquals("3", records.getMetadata().get("offset"));
        assertNull(records.getMetadata().get("truncated"));
    }

    @Test
    public void test_search_limit_under_1000_single_request() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(50));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        RecordList records = adapter.search(buildRequest("Entry > Foo", "limit=50"));

        // A full page at or below 1000 must never trigger a follow up request.
        assertEquals(1, stub.urls.size());
        assertTrue(stub.urls.get(0).contains("limit=50"));
        assertEquals(50, records.getRecords().size());
        assertEquals("50", records.getMetadata().get("offset"));
    }

    @Test
    public void test_search_aggregates_multiple_pages() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(500));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        RecordList records = adapter.search(buildRequest("Entry > Foo", "limit=2500"));

        assertEquals(3, stub.urls.size());
        assertTrue(stub.urls.get(0).contains("limit=1000"));
        assertFalse(stub.urls.get(0).contains("offset="));
        assertTrue(stub.urls.get(1).contains("limit=1000"));
        assertTrue(stub.urls.get(1).contains("offset=1000"));
        assertTrue(stub.urls.get(2).contains("limit=500"));
        assertTrue(stub.urls.get(2).contains("offset=2000"));
        assertEquals(2500, records.getRecords().size());
        assertEquals("2500", records.getMetadata().get("offset"));
        assertNull(records.getMetadata().get("truncated"));
    }

    @Test
    public void test_search_aggregation_stops_when_exhausted() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(700));
        stub.responses.add(buildPage(0));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        RecordList records = adapter.search(buildRequest("Entry > Foo", "limit=5000"));

        // The partial page does not stop aggregation; the empty page does.
        assertEquals(3, stub.urls.size());
        assertTrue(stub.urls.get(2).contains("offset=1700"));
        assertEquals(1700, records.getRecords().size());
        assertEquals("1700", records.getMetadata().get("offset"));
        assertNull(records.getMetadata().get("truncated"));
    }

    @Test
    public void test_search_max_records_ceiling_truncates() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(1000));
        ArsRestV2Adapter adapter = buildAdapter(stub);
        adapter.maxRecords = 2000;

        RecordList records = adapter.search(buildRequest("Entry > Foo", "limit=5000"));

        assertEquals(2, stub.urls.size());
        assertEquals(2000, records.getRecords().size());
        assertEquals("true", records.getMetadata().get("truncated"));
        assertEquals("2000", records.getMetadata().get("offset"));
    }

    @Test
    public void test_search_initial_offset_honored() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(1000));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        RecordList records = adapter.search(
            buildRequest("Entry > Foo", "offset=500&limit=2000"));

        assertEquals(2, stub.urls.size());
        assertTrue(stub.urls.get(0).contains("offset=500"));
        assertTrue(stub.urls.get(1).contains("offset=1500"));
        assertEquals(2000, records.getRecords().size());
        assertEquals("2500", records.getMetadata().get("offset"));
    }

    @Test
    public void test_search_server_capped_pages_continue() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(500));
        stub.responses.add(buildPage(500));
        stub.responses.add(buildPage(500));
        stub.responses.add(buildPage(500));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        RecordList records = adapter.search(buildRequest("Entry > Foo", "limit=2000"));

        // A server configured to return fewer records than requested must not
        // end aggregation early.
        assertEquals(4, stub.urls.size());
        assertTrue(stub.urls.get(1).contains("offset=500"));
        assertTrue(stub.urls.get(2).contains("offset=1000"));
        assertTrue(stub.urls.get(3).contains("offset=1500"));
        assertEquals(2000, records.getRecords().size());
        assertEquals("2000", records.getMetadata().get("offset"));
    }

    @Test
    public void test_search_order_metadata_applies_sort() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(2));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        BridgeRequest request = buildRequest("Entry > Foo", "");
        Map<String, String> metadata = new HashMap<>();
        metadata.put("order", "<%=field[\"Last Name\"]%>:DESC");
        request.setMetadata(metadata);

        adapter.search(request);

        // Previously dead code: order metadata was checked after the metadata
        // map was cleared and never produced a sort.
        assertTrue(stub.urls.get(0).contains("sort=Last+Name.desc"));
    }

    @Test
    public void test_search_adhoc_aggregation_clean_url() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(500));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        RecordList records = adapter.search(
            buildRequest("Adhoc", "/entry/Foo?limit=1500"));

        assertEquals(2, stub.urls.size());
        for (String url : stub.urls) {
            assertTrue(url.startsWith("/api/arsys/v1/entry/Foo?"));
            assertFalse(url.contains("adapterPath"));
        }
        assertEquals(1500, records.getRecords().size());
    }

    @Test
    public void test_count_loops_all_pages() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(250));
        stub.responses.add(buildPage(0));
        ArsRestV2Adapter adapter = buildAdapter(stub);

        Count count = adapter.count(buildRequest("Entry > Foo", ""));

        // The partial page does not stop the count; the empty page does.
        assertEquals(4, stub.urls.size());
        assertEquals(Integer.valueOf(2250), count.getValue());
    }

    @Test
    public void test_count_ceiling_truncated() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        stub.responses.add(buildPage(1000));
        stub.responses.add(buildPage(500));
        ArsRestV2Adapter adapter = buildAdapter(stub);
        adapter.maxRecords = 1500;

        Count count = adapter.count(buildRequest("Entry > Foo", ""));

        assertEquals(2, stub.urls.size());
        assertEquals(Integer.valueOf(1500), count.getValue());
        assertEquals("true", count.getMetadata().get("truncated"));
    }

    @Test
    public void test_count_single_entry_values_response() throws BridgeError {
        StubApiHelper stub = new StubApiHelper();
        JSONObject values = new JSONObject();
        values.put("First Name", "Foo");
        JSONObject single = new JSONObject();
        single.put("values", values);
        stub.responses.add(single);
        ArsRestV2Adapter adapter = buildAdapter(stub);

        Count count = adapter.count(buildRequest("Entry > Foo", "entry_id=PPL000000000309"));

        assertEquals(1, stub.urls.size());
        assertEquals(Integer.valueOf(1), count.getValue());
    }

    @Test
    public void test_get_requested_limit() {
        ArsRestV2Adapter adapter = new ArsRestV2Adapter();

        Map<String, String> parameters = new HashMap<>();
        assertEquals(1000, adapter.getRequestedLimit(parameters));

        parameters.put("limit", "500");
        assertEquals(500, adapter.getRequestedLimit(parameters));

        parameters.put("limit", "20000");
        assertEquals(20000, adapter.getRequestedLimit(parameters));

        parameters.put("limit", " 1500 ");
        assertEquals(1500, adapter.getRequestedLimit(parameters));

        parameters.put("limit", "-5");
        assertEquals(1000, adapter.getRequestedLimit(parameters));

        parameters.put("limit", "abc");
        assertEquals(1000, adapter.getRequestedLimit(parameters));
    }
}
