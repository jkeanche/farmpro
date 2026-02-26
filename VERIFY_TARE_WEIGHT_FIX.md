# Verify Tare Weight Persistence Fix

## What Was Fixed

I've added enhanced logging and automatic recovery to the tare weight persistence system:

### 1. Enhanced Logging

- Shows exactly how many rows were updated
- Displays the record ID being used
- Logs the raw value from database
- Tracks the complete save/load cycle

### 2. Automatic Recovery

- If no rows are updated (record doesn't exist), the system now automatically inserts a new record
- This handles cases where the database was corrupted or the default record is missing

## Testing Instructions

### Test 1: Change and Save Tare Weight

1. Open the app
2. Go to **Settings** → **System Settings**
3. Tap on **"Default Tare Weight"**
4. Change the value from `0.5` to `1.5`
5. Tap **"Save"** in the dialog
6. Tap **"Save Settings"** at the bottom

**Watch the console for:**

```
💾 SystemSettingsScreen: Saving defaultTareWeight = 1.5
💾 Saving defaultTareWeight to database: 1.5
💾 Updating system_settings where id = default
✅ Successfully saved settings to database (updated 1 row(s))
```

**If you see:**

```
⚠️ WARNING: No rows were updated!
```

This means the record didn't exist, but the system will automatically create it.

### Test 2: Verify Persistence After Restart

1. **Completely close the app** (swipe it away from recent apps)
2. **Reopen the app**
3. **Watch the console** for startup logs:

```
📊 Found 1 system_settings record(s)
📖 System settings record ID: default
📖 Raw defaultTareWeight from database: 1.5
📥 Loaded defaultTareWeight from database: 1.5
```

4. Go to **Settings** → **System Settings**
5. **Verify** the tare weight shows `1.5 kg` (not 0.5)

### Test 3: Verify in Coffee Collection

1. Go to **Coffee Collection** screen
2. **Check** that the "Tare Weight" field is pre-filled with `1.5`
3. This confirms the value is being used throughout the app

## What to Look For

### ✅ Success Indicators:

- Console shows "updated 1 row(s)"
- After restart, console shows "Raw defaultTareWeight from database: 1.5"
- System Settings UI displays 1.5 kg
- Coffee Collection pre-fills 1.5 kg
- Value persists across multiple app restarts

### ❌ Failure Indicators:

- Console shows "updated 0 row(s)" repeatedly (even after auto-insert)
- After restart, console shows "Raw defaultTareWeight from database: 0.5"
- System Settings UI reverts to 0.5 kg
- Error messages in console

## Possible Issues and Solutions

### Issue 1: Database Record Missing

**Symptom**: "No rows were updated" on first save
**Solution**: System will auto-insert the record
**Action**: Try saving again after the auto-insert

### Issue 2: Multiple Database Files

**Symptom**: Value saves but loads 0.5 on restart
**Solution**: App might be using different database files
**Action**: Check database file path in logs

### Issue 3: Database Schema Outdated

**Symptom**: Error during update mentioning column doesn't exist
**Solution**: Database schema needs update
**Action**: Clear app data or run schema migration

### Issue 4: Settings Overwritten

**Symptom**: Correct value loads but then changes to 0.5
**Solution**: Something is resetting settings after load
**Action**: Check for initialization code that creates default settings

## Share These Logs

If the issue persists, please share:

1. **Complete console output** from saving (Test 1)
2. **Complete console output** from loading (Test 2)
3. **Screenshots** of:
   - System Settings screen showing the tare weight value
   - Coffee Collection screen showing the pre-filled tare weight
4. **Any error messages** that appear

## Expected Final Result

After this fix:

- ✅ You can change the tare weight in System Settings
- ✅ The app shows "Successfully saved settings"
- ✅ After closing and reopening the app, the value persists
- ✅ System Settings shows your custom value (e.g., 1.5 kg)
- ✅ Coffee Collection uses your custom value
- ✅ The value remains even after multiple app restarts

## Quick Verification Command

If you have access to the database file, you can verify directly:

```sql
SELECT id, defaultTareWeight FROM system_settings;
```

Expected result:

```
id      | defaultTareWeight
--------|------------------
default | 1.5
```

If you see `0.5` here after saving `1.5`, then the save is not working.
If you see `1.5` here but the app shows `0.5`, then the load is not working.
