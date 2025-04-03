# Main Parts of the Flutter Code

Let me break down the key components of the PostureFit Flutter application:

## 1. Application Structure
The app is built with a tab-based interface containing three main sections:
- *Dashboard Tab*: Shows real-time posture data and device status
- *History Tab*: Displays historical posture data in a graph
- *Exercises Tab*: Lists recommended exercises for posture improvement

## 2. Bluetooth Connectivity
The app uses Flutter's Bluetooth packages to:
- Scan for devices named "PostureFit"
- Connect to the selected device
- Discover services and characteristics
- Subscribe to notifications for posture and battery data

Key methods:
- initBluetooth(): Sets up Bluetooth scanning
- startScan() and stopScan(): Control the device discovery process
- connectToDevice(): Establishes connection with the selected device
- discoverServices(): Finds and subscribes to the required characteristics

## 3. Data Handling & Storage
The app processes and stores posture data:
- onPostureData(): Parses incoming data from the device
- onBatteryData(): Updates battery level information
- loadPostureHistory() and savePostureHistory(): Save and retrieve historical data using SharedPreferences
- dataCollectionTimer: Periodically records posture data for historical tracking

## 4. UI Components

### Dashboard Tab
Shows real-time information:
- Device connection status
- Battery level
- Current posture visualization with color-coding
- Posture deviation measurement
- Calibration button

### History Tab
Visualizes historical data:
- Time-series chart showing posture deviation over time
- Color-coded data points (green, orange, red)
- Summary statistics of good/moderate/bad posture occurrences

### Exercises Tab
Lists recommended exercises with:
- Exercise name and target area
- Duration information
- Expandable cards with detailed instructions
- Placeholders for exercise images

## 5. State Management
The app uses StatefulWidget to manage its state:
- isConnected and isScanning: Track connection status
- postureDeviation and currentPostureStatus: Store posture data
- batteryLevel: Tracks device battery percentage
- postureHistory: Stores historical measurements
- TabController: Manages the tab navigation

## 6. Device Communication
Two key Bluetooth characteristics:
- Posture characteristic: Receives posture data in the format "x,y,z,deviation"
- Battery characteristic: Receives battery percentage

The app interprets the posture data to determine if the user's posture is good (green), moderate (orange), or bad (red) based on the deviation value.

## 7. Device Control
The app provides functions to:
- Connect and disconnect from the device
- Calibrate the device (which tells the device to set the current posture as the reference)
- Visualize the current posture status with appropriate colors

This architecture creates a comprehensive application that connects to the PostureFit hardware, provides real-time feedback, tracks posture history, and offers exercise guidance - all essential components for an effective posture improvement solution.
