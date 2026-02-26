package com.codejar.inukaadmin.ui;

import com.codejar.inukaadmin.database.DatabaseManager;
import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.sql.*;
import java.text.SimpleDateFormat;

public class CollectionsPanel extends JPanel {
    private JTable collectionsTable;
    private DefaultTableModel tableModel;
    private JLabel totalLabel;
    
    public CollectionsPanel() {
        setLayout(new BorderLayout(10, 10));
        setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
        
        JLabel titleLabel = new JLabel("Coffee Collections", JLabel.CENTER);
        titleLabel.setFont(new Font("Arial", Font.BOLD, 24));
        add(titleLabel, BorderLayout.NORTH);
        
        String[] columns = {"Receipt#", "Date", "Member", "Season", "Product", "Net Weight (Kg)", "Value (KES)"};
        tableModel = new DefaultTableModel(columns, 0) {
            @Override
            public boolean isCellEditable(int row, int column) {
                return false;
            }
        };
        
        collectionsTable = new JTable(tableModel);
        collectionsTable.setRowHeight(25);
        collectionsTable.getTableHeader().setFont(new Font("Arial", Font.BOLD, 12));
        
        JScrollPane scrollPane = new JScrollPane(collectionsTable);
        add(scrollPane, BorderLayout.CENTER);
        
        JPanel bottomPanel = new JPanel(new BorderLayout());
        
        totalLabel = new JLabel("Total Collections: 0 | Total Value: KES 0.00");
        totalLabel.setFont(new Font("Arial", Font.BOLD, 14));
        bottomPanel.add(totalLabel, BorderLayout.WEST);
        
        JButton refreshButton = new JButton("Refresh");
        refreshButton.addActionListener(e -> loadCollections());
        bottomPanel.add(refreshButton, BorderLayout.EAST);
        
        add(bottomPanel, BorderLayout.SOUTH);
        
        loadCollections();
    }
    
    private void loadCollections() {
        SwingWorker<Void, Void> worker = new SwingWorker<>() {
            @Override
            protected Void doInBackground() throws Exception {
                tableModel.setRowCount(0);
                
                SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm");
                int totalCount = 0;
                double totalValue = 0.0;
                
                try (Connection conn = DatabaseManager.getConnection();
                     Statement stmt = conn.createStatement();
                     ResultSet rs = stmt.executeQuery(
                         "SELECT receipt_number, collection_date, member_name, season_name, " +
                         "product_type, net_weight, total_value " +
                         "FROM coffee_collections ORDER BY collection_date DESC LIMIT 1000")) {
                    
                    while (rs.next()) {
                        Object[] row = {
                            rs.getString("receipt_number"),
                            sdf.format(rs.getTimestamp("collection_date")),
                            rs.getString("member_name"),
                            rs.getString("season_name"),
                            rs.getString("product_type"),
                            String.format("%.2f", rs.getDouble("net_weight")),
                            String.format("%.2f", rs.getDouble("total_value"))
                        };
                        tableModel.addRow(row);
                        totalCount++;
                        totalValue += rs.getDouble("total_value");
                    }
                }
                
                final int count = totalCount;
                final double value = totalValue;
                SwingUtilities.invokeLater(() -> {
                    totalLabel.setText(String.format("Total Collections: %d | Total Value: KES %.2f", count, value));
                });
                
                return null;
            }
            
            @Override
            protected void done() {
                try {
                    get();
                } catch (Exception e) {
                    e.printStackTrace();
                    JOptionPane.showMessageDialog(CollectionsPanel.this, 
                        "Error loading collections: " + e.getMessage(), 
                        "Error", 
                        JOptionPane.ERROR_MESSAGE);
                }
            }
        };
        worker.execute();
    }
}
