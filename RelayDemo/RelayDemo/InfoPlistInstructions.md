# Info.plist Configuration for Background Modes

To enable background message receiving in your app, you need to update the Info.plist file with the following configurations:

## Required Background Modes

Add the following keys to your Info.plist file:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>processing</string>
    <string>remote-notification</string>
</array>
```

## Background Task Scheduler

Add the following key to register your background task:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.relaydemo.refresh</string>
</array>
```

## How to Update Info.plist

1. Open your project in Xcode
2. Find the Info.plist file in the project navigator
3. Add the keys and values as shown above
4. Save the file

## Additional Configuration

You may also need to update your app's capabilities in Xcode:

1. Select your project in the project navigator
2. Select your target
3. Go to the "Signing & Capabilities" tab
4. Click the "+" button to add a capability
5. Add "Background Modes"
6. Check the following options:
   - Background fetch
   - Background processing
   - Remote notifications

## Testing Background Modes

To test background modes:

1. Run your app on a physical device (not a simulator)
2. Connect the device to your Mac
3. In Xcode, go to Debug > Simulate Background Fetch
4. You should see the background fetch being triggered

## Troubleshooting

If background modes are not working:

1. Make sure you've added all the required keys to Info.plist
2. Verify that you've enabled the capabilities in Xcode
3. Check that you're testing on a physical device
4. Ensure your app is properly registered for background tasks
5. Check the console for any error messages 