package com.codejar.inukaadmin.database;

import java.sql.*;
import java.io.File;

public class DatabaseManager {
    private static final String DB_NAME = "inuka_admin.db";
    private static final String DB_URL = "jdbc:sqlite:" + DB_NAME;
    private static Connection connection;
    
    public static void initialize() {
        try {
            // Load SQLite JDBC driver
            Class.forName("org.sqlite.JDBC");
            
            // Create database file if it doesn't exist
            File dbFile = new File(DB_NAME);
            boolean isNewDatabase = !dbFile.exists();
            
            // Establish connection
            connection = DriverManager.getConnection(DB_URL);
            
            if (isNewDatabase) {
                createTables();
                insertDefaultData();
            }
            
            System.out.println("Database initialized successfully");
        } catch (Exception e) {
            e.printStackTrace();
            System.err.println("Failed to initialize database: " + e.getMessage());
        }
    }
    
    public static Connection getConnection() throws SQLException {
        if (connection == null || connection.isClosed()) {
            connection = DriverManager.getConnection(DB_URL);
        }
        return connection;
    }
    
    private static void createTables() throws SQLException {
        try (Statement stmt = connection.createStatement()) {
            // Users table
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    password TEXT NOT NULL,
                    full_name TEXT NOT NULL,
                    role TEXT NOT NULL,
                    is_active INTEGER DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """);
            
            // Members table
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS members (
                    id TEXT PRIMARY KEY,
                    member_number TEXT UNIQUE NOT NULL,
                    full_name TEXT NOT NULL,
                    id_number TEXT,
                    phone_number TEXT,
                    email TEXT,
                    registration_date TIMESTAMP NOT NULL,
                    gender TEXT,
                    zone TEXT,
                    acreage REAL,
                    no_trees INTEGER,
                    is_active INTEGER DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """);
            
            // Seasons table
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS seasons (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    description TEXT,
                    start_date TIMESTAMP NOT NULL,
                    end_date TIMESTAMP,
                    is_active INTEGER DEFAULT 1,
                    total_sales REAL DEFAULT 0.0,
                    total_transactions INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    created_by TEXT,
                    created_by_name TEXT
                )
            """);
            
            // Coffee collections table
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS coffee_collections (
                    id TEXT PRIMARY KEY,
                    member_id TEXT NOT NULL,
                    member_number TEXT NOT NULL,
                    member_name TEXT NOT NULL,
                    collection_date TIMESTAMP NOT NULL,
                    season_id TEXT NOT NULL,
                    season_name TEXT NOT NULL,
                    product_type TEXT NOT NULL,
                    gross_weight REAL NOT NULL,
                    tare_weight REAL DEFAULT 0,
                    net_weight REAL NOT NULL,
                    number_of_bags INTEGER,
                    price_per_kg REAL,
                    total_value REAL,
                    receipt_number TEXT,
                    is_manual_entry INTEGER NOT NULL,
                    collected_by TEXT,
                    user_id TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (member_id) REFERENCES members(id),
                    FOREIGN KEY (season_id) REFERENCES seasons(id)
                )
            """);
            
            // Sales table
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS sales (
                    id TEXT PRIMARY KEY,
                    member_id TEXT,
                    member_name TEXT,
                    sale_type TEXT NOT NULL,
                    total_amount REAL NOT NULL,
                    paid_amount REAL NOT NULL,
                    balance_amount REAL NOT NULL,
                    sale_date TIMESTAMP NOT NULL,
                    receipt_number TEXT,
                    notes TEXT,
                    user_id TEXT NOT NULL,
                    user_name TEXT,
                    season_id TEXT,
                    season_name TEXT,
                    is_active INTEGER DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """);
            
            // Sale items table
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS sale_items (
                    id TEXT PRIMARY KEY,
                    sale_id TEXT NOT NULL,
                    product_id TEXT NOT NULL,
                    product_name TEXT NOT NULL,
                    quantity REAL NOT NULL,
                    unit_price REAL NOT NULL,
                    total_price REAL NOT NULL,
                    notes TEXT,
                    FOREIGN KEY (sale_id) REFERENCES sales(id)
                )
            """);
            
            // Products table
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS products (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    description TEXT,
                    category_name TEXT,
                    unit_of_measure_name TEXT,
                    pack_size REAL NOT NULL,
                    sales_price REAL NOT NULL,
                    cost_price REAL,
                    is_active INTEGER DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """);
            
            // Sync log table
            stmt.execute("""
                CREATE TABLE IF NOT EXISTS sync_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    sync_type TEXT NOT NULL,
                    record_id TEXT NOT NULL,
                    status TEXT NOT NULL,
                    message TEXT,
                    synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """);
            
            System.out.println("Database tables created successfully");
        }
    }
    
    private static void insertDefaultData() throws SQLException {
        try (PreparedStatement pstmt = connection.prepareStatement(
            "INSERT INTO users (username, password, full_name, role) VALUES (?, ?, ?, ?)"
        )) {
            pstmt.setString(1, "admin");
            pstmt.setString(2, "admin"); // In production, use hashed passwords
            pstmt.setString(3, "Administrator");
            pstmt.setString(4, "ADMIN");
            pstmt.executeUpdate();
            System.out.println("Default admin user created");
        }
    }
    
    public static void close() {
        try {
            if (connection != null && !connection.isClosed()) {
                connection.close();
                System.out.println("Database connection closed");
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}
