package com.codejar.inukaadmin.ui;

import com.codejar.inukaadmin.service.ReportService;
import javax.swing.*;
import java.awt.*;
import java.text.NumberFormat;
import java.util.Map;

public class DashboardPanel extends JPanel {
    private JLabel collectionsCountLabel;
    private JLabel collectionsValueLabel;
    private JLabel salesCountLabel;
    private JLabel salesValueLabel;
    private JLabel membersCountLabel;
    private JLabel creditLabel;
    
    public DashboardPanel() {
        setLayout(new BorderLayout(10, 10));
        setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
        
        JLabel titleLabel = new JLabel("Dashboard", JLabel.CENTER);
        titleLabel.setFont(new Font("Arial", Font.BOLD, 24));
        add(titleLabel, BorderLayout.NORTH);
        
        JPanel statsPanel = new JPanel(new GridLayout(2, 3, 20, 20));
        
        statsPanel.add(createStatCard("Total Collections", "0", Color.decode("#4CAF50")));
        statsPanel.add(createStatCard("Total Collection Value", "KES 0.00", Color.decode("#2196F3")));
        statsPanel.add(createStatCard("Total Sales", "0", Color.decode("#FF9800")));
        statsPanel.add(createStatCard("Total Sales Value", "KES 0.00", Color.decode("#9C27B0")));
        statsPanel.add(createStatCard("Active Members", "0", Color.decode("#00BCD4")));
        statsPanel.add(createStatCard("Outstanding Credit", "KES 0.00", Color.decode("#F44336")));
        
        add(statsPanel, BorderLayout.CENTER);
        
        JButton refreshButton = new JButton("Refresh Statistics");
        refreshButton.addActionListener(e -> loadStatistics());
        
        JPanel buttonPanel = new JPanel(new FlowLayout(FlowLayout.CENTER));
        buttonPanel.add(refreshButton);
        add(buttonPanel, BorderLayout.SOUTH);
        
        loadStatistics();
    }
    
    private JPanel createStatCard(String title, String value, Color color) {
        JPanel card = new JPanel(new BorderLayout());
        card.setBorder(BorderFactory.createCompoundBorder(
            BorderFactory.createLineBorder(color, 2),
            BorderFactory.createEmptyBorder(20, 20, 20, 20)
        ));
        card.setBackground(Color.WHITE);
        
        JLabel titleLabel = new JLabel(title, JLabel.CENTER);
        titleLabel.setFont(new Font("Arial", Font.BOLD, 14));
        titleLabel.setForeground(color);
        
        JLabel valueLabel = new JLabel(value, JLabel.CENTER);
        valueLabel.setFont(new Font("Arial", Font.BOLD, 28));
        
        card.add(titleLabel, BorderLayout.NORTH);
        card.add(valueLabel, BorderLayout.CENTER);
        
        if (title.contains("Collections") && !title.contains("Value")) {
            collectionsCountLabel = valueLabel;
        } else if (title.contains("Collection Value")) {
            collectionsValueLabel = valueLabel;
        } else if (title.contains("Sales") && !title.contains("Value")) {
            salesCountLabel = valueLabel;
        } else if (title.contains("Sales Value")) {
            salesValueLabel = valueLabel;
        } else if (title.contains("Members")) {
            membersCountLabel = valueLabel;
        } else if (title.contains("Credit")) {
            creditLabel = valueLabel;
        }
        
        return card;
    }
    
    private void loadStatistics() {
        SwingWorker<Map<String, Object>, Void> worker = new SwingWorker<>() {
            @Override
            protected Map<String, Object> doInBackground() throws Exception {
                return ReportService.getDashboardStatistics();
            }
            
            @Override
            protected void done() {
                try {
                    Map<String, Object> stats = get();
                    NumberFormat currencyFormat = NumberFormat.getCurrencyInstance();
                    currencyFormat.setMaximumFractionDigits(2);
                    
                    collectionsCountLabel.setText(stats.get("totalCollections").toString());
                    collectionsValueLabel.setText("KES " + String.format("%.2f", stats.get("totalCollectionValue")));
                    salesCountLabel.setText(stats.get("totalSales").toString());
                    salesValueLabel.setText("KES " + String.format("%.2f", stats.get("totalSalesAmount")));
                    membersCountLabel.setText(stats.get("activeMembers").toString());
                    creditLabel.setText("KES " + String.format("%.2f", stats.get("outstandingCredit")));
                } catch (Exception e) {
                    e.printStackTrace();
                    JOptionPane.showMessageDialog(DashboardPanel.this, 
                        "Error loading statistics: " + e.getMessage(), 
                        "Error", 
                        JOptionPane.ERROR_MESSAGE);
                }
            }
        };
        worker.execute();
    }
}
