# Quick Start Guide

## Step 1: Install Java

Download and install Java 17 or higher from:
- https://www.oracle.com/java/technologies/downloads/
- Or use OpenJDK: https://adoptium.net/

Verify installation:
```bash
java -version
```

## Step 2: Install Maven

Download from: https://maven.apache.org/download.cgi

Verify installation:
```bash
mvn -version
```

## Step 3: Build the Application

### Windows
Double-click `build.bat` or run:
```cmd
build.bat
```

### Linux/Mac
```bash
./build.sh
```

Or manually:
```bash
mvn clean package
```

## Step 4: Run the Application

```bash
java -jar target/InukaAdmin-1.0-SNAPSHOT-jar-with-dependencies.jar
```

## Step 5: Login

Use default credentials:
- Username: `admin`
- Password: `admin`

## Step 6: Configure Mobile App

### 1. Find Your Computer's IP Address

**Windows:**
```cmd
ipconfig
```
Look for "IPv4 Address" (e.g., 192.168.1.100)

**Mac:**
```bash
ifconfig | grep "inet "
```

**Linux:**
```bash
ip addr show
```

### 2. Update Flutter App

In your Flutter app, use the `DesktopSyncService`:

```dart
// Add to your service locator or dependency injection
final syncService = DesktopSyncService(
  baseUrl: 'http://192.168.1.100:8080', // Your computer's IP
);

// Save connection settings
await syncService.saveConnectionSettings(
  serverAddress: '192.168.1.100',  // Your IP
  port: '8080',
  username: 'admin',
  password: 'admin',
);

// Test connection
bool connected = await syncService.testConnection();
if (connected) {
  print('Connected to desktop app!');
}

// Sync collections
final results = await syncService.syncPendingCollections(collections);
print('Synced: ${results['success']} collections');

// Sync sales
final salesResults = await syncService.syncPendingSales(sales);
print('Synced: ${salesResults['success']} sales');
```

## Step 7: Configure Firewall

### Windows
1. Open Windows Defender Firewall
2. Click "Advanced Settings"
3. Click "Inbound Rules" → "New Rule"
4. Select "Port" → Next
5. Select "TCP" and enter port `8080` → Next
6. Select "Allow the connection" → Next
7. Apply to all profiles → Next
8. Name it "Inuka Admin" → Finish

### Linux (UFW)
```bash
sudo ufw allow 8080/tcp
```

### Mac
```bash
# Usually no configuration needed on local network
# If needed, go to System Preferences → Security & Privacy → Firewall
```

## Troubleshooting

### Mobile app can't connect

1. ✅ Verify desktop app is running (check for "API Server: Running on port 8080" in status bar)
2. ✅ Both devices on same WiFi network
3. ✅ Firewall allows port 8080
4. ✅ Correct IP address in mobile app
5. ✅ Test from browser: `http://YOUR_IP:8080/api/test`

### Build errors

**"JAVA_HOME not set"**
- Set JAVA_HOME environment variable to your Java installation directory

**"Maven not found"**
- Add Maven's bin directory to PATH environment variable

**"Dependencies not downloading"**
- Check internet connection
- Clear Maven cache: Delete `~/.m2/repository`

### Runtime errors

**"Port 8080 already in use"**
- Another application is using port 8080
- Either close that application or change the port in `ApiServer.java`

**"Database locked"**
- Close any other instances of the application
- Check if antivirus is blocking database access

## Next Steps

1. ✅ Create members in the database
2. ✅ Set up seasons
3. ✅ Configure products for sales
4. ✅ Test syncing from mobile app
5. ✅ Generate and export reports

## Tips

- **Backup regularly**: Copy `inuka_admin.db` to a safe location
- **Change default password**: In production, change the admin password
- **Network stability**: Use wired connection for desktop app if possible
- **Monitor sync**: Check sync logs in database or via API `/api/sync/status`

## Getting Help

- Check README.md for detailed documentation
- Review API documentation in IMPLEMENTATION_GUIDE.md
- Contact support: support@codejar.co.ke
