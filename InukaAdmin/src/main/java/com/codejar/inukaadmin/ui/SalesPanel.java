package com.codejar.inukaadmin.ui;

import com.codejar.inukaadmin.database.DatabaseManager;
import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.sql.*;
import java.text.SimpleDateFormat;

public class SalesPanel extends JPanel {
    private JTable salesTable;
    private DefaultTableModel tableModel;
    private JLabel totalLabel;
    
    public SalesPanel() {
        setLayout(new BorderLayout(10, 10));
        setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
        
        JLabel titleLabel = new JLabel("Sales", JLabel.CENTER);
        titleLabel.setFont(new Font("Arial", Font.BOLD, 24));
        add(titleLabel, BorderLayout.NORTH);
        
        String[] columns = {"Receipt#", "Date", "Member", "Type", "Total (KES)", "Paid (KES)", "Balance (KES)"};
        tableModel = new DefaultTableModel(columns, 0) {
            @Override
            public boolean isCellEditable(int row, int column) {
                return false;
            }
        };
        
        salesTable = new JTable(tableModel);
        salesTable.setRowHeight(25);
        salesTable.getTableHeader().setFont(new Font("Arial", Font.BOLD, 12));
        
        JScrollPane scrollPane = new JScrollPane(salesTable);
        add(scrollPane, BorderLayout.CENTER);
        
        JPanel bottomPanel = new JPanel(new BorderLayout());
        
        totalLabel = new JLabel("Total Sales: 0 | Total Amount: KES 0.00");
        totalLabel.setFont(new Font("Arial", Font.BOLD, 14));
        bottomPanel.add(totalLabel, BorderLayout.WEST);
        
        JButton refreshButton = new JButton("Refresh");
        refreshButton.addActionListener(e -> loadSales());
        bottomPanel.add(refreshButton, BorderLayout.EAST);
        
        add(bottomPanel, BorderLayout.SOUTH);
        
        loadSales();
    }
    
    private void loadSales() {
        SwingWorker<Void, Void> worker = new SwingWorker<>() {
            @Override
            protected Void doInBackground() throws Exception {
                tableModel.setRowCount(0);
                
                SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm");
                int totalCount = 0;
                double totalAmount = 0.0;
                
                try (Connection conn = DatabaseManager.getConnection();
                     Statement stmt = conn.createStatement();
                     ResultSet rs = stmt.executeQuery(
                         "SELECT receipt_number, sale_date, member_name, sale_type, " +
                         "total_amount, paid_amount, balance_amount " +
                         "FROM sales WHERE is_active = 1 ORDER BY sale_date DESC LIMIT 1000")) {
                    
                    while (rs.next()) {
                        Object[] row = {
                            rs.getString("receipt_number"),
                            sdf.format(rs.getTimestamp("sale_date")),
                            rs.getString("member_name"),
                            rs.getString("sale_type"),
                            String.format("%.2f", rs.getDouble("total_amount")),
                            String.format("%.2f", rs.getDouble("paid_amount")),
                            String.format("%.2f", rs.getDouble("balance_amount"))
                        };
                        tableModel.addRow(row);
                        totalCount++;
                        totalAmount += rs.getDouble("total_amount");
                    }
                }
                
                final int count = totalCount;
                final double amount = totalAmount;
                SwingUtilities.invokeLater(() -> {
                    totalLabel.setText(String.format("Total Sales: %d | Total Amount: KES %.2f", count, amount));
                });
                
                return null;
            }
            
            @Override
            protected void done() {
                try {
                    get();
                } catch (Exception e) {
                    e.printStackTrace();
                    JOptionPane.showMessageDialog(SalesPanel.this, 
                        "Error loading sales: " + e.getMessage(), 
                        "Error", 
                        JOptionPane.ERROR_MESSAGE);
                }
            }
        };
        worker.execute();
    }
}
