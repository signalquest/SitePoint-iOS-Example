# SitePoint Swift Example App for iOS

To make it easy for you to get started integrating your own app with SitePoint, this demo app provides example code for:

- Managing connections to SitePoint sensors
- Aiding SitePoint sensors via NTRIP
- Displaying realtime location and status information

To keep the focus on the required functional code, we've opted to provide additional information in the form of detailed comments where applicable. This approach keeps functional code separate from implementation code, allowing you to see recommendations, tips, and options for implementation where applicable. 

## Getting Started

1. Clone this repo on your development machine.
2. Make sure you have GitHub repository access tokens configured in Xcode for the SitePoint SDK package to be sourced.
3. Last, assign a Development Team and update the Bundle Identifier under your target signing settings with your organization's information.

## Connecting to the SitePoint

1. To ensure that your SitePoint has a sufficient charge, please connect the USB charger. You can verify the charge level once connected in the following steps.
2. From Xcode, build and run the app to a physical device. The Xcode simulator for iOS devices does not support Bluetooth, which is required.
3. When the app loads, find your SitePoint in the scan results and click the `Connect` button.
4. Once connected, spin down the `Status` and `Location` sections.
5. The data in the `Status`` section will update around once per second.
6. The data in the `Location` section will begin to improve in accuracy once the SitePoint acquires satellites and progresses with determining its location.
  - Note: For best results, we recommend placing your SitePoint in a location with open sky view. Placing in a window will take much longer to get an accurate location compared to placement with an open sky view, and may not be able to get into RTK Fixed mode when aided by NTRIP as described below.

## Connect to NTRIP for high-accuracy location

This process requires you to have an active account with an NTRIP provider (RTK network with an NTRIP caster).

For a list of NTRIP providers in US states, please [refer to this GPS World article](https://www.gpsworld.com/finally-a-list-of-public-rtk-base-stations-in-the-u-s/).

1. With the SitePoint still connected, spin down the `NTRIP` section.
3. Fill in your NTRIP server address, port, username, password, and mountpoint.
4. Click the `Connect` button to begin receiving RTCM aiding data and relaying them to the SitePoint.
5. View the success of the last 8 RTCM messages by observing the `aidingQuality` values at the bottom of the `Status` section.
  - The `aidingQuality` is an array of boolean values.
  - True (1) indicates that the message was successfully used, while False (0) indicates that a message was received but could not be used.
  - Occasional False values are not uncommon, which is dependent upon the RTCM message formatting from your NTRIP service provider.
  - SignalQuest's NTRIP parsing complies with all RTCM standards, but we include some additional handling measures for common deviations from the standard.

## Integrate with your app

Using the SitePoint demo app code as a reference, you can begin to add the functionality to your existing app.

If you need any assistance, please submit a request through the [SignalQuest contact page](https://signalquest.com/contact/corporate-information/).

Be sure to check out the [SitePoint iOS SDK documentation](https://signalquest.github.io/SitePoint-iOS-SDK-documentation/documentation/sitepointsdk) for additional information.
