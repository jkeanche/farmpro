package com.codejar.inukaadmin.api;

import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import com.codejar.inukaadmin.database.DatabaseManager;
import com.codejar.inukaadmin.model.CoffeeCollection;
import com.codejar.inukaadmin.model.Sale;
import org.json.JSONObject;
import org.json.JSONArray;

import java.io.*;
import java.net.InetSocketAddress;
import java.sql.*;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;

public class ApiServer {
    private HttpServer server;
    private static final int PORT = 8080;
    private static Map<String, String> activeSessions = new HashMap<>();
    
    public void start() {
        try {
            server = HttpServer.create(new InetSocketAddress(PORT), 0);
            
            // Register API endpoints
            server.createContext("/api/test", new TestHandler());
            server.createContext("/api/auth/login", new LoginHandler());
            server.createContext("/api/collections", new CollectionsHandler());
            server.createContext("/api/sales", new SalesHandler());
            server.createContext("/api/members", new MembersHandler());
            server.createContext("/api/sync/status", new SyncStatusHandler());
            
            server.setExecutor(null); // Use default executor
            server.start();
            
            System.out.println("API Server started on port " + PORT);
        } catch (IOException e) {
            e.printStackTrace();
            System.err.println("Failed to start API server: " + e.getMessage());
        }
    }
    
    public void stop() {
        if (server != null) {
            server.stop(0);
            System.out.println("API Server stopped");
        }
    }
    
    // Test endpoint handler
    static class TestHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            String response = "{\"status\":\"ok\",\"message\":\"Server is running\"}";
            sendResponse(exchange, 200, response);
        }
    }
    
    // Login handler
    static class LoginHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!"POST".equals(exchange.getRequestMethod())) {
                sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
                return;
            }
            
            try {
                String body = readRequestBody(exchange);
                JSONObject json = new JSONObject(body);
                String username = json.getString("username");
                String password = json.getString("password");
                
                // Authenticate user
                try (Connection conn = DatabaseManager.getConnection();
                     PreparedStatement pstmt = conn.prepareStatement(
                         "SELECT id, full_name, role FROM users WHERE username = ? AND password = ? AND is_active = 1")) {
                    
                    pstmt.setString(1, username);
                    pstmt.setString(2, password);
                    
                    ResultSet rs = pstmt.executeQuery();
                    if (rs.next()) {
                        // Generate session token
                        String token = UUID.randomUUID().toString();
                        activeSessions.put(token, username);
                        
                        JSONObject responseJson = new JSONObject();
                        responseJson.put("token", token);
                        responseJson.put("userId", rs.getInt("id"));
                        responseJson.put("fullName", rs.getString("full_name"));
                        responseJson.put("role", rs.getString("role"));
                        
                        sendResponse(exchange, 200, responseJson.toString());
                    } else {
                        sendResponse(exchange, 401, "{\"error\":\"Invalid credentials\"}");
                    }
                } catch (SQLException e) {
                    e.printStackTrace();
                    sendResponse(exchange, 500, "{\"error\":\"Database error\"}");
                }
            } catch (Exception e) {
                e.printStackTrace();
                sendResponse(exchange, 400, "{\"error\":\"Invalid request\"}");
            }
        }
    }
    
    // Collections handler
    static class CollectionsHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!isAuthenticated(exchange)) {
                sendResponse(exchange, 401, "{\"error\":\"Unauthorized\"}");
                return;
            }
            
            if ("POST".equals(exchange.getRequestMethod())) {
                handleCreateCollection(exchange);
            } else if ("GET".equals(exchange.getRequestMethod())) {
                handleGetCollections(exchange);
            } else {
                sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
            }
        }
        
        private void handleCreateCollection(HttpExchange exchange) throws IOException {
            try {
                String body = readRequestBody(exchange);
                JSONObject json = new JSONObject(body);
                
                try (Connection conn = DatabaseManager.getConnection();
                     PreparedStatement pstmt = conn.prepareStatement(
                         """
                         INSERT INTO coffee_collections 
                         (id, member_id, member_number, member_name, collection_date, season_id, season_name,
                          product_type, gross_weight, tare_weight, net_weight, number_of_bags, price_per_kg,
                          total_value, receipt_number, is_manual_entry, collected_by, user_id)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                         """)) {
                    
                    pstmt.setString(1, json.getString("id"));
                    pstmt.setString(2, json.getString("memberId"));
                    pstmt.setString(3, json.getString("memberNumber"));
                    pstmt.setString(4, json.getString("memberName"));
                    pstmt.setString(5, json.getString("collectionDate"));
                    pstmt.setString(6, json.getString("seasonId"));
                    pstmt.setString(7, json.getString("seasonName"));
                    pstmt.setString(8, json.getString("productType"));
                    pstmt.setDouble(9, json.getDouble("grossWeight"));
                    pstmt.setDouble(10, json.getDouble("tareWeight"));
                    pstmt.setDouble(11, json.getDouble("netWeight"));
                    pstmt.setInt(12, json.optInt("numberOfBags", 0));
                    pstmt.setDouble(13, json.optDouble("pricePerKg", 0.0));
                    pstmt.setDouble(14, json.optDouble("totalValue", 0.0));
                    pstmt.setString(15, json.optString("receiptNumber", null));
                    pstmt.setBoolean(16, json.getBoolean("isManualEntry"));
                    pstmt.setString(17, json.optString("collectedBy", null));
                    pstmt.setString(18, json.optString("userId", null));
                    
                    pstmt.executeUpdate();
                    
                    // Log sync
                    logSync("COLLECTION", json.getString("id"), "SUCCESS", "Collection synced successfully");
                    
                    sendResponse(exchange, 201, "{\"status\":\"success\",\"message\":\"Collection created\"}");
                } catch (SQLException e) {
                    e.printStackTrace();
                    logSync("COLLECTION", json.getString("id"), "FAILED", e.getMessage());
                    sendResponse(exchange, 500, "{\"error\":\"Database error\"}");
                }
            } catch (Exception e) {
                e.printStackTrace();
                sendResponse(exchange, 400, "{\"error\":\"Invalid request\"}");
            }
        }
        
        private void handleGetCollections(HttpExchange exchange) throws IOException {
            // Get query parameters for filtering
            String query = exchange.getRequestURI().getQuery();
            Map<String, String> params = parseQueryParams(query);
            
            try (Connection conn = DatabaseManager.getConnection()) {
                StringBuilder sql = new StringBuilder(
                    "SELECT * FROM coffee_collections WHERE 1=1"
                );
                
                if (params.containsKey("seasonId")) {
                    sql.append(" AND season_id = '").append(params.get("seasonId")).append("'");
                }
                if (params.containsKey("memberId")) {
                    sql.append(" AND member_id = '").append(params.get("memberId")).append("'");
                }
                
                sql.append(" ORDER BY collection_date DESC");
                
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery(sql.toString());
                
                JSONArray collections = new JSONArray();
                while (rs.next()) {
                    JSONObject collection = new JSONObject();
                    collection.put("id", rs.getString("id"));
                    collection.put("memberNumber", rs.getString("member_number"));
                    collection.put("memberName", rs.getString("member_name"));
                    collection.put("collectionDate", rs.getString("collection_date"));
                    collection.put("seasonName", rs.getString("season_name"));
                    collection.put("productType", rs.getString("product_type"));
                    collection.put("netWeight", rs.getDouble("net_weight"));
                    collection.put("totalValue", rs.getDouble("total_value"));
                    collection.put("receiptNumber", rs.getString("receipt_number"));
                    collections.put(collection);
                }
                
                JSONObject response = new JSONObject();
                response.put("data", collections);
                response.put("count", collections.length());
                
                sendResponse(exchange, 200, response.toString());
            } catch (SQLException e) {
                e.printStackTrace();
                sendResponse(exchange, 500, "{\"error\":\"Database error\"}");
            }
        }
    }
    
    // Sales handler
    static class SalesHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!isAuthenticated(exchange)) {
                sendResponse(exchange, 401, "{\"error\":\"Unauthorized\"}");
                return;
            }
            
            if ("POST".equals(exchange.getRequestMethod())) {
                handleCreateSale(exchange);
            } else if ("GET".equals(exchange.getRequestMethod())) {
                handleGetSales(exchange);
            } else {
                sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
            }
        }
        
        private void handleCreateSale(HttpExchange exchange) throws IOException {
            try {
                String body = readRequestBody(exchange);
                JSONObject json = new JSONObject(body);
                
                Connection conn = DatabaseManager.getConnection();
                conn.setAutoCommit(false);
                
                try {
                    // Insert sale
                    try (PreparedStatement pstmt = conn.prepareStatement(
                         """
                         INSERT INTO sales 
                         (id, member_id, member_name, sale_type, total_amount, paid_amount, balance_amount,
                          sale_date, receipt_number, notes, user_id, user_name, season_id, season_name, is_active)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                         """)) {
                        
                        pstmt.setString(1, json.getString("id"));
                        pstmt.setString(2, json.optString("memberId", null));
                        pstmt.setString(3, json.optString("memberName", null));
                        pstmt.setString(4, json.getString("saleType"));
                        pstmt.setDouble(5, json.getDouble("totalAmount"));
                        pstmt.setDouble(6, json.getDouble("paidAmount"));
                        pstmt.setDouble(7, json.getDouble("balanceAmount"));
                        pstmt.setString(8, json.getString("saleDate"));
                        pstmt.setString(9, json.optString("receiptNumber", null));
                        pstmt.setString(10, json.optString("notes", null));
                        pstmt.setString(11, json.getString("userId"));
                        pstmt.setString(12, json.optString("userName", null));
                        pstmt.setString(13, json.optString("seasonId", null));
                        pstmt.setString(14, json.optString("seasonName", null));
                        pstmt.setBoolean(15, true);
                        
                        pstmt.executeUpdate();
                    }
                    
                    // Insert sale items
                    JSONArray items = json.getJSONArray("items");
                    try (PreparedStatement pstmt = conn.prepareStatement(
                         """
                         INSERT INTO sale_items 
                         (id, sale_id, product_id, product_name, quantity, unit_price, total_price, notes)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                         """)) {
                        
                        for (int i = 0; i < items.length(); i++) {
                            JSONObject item = items.getJSONObject(i);
                            pstmt.setString(1, item.getString("id"));
                            pstmt.setString(2, json.getString("id"));
                            pstmt.setString(3, item.getString("productId"));
                            pstmt.setString(4, item.getString("productName"));
                            pstmt.setDouble(5, item.getDouble("quantity"));
                            pstmt.setDouble(6, item.getDouble("unitPrice"));
                            pstmt.setDouble(7, item.getDouble("totalPrice"));
                            pstmt.setString(8, item.optString("notes", null));
                            pstmt.addBatch();
                        }
                        pstmt.executeBatch();
                    }
                    
                    conn.commit();
                    
                    // Log sync
                    logSync("SALE", json.getString("id"), "SUCCESS", "Sale synced successfully");
                    
                    sendResponse(exchange, 201, "{\"status\":\"success\",\"message\":\"Sale created\"}");
                } catch (Exception e) {
                    conn.rollback();
                    throw e;
                } finally {
                    conn.setAutoCommit(true);
                }
            } catch (Exception e) {
                e.printStackTrace();
                sendResponse(exchange, 400, "{\"error\":\"Invalid request: " + e.getMessage() + "\"}");
            }
        }
        
        private void handleGetSales(HttpExchange exchange) throws IOException {
            String query = exchange.getRequestURI().getQuery();
            Map<String, String> params = parseQueryParams(query);
            
            try (Connection conn = DatabaseManager.getConnection()) {
                StringBuilder sql = new StringBuilder(
                    "SELECT * FROM sales WHERE is_active = 1"
                );
                
                if (params.containsKey("seasonId")) {
                    sql.append(" AND season_id = '").append(params.get("seasonId")).append("'");
                }
                if (params.containsKey("memberId")) {
                    sql.append(" AND member_id = '").append(params.get("memberId")).append("'");
                }
                
                sql.append(" ORDER BY sale_date DESC");
                
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery(sql.toString());
                
                JSONArray sales = new JSONArray();
                while (rs.next()) {
                    JSONObject sale = new JSONObject();
                    sale.put("id", rs.getString("id"));
                    sale.put("memberName", rs.getString("member_name"));
                    sale.put("saleType", rs.getString("sale_type"));
                    sale.put("totalAmount", rs.getDouble("total_amount"));
                    sale.put("paidAmount", rs.getDouble("paid_amount"));
                    sale.put("balanceAmount", rs.getDouble("balance_amount"));
                    sale.put("saleDate", rs.getString("sale_date"));
                    sale.put("receiptNumber", rs.getString("receipt_number"));
                    sales.put(sale);
                }
                
                JSONObject response = new JSONObject();
                response.put("data", sales);
                response.put("count", sales.length());
                
                sendResponse(exchange, 200, response.toString());
            } catch (SQLException e) {
                e.printStackTrace();
                sendResponse(exchange, 500, "{\"error\":\"Database error\"}");
            }
        }
    }
    
    // Members handler
    static class MembersHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!isAuthenticated(exchange)) {
                sendResponse(exchange, 401, "{\"error\":\"Unauthorized\"}");
                return;
            }
            
            if ("GET".equals(exchange.getRequestMethod())) {
                try (Connection conn = DatabaseManager.getConnection();
                     Statement stmt = conn.createStatement();
                     ResultSet rs = stmt.executeQuery("SELECT * FROM members WHERE is_active = 1 ORDER BY full_name")) {
                    
                    JSONArray members = new JSONArray();
                    while (rs.next()) {
                        JSONObject member = new JSONObject();
                        member.put("id", rs.getString("id"));
                        member.put("memberNumber", rs.getString("member_number"));
                        member.put("fullName", rs.getString("full_name"));
                        member.put("idNumber", rs.getString("id_number"));
                        member.put("phoneNumber", rs.getString("phone_number"));
                        member.put("email", rs.getString("email"));
                        member.put("registrationDate", rs.getString("registration_date"));
                        member.put("gender", rs.getString("gender"));
                        member.put("zone", rs.getString("zone"));
                        member.put("isActive", rs.getBoolean("is_active"));
                        members.put(member);
                    }
                    
                    JSONObject response = new JSONObject();
                    response.put("data", members);
                    response.put("count", members.length());
                    
                    sendResponse(exchange, 200, response.toString());
                } catch (SQLException e) {
                    e.printStackTrace();
                    sendResponse(exchange, 500, "{\"error\":\"Database error\"}");
                }
            } else {
                sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
            }
        }
    }
    
    // Sync status handler
    static class SyncStatusHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            if (!isAuthenticated(exchange)) {
                sendResponse(exchange, 401, "{\"error\":\"Unauthorized\"}");
                return;
            }
            
            try (Connection conn = DatabaseManager.getConnection()) {
                JSONObject status = new JSONObject();
                
                // Get collection count
                Statement stmt = conn.createStatement();
                ResultSet rs = stmt.executeQuery("SELECT COUNT(*) as count FROM coffee_collections");
                if (rs.next()) {
                    status.put("totalCollections", rs.getInt("count"));
                }
                
                // Get sales count
                rs = stmt.executeQuery("SELECT COUNT(*) as count FROM sales WHERE is_active = 1");
                if (rs.next()) {
                    status.put("totalSales", rs.getInt("count"));
                }
                
                // Get recent sync logs
                rs = stmt.executeQuery(
                    "SELECT sync_type, COUNT(*) as count, MAX(synced_at) as last_sync " +
                    "FROM sync_log GROUP BY sync_type ORDER BY last_sync DESC"
                );
                
                JSONArray syncLogs = new JSONArray();
                while (rs.next()) {
                    JSONObject log = new JSONObject();
                    log.put("type", rs.getString("sync_type"));
                    log.put("count", rs.getInt("count"));
                    log.put("lastSync", rs.getString("last_sync"));
                    syncLogs.put(log);
                }
                
                status.put("syncLogs", syncLogs);
                status.put("status", "online");
                status.put("serverTime", new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss").format(new java.util.Date()));
                
                sendResponse(exchange, 200, status.toString());
            } catch (SQLException e) {
                e.printStackTrace();
                sendResponse(exchange, 500, "{\"error\":\"Database error\"}");
            }
        }
    }
    
    // Helper methods
    private static boolean isAuthenticated(HttpExchange exchange) {
        String authHeader = exchange.getRequestHeaders().getFirst("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            return activeSessions.containsKey(token);
        }
        return false;
    }
    
    private static String readRequestBody(HttpExchange exchange) throws IOException {
        InputStream is = exchange.getRequestBody();
        return new String(is.readAllBytes(), StandardCharsets.UTF_8);
    }
    
    private static void sendResponse(HttpExchange exchange, int statusCode, String response) throws IOException {
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
        exchange.sendResponseHeaders(statusCode, response.getBytes().length);
        OutputStream os = exchange.getResponseBody();
        os.write(response.getBytes());
        os.close();
    }
    
    private static Map<String, String> parseQueryParams(String query) {
        Map<String, String> params = new HashMap<>();
        if (query != null) {
            String[] pairs = query.split("&");
            for (String pair : pairs) {
                String[] keyValue = pair.split("=");
                if (keyValue.length == 2) {
                    params.put(keyValue[0], keyValue[1]);
                }
            }
        }
        return params;
    }
    
    private static void logSync(String syncType, String recordId, String status, String message) {
        try (Connection conn = DatabaseManager.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(
                 "INSERT INTO sync_log (sync_type, record_id, status, message) VALUES (?, ?, ?, ?)")) {
            
            pstmt.setString(1, syncType);
            pstmt.setString(2, recordId);
            pstmt.setString(3, status);
            pstmt.setString(4, message);
            pstmt.executeUpdate();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}
