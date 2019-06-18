package com.kineticdata.bridgehub.adapter.ars;

import com.kineticdata.bridgehub.adapter.BridgeError;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 *
 */
public class ArsQualificationParser {
    public static String PARAMETER_PATTERN = "<%=\\s*parameter\\[\\\"?(.*?)\\\"?\\]\\s*%>";

    public String encodeParameter(String value) {
        String result = null;
        if (value != null) {result = value.replaceAll("\"", "\"\"");}
        return result;
    }

    public String parse(String query, Map<String,String> parameters) throws BridgeError {
        // Create the pattern and pattern matcher
        Pattern pattern = Pattern.compile(PARAMETER_PATTERN);
        Matcher matcher = pattern.matcher(query);

        Pattern quotePattern = Pattern.compile("\"");

        // Build up the results string
        StringBuffer buffer = new StringBuffer();
        while(matcher.find()) {
            // Retrieve the necessary values
            String parameterName = matcher.group(1);
            // If there were no parameters provided
            if (parameters == null) {
                throw new BridgeError("Unable to parse qualification, "+
                    "the '"+parameterName+"' parameter was referenced but no "+
                    "parameters were provided.");
            }
            String parameterValue = parameters.get(parameterName);
            // If there is a reference to a parameter that was not passed
            if (parameterValue == null) {
                throw new BridgeError("Unable to parse qualification, "+
                    "the '"+parameterName+"' parameter was referenced but "+
                    "not provided.");
            }

            // Count the number of quotation marks in the query string prior
            // to the match.
            String querySubstring = query.substring(0, matcher.start());
            Matcher quoteMatcher = quotePattern.matcher(querySubstring);
            int count = 0;
            while (quoteMatcher.find()) {count++;}

            // Determine the value.  If it is an even number then the parameter
            // should be escaped, if it is an odd number than the parameter
            // should be interpreted as a raw ARS qualification segment.
            String value;
            if (count % 2 == 0) {value = parameterValue;}
            else {value = encodeParameter(parameterValue);}

            // Append any part of the qualification that exists before the match
            matcher.appendReplacement(buffer, Matcher.quoteReplacement(value));
        }
        // Append any part of the qualification remaining after the last match
        matcher.appendTail(buffer);

        // Return the results string
        return buffer.toString();
    }
}