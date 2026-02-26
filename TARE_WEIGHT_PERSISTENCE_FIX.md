# Default Tare Weight Persistence Fix

## Problem

When users update the default tare weight in System Settings, the value is lost when the app is restarted and defaults back to 0.5 kg.

## Solution

Added comprehensive debug logging to trace the tare weight value through the entire persistence cycle. This will help identify where the value is being lost.

## Changes Made

### 1. lib/services/settings_service.dart

Added logging at key points in the settings lifecycle:

**Loading from database:**

```dart
// Line ~180 - Log raw database value
print('📖 Raw defaultTareWeight from database: ${settingsMap['defaultTareWeight']}');

// Line ~265 - Log parsed value
print('📥 Loaded defaultTareWeight from database: ${settings.defaultTareWeight}');

// Line ~300 - Log if error path is taken
print('❌ Error loading system settings: $e');
print('⚠️ Using default settings with defaultTareWeight: 0.5');
```

**Saving to database:**

```dart
// Line ~470 - Log value being saved
print('💾 Saving defaultTareWeight to database: ${settingsMap['defaultTareWeight']}');

// Line ~475 - Confirm successful save
print('✅ Successfully saved settings to database');
```

### 2. lib/screens/settings/system_settings_screen.dart

Added logging in the UI layer:

**Loading settings:**

```dart
// Line ~67 - Log when loading into UI
print('🔧 SystemSettingsScreen: Loading defaultTareWeight = ${settings.defaultTareWeight}');
```

**Saving settings:**

```dart
// Line ~362 - Log when saving from UI
print('💾 SystemSettingsScreen: Saving defaultTareWeight = $_defaultTareWeight');
```

## How to Test

1. **Run the app** and observe console logs on startup
2. **Go to System Settings** → tap "Default Tare Weight"
3. **Change the value** (e.g., from 0.5 to 1.5)
4. **Save the dialog** and then **Save Settings**
5. **Restart the app completely**
6. **Check if the value persists** by going back to System Settings

## Expected Console Output

### On First Save:

```
💾 SystemSettingsScreen: Saving defaultTareWeight = 1.5
💾 Saving defaultTareWeight to database: 1.5
✅ Successfully saved settings to database
```

### On App Restart:

```
📖 Raw defaultTareWeight from database: 1.5
📥 Loaded defaultTareWeight from database: 1.5
🔧 SystemSettingsScreen: Loading defaultTareWeight = 1.5
```

## Diagnosis

The logging will reveal:

1. **If the value is being saved correctly** - Check for "💾 Saving" and "✅ Successfully saved" messages
2. **If the value is in the database** - Check "📖 Raw defaultTareWeight from database" on restart
3. **If the value is being loaded correctly** - Check "📥 Loaded defaultTareWeight from database"
4. **If errors are occurring** - Look for "❌ Error" messages

## Potential Issues to Look For

### Issue 1: Database Update Failing

**Symptom:** No "✅ Successfully saved" message
**Cause:** Database update is throwing an error
**Solution:** Check error logs for database issues

### Issue 2: Database Being Reset

**Symptom:** "📖 Raw defaultTareWeight from database: 0.5" after restart
**Cause:** Database file is being recreated or reset
**Solution:** Check database initialization logic

### Issue 3: Error Path Being Triggered

**Symptom:** "❌ Error loading system settings" on startup
**Cause:** Exception during settings load
**Solution:** Fix the underlying error shown in logs

### Issue 4: Settings Overwritten After Load

**Symptom:** Correct value loads but then changes to 0.5
**Cause:** Something is resetting settings after initial load
**Solution:** Check for code that creates new SystemSettings instances

## Code Structure Verification

The persistence flow is correctly implemented:

✅ **Database Schema** - `defaultTareWeight REAL DEFAULT 0.5` column exists
✅ **Model** - `SystemSettings` includes `defaultTareWeight` field
✅ **Save Logic** - `updateSystemSettings()` includes field in database update
✅ **Load Logic** - `_loadSettings()` reads field from database
✅ **UI Binding** - Screen correctly loads and saves the value

## Next Steps

1. Run the app with logging enabled
2. Perform the test steps above
3. Share the console output to identify the exact point of failure
4. Based on the logs, we can implement a targeted fix

## Files Modified

- `lib/services/settings_service.dart` - Added 5 log statements
- `lib/screens/settings/system_settings_screen.dart` - Added 2 log statements
- `TARE_WEIGHT_FIX_TESTING.md` - Created testing guide
- `TARE_WEIGHT_PERSISTENCE_FIX.md` - This file
