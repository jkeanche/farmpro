package com.codejar.inukaadmin.ui;

import com.codejar.inukaadmin.api.ApiServer;
import com.codejar.inukaadmin.model.User;
import com.formdev.flatlaf.FlatLightLaf;
import javax.swing.*;
import java.awt.*;


import java.net.InetAddress;
import java.net.UnknownHostException;

public class MainFrame extends JFrame {
    private User currentUser;
    private ApiServer apiServer;
    private JTabbedPane tabbedPane;
    
    public MainFrame(User user) {
        this.currentUser = user;
        
        try {
            UIManager.setLookAndFeel(new FlatLightLaf());
        } catch (Exception e) {
            e.printStackTrace();
        }
        
        initComponents();
        startApiServer();
        
        setTitle("Inuka Admin - " + user.getFullName());
        setSize(1200, 800);
        setLocationRelativeTo(null);
        setDefaultCloseOperation(EXIT_ON_CLOSE);
    }
    
    private void initComponents() {
        JMenuBar menuBar = new JMenuBar();
        
        JMenu fileMenu = new JMenu("File");
        JMenuItem exitItem = new JMenuItem("Exit");
        exitItem.addActionListener(e -> handleExit());
        fileMenu.add(exitItem);
        
        JMenu helpMenu = new JMenu("Help");
        JMenuItem aboutItem = new JMenuItem("About");
        aboutItem.addActionListener(e -> showAbout());
        helpMenu.add(aboutItem);
        
        menuBar.add(fileMenu);
        menuBar.add(helpMenu);
        setJMenuBar(menuBar);
        
        tabbedPane = new JTabbedPane();
        tabbedPane.setFont(new Font("Arial", Font.PLAIN, 14));
        
        tabbedPane.addTab("Dashboard", new DashboardPanel());
        tabbedPane.addTab("Coffee Collections", new CollectionsPanel());
        tabbedPane.addTab("Sales", new SalesPanel());
        tabbedPane.addTab("Reports", new ReportsPanel());
        
        add(tabbedPane, BorderLayout.CENTER);
        
        JPanel statusBar = new JPanel(new BorderLayout());
        statusBar.setBorder(BorderFactory.createEtchedBorder());
        JLabel statusLabel = new JLabel("  Logged in as: " + currentUser.getFullName() + " | API Server: Running on "+String.format("%s : 8080", getServerIp()));
        statusBar.add(statusLabel, BorderLayout.WEST);
        add(statusBar, BorderLayout.SOUTH);
    }
    
    
    
    private void startApiServer() {
        apiServer = new ApiServer();
        new Thread(() -> apiServer.start()).start();
    }
    
    
    private String getServerIp() {
        try {
            InetAddress localHost = InetAddress.getLocalHost();
            String ipAddress = localHost.getHostAddress();
            return ipAddress;
        } catch (UnknownHostException e) {
            e.printStackTrace();
        }
        return "";
    }
    
    private void handleExit() {
        int confirm = JOptionPane.showConfirmDialog(
            this,
            "Are you sure you want to exit?",
            "Confirm Exit",
            JOptionPane.YES_NO_OPTION
        );
        
        if (confirm == JOptionPane.YES_OPTION) {
            if (apiServer != null) {
                apiServer.stop();
            }
            System.exit(0);
        }
    }
    
    private void showAbout() {
        JOptionPane.showMessageDialog(
            this,
            "Inuka Admin System\nVersion 1.0\n\nCoffee Collection & Inventory Management",
            "About",
            JOptionPane.INFORMATION_MESSAGE
        );
    }
}
