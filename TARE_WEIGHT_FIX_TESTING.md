# Tare Weight Persistence Fix - Testing Guide

## Issue

The default tare weight in System Settings was resetting to 0.5 kg after app restart, even though the user had updated it to a different value.

## Changes Made

### 1. Added Debug Logging

Added comprehensive logging to trace the tare weight value through the entire save/load cycle:

- **lib/services/settings_service.dart**:

  - Line ~180: Logs raw value read from database
  - Line ~265: Logs loaded value after parsing
  - Line ~300: Logs error if default settings are used
  - Line ~470: Logs value being saved to database
  - Line ~475: Confirms successful save

- **lib/screens/settings/system_settings_screen.dart**:
  - Line ~67: Logs value when loading settings into UI
  - Line ~362: Logs value when saving from UI

### 2. Testing Steps

#### Step 1: Check Current Behavior

1. Run the app and check the console for these log messages:

   ```
   📖 Raw defaultTareWeight from database: [value]
   📥 Loaded defaultTareWeight from database: [value]
   ```

2. Go to System Settings
3. Look for log: `🔧 SystemSettingsScreen: Loading defaultTareWeight = [value]`

#### Step 2: Update Tare Weight

1. In System Settings, tap on "Default Tare Weight"
2. Change the value (e.g., from 0.5 to 1.2)
3. Tap "Save" in the dialog
4. Tap "Save Settings" button at the bottom
5. Check console for:
   ```
   💾 SystemSettingsScreen: Saving defaultTareWeight = 1.2
   💾 Saving defaultTareWeight to database: 1.2
   ✅ Successfully saved settings to database
   ```

#### Step 3: Verify Persistence

1. **Restart the app completely** (close and reopen)
2. Check console logs on startup:
   ```
   📖 Raw defaultTareWeight from database: 1.2
   📥 Loaded defaultTareWeight from database: 1.2
   ```
3. Go to System Settings
4. Verify the tare weight shows your updated value (1.2), not 0.5

#### Step 4: Verify in Coffee Collection

1. Go to Coffee Collection screen
2. Check that the tare weight field is pre-filled with your updated value

### 3. Expected Results

✅ **Success Indicators:**

- Console shows the correct value being saved
- Console shows the correct value being loaded on restart
- System Settings screen displays the updated value
- Coffee Collection screen uses the updated default value

❌ **Failure Indicators:**

- Console shows error: `❌ Error loading system settings`
- Console shows: `⚠️ Using default settings with defaultTareWeight: 0.5`
- Value resets to 0.5 after restart

### 4. Troubleshooting

If the value still resets to 0.5:

1. **Check for database errors:**

   - Look for "Error updating system settings" in console
   - This might indicate a database schema issue

2. **Check if error path is triggered:**

   - If you see "❌ Error loading system settings", there's a problem reading from database
   - Check the full error message for details

3. **Verify database column exists:**

   - The `defaultTareWeight` column should exist in `system_settings` table
   - Schema is defined in `lib/services/database_helper.dart` line ~193

4. **Check for multiple database instances:**
   - Ensure only one database file is being used
   - Check if app is creating a new database on each restart

### 5. Root Cause Analysis

The code structure is correct:

- ✅ Database schema includes `defaultTareWeight` column
- ✅ Save logic includes the field in the update
- ✅ Load logic reads the field from database
- ✅ UI correctly loads and saves the value

**Most likely causes:**

1. Database update is failing silently (check error logs)
2. Database file is being reset/recreated on app restart
3. Settings are being loaded from a different source after initial load
4. There's a timing issue where default settings overwrite loaded settings

### 6. Next Steps

Run the app with the logging in place and share the console output to identify exactly where the value is being lost.
