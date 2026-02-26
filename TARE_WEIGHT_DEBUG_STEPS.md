# Tare Weight Persistence - Debug Steps

## Issue

The tare weight value shows as updated in the app, but after closing and reopening, it reverts to 0.5 kg.

## Enhanced Logging Added

I've added detailed logging to help identify where the issue is occurring. Follow these steps:

## Step 1: Test the Save Process

1. **Open the app** and go to System Settings
2. **Change the tare weight** from 0.5 to a different value (e.g., 1.5)
3. **Click "Save Settings"**
4. **Check the console logs** for these messages:

### Expected Save Logs:

```
💾 SystemSettingsScreen: Saving defaultTareWeight = 1.5
💾 Saving defaultTareWeight to database: 1.5
💾 Updating system_settings where id = default
✅ Successfully saved settings to database (updated 1 row(s))
```

### Possible Issues:

#### Issue A: No rows updated

```
⚠️ WARNING: No rows were updated! The record with id="default" may not exist.
📊 Found 0 record(s) with id="default"
🔧 Attempting to insert new record...
✅ Inserted new system_settings record
```

**Cause**: The system_settings table doesn't have a record with id='default'
**Solution**: The code will now automatically insert the record

#### Issue B: Update fails with error

```
Error updating system settings with all columns: [error message]
```

**Cause**: Database schema mismatch or column doesn't exist
**Solution**: Check the error message for details

## Step 2: Test the Load Process

1. **Completely close the app** (swipe away from recent apps)
2. **Reopen the app**
3. **Check the console logs** for these messages:

### Expected Load Logs:

```
📊 Found 1 system_settings record(s)
📖 System settings record ID: default
📖 Raw defaultTareWeight from database: 1.5
📥 Loaded defaultTareWeight from database: 1.5
```

### Possible Issues:

#### Issue C: Wrong value loaded

```
📖 Raw defaultTareWeight from database: 0.5
```

**Cause**: The value wasn't actually saved to the database
**Solution**: Check Step 1 logs to see if save succeeded

#### Issue D: No records found

```
📊 Found 0 system_settings record(s)
❌ Error loading system settings: [error]
⚠️ Using default settings with defaultTareWeight: 0.5
```

**Cause**: Database is being reset or records are being deleted
**Solution**: Check if database file is being recreated

## Step 3: Verify in UI

1. **Go to System Settings**
2. **Check the console** for:

```
🔧 SystemSettingsScreen: Loading defaultTareWeight = 1.5
```

3. **Verify the UI** shows 1.5 kg (not 0.5 kg)

4. **Go to Coffee Collection screen**
5. **Check that the tare weight field** is pre-filled with 1.5 kg

## Step 4: Database Verification (Advanced)

If the logs show the value is being saved but not loaded, the database might be getting reset. Check:

1. **Database location**: Look for logs showing database path
2. **Multiple databases**: Check if multiple database files exist
3. **Database recreation**: Check if `onCreate` is being called on every app start

## Common Root Causes

### 1. Database Not Initialized

**Symptom**: "No rows were updated" message
**Fix**: The code now auto-inserts the record if missing

### 2. Wrong ID Being Used

**Symptom**: Update succeeds but load fails
**Fix**: Check that both save and load use id='default'

### 3. Database Being Reset

**Symptom**: Value saves but disappears on restart
**Fix**: Check database initialization logic

### 4. Column Doesn't Exist

**Symptom**: Error during update
**Fix**: Run database schema update

### 5. Settings Overwritten After Load

**Symptom**: Correct value loads but then changes
**Fix**: Check for code that creates new SystemSettings instances

## What to Share

Please share the complete console output including:

1. All logs from Step 1 (saving)
2. All logs from Step 2 (loading after restart)
3. Any error messages
4. The actual behavior you observe in the UI

This will help identify exactly where the persistence is failing.

## Quick Fix Attempts

If the issue persists, try these in order:

### Fix 1: Force Database Schema Update

```dart
// In your app initialization
final dbHelper = Get.find<DatabaseHelper>();
await dbHelper.updateDatabaseSchema();
```

### Fix 2: Verify Record Exists

Run this query manually to check:

```sql
SELECT * FROM system_settings WHERE id = 'default';
```

### Fix 3: Clear App Data

As a last resort, clear the app data and let it recreate the database with the correct schema.

## Expected Behavior

After the fix:

- ✅ Changing tare weight shows success message
- ✅ Value persists after app restart
- ✅ System Settings shows correct value
- ✅ Coffee Collection pre-fills correct value
- ✅ Console logs show value being saved and loaded correctly
