package com.codejar.inukaadmin.ui;

import com.codejar.inukaadmin.service.ReportService;
import javax.swing.*;
import javax.swing.table.DefaultTableModel;
import java.awt.*;
import java.io.File;
import java.text.SimpleDateFormat;
import java.text.ParseException;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Calendar;

public class ReportsPanel extends JPanel {
    private JComboBox<String> reportTypeCombo;
    private JTextField startDateField;
    private JTextField endDateField;
    private JTable reportTable;
    private DefaultTableModel tableModel;
    private SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd");
    
    public ReportsPanel() {
        setLayout(new BorderLayout(10, 10));
        setBorder(BorderFactory.createEmptyBorder(20, 20, 20, 20));
        
        JLabel titleLabel = new JLabel("Reports", JLabel.CENTER);
        titleLabel.setFont(new Font("Arial", Font.BOLD, 24));
        add(titleLabel, BorderLayout.NORTH);
        
        JPanel filterPanel = createFilterPanel();
        add(filterPanel, BorderLayout.NORTH);
        
        tableModel = new DefaultTableModel() {
            @Override
            public boolean isCellEditable(int row, int column) {
                return false;
            }
        };
        
        reportTable = new JTable(tableModel);
        reportTable.setRowHeight(25);
        reportTable.getTableHeader().setFont(new Font("Arial", Font.BOLD, 12));
        
        JScrollPane scrollPane = new JScrollPane(reportTable);
        add(scrollPane, BorderLayout.CENTER);
        
        JPanel buttonPanel = new JPanel(new FlowLayout(FlowLayout.RIGHT));
        
        JButton exportButton = new JButton("Export to Excel");
        exportButton.addActionListener(e -> exportToExcel());
        
        JButton generateButton = new JButton("Generate Report");
        generateButton.addActionListener(e -> generateReport());
        
        buttonPanel.add(generateButton);
        buttonPanel.add(exportButton);
        
        add(buttonPanel, BorderLayout.SOUTH);
    }
    
    private JPanel createFilterPanel() {
        JPanel panel = new JPanel(new GridBagLayout());
        panel.setBorder(BorderFactory.createTitledBorder("Filters"));
        GridBagConstraints gbc = new GridBagConstraints();
        gbc.insets = new Insets(5, 5, 5, 5);
        gbc.fill = GridBagConstraints.HORIZONTAL;
        
        gbc.gridx = 0;
        gbc.gridy = 0;
        panel.add(new JLabel("Report Type:"), gbc);
        
        gbc.gridx = 1;
        reportTypeCombo = new JComboBox<>(new String[]{"Coffee Collections", "Inventory"});
        panel.add(reportTypeCombo, gbc);
        
        gbc.gridx = 2;
        panel.add(new JLabel("Start Date (yyyy-MM-dd):"), gbc);
        
        gbc.gridx = 3;
        startDateField = new JTextField(10);
        startDateField.setToolTipText("Format: yyyy-MM-dd (e.g., 2024-01-01)");
        panel.add(startDateField, gbc);
        
        gbc.gridx = 4;
        panel.add(new JLabel("End Date (yyyy-MM-dd):"), gbc);
        
        gbc.gridx = 5;
        endDateField = new JTextField(10);
        endDateField.setToolTipText("Format: yyyy-MM-dd (e.g., 2024-12-31)");
        panel.add(endDateField, gbc);
        
        // Set default dates (last 30 days)
        Calendar cal = Calendar.getInstance();
        endDateField.setText(dateFormat.format(cal.getTime()));
        cal.add(Calendar.DAY_OF_MONTH, -30);
        startDateField.setText(dateFormat.format(cal.getTime()));
        
        return panel;
    }
    
    private void generateReport() {
        String reportType = (String) reportTypeCombo.getSelectedItem();
        
        Date startDate = null;
        Date endDate = null;
        
        try {
            if (!startDateField.getText().trim().isEmpty()) {
                startDate = dateFormat.parse(startDateField.getText().trim());
            }
            if (!endDateField.getText().trim().isEmpty()) {
                endDate = dateFormat.parse(endDateField.getText().trim());
            }
        } catch (ParseException e) {
            JOptionPane.showMessageDialog(this, 
                "Invalid date format. Please use yyyy-MM-dd (e.g., 2024-01-01)", 
                "Error", 
                JOptionPane.ERROR_MESSAGE);
            return;
        }
        
        final Date finalStartDate = startDate;
        final Date finalEndDate = endDate;
        
        SwingWorker<List<Map<String, Object>>, Void> worker = new SwingWorker<>() {
            @Override
            protected List<Map<String, Object>> doInBackground() throws Exception {
                if ("Coffee Collections".equals(reportType)) {
                    return ReportService.getCollectionsReport(finalStartDate, finalEndDate, null, null);
                } else {
                    return ReportService.getSalesReport(finalStartDate, finalEndDate, null, null);
                }
            }
            
            @Override
            protected void done() {
                try {
                    List<Map<String, Object>> data = get();
                    displayReport(data, reportType);
                } catch (Exception e) {
                    e.printStackTrace();
                    JOptionPane.showMessageDialog(ReportsPanel.this, 
                        "Error generating report: " + e.getMessage(), 
                        "Error", 
                        JOptionPane.ERROR_MESSAGE);
                }
            }
        };
        worker.execute();
    }
    
    private void displayReport(List<Map<String, Object>> data, String reportType) {
        tableModel.setRowCount(0);
        tableModel.setColumnCount(0);
        
        if (data.isEmpty()) {
            JOptionPane.showMessageDialog(this, "No data found for the selected criteria", 
                "Info", JOptionPane.INFORMATION_MESSAGE);
            return;
        }
        
        if ("Coffee Collections".equals(reportType)) {
            String[] columns = {"Receipt#", "Date", "Member#", "Member", "Season", "Product", 
                               "Net Wt", "Value"};
            for (String col : columns) {
                tableModel.addColumn(col);
            }
            
            for (Map<String, Object> record : data) {
                Object[] row = {
                    record.get("receiptNumber"),
                    record.get("collectionDate"),
                    record.get("memberNumber"),
                    record.get("memberName"),
                    record.get("seasonName"),
                    record.get("productType"),
                    String.format("%.2f", record.get("netWeight")),
                    String.format("%.2f", record.get("totalValue"))
                };
                tableModel.addRow(row);
            }
        } else {
            String[] columns = {"Receipt#", "Date", "Member", "Type", "Total", "Paid", "Balance"};
            for (String col : columns) {
                tableModel.addColumn(col);
            }
            
            for (Map<String, Object> record : data) {
                Object[] row = {
                    record.get("receiptNumber"),
                    record.get("saleDate"),
                    record.get("memberName"),
                    record.get("saleType"),
                    String.format("%.2f", record.get("totalAmount")),
                    String.format("%.2f", record.get("paidAmount")),
                    String.format("%.2f", record.get("balanceAmount"))
                };
                tableModel.addRow(row);
            }
        }
    }
    
    private void exportToExcel() {
        if (tableModel.getRowCount() == 0) {
            JOptionPane.showMessageDialog(this, "Please generate a report first", 
                "Info", JOptionPane.INFORMATION_MESSAGE);
            return;
        }
        
        JFileChooser fileChooser = new JFileChooser();
        fileChooser.setDialogTitle("Save Excel File");
        fileChooser.setSelectedFile(new File("report_" + System.currentTimeMillis() + ".xlsx"));
        
        int result = fileChooser.showSaveDialog(this);
        if (result == JFileChooser.APPROVE_OPTION) {
            File file = fileChooser.getSelectedFile();
            String filePath = file.getAbsolutePath();
            if (!filePath.toLowerCase().endsWith(".xlsx")) {
                filePath += ".xlsx";
            }
            
            final String finalPath = filePath;
            String reportType = (String) reportTypeCombo.getSelectedItem();
            
            Date startDate = null;
            Date endDate = null;
            
            try {
                if (!startDateField.getText().trim().isEmpty()) {
                    startDate = dateFormat.parse(startDateField.getText().trim());
                }
                if (!endDateField.getText().trim().isEmpty()) {
                    endDate = dateFormat.parse(endDateField.getText().trim());
                }
            } catch (ParseException e) {
                JOptionPane.showMessageDialog(this, 
                    "Invalid date format", 
                    "Error", 
                    JOptionPane.ERROR_MESSAGE);
                return;
            }
            
            final Date finalStartDate = startDate;
            final Date finalEndDate = endDate;
            
            SwingWorker<Void, Void> worker = new SwingWorker<>() {
                @Override
                protected Void doInBackground() throws Exception {
                    List<Map<String, Object>> data;
                    if ("Coffee Collections".equals(reportType)) {
                        data = ReportService.getCollectionsReport(finalStartDate, finalEndDate, null, null);
                        ReportService.exportCollectionsToExcel(data, finalPath);
                    } else {
                        data = ReportService.getSalesReport(finalStartDate, finalEndDate, null, null);
                        ReportService.exportSalesToExcel(data, finalPath);
                    }
                    return null;
                }
                
                @Override
                protected void done() {
                    try {
                        get();
                        JOptionPane.showMessageDialog(ReportsPanel.this, 
                            "Report exported successfully to:\n" + finalPath, 
                            "Success", 
                            JOptionPane.INFORMATION_MESSAGE);
                    } catch (Exception e) {
                        e.printStackTrace();
                        JOptionPane.showMessageDialog(ReportsPanel.this, 
                            "Error exporting report: " + e.getMessage(), 
                            "Error", 
                            JOptionPane.ERROR_MESSAGE);
                    }
                }
            };
            worker.execute();
        }
    }
}
