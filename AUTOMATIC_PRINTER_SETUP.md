# Automatic Default Printer Setup

This guide explains how the Farm Fresh app automatically uses the system default printer for printing receipts.

## How It Works

The app has been enhanced to automatically detect and use the printer selected as default in your system settings. This ensures that all printing operations use the correct printer without manual configuration.

### Key Features

1. **Automatic Detection**: The app automatically discovers available printers and identifies the system default printer
2. **Persistent Selection**: Once detected, the default printer preference is saved and restored on app startup
3. **Manual Refresh**: Users can manually refresh the printer selection if system settings change
4. **Fallback Logic**: If no default printer is found, the app uses the first available printer

### Setup Process

#### For Standard/Direct Printing:

1. **Set Default Printer in System Settings**:
   - Open your system's printer settings
   - Set your desired printer as the default printer
   - The app will automatically detect this setting

2. **Configure App Print Method**:
   - Open Farm Fresh app
   - Go to Settings → System Settings
   - Set Print Method to "Standard Printer"
   - The app will automatically use your system default printer

3. **Manual Refresh (Optional)**:
   - If you change your system default printer after the app is running
   - Go to Settings → System Settings
   - Click "Refresh Default Printer"
   - The app will update to use the new default printer

### Usage

Once configured, the app will automatically:
- Use the system default printer for all receipt printing
- Print directly without showing printer selection dialogs
- Maintain the printer selection across app restarts

### Technical Details

The app uses the Flutter `printing` package to:
- List available system printers
- Identify the default printer
- Send print jobs directly to the selected printer

### Troubleshooting

#### Printer Not Found
- Ensure your printer is properly installed and set as default in system settings
- Check that the printer drivers are correctly installed
- Try the "Refresh Default Printer" option in app settings

#### Print Jobs Not Working
- Verify the printer is online and has paper/toner
- Check printer queue for any stuck jobs
- Ensure the app has necessary permissions for printing

#### Fallback to First Printer
- If no default printer is detected, the app uses the first available printer
- Set a default printer in system settings for better control

### Supported Platforms

This feature works on:
- Windows (Desktop)
- macOS (Desktop)  
- Linux (Desktop)

Note: Mobile platforms (Android/iOS) use different printing mechanisms and may show system print dialogs.

## Settings Location

The printer preferences are automatically saved in the app's settings database and will persist across app sessions.

To manually configure:
1. Open Farm Fresh app
2. Navigate to Settings → System Settings
3. Find "Print Method" and select "Standard Printer"
4. Use "Refresh Default Printer" to update the selection

## Support

If you experience issues with automatic printer detection, check that:
1. Your printer is properly installed in system settings
2. The printer is set as the default printer
3. The app print method is set to "Standard Printer"
4. Try refreshing the printer selection in app settings 