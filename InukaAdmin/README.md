# Inuka Admin - Desktop Application

Desktop application for managing coffee collections and inventory sales, syncing with mobile Flutter application over LAN.

## Features

- ✅ Modern UI using FlatLaf Look and Feel
- ✅ REST API Server (Port 8080)
- ✅ SQLite Database (No external database needed)
- ✅ Coffee Collections Management
- ✅ Sales Tracking with Items
- ✅ Excel Export for Reports
- ✅ Dashboard with Statistics
- ✅ Filter Reports by Date, Season, Member
- ✅ Real-time Sync with Mobile App

## Requirements

- Java 17 or higher
- Maven 3.6+

## Building the Application

```bash
mvn clean package
```

This will create an executable JAR file:
```
target/InukaAdmin-1.0-SNAPSHOT-jar-with-dependencies.jar
```

## Running the Application

```bash
java -jar target/InukaAdmin-1.0-SNAPSHOT-jar-with-dependencies.jar
```

Or on Windows, you can double-click the JAR file.

## Default Login

- **Username**: admin
- **Password**: admin

⚠️ **Important**: Change the default password after first login in production!

## API Endpoints

The application starts a REST API server on port 8080. Mobile apps can connect to sync data.

### Authentication
- `POST /api/auth/login` - Login and get token

### Collections
- `POST /api/collections` - Sync coffee collection
- `GET /api/collections?seasonId=xxx&memberId=xxx` - Get collections

### Sales
- `POST /api/sales` - Sync sale
- `GET /api/sales?seasonId=xxx&memberId=xxx` - Get sales

### Members
- `GET /api/members` - Get all members

### Status
- `GET /api/test` - Test server connection
- `GET /api/sync/status` - Get sync status

## Network Configuration

### Desktop App
1. The app runs on port 8080
2. Get your computer's LAN IP address:
   - Windows: `ipconfig`
   - Mac/Linux: `ifconfig` or `ip addr`

### Firewall
Ensure port 8080 is open in your firewall:

**Windows Firewall:**
```
Control Panel → System and Security → Windows Defender Firewall → Advanced Settings
→ Inbound Rules → New Rule → Port → TCP 8080
```

**Linux (UFW):**
```bash
sudo ufw allow 8080/tcp
```

### Mobile App Configuration
In the Flutter app, set the server address to your desktop's LAN IP:
```dart
final syncService = DesktopSyncService(
  baseUrl: 'http://192.168.1.100:8080', // Your desktop IP
);
```

## Database

The application uses SQLite database `inuka_admin.db` stored in the same directory as the JAR file.

### Backup Database
Copy the `inuka_admin.db` file to a safe location.

### Restore Database
Replace the `inuka_admin.db` file with your backup.

## Project Structure

```
InukaAdmin/
├── src/main/java/com/codejar/inukaadmin/
│   ├── InukaAdmin.java           # Main entry point
│   ├── api/
│   │   └── ApiServer.java        # REST API server
│   ├── database/
│   │   └── DatabaseManager.java  # Database operations
│   ├── model/
│   │   ├── User.java
│   │   ├── CoffeeCollection.java
│   │   ├── Sale.java
│   │   ├── SaleItem.java
│   │   ├── Member.java
│   │   └── Season.java
│   ├── service/
│   │   └── ReportService.java    # Report generation & export
│   └── ui/
│       ├── LoginDialog.java      # Login screen
│       ├── MainFrame.java        # Main application window
│       ├── DashboardPanel.java   # Dashboard tab
│       ├── CollectionsPanel.java # Collections tab
│       ├── SalesPanel.java       # Sales tab
│       └── ReportsPanel.java     # Reports tab
├── pom.xml
└── README.md
```

## Troubleshooting

### Cannot connect from mobile app

1. Check if desktop app is running
2. Verify desktop and mobile are on same network
3. Check firewall settings on desktop
4. Verify IP address is correct
5. Test connection: `http://YOUR_IP:8080/api/test`

### Database errors

1. Ensure you have write permissions in the directory
2. Check disk space
3. Close any other applications using the database

### Port 8080 already in use

Change the port in `ApiServer.java`:
```java
private static final int PORT = 8081; // Use different port
```

Then rebuild the application.

## Security Considerations

⚠️ This application is designed for LAN use only. Do NOT expose it to the internet without:

1. Implementing proper password hashing (currently uses plain text)
2. Using HTTPS/TLS encryption
3. Adding rate limiting
4. Implementing proper input validation
5. Using JWT tokens instead of simple session tokens

## Support

For issues or questions, please contact: support@codejar.co.ke

## License

Copyright © 2024 CodeJar. All rights reserved.
