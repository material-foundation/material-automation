# Material Automation

This repo contains our Github App backend built using Swift that runs on a Google App Engine flexible environment.

## Usage (xcodebuild)

To build the project and generate an xcode project:
`swift build`
`swift package generate-xcodeproj`

Then open the project in xcode and you are good to go!

You can now build and run the server locally by choosing the MaterialAutomation target in your Xcode.

## Current Features

The backend is listening to Github activity through the `/webhook` endpoint. This endpoint is set up as the Webhook URL when creating the Github App. It then does operations based on the data it has received.

We currently support:
* Live labeling for new Pull Requests
* Live labeling for new Issues
* Bulk labeling for existing Pull Requests and Issues
