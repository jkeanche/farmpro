package com.codejar.inukaadmin;

import com.codejar.inukaadmin.database.DatabaseManager;
import com.codejar.inukaadmin.ui.MainFrame;
import com.codejar.inukaadmin.ui.LoginDialog;
import javax.swing.*;

public class InukaAdmin {
    public static void main(String[] args) {
        // Set look and feel to system default for better UI
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        } catch (Exception e) {
            e.printStackTrace();
        }
        
        // Initialize database
        DatabaseManager.initialize();
        
        // Run application on Event Dispatch Thread
        SwingUtilities.invokeLater(() -> {
            // Show login dialog
            LoginDialog loginDialog = new LoginDialog(null);
            loginDialog.setVisible(true);
            
            if (loginDialog.isAuthenticated()) {
                // Show main frame
                MainFrame mainFrame = new MainFrame(loginDialog.getAuthenticatedUser());
                mainFrame.setVisible(true);
            } else {
                // User cancelled login, exit
                System.exit(0);
            }
        });
    }
}
