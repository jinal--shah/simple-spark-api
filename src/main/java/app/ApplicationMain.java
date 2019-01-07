package app;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.Reader;
import java.net.HttpURLConnection;
import java.util.Iterator;
import java.util.List;
import java.net.URL;

import app.utils.SparkUtils;
import org.apache.log4j.Logger;

import static spark.Spark.get;

public class ApplicationMain {

    public static void main(String[] args) throws Exception {
        Logger logger = Logger.getLogger(ApplicationMain.class);
        SparkUtils.createServerWithRequestLog(logger);

        get("/message", (request, response) -> {
            response.header("Content-Type", "application/json") ;
            return getFullResponse(); 
        } );
        get("/health", (request, response) -> "OK");
    }

    private static String getFullResponse() throws IOException {

        // create http connection to app B
        URL url;
        final String appBUrl = System.getenv("APP_B_URL"); // DNS name, or unique url for this stack's appB
        if (appBUrl != null && !appBUrl.isEmpty()) {
            url = new URL(appBUrl); // for addressing by DNS, or multiple stacks on a single host
        }
        else {
            url = new URL("http://appB:5000/message"); // defaults to container name 'appB'
        }
        HttpURLConnection con = (HttpURLConnection) url.openConnection();
        con.setRequestMethod("GET");
        StringBuilder fullResponseBuilder = new StringBuilder();

        Reader streamReader = null;

        // ... handle redirects or error response statuses
        if (con.getResponseCode() > 299) {
            streamReader = new InputStreamReader(con.getErrorStream());
        } else {
            streamReader = new InputStreamReader(con.getInputStream());
        }

        // ... read in body from /message
        String inputLine;
        StringBuilder content = new StringBuilder();
        BufferedReader in = new BufferedReader(streamReader);

        while ((inputLine = in.readLine()) != null) {
            content.append(inputLine);
        }

        in.close();

        fullResponseBuilder.append(content);

        return fullResponseBuilder.toString();
    }
}
