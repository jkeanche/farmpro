package com.codejar.inukaadmin.service;

import com.codejar.inukaadmin.database.DatabaseManager;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

import java.io.FileOutputStream;
import java.sql.*;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

public class ReportService {
    
    public static List<Map<String, Object>> getCollectionsReport(
            Date startDate, Date endDate, String seasonId, String memberId) throws SQLException {
        
        List<Map<String, Object>> results = new ArrayList<>();
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
        
        StringBuilder sql = new StringBuilder("""
            SELECT 
                c.receipt_number,
                c.collection_date,
                c.member_number,
                c.member_name,
                c.season_name,
                c.product_type,
                c.gross_weight,
                c.tare_weight,
                c.net_weight,
                c.number_of_bags,
                c.price_per_kg,
                c.total_value,
                c.collected_by
            FROM coffee_collections c
            WHERE 1=1
        """);
        
        List<Object> params = new ArrayList<>();
        
        if (startDate != null) {
            sql.append(" AND DATE(c.collection_date) >= ?");
            params.add(sdf.format(startDate));
        }
        if (endDate != null) {
            sql.append(" AND DATE(c.collection_date) <= ?");
            params.add(sdf.format(endDate));
        }
        if (seasonId != null && !seasonId.isEmpty()) {
            sql.append(" AND c.season_id = ?");
            params.add(seasonId);
        }
        if (memberId != null && !memberId.isEmpty()) {
            sql.append(" AND c.member_id = ?");
            params.add(memberId);
        }
        
        sql.append(" ORDER BY c.collection_date DESC");
        
        try (Connection conn = DatabaseManager.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql.toString())) {
            
            for (int i = 0; i < params.size(); i++) {
                pstmt.setObject(i + 1, params.get(i));
            }
            
            ResultSet rs = pstmt.executeQuery();
            while (rs.next()) {
                Map<String, Object> row = new HashMap<>();
                row.put("receiptNumber", rs.getString("receipt_number"));
                row.put("collectionDate", rs.getString("collection_date"));
                row.put("memberNumber", rs.getString("member_number"));
                row.put("memberName", rs.getString("member_name"));
                row.put("seasonName", rs.getString("season_name"));
                row.put("productType", rs.getString("product_type"));
                row.put("grossWeight", rs.getDouble("gross_weight"));
                row.put("tareWeight", rs.getDouble("tare_weight"));
                row.put("netWeight", rs.getDouble("net_weight"));
                row.put("numberOfBags", rs.getInt("number_of_bags"));
                row.put("pricePerKg", rs.getDouble("price_per_kg"));
                row.put("totalValue", rs.getDouble("total_value"));
                row.put("collectedBy", rs.getString("collected_by"));
                results.add(row);
            }
        }
        
        return results;
    }
    
    public static List<Map<String, Object>> getSalesReport(
            Date startDate, Date endDate, String seasonId, String memberId) throws SQLException {
        
        List<Map<String, Object>> results = new ArrayList<>();
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd");
        
        StringBuilder sql = new StringBuilder("""
            SELECT 
                s.receipt_number,
                s.sale_date,
                s.member_name,
                s.season_name,
                s.sale_type,
                s.total_amount,
                s.paid_amount,
                s.balance_amount,
                s.user_name
            FROM sales s
            WHERE s.is_active = 1
        """);
        
        List<Object> params = new ArrayList<>();
        
        if (startDate != null) {
            sql.append(" AND DATE(s.sale_date) >= ?");
            params.add(sdf.format(startDate));
        }
        if (endDate != null) {
            sql.append(" AND DATE(s.sale_date) <= ?");
            params.add(sdf.format(endDate));
        }
        if (seasonId != null && !seasonId.isEmpty()) {
            sql.append(" AND s.season_id = ?");
            params.add(seasonId);
        }
        if (memberId != null && !memberId.isEmpty()) {
            sql.append(" AND s.member_id = ?");
            params.add(memberId);
        }
        
        sql.append(" ORDER BY s.sale_date DESC");
        
        try (Connection conn = DatabaseManager.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql.toString())) {
            
            for (int i = 0; i < params.size(); i++) {
                pstmt.setObject(i + 1, params.get(i));
            }
            
            ResultSet rs = pstmt.executeQuery();
            while (rs.next()) {
                Map<String, Object> row = new HashMap<>();
                row.put("receiptNumber", rs.getString("receipt_number"));
                row.put("saleDate", rs.getString("sale_date"));
                row.put("memberName", rs.getString("member_name"));
                row.put("seasonName", rs.getString("season_name"));
                row.put("saleType", rs.getString("sale_type"));
                row.put("totalAmount", rs.getDouble("total_amount"));
                row.put("paidAmount", rs.getDouble("paid_amount"));
                row.put("balanceAmount", rs.getDouble("balance_amount"));
                row.put("userName", rs.getString("user_name"));
                results.add(row);
            }
        }
        
        return results;
    }
    
    public static void exportCollectionsToExcel(List<Map<String, Object>> data, String filePath) 
            throws Exception {
        
        Workbook workbook = new XSSFWorkbook();
        Sheet sheet = workbook.createSheet("Coffee Collections");
        
        CellStyle headerStyle = workbook.createCellStyle();
        Font headerFont = workbook.createFont();
        headerFont.setBold(true);
        headerStyle.setFont(headerFont);
        headerStyle.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
        headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        
        Row headerRow = sheet.createRow(0);
        String[] headers = {"Receipt#", "Date", "Member#", "Member Name", "Season", 
                           "Product", "Gross Wt", "Tare Wt", "Net Wt", "Bags", 
                           "Price/Kg", "Total Value", "Collected By"};
        
        for (int i = 0; i < headers.length; i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(headerStyle);
        }
        
        int rowNum = 1;
        for (Map<String, Object> record : data) {
            Row row = sheet.createRow(rowNum++);
            row.createCell(0).setCellValue((String) record.get("receiptNumber"));
            row.createCell(1).setCellValue((String) record.get("collectionDate"));
            row.createCell(2).setCellValue((String) record.get("memberNumber"));
            row.createCell(3).setCellValue((String) record.get("memberName"));
            row.createCell(4).setCellValue((String) record.get("seasonName"));
            row.createCell(5).setCellValue((String) record.get("productType"));
            row.createCell(6).setCellValue((Double) record.get("grossWeight"));
            row.createCell(7).setCellValue((Double) record.get("tareWeight"));
            row.createCell(8).setCellValue((Double) record.get("netWeight"));
            row.createCell(9).setCellValue((Integer) record.get("numberOfBags"));
            row.createCell(10).setCellValue((Double) record.get("pricePerKg"));
            row.createCell(11).setCellValue((Double) record.get("totalValue"));
            row.createCell(12).setCellValue((String) record.get("collectedBy"));
        }
        
        for (int i = 0; i < headers.length; i++) {
            sheet.autoSizeColumn(i);
        }
        
        try (FileOutputStream fileOut = new FileOutputStream(filePath)) {
            workbook.write(fileOut);
        }
        
        workbook.close();
    }
    
    public static void exportSalesToExcel(List<Map<String, Object>> data, String filePath) 
            throws Exception {
        
        Workbook workbook = new XSSFWorkbook();
        Sheet sheet = workbook.createSheet("Sales");
        
        CellStyle headerStyle = workbook.createCellStyle();
        Font headerFont = workbook.createFont();
        headerFont.setBold(true);
        headerStyle.setFont(headerFont);
        headerStyle.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
        headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        
        Row headerRow = sheet.createRow(0);
        String[] headers = {"Receipt#", "Date", "Member Name", "Season", "Type", 
                           "Total Amount", "Paid Amount", "Balance", "User"};
        
        for (int i = 0; i < headers.length; i++) {
            Cell cell = headerRow.createCell(i);
            cell.setCellValue(headers[i]);
            cell.setCellStyle(headerStyle);
        }
        
        int rowNum = 1;
        for (Map<String, Object> record : data) {
            Row row = sheet.createRow(rowNum++);
            row.createCell(0).setCellValue((String) record.get("receiptNumber"));
            row.createCell(1).setCellValue((String) record.get("saleDate"));
            row.createCell(2).setCellValue((String) record.get("memberName"));
            row.createCell(3).setCellValue((String) record.get("seasonName"));
            row.createCell(4).setCellValue((String) record.get("saleType"));
            row.createCell(5).setCellValue((Double) record.get("totalAmount"));
            row.createCell(6).setCellValue((Double) record.get("paidAmount"));
            row.createCell(7).setCellValue((Double) record.get("balanceAmount"));
            row.createCell(8).setCellValue((String) record.get("userName"));
        }
        
        for (int i = 0; i < headers.length; i++) {
            sheet.autoSizeColumn(i);
        }
        
        try (FileOutputStream fileOut = new FileOutputStream(filePath)) {
            workbook.write(fileOut);
        }
        
        workbook.close();
    }
    
    public static Map<String, Object> getDashboardStatistics() throws SQLException {
        Map<String, Object> stats = new HashMap<>();
        
        try (Connection conn = DatabaseManager.getConnection();
             Statement stmt = conn.createStatement()) {
            
            ResultSet rs = stmt.executeQuery(
                "SELECT COUNT(*) as count, COALESCE(SUM(total_value), 0) as total FROM coffee_collections"
            );
            if (rs.next()) {
                stats.put("totalCollections", rs.getInt("count"));
                stats.put("totalCollectionValue", rs.getDouble("total"));
            }
            
            rs = stmt.executeQuery(
                "SELECT COUNT(*) as count, COALESCE(SUM(total_amount), 0) as total FROM sales WHERE is_active = 1"
            );
            if (rs.next()) {
                stats.put("totalSales", rs.getInt("count"));
                stats.put("totalSalesAmount", rs.getDouble("total"));
            }
            
            rs = stmt.executeQuery("SELECT COUNT(*) as count FROM members WHERE is_active = 1");
            if (rs.next()) {
                stats.put("activeMembers", rs.getInt("count"));
            }
            
            rs = stmt.executeQuery(
                "SELECT COALESCE(SUM(balance_amount), 0) as total FROM sales WHERE is_active = 1 AND balance_amount > 0"
            );
            if (rs.next()) {
                stats.put("outstandingCredit", rs.getDouble("total"));
            }
        }
        
        return stats;
    }
}
